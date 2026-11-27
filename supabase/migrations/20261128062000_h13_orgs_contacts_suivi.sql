-- H13 ORGS (3/4) : suivi des demandes de contact envoyées aux talents — statut, réponse du talent, délai (CDC : « contact avec un candidat », suivi des échanges).
-- Avant : talent_contacts (20261115200300, élargi par 20261127020300) n'avait ni statut, ni réponse, ni délai : l'organisation ne savait jamais si sa demande avait été vue ou acceptée
--   et le talent ne pouvait pas répondre depuis la plateforme.
--  1. talent_contacts : status (sent | seen | accepted | declined | expired), seen_at, responded_at, response (texte facultatif du talent, 500 car.), expires_at (délai de réponse : 14 jours par défaut,
--     valeur technique sans effet financier), org_id (organisation au nom de laquelle la demande est envoyée). Les anciennes lignes gardent status = 'sent' sans échéance (jamais « expirées » rétroactivement).
--     Un déclencheur pose l'échéance et, pour les anciens appelants (talent_contact_request), l'organisation (fiche entreprise du compte ou son équipe active).
--  2. talent_contact_seen(p_id) : le talent marque une demande reçue comme vue (idempotent). talent_contact_respond(p_id, p_decision, p_message) : le talent accepte ou décline UNE fois ; refusé si la
--     demande est expirée ou déjà traitée ; l'expéditeur est notifié une seule fois. my_talent_contact_requests renvoie statut, échéance et réponse.
--  3. pool_contact_requests_get(p_org, p_status) : suivi côté organisation (propriétaire, administrateurs et lecteurs ; « finance » et autres organisations refusés) = demandes émises par l'organisation
--     et son équipe, talents encore visibles uniquement, avec statut effectif, réponse, délai de réponse en heures et indicateurs (envoyées, vues, acceptées, déclinées, expirées, en attente, délai moyen).
--     pool_contacts_get (historique du vivier) expose statut et réponse des demandes de la plateforme.
--  4. contact_requests_expire() (tâche planifiée, pg_cron 07h20) : passe en « expirée » les demandes sans réponse après l'échéance et prévient l'expéditeur une fois.
--  5. discovery_contact_request enregistre l'organisation choisie (org_id).
-- Additive et rejouable. Retour arrière : drop function talent_contact_seen(uuid), talent_contact_respond(uuid, text, text), pool_contact_requests_get(uuid, text), contact_requests_expire(), _contact_defaults() ;
--   drop trigger trg_talent_contacts_defaults ; recréer discovery_contact_request, my_talent_contact_requests (20261127020300), pool_contacts_get (20261126060300) ; select cron.unschedule('contact-requests-expire').

alter table talent_contacts add column if not exists status text not null default 'sent';
alter table talent_contacts add column if not exists seen_at timestamptz;
alter table talent_contacts add column if not exists responded_at timestamptz;
alter table talent_contacts add column if not exists response text not null default '';
alter table talent_contacts add column if not exists expires_at timestamptz;
alter table talent_contacts add column if not exists org_id uuid references profiles (id) on delete set null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'talent_contacts_status_check') then
    alter table talent_contacts add constraint talent_contacts_status_check check (status in ('sent', 'seen', 'accepted', 'declined', 'expired'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'talent_contacts_response_len') then
    alter table talent_contacts add constraint talent_contacts_response_len check (char_length(response) <= 500);
  end if;
end $$;
create index if not exists talent_contacts_org on talent_contacts (org_id, created_at desc);
create index if not exists talent_contacts_pending on talent_contacts (expires_at) where status in ('sent', 'seen');

create or replace function _contact_defaults() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.expires_at := coalesce(new.expires_at, now() + interval '14 days');
  if new.org_id is null then
    new.org_id := coalesce(
      (select p.id from profiles p where p.id = new.sender_id and p.role::text = 'company'),
      (select m.owner_id from company_members m where m.user_id = new.sender_id and m.status = 'active' order by m.joined_at nulls last limit 1));
  end if;
  return new;
end $$;
revoke all on function _contact_defaults() from public, anon, authenticated;
drop trigger if exists trg_talent_contacts_defaults on talent_contacts;
create trigger trg_talent_contacts_defaults before insert on talent_contacts for each row execute function _contact_defaults();

-- Une demande sans réponse après l'échéance est « expirée », même avant le passage de la tâche planifiée.
create or replace function _contact_status(p_status text, p_expires timestamptz) returns text
language sql immutable set search_path = public as $$
  select case when p_status in ('sent', 'seen') and p_expires is not null and p_expires < now() then 'expired' else p_status end
$$;
revoke all on function _contact_status(text, timestamptz) from public, anon, authenticated;

create or replace function discovery_contact_request(p_student uuid, p_kind text, p_message text default '', p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_msg text := left(_clean_text(p_message), 500); v_id uuid;
begin
  if p_kind is null or p_kind not in ('contact', 'interview', 'internship_offer', 'job_offer', 'mission_offer') then raise exception 'Type de demande inconnu'; end if;
  if p_student is null or p_student = auth.uid() or p_student = v_org then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not _discovery_ok(p_student) then raise exception 'Talent introuvable'; end if;
  if p_kind <> 'contact' and char_length(v_msg) < 10 then raise exception 'Précisez votre demande (10 caractères minimum).'; end if;
  if (select count(*) from talent_contacts where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix demandes par jour au plus'; end if;
  if v_msg <> '' and (select count(*) from talent_contacts where sender_id = auth.uid() and message = v_msg and created_at > now() - interval '1 day') >= 3 then
    raise exception 'Ce même message a déjà été envoyé à trois talents aujourd''hui : personnalisez-le.';
  end if;
  begin
    insert into talent_contacts (sender_id, target_id, kind, message, org_id) values (auth.uid(), p_student, p_kind, v_msg, v_org) returning id into v_id;
  exception when unique_violation then
    raise exception 'Vous avez déjà adressé cette demande à ce talent aujourd''hui';
  end;
  perform notify_user(p_student, 'talent_contact',
    case p_kind when 'internship_offer' then 'Proposition de stage' when 'job_offer' then 'Proposition d''emploi' when 'mission_offer' then 'Proposition de mission' when 'interview' then 'Invitation à un entretien' else 'Demande de contact' end,
    left(_talent_sender_label(v_org) || case p_kind when 'internship_offer' then ' vous propose un stage' when 'job_offer' then ' vous propose un emploi' when 'mission_offer' then ' vous propose une mission'
                                                    when 'interview' then ' vous invite à un entretien' else ' souhaite vous contacter' end || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('from', auth.uid(), 'kind', p_kind, 'contact', v_id));
  return jsonb_build_object('ok', true, 'id', v_id, 'kind', p_kind, 'student', p_student);
end $$;

-- ============================================================ côté talent
create or replace function my_talent_contact_requests(p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'kind', c.kind, 'message', c.message,
      'sender', coalesce((select _talent_sender_label(m.owner_id) from company_members m where m.user_id = c.sender_id and m.status = 'active' and _org_approved(m.owner_id) limit 1), _talent_sender_label(c.sender_id)),
      'created_at', c.created_at, 'status', _contact_status(c.status, c.expires_at), 'expires_at', c.expires_at, 'responded_at', c.responded_at, 'response', c.response,
      'can_respond', _contact_status(c.status, c.expires_at) in ('sent', 'seen')) order by c.created_at desc)
    from (select * from talent_contacts where target_id = auth.uid() order by created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) c), '[]'::jsonb);
end $$;

create or replace function talent_contact_seen(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c talent_contacts%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from talent_contacts where id = p_id and target_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if c.status = 'sent' then
    update talent_contacts set status = 'seen', seen_at = now() where id = c.id;
    return 'seen';
  end if;
  return _contact_status(c.status, c.expires_at);
end $$;

create or replace function talent_contact_respond(p_id uuid, p_decision text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c talent_contacts%rowtype; v_msg text := left(_clean_text(p_message), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_decision is null or p_decision not in ('accepted', 'declined') then raise exception 'Choisissez Accepter ou Décliner'; end if;
  select * into c from talent_contacts where id = p_id and target_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if c.status in ('accepted', 'declined') then raise exception 'Vous avez déjà répondu à cette demande'; end if;
  if _contact_status(c.status, c.expires_at) = 'expired' then raise exception 'Cette demande a expiré'; end if;
  update talent_contacts set status = p_decision, responded_at = now(), seen_at = coalesce(seen_at, now()), response = coalesce(v_msg, '') where id = c.id;
  perform notify_user(c.sender_id, 'talent_contact_reply',
    case p_decision when 'accepted' then 'Demande acceptée' else 'Demande déclinée' end,
    left(display_name(auth.uid()) || case p_decision when 'accepted' then ' a accepté votre demande' else ' a décliné votre demande' end || case when coalesce(v_msg, '') <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('contact', c.id, 'student', auth.uid(), 'status', p_decision, 'org', c.org_id));
  return p_decision;
end $$;

-- ============================================================ côté organisation
create or replace function pool_contact_requests_get(p_org uuid default null, p_status text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); v_items jsonb; v_stats jsonb;
begin
  if p_status is not null and p_status not in ('sent', 'seen', 'accepted', 'declined', 'expired', 'pending') then raise exception 'Statut inconnu'; end if;
  select coalesce(jsonb_agg(x.j order by x.created_at desc), '[]'::jsonb) into v_items from (
    select c.created_at, jsonb_build_object('id', c.id, 'student', c.target_id, 'name', display_name(c.target_id), 'kind', c.kind, 'message', c.message, 'created_at', c.created_at,
        'status', _contact_status(c.status, c.expires_at), 'expires_at', c.expires_at, 'seen_at', c.seen_at, 'responded_at', c.responded_at, 'response', c.response,
        'delay_hours', case when c.responded_at is not null then round((extract(epoch from (c.responded_at - c.created_at)) / 3600)::numeric, 1) end,
        'author', coalesce(display_name(c.sender_id), 'Un membre'), 'in_pool', _pool_in_pool(v_org, c.target_id)) j
      from talent_contacts c
     where (c.org_id = v_org or (c.org_id is null and (c.sender_id = v_org or exists (select 1 from company_members m where m.owner_id = v_org and m.user_id = c.sender_id and m.status = 'active'))))
       and _talent_listable(c.target_id)
       and (p_status is null or _contact_status(c.status, c.expires_at) = p_status or (p_status = 'pending' and _contact_status(c.status, c.expires_at) in ('sent', 'seen')))
     order by c.created_at desc limit 200) x;
  select jsonb_build_object('total', count(*)::int,
      'pending', count(*) filter (where _contact_status(c.status, c.expires_at) in ('sent', 'seen'))::int,
      'seen', count(*) filter (where _contact_status(c.status, c.expires_at) = 'seen')::int,
      'accepted', count(*) filter (where c.status = 'accepted')::int,
      'declined', count(*) filter (where c.status = 'declined')::int,
      'expired', count(*) filter (where _contact_status(c.status, c.expires_at) = 'expired')::int,
      'avg_delay_hours', (select round(avg(extract(epoch from (r.responded_at - r.created_at)) / 3600)::numeric, 1) from talent_contacts r
                           where r.responded_at is not null and r.org_id = v_org and _talent_listable(r.target_id)))
    into v_stats
    from talent_contacts c
   where (c.org_id = v_org or (c.org_id is null and (c.sender_id = v_org or exists (select 1 from company_members m where m.owner_id = v_org and m.user_id = c.sender_id and m.status = 'active'))))
     and _talent_listable(c.target_id);
  return jsonb_build_object('items', v_items, 'stats', v_stats);
end $$;

create or replace function pool_contacts_get(p_student uuid, p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false);
begin
  if not _pool_in_pool(v_org, p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  return coalesce((select jsonb_agg(x.j order by x.ts desc) from (
      select c.occurred_at as ts, jsonb_build_object('id', c.id, 'source', 'manuel', 'channel', c.channel, 'summary', c.summary, 'at', c.occurred_at, 'author', coalesce(display_name(c.author_id), 'Un membre')) j
      from talent_pool_contacts c where c.org_id = v_org and c.student_id = p_student
      union all
      select t.created_at, jsonb_build_object('id', t.id, 'source', 'plateforme',
        'channel', case t.kind when 'internship_offer' then 'proposition_de_stage' when 'interview' then 'entretien' when 'job_offer' then 'proposition_d_emploi' when 'mission_offer' then 'proposition_de_mission' else 'message' end,
        'summary', t.message, 'at', t.created_at, 'author', coalesce(display_name(t.sender_id), 'Un membre'),
        'status', _contact_status(t.status, t.expires_at), 'response', t.response, 'responded_at', t.responded_at)
      from talent_contacts t where t.target_id = p_student
        and (t.sender_id = v_org or t.org_id = v_org or exists (select 1 from company_members m where m.owner_id = v_org and m.user_id = t.sender_id and m.status = 'active'))) x), '[]'::jsonb);
end $$;

-- ============================================================ expiration planifiée
create or replace function contact_requests_expire() returns integer
language plpgsql security definer set search_path = public as $$
declare c record; v_n integer := 0;
begin
  for c in select * from talent_contacts where status in ('sent', 'seen') and expires_at is not null and expires_at < now() order by expires_at limit 500 for update skip locked loop
    update talent_contacts set status = 'expired' where id = c.id;
    perform notify_user(c.sender_id, 'talent_contact_reply', 'Demande restée sans réponse',
      left('Votre demande à ' || display_name(c.target_id) || ' a expiré sans réponse.', 500), jsonb_build_object('contact', c.id, 'student', c.target_id, 'status', 'expired', 'org', c.org_id));
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke all on function contact_requests_expire() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('contact-requests-expire') where exists (select 1 from cron.job where jobname = 'contact-requests-expire');
  perform cron.schedule('contact-requests-expire', '20 7 * * *', 'select public.contact_requests_expire()');
exception when others then
  raise notice 'pg_cron indisponible : contact_requests_expire() doit être planifiée autrement (%).', sqlerrm;
end $$;

revoke all on function discovery_contact_request(uuid, text, text, uuid), my_talent_contact_requests(integer), talent_contact_seen(uuid), talent_contact_respond(uuid, text, text),
  pool_contact_requests_get(uuid, text), pool_contacts_get(uuid, uuid) from public, anon;
grant execute on function discovery_contact_request(uuid, text, text, uuid), my_talent_contact_requests(integer), talent_contact_seen(uuid), talent_contact_respond(uuid, text, text),
  pool_contact_requests_get(uuid, text), pool_contacts_get(uuid, uuid) to authenticated;
