-- H13 ORGS (1/4) : suivi d'une mission de bout en bout, côté ORGANISATION (équipe comprise) et côté étudiant.
--   Avant : publier une mission passait par l'équipe (save_mission p_owner), mais décider d'une proposition, valider ou refuser un jalon, déclarer un paiement, clôturer, annuler
--   et écrire dans le dossier exigeaient « client_id = auth.uid() » : un administrateur d'équipe ne pouvait pas agir au nom de l'organisation, et aucun avis n'existait.
--   1. Droits côté client, relus dans l'organisation CLIENTE de la mission (company_role_of(client_id)) :
--        propriétaire et administrateur : décident (proposition, jalon), clôturent, annulent, écrivent, déclarent un paiement et donnent l'avis ;
--        finance : déclare le paiement d'un jalon validé et LIT ; lecteur : LIT seulement (aucune décision) ; une autre organisation, un tiers : « Mission introuvable ».
--      Les règles existantes sont conservées à l'identique (compte suspendu refusé, jalons dans l'ordre, preuve obligatoire, un seul prestataire retenu, capacité vendeur imposée par
--      le déclencheur trg_zz_l4_proposal de 20261122030000, aucune règle financière : montants, jalons 30/40/30 et déclaration de paiement entre les parties sont inchangés).
--   2. Lecture : les membres actifs lisent besoins, propositions, jalons, accord et dossier de leur organisation (RLS) ; le cloisonnement existant (H2 département, prestataire retenu, client) est conservé : aucune ouverture
--      de la table missions à d'autres comptes.
--   3. Notifications : les administrateurs d'équipe reçoivent aussi nouvelle proposition, jalon livré, message du prestataire et paiement confirmé/non reçu (une fois chacun) ;
--      le propriétaire est prévenu quand un administrateur décide à sa place ; jamais de doublon (états terminaux, verrous sur la ligne de mission).
--   4. Avis de mission (mission_reviews) : une fois la mission CLÔTURÉE, le client note le prestataire et le prestataire note le client, une fois chacun (1 à 5, commentaire facultatif).
--   5. org_missions(p_owner) : missions de l'organisation (jalons, preuves, paiement tracé, avis) pour tout membre actif, avec les droits du rôle dans CETTE organisation.
-- Additive et rejouable. Retour arrière : recréer decide_proposal (20261118030000), decide_milestone (20261031000200), mission_close, milestone_pay_declare, send_mission_message,
--   mission_invoice (20261117045100), mission_cancel (20261115210000), is_mission_party (20261031000200), is_mission_participant (20261120020300, cloisonnement H2), les politiques « missions : ... » ;
--   drop trigger trg_h13_team_proposal, trg_h13_team_milestone, trg_h13_team_message ; drop function _h13_mission_team_fanout(), _h13_org_member(uuid), org_missions(uuid),
--   mission_review_save(uuid, integer, text), mission_reviews_get(uuid), _mission_client_gate(uuid, text) ; drop table mission_reviews.

-- ============================================================ 1. droits côté client
-- Retourne la mission verrouillée si la personne connectée y a le droit demandé ; sinon « Mission introuvable » (une autre organisation ne distingue pas l'existence d'un dossier).
--   p_level : 'decide' (propriétaire, administrateur), 'pay' (+ finance), 'read' (tout membre actif).
create or replace function _mission_client_gate(p_mission uuid, p_level text) returns missions
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; v_role text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found then raise exception 'Mission introuvable'; end if;
  v_role := company_role_of(m.client_id);
  if v_role is null then raise exception 'Mission introuvable'; end if;
  if p_level = 'read' then return m; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  if v_role in ('owner', 'admin') or (p_level = 'pay' and v_role = 'finance') then
    select * into m from missions where id = p_mission for update;
    return m;
  end if;
  if p_level = 'pay' then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''organisation'; end if;
  raise exception 'Réservé au propriétaire et aux administrateurs de l''organisation';
end $$;
revoke all on function _mission_client_gate(uuid, text) from public, anon, authenticated;

create or replace function is_mission_participant(p_mission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from missions m where m.id = p_mission and (m.client_id = auth.uid() or company_role_of(m.client_id) is not null
           or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')))
      or coalesce(current_role_name()::text, '') = 'admin' or (coalesce(current_role_name()::text, '') = 'dept' and _mission_dept_sees(p_mission));
$$;

-- Les parties qui écrivent et déposent : le client (propriétaire ou administrateur d'équipe) et le prestataire retenu.
create or replace function is_mission_party(p_mission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from missions m where m.id = p_mission and (m.client_id = auth.uid() or company_role_of(m.client_id) = 'admin'
           or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')));
$$;

-- company_role_of n'est pas exécutable par les rôles clients : les politiques passent par cette aide (vrai seulement pour un membre actif connecté de l'organisation indiquée).
create or replace function _h13_org_member(p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and company_role_of(p_owner) is not null
$$;
revoke all on function _h13_org_member(uuid) from public;
grant execute on function _h13_org_member(uuid) to anon, authenticated;

-- Lecture directe d'une mission (politique de 20261117040500, cloisonnement H2 conservé) : le client, son équipe, le prestataire retenu, le département concerné et l'administration.
-- is_mission_participant est déjà exécutable par anon (garde interne : sans compte, faux).
drop policy if exists "missions : propriétaire et participants" on missions;
create policy "missions : propriétaire et participants" on missions for select using (client_id = auth.uid() or is_mission_participant(id));
-- Politiques de 20261120020400 (cloisonnement H2) + lecture des membres actifs de l'organisation cliente.
drop policy if exists "propositions : auteur, client, département" on mission_proposals;
create policy "propositions : auteur, client, département" on mission_proposals for select
  using (author_id = auth.uid() or exists (select 1 from missions m where m.id = mission_id and (m.client_id = auth.uid() or _h13_org_member(m.client_id)))
         or (current_role_name() in ('admin') or _dept_sees(author_id)));
drop policy if exists "jalons : client, prestataire retenu, département" on mission_milestones;
create policy "jalons : client, prestataire retenu, département" on mission_milestones for select
  using (exists (select 1 from missions m where m.id = mission_id and (m.client_id = auth.uid() or _h13_org_member(m.client_id)
           or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')))
         or (current_role_name() in ('admin') or _dept_sees_mission_provider(mission_id)));
drop policy if exists "accords de mission : parties et département" on mission_agreements;
create policy "accords de mission : parties et département" on mission_agreements for select
  using (client_id = auth.uid() or _h13_org_member(client_id) or provider_id = auth.uid() or (current_role_name() in ('admin') or _dept_sees(provider_id)));

-- ============================================================ 2. décisions de l'organisation
create or replace function decide_proposal(p_id uuid, p_accept boolean, p_reason text default null) returns text
language plpgsql security definer set search_path = public as $$
declare p mission_proposals%rowtype; m missions%rowtype; v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 300), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from mission_proposals where id = p_id;
  if not found then raise exception 'Proposition introuvable'; end if;
  begin
    m := _mission_client_gate(p.mission_id, 'decide');
  exception when others then
    if sqlerrm like 'Réservé%' or sqlerrm like 'Votre compte est suspendu%' then raise; end if;
    raise exception 'Proposition introuvable';
  end;
  select * into p from mission_proposals where id = p_id for update;
  if p.status <> 'submitted' then raise exception 'Cette proposition est déjà traitée'; end if;
  if not p_accept then
    update mission_proposals set status = 'declined', decided_at = now(), decline_reason = v_reason where id = p.id;
    perform notify_user(p.author_id, 'mission', 'Proposition non retenue',
      'Besoin « ' || coalesce(m.title, m.number) || ' »' || case when v_reason is null then '' else ' · Motif : ' || v_reason end, jsonb_build_object('mission_id', m.id));
    return 'declined';
  end if;
  if m.status <> 'published' then raise exception 'Ce besoin est déjà attribué'; end if;
  if exists (select 1 from profiles where id = p.author_id and coalesce(suspended, false)) then raise exception 'Ce talent n''est plus disponible'; end if;
  perform _mission_accept(p.id, null, false);
  if m.client_id <> auth.uid() then
    perform notify_user(m.client_id, 'company_team', 'Prestataire retenu par votre équipe', display_name(auth.uid()) || ' a retenu une proposition pour « ' || coalesce(m.title, m.number) || ' ».', jsonb_build_object('mission_id', m.id, 'by', auth.uid()));
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Prestataire retenu au nom de l''organisation', coalesce(m.title, m.number), 'Entreprise', 'Info');
  end if;
  return 'accepted';
end $$;

create or replace function decide_milestone(p_mission uuid, p_position smallint, p_validate boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare j mission_milestones%rowtype; m missions%rowtype; who uuid;
begin
  m := _mission_client_gate(p_mission, 'decide');
  select * into j from mission_milestones where mission_id = m.id and position = p_position for update;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status <> 'submitted' then raise exception 'Ce jalon n''a pas été livré'; end if;
  if not p_validate and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Précisez la correction demandée'; end if;
  update mission_milestones set status = case when p_validate then 'validated' else 'correction' end, note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), updated_at = now() where id = j.id;
  if p_validate and not exists (select 1 from mission_milestones where mission_id = m.id and status <> 'validated') then
    update missions set status = 'delivered', updated_at = now() where id = m.id;
  end if;
  select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  if who is not null then
    insert into notifications (user_id, kind, title, body, data) values (who, 'mission', case when p_validate then 'Jalon validé' else 'Correction demandée' end, j.title, jsonb_build_object('mission_id', m.id, 'position', p_position));
  end if;
  if m.client_id <> auth.uid() then
    perform notify_user(m.client_id, 'company_team', case when p_validate then 'Jalon validé par votre équipe' else 'Correction demandée par votre équipe' end,
      display_name(auth.uid()) || ' : ' || j.title || ' (' || coalesce(m.title, m.number) || ').', jsonb_build_object('mission_id', m.id, 'position', p_position, 'by', auth.uid()));
  end if;
  return case when p_validate then 'validated' else 'correction' end;
end $$;

create or replace function mission_close(p_mission uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; who uuid;
begin
  m := _mission_client_gate(p_mission, 'decide');
  if m.status = 'closed' then return 'closed'; end if;
  if m.status <> 'delivered' then raise exception 'La mission se clôture une fois tous les jalons validés'; end if;
  update missions set status = 'closed', updated_at = now() where id = m.id;
  select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  if who is not null then
    perform notify_user(who, 'mission', 'Mission clôturée', coalesce(m.title, m.number) || ' : le client a clôturé la mission.', jsonb_build_object('mission_id', m.id));
  end if;
  if m.client_id <> auth.uid() then
    perform notify_user(m.client_id, 'company_team', 'Mission clôturée par votre équipe', display_name(auth.uid()) || ' a clôturé « ' || coalesce(m.title, m.number) || ' ».', jsonb_build_object('mission_id', m.id, 'by', auth.uid()));
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Mission clôturée au nom de l''organisation', coalesce(m.title, m.number), 'Entreprise', 'Info');
  end if;
  return 'closed';
end $$;

create or replace function milestone_pay_declare(p_mission uuid, p_position smallint, p_method text, p_reference text default null) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; j mission_milestones%rowtype; who uuid; v_method text := nullif(left(trim(coalesce(p_method, '')), 40), ''); v_ref text := nullif(left(trim(coalesce(p_reference, '')), 80), '');
begin
  m := _mission_client_gate(p_mission, 'pay');
  select * into j from mission_milestones where mission_id = m.id and position = p_position for update;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status <> 'validated' then raise exception 'Le paiement se déclare une fois le jalon validé'; end if;
  if j.pay_status = 'confirmed' then raise exception 'Ce paiement est déjà confirmé par le prestataire'; end if;
  if v_method is null then raise exception 'Indiquez le moyen de paiement utilisé'; end if;
  update mission_milestones set pay_status = 'declared', pay_method = v_method, pay_reference = v_ref, pay_declared_at = now(), pay_confirmed_at = null, updated_at = now() where id = j.id;
  select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  if who is not null then
    perform notify_user(who, 'mission', 'Paiement déclaré', j.title || ' : ' || j.amount || ' FCFA réglés par ' || v_method || '. Confirmez la réception dans « Mes missions ».', jsonb_build_object('mission_id', m.id, 'position', p_position));
  end if;
  return 'declared';
end $$;

create or replace function mission_cancel(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; r record;
begin
  begin
    m := _mission_client_gate(p_id, 'decide');
  exception when others then
    if sqlerrm like 'Réservé%' or sqlerrm like 'Votre compte est suspendu%' or sqlerrm like 'Connexion%' then raise; end if;
    raise exception 'Besoin introuvable';
  end;
  if m.status = 'cancelled' then return 'cancelled'; end if;
  if m.status not in ('draft', 'published') then raise exception 'Ce besoin est déjà attribué : contactez le département pour l''arrêter'; end if;
  update missions set status = 'cancelled', updated_at = now() where id = m.id;
  for r in select author_id from mission_proposals where mission_id = m.id and status = 'submitted' loop
    perform notify_user(r.author_id, 'mission', 'Besoin retiré', 'Le besoin « ' || coalesce(m.title, m.number) || ' » a été retiré par son auteur.', jsonb_build_object('mission_id', m.id));
  end loop;
  update mission_proposals set status = 'declined', decided_at = now() where mission_id = m.id and status = 'submitted';
  if m.client_id <> auth.uid() then
    perform notify_user(m.client_id, 'company_team', 'Besoin retiré par votre équipe', display_name(auth.uid()) || ' a retiré « ' || coalesce(m.title, m.number) || ' ».', jsonb_build_object('mission_id', m.id, 'by', auth.uid()));
  end if;
  return 'cancelled';
end $$;

create or replace function send_mission_message(p_mission uuid, p_body text, p_file uuid default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid bigint; who uuid; other uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into m from missions where id = p_mission;
  if not found or not is_mission_party(p_mission) then raise exception 'Dossier introuvable'; end if;
  if m.status not in ('assigned', 'in_progress', 'delivered') then raise exception 'Le dossier s''ouvre une fois la mission attribuée'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  if p_file is not null and not exists (select 1 from files where id = p_file and owner_id = auth.uid() and scope = 'mission' and ref = m.id) then
    raise exception 'Fichier introuvable dans ce dossier';
  end if;
  if company_role_of(m.client_id) is not null then
    select author_id into other from mission_proposals where mission_id = m.id and status = 'accepted';
  else
    other := m.client_id;
  end if;
  if other is not null then perform chat_guard(other); end if;
  if (select count(*) from mission_messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then
    raise exception 'Trop de messages : patientez un instant';
  end if;
  insert into mission_messages (mission_id, sender_id, body, file_id) values (m.id, auth.uid(), left(trim(p_body), 2000), p_file) returning id into mid;
  who := other;
  if who is not null and who <> auth.uid() then
    insert into notifications (user_id, kind, title, body, data) values (who, 'mission', 'Nouveau message du dossier', coalesce(m.title, m.number), jsonb_build_object('mission_id', m.id));
  end if;
  return mid;
end $$;

-- ============================================================ 3. notifications de l'équipe (administrateurs), une par personne
-- Le propriétaire reçoit déjà ces notifications des fonctions d'origine ; les administrateurs actifs, non suspendus, qui ne sont pas l'auteur de l'événement les reçoivent aussi.
create or replace function _h13_mission_team_fanout() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_mission uuid; m missions%rowtype; v_title text; v_body text; v_actor uuid := auth.uid(); r record; v_pos integer;
begin
  if tg_table_name = 'mission_proposals' then
    if new.status <> 'submitted' or (tg_op = 'UPDATE' and old.status = 'submitted') or coalesce(current_role_name()::text, '') in ('dept', 'admin') then return null; end if;
    v_mission := new.mission_id; v_title := 'Nouvelle proposition';
  elsif tg_table_name = 'mission_milestones' then
    v_mission := new.mission_id; v_pos := new.position;
    if tg_op <> 'UPDATE' then return null; end if;
    if new.status = 'submitted' and old.status is distinct from 'submitted' then v_title := 'Jalon livré';
    elsif new.pay_status = 'confirmed' and old.pay_status is distinct from 'confirmed' then v_title := 'Paiement confirmé';
    elsif new.pay_status = 'unpaid' and old.pay_status = 'declared' then v_title := 'Paiement non reçu';
    else return null; end if;
  else
    v_mission := new.mission_id; v_title := 'Nouveau message du dossier';
    if exists (select 1 from missions where id = v_mission and client_id = new.sender_id) or new.sender_id = any (select user_id from company_members where owner_id = (select client_id from missions where id = v_mission) and status = 'active') then
      return null;
    end if;
  end if;
  select * into m from missions where id = v_mission;
  if not found then return null; end if;
  v_body := coalesce(m.title, m.number);
  for r in select cm.user_id from company_members cm join profiles p on p.id = cm.user_id
            where cm.owner_id = m.client_id and cm.status = 'active' and cm.role = 'admin' and not coalesce(p.suspended, false) and cm.user_id is distinct from v_actor loop
    insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'mission', v_title, left(v_body, 500), jsonb_build_object('mission_id', m.id, 'owner', m.client_id) || case when v_pos is null then '{}'::jsonb else jsonb_build_object('position', v_pos) end);
  end loop;
  return null;
end $$;
revoke all on function _h13_mission_team_fanout() from public, anon, authenticated;
drop trigger if exists trg_h13_team_proposal on mission_proposals;
create trigger trg_h13_team_proposal after insert or update of status on mission_proposals for each row execute function _h13_mission_team_fanout();
drop trigger if exists trg_h13_team_milestone on mission_milestones;
create trigger trg_h13_team_milestone after update on mission_milestones for each row execute function _h13_mission_team_fanout();
drop trigger if exists trg_h13_team_message on mission_messages;
create trigger trg_h13_team_message after insert on mission_messages for each row execute function _h13_mission_team_fanout();

-- ============================================================ 4. avis de mission
create table if not exists mission_reviews (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references missions (id) on delete cascade,
  reviewer_id uuid not null references profiles (id) on delete cascade,
  reviewed_id uuid not null references profiles (id) on delete cascade,
  direction text not null check (direction in ('client_to_provider', 'provider_to_client')),
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 1000),
  created_at timestamptz not null default now(),
  unique (mission_id, direction)
);
create index if not exists mission_reviews_reviewed on mission_reviews (reviewed_id, created_at desc);
alter table mission_reviews enable row level security;
revoke all on mission_reviews from public, anon, authenticated;

create or replace function mission_review_save(p_mission uuid, p_rating integer, p_comment text default null) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; v_role text; v_provider uuid; v_dir text; v_to uuid; v_comment text := nullif(left(_clean_text(p_comment), 1000), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into m from missions where id = p_mission for update;
  if not found then raise exception 'Mission introuvable'; end if;
  select author_id into v_provider from mission_proposals where mission_id = m.id and status = 'accepted';
  v_role := company_role_of(m.client_id);
  if v_role in ('owner', 'admin') then
    v_dir := 'client_to_provider'; v_to := v_provider;
  elsif v_role is not null then
    raise exception 'Réservé au propriétaire et aux administrateurs de l''organisation';
  elsif v_provider = auth.uid() then
    v_dir := 'provider_to_client'; v_to := m.client_id;
  else
    raise exception 'Mission introuvable';
  end if;
  if m.status <> 'closed' then raise exception 'L''avis se donne une fois la mission clôturée'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'La note va de 1 à 5'; end if;
  if v_to is null then raise exception 'Mission introuvable'; end if;
  if exists (select 1 from mission_reviews where mission_id = m.id and direction = v_dir) then raise exception 'Un avis a déjà été donné pour cette mission'; end if;
  insert into mission_reviews (mission_id, reviewer_id, reviewed_id, direction, rating, comment) values (m.id, auth.uid(), v_to, v_dir, p_rating, v_comment);
  perform notify_user(v_to, 'mission', 'Nouvel avis sur une mission', coalesce(m.title, m.number) || ' : ' || p_rating || '/5.', jsonb_build_object('mission_id', m.id));
  return v_dir;
end $$;

create or replace function mission_reviews_get(p_mission uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m missions%rowtype; v_client boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or not is_mission_participant(p_mission) then raise exception 'Mission introuvable'; end if;
  v_client := company_role_of(m.client_id) is not null;
  return coalesce((select jsonb_agg(jsonb_build_object('direction', r.direction, 'rating', r.rating, 'comment', r.comment, 'created_at', r.created_at,
      'mine', r.direction = case when v_client then 'client_to_provider' else 'provider_to_client' end) order by r.created_at)
    from mission_reviews r where r.mission_id = m.id), '[]'::jsonb);
end $$;

-- ============================================================ 5. missions de l'organisation (tout membre actif), avec les droits du rôle dans CETTE organisation
create or replace function org_missions(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_role text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  v_role := company_role_of(v_owner);
  return coalesce((select jsonb_agg(_mission_json(x.id, 'client') || jsonb_build_object(
        'my_role', v_role, 'can_decide', v_role in ('owner', 'admin'), 'can_pay', v_role in ('owner', 'admin', 'finance'),
        'reviews', coalesce((select jsonb_agg(jsonb_build_object('direction', r.direction, 'rating', r.rating, 'comment', r.comment, 'created_at', r.created_at) order by r.created_at)
                              from mission_reviews r where r.mission_id = x.id),                               '[]'::jsonb)) order by x.updated_at desc)
    from (select id, updated_at from missions where client_id = v_owner and status not in ('draft', 'cancelled') order by updated_at desc limit 100) x), '[]'::jsonb);
end $$;

revoke all on function decide_proposal(uuid, boolean, text), decide_milestone(uuid, smallint, boolean, text), mission_close(uuid), milestone_pay_declare(uuid, smallint, text, text),
  mission_cancel(uuid), send_mission_message(uuid, text, uuid), mission_review_save(uuid, integer, text), mission_reviews_get(uuid), org_missions(uuid) from public, anon;
grant execute on function decide_proposal(uuid, boolean, text), decide_milestone(uuid, smallint, boolean, text), mission_close(uuid), milestone_pay_declare(uuid, smallint, text, text),
  mission_cancel(uuid), send_mission_message(uuid, text, uuid), mission_review_save(uuid, integer, text), mission_reviews_get(uuid), org_missions(uuid) to authenticated;
