-- 20261031c — Correctifs de sécurité et de cohérence de 20261031a et 20261031b (audit du 31/10/2026).
-- Dépend de 20261031a et 20261031b. Idempotente. Testée sur une réplique exacte de la production (voir
-- docs/final-audit/AUDIT_REGULARISATION_MIGRATIONS_20261031.md et supabase/tests/security_31_rest.py).
-- Nom au même format que les migrations voisines : la CLI l'ignore tant que l'historique n'est pas régularisé
-- (aucune application accidentelle par « db push »).

-- ============================================================ 1. missions : politiques héritées et visibilité
-- La production a été créée avec des noms de politiques sans accents ; 20261031a ne supprimait que les noms accentués.
drop policy if exists "mise à jour des missions" on missions;
drop policy if exists "mise a jour des missions" on missions;
drop policy if exists "un client crée sa mission" on missions;
drop policy if exists "un client cree sa mission" on missions;
drop policy if exists "missions du client ou de l'administration" on missions;
drop policy if exists "missions du client ou de l administration" on missions;
drop policy if exists "missions : propriétaire, publiées, département" on missions;
drop policy if exists "missions : visibilité restreinte" on missions;
-- Un besoin PUBLIÉ est visible des comptes connectés ; une mission attribuée, en cours ou livrée ne l'est plus que des
-- parties (client, prestataire retenu) et du département (is_mission_participant inclut dept et admin).
create policy "missions : visibilité restreinte" on missions for select
  using (client_id = auth.uid() or (status = 'published' and auth.uid() is not null) or is_mission_participant(id));
-- La politique appelle is_mission_participant : les visiteurs doivent pouvoir l'évaluer (elle renvoie faux sans compte).
grant execute on function is_mission_participant(uuid) to anon;

-- Politiques permissives de schema.sql que les migrations ne retiraient que sous leur nom sans accents
-- (absentes en production ; présentes dans tout environnement construit depuis schema.sql).
drop policy if exists "journal alimenté par les utilisateurs connectés" on audit_log;
drop policy if exists "validation par le département" on listings;

-- ============================================================ 2. contrôle explicite de l'authentification
create or replace function assign_mission(p_mission uuid, p_team text) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_team is null or char_length(trim(p_team)) not between 2 and 120 then raise exception 'Équipe invalide'; end if;
  select * into m from missions where id = p_mission;
  if not found or m.status <> 'published' then raise exception 'Ce besoin n''est pas attribuable'; end if;
  update missions set status = 'assigned', assigned_team = trim(p_team), assigned_by = auth.uid(), updated_at = now() where id = m.id;
  insert into notifications (user_id, kind, title, body, data) values (m.client_id, 'mission', 'Besoin attribué', 'Équipe : ' || trim(p_team), jsonb_build_object('mission_id', m.id));
  return 'assigned';
end $$;

create or replace function submit_milestone(p_mission uuid, p_position smallint) returns text
language plpgsql security definer set search_path = public as $$
declare j mission_milestones%rowtype; m missions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or not exists (select 1 from mission_proposals where mission_id = m.id and author_id = auth.uid() and status = 'accepted') then raise exception 'Mission introuvable'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status not in ('pending', 'correction') then raise exception 'Ce jalon est déjà livré'; end if;
  update mission_milestones set status = 'submitted', updated_at = now() where id = j.id;
  update missions set status = 'in_progress', updated_at = now() where id = m.id and status = 'assigned';
  insert into notifications (user_id, kind, title, body, data) values (m.client_id, 'mission', 'Jalon livré', j.title || ' : à valider', jsonb_build_object('mission_id', m.id, 'position', p_position));
  return 'submitted';
end $$;

create or replace function decide_milestone(p_mission uuid, p_position smallint, p_validate boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare j mission_milestones%rowtype; m missions%rowtype; who uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission and client_id = auth.uid();
  if not found then raise exception 'Mission introuvable'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position;
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
  return case when p_validate then 'validated' else 'correction' end;
end $$;

-- ============================================================ 3. dossier de mission : seules les parties écrivent et déposent
-- Le département garde la lecture (modération, via les politiques) mais n'intervient pas dans l'échange.
create or replace function is_mission_party(p_mission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from missions m where m.id = p_mission and (m.client_id = auth.uid()
           or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')));
$$;

create or replace function send_mission_message(p_mission uuid, p_body text, p_file uuid default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid bigint; who uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or not is_mission_party(p_mission) then raise exception 'Dossier introuvable'; end if;
  if m.status not in ('assigned', 'in_progress', 'delivered') then raise exception 'Le dossier s''ouvre une fois la mission attribuée'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  if p_file is not null and not exists (select 1 from files where id = p_file and owner_id = auth.uid() and scope = 'mission' and ref = m.id) then
    raise exception 'Fichier introuvable dans ce dossier';
  end if;
  insert into mission_messages (mission_id, sender_id, body, file_id) values (m.id, auth.uid(), left(trim(p_body), 2000), p_file) returning id into mid;
  if m.client_id = auth.uid() then
    select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  else
    who := m.client_id;
  end if;
  if who is not null and who <> auth.uid() then
    insert into notifications (user_id, kind, title, body, data) values (who, 'mission', 'Nouveau message du dossier', coalesce(m.title, m.number), jsonb_build_object('mission_id', m.id));
  end if;
  return mid;
end $$;

create or replace function register_file(p_scope text, p_ref uuid, p_path text, p_name text, p_mime text, p_size integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare fid uuid; lim integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if (storage.foldername(p_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier invalide'; end if;
  if not exists (select 1 from storage.objects where bucket_id = 'project-files' and name = p_path) then raise exception 'Fichier non déposé'; end if;
  if p_name ~* '\.(exe|bat|cmd|com|msi|scr|js|vbs|ps1|sh|jar|apk|dll)$' then raise exception 'Type de fichier refusé'; end if;
  lim := case when p_mime like 'image/%' then 5242880 else 52428800 end;
  if p_size is null or p_size < 1 or p_size > lim then raise exception 'Fichier trop lourd (5 Mo par image, 50 Mo sinon)'; end if;
  if p_scope = 'media' and coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Médiathèque réservée au département'; end if;
  if p_scope = 'project' and (p_ref is null or not exists (select 1 from projects where id = p_ref and owner_id = auth.uid())) then raise exception 'Projet introuvable'; end if;
  if p_scope = 'mission' and (p_ref is null or not is_mission_party(p_ref)) then raise exception 'Dossier introuvable'; end if;
  insert into files (owner_id, scope, ref, path, name, mime, size_bytes) values (auth.uid(), p_scope, p_ref, p_path, left(p_name, 160), p_mime, p_size) returning id into fid;
  return fid;
end $$;

-- ============================================================ 4. projets : pas de contenu public non validé
-- En cours d'examen : non modifiable. Approuvé : toute modification repasse en validation (le département est notifié).
create or replace function save_project(p_id uuid, p_title text, p_summary text, p_department text, p_links jsonb, p_submit boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; l jsonb := coalesce(p_links, '{}'::jsonb); next_status text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(l) <> 'object' or pg_column_size(l) > 4000 then raise exception 'Liens invalides'; end if;
  if p_id is null then
    if p_submit and char_length(trim(coalesce(p_summary, ''))) < 30 then raise exception 'Présentez le projet en 30 caractères minimum avant de l''envoyer'; end if;
    insert into projects (owner_id, title, summary, department, links, status)
    values (auth.uid(), trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), nullif(left(trim(coalesce(p_department, '')), 120), ''), l, case when p_submit then 'submitted' else 'draft' end)
    returning id into pid;
    return pid;
  end if;
  select * into p from projects where id = p_id and owner_id = auth.uid() for update;
  if not found then raise exception 'Projet introuvable'; end if;
  if p.status = 'submitted' then raise exception 'Projet en cours d''examen : modification impossible jusqu''à la décision'; end if;
  if p_submit and p.status not in ('draft', 'rejected') then raise exception 'Ce projet est déjà envoyé'; end if;
  if p_submit and char_length(trim(coalesce(nullif(trim(coalesce(p_summary, '')), ''), p.summary, ''))) < 30 then
    raise exception 'Présentez le projet en 30 caractères minimum avant de l''envoyer';
  end if;
  next_status := case when p_submit or p.status = 'approved' then 'submitted' else p.status end;
  update projects set title = trim(p_title), summary = coalesce(nullif(left(trim(coalesce(p_summary, '')), 4000), ''), summary),
    department = coalesce(nullif(left(trim(coalesce(p_department, '')), 120), ''), department), links = links || l,
    status = next_status, updated_at = now() where id = p.id;
  if p.status = 'approved' then
    insert into notifications (user_id, kind, title, body, data)
    select id, 'project', 'Projet modifié à revalider', trim(p_title), jsonb_build_object('project_id', p.id) from profiles where role = 'dept';
  end if;
  return p.id;
end $$;

-- ============================================================ 5. certificats : code de 64 bits (non énumérable)
do $$
declare c text;
begin
  for c in select conname from pg_constraint where conrelid = 'public.certificates'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%BE-CERT-%' loop
    execute format('alter table certificates drop constraint %I', c);
  end loop;
end $$;
-- Les codes à 8 caractères éventuellement émis avant ce correctif restent valides.
alter table certificates add constraint certificates_code_format check (code ~ '^BE-CERT-([0-9A-F]{8}|[0-9A-F]{16})$');

create or replace function issue_certificate(p_kind text, p_subject text, p_holder_email text, p_holder_name text, p_department text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare l listings%rowtype; h profiles%rowtype; c text; fp text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Émission réservée au département ou à l''administrateur'; end if;
  if p_kind not in ('product', 'project', 'talent') then raise exception 'Type de certificat inconnu'; end if;
  if p_subject is null or char_length(trim(p_subject)) not between 3 and 160 then raise exception 'Objet du certificat : 3 à 160 caractères'; end if;
  if p_kind = 'product' then
    select * into l from listings where title = trim(p_subject) and status = 'approved' order by created_at desc limit 1;
    if not found then raise exception 'Seul un produit validé peut être certifié'; end if;
  end if;
  if nullif(trim(coalesce(p_holder_email, '')), '') is not null then
    select * into h from profiles where lower(email) = lower(trim(p_holder_email));
    if not found then raise exception 'Titulaire introuvable'; end if;
  end if;
  if coalesce(h.name, trim(coalesce(p_holder_name, ''))) = '' then raise exception 'Nom du titulaire obligatoire'; end if;
  if exists (select 1 from certificates where subject_kind = p_kind and lower(subject_title) = lower(trim(p_subject)) and coalesce(holder_id::text, holder_name) = coalesce(h.id::text, trim(p_holder_name)) and not revoked) then
    raise exception 'Un certificat valide existe déjà pour ce titulaire et cet objet';
  end if;
  c := 'BE-CERT-' || upper(encode(gen_random_bytes(8), 'hex'));
  fp := encode(digest(c || '|' || p_kind || '|' || trim(p_subject) || '|' || coalesce(h.id::text, trim(p_holder_name)) || '|' || now()::text, 'sha256'), 'hex');
  insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, department, listing_id, issued_by, fingerprint)
  values (c, p_kind, trim(p_subject), h.id, coalesce(h.name, trim(p_holder_name)), nullif(left(trim(coalesce(p_department, '')), 120), ''), l.id, auth.uid(), fp);
  if h.id is not null then
    insert into notifications (user_id, kind, title, body, data) values (h.id, 'certificate', 'Certificat délivré', trim(p_subject) || ' · ' || c, jsonb_build_object('code', c));
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Certificat émis', c, 'Certificats', 'Sensible');
  return c;
end $$;

-- ============================================================ 6. code de retrait : aléa cryptographique, essais journalisés et limités
alter table orders add column if not exists pickup_attempts smallint not null default 0;

create or replace function my_pickup_code(p_number text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_number and buyer_id = auth.uid() for update;
  if not found then raise exception 'Commande introuvable'; end if;
  if not o.paid or o.cancelled or o.cancelled_at is not null then raise exception 'Le code de retrait est délivré une fois la commande payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà retirée'; end if;
  -- nouveau code si aucun n'existe, ou si le précédent a été bloqué par des essais erronés
  if o.pickup_code is null or o.pickup_attempts >= 5 then
    update orders set pickup_code = lpad(((('x' || encode(gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0'), pickup_attempts = 0
    where id = o.id returning pickup_code into o.pickup_code;
  end if;
  return o.pickup_code;
end $$;

-- Un code erroné n'interrompt plus la transaction (sinon la trace d'audit était annulée avec elle) : il est compté,
-- journalisé et signalé par la valeur « incorrect ». Après 5 essais, la remise est bloquée jusqu'à un nouveau code.
create or replace function confirm_pickup(p_number text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au personnel du kiosque'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not o.paid or o.cancelled then raise exception 'Commande introuvable ou non payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà remise'; end if;
  if o.pickup_attempts >= 5 then raise exception 'Trop d''essais : l''acheteur doit afficher un nouveau code de retrait'; end if;
  if o.pickup_code is null or o.pickup_code <> trim(coalesce(p_code, '')) then
    update orders set pickup_attempts = pickup_attempts + 1 where id = o.id;
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Code de retrait erroné', o.number, 'Kiosques', 'Sensible');
    return 'incorrect';
  end if;
  update orders set picked_up_at = now(), status = 3 where id = o.id;
  update order_lines set fulfillment = 4 where order_id = o.id;
  insert into notifications (user_id, kind, title, body, data) values (o.buyer_id, 'order', 'Commande retirée', o.number, jsonb_build_object('order_number', o.number));
  return 'delivered';
end $$;

-- ============================================================ 7. hygiène des fonctions
alter function sync_order_cancelled() set search_path = public;
-- Les fonctions de déclencheur ne s'appellent pas directement (le droit EXECUTE n'est pas vérifié au déclenchement).
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.prorettype = 'trigger'::regtype loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;

revoke all on function is_mission_party(uuid) from public, anon;
grant execute on function is_mission_party(uuid) to authenticated;
revoke all on function assign_mission(uuid, text), submit_milestone(uuid, smallint), decide_milestone(uuid, smallint, boolean, text),
  send_mission_message(uuid, text, uuid), register_file(text, uuid, text, text, text, integer), save_project(uuid, text, text, text, jsonb, boolean),
  issue_certificate(text, text, text, text, text), my_pickup_code(text), confirm_pickup(text, text) from public, anon;
grant execute on function assign_mission(uuid, text), submit_milestone(uuid, smallint), decide_milestone(uuid, smallint, boolean, text),
  send_mission_message(uuid, text, uuid), register_file(text, uuid, text, text, text, integer), save_project(uuid, text, text, text, jsonb, boolean),
  issue_certificate(text, text, text, text, text), my_pickup_code(text), confirm_pickup(text, text) to authenticated;

-- ============================================================ RETOUR ARRIÈRE (manuel) : réappliquer les définitions de 20261031a/b
-- (fonctions assign_mission, submit_milestone, decide_milestone, send_mission_message, register_file, save_project,
--  issue_certificate, my_pickup_code, confirm_pickup), puis :
-- drop policy if exists "missions : visibilité restreinte" on missions;
-- create policy "missions : propriétaire, publiées, département" on missions for select
--   using (client_id = auth.uid() or (status <> 'draft' and auth.uid() is not null) or current_role_name() in ('dept', 'admin'));
-- drop function if exists is_mission_party(uuid);
-- alter table certificates drop constraint if exists certificates_code_format;
-- alter table certificates add constraint certificates_code_check check (code ~ '^BE-CERT-[0-9A-F]{8}$');   -- seulement si aucun code à 16 caractères
-- alter table orders drop column if exists pickup_attempts;
