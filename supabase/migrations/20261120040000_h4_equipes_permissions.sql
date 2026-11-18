-- Lot H4 : centre d'administration et équipes internes.
-- Finance et Support ne sont plus des acteurs autonomes : ce sont des équipes internes de l'administrateur global, avec deux équipes de plus
-- (Sécurité et modération, Technique). Les droits d'un agent viennent de permissions explicites attribuées (et retirées) par l'administrateur global.
--  1. tables admin_teams, admin_permissions (catalogue), admin_team_members (agent, équipe, permissions[]), admin_team_history (traçabilité) ;
--  2. fonctions has_admin_permission(perm), has_any_admin_permission(perms[]), is_admin_team_member() : l'administrateur global a toutes les permissions ;
--     un agent (rôle technique finance ou support, non suspendu) n'a que celles de ses équipes ;
--  3. attribution / retrait par l'administrateur global (RPC), journalisés dans admin_team_history ET audit_log ;
--  4. migration des comptes finance / support existants vers leur équipe, avec EXACTEMENT les droits qu'ils avaient (aucun flux interrompu) ;
--     un nouveau compte finance / support est inscrit automatiquement dans son équipe avec les droits de base de cette équipe ;
--  5. is_platform_staff() ne reconnaît plus un support sans équipe ni permission de support/sécurité/technique.
-- Les valeurs de l'enum app_role ne changent pas (compatibilité).
-- Retour arrière : drop trigger trg_admin_team_autoenroll on profiles; drop function admin_team_member_set(uuid, text, text[], text), admin_team_member_remove(uuid, text, text),
--   admin_teams_overview(), admin_team_members_list(text), admin_team_candidates(text), admin_team_history_list(uuid, int), my_admin_access(), has_admin_permission(text),
--   has_any_admin_permission(text[]), is_admin_team_member(), _admin_perm_check(uuid, text[]), _admin_team_autoenroll(), _admin_team_defaults(text);
--   drop table admin_team_history, admin_team_members, admin_permissions, admin_teams; puis redéfinir is_platform_staff() comme dans 20261103000100.

-- ============================================================ 1. Tables
create table if not exists admin_teams (
  code text primary key check (code in ('finance', 'support', 'security', 'tech')),
  name text not null,
  description text not null,
  position integer not null default 0
);

create table if not exists admin_permissions (
  code text primary key check (code ~ '^(finance|support|security|tech)\.[a-z_]+$'),
  team_code text not null references admin_teams (code),
  label text not null,
  description text not null,
  sensitive boolean not null default false,
  position integer not null default 0
);

create table if not exists admin_team_members (
  user_id uuid not null references profiles (id) on delete cascade,
  team_code text not null references admin_teams (code),
  permissions text[] not null default '{}',
  granted_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, team_code)
);
create index if not exists admin_team_members_team on admin_team_members (team_code);

create table if not exists admin_team_history (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  actor_id uuid references profiles (id) on delete set null,
  user_id uuid not null references profiles (id) on delete cascade,
  team_code text not null,
  action text not null check (action in ('grant', 'update', 'revoke', 'auto_enroll', 'auto_revoke', 'migration')),
  before_permissions text[] not null default '{}',
  after_permissions text[] not null default '{}',
  note text
);
create index if not exists admin_team_history_user on admin_team_history (user_id, created_at desc);

alter table admin_teams enable row level security;
alter table admin_permissions enable row level security;
alter table admin_team_members enable row level security;
alter table admin_team_history enable row level security;
revoke all on admin_teams, admin_permissions, admin_team_members, admin_team_history from public, anon, authenticated;
grant select on admin_teams, admin_permissions, admin_team_members, admin_team_history to authenticated;
drop policy if exists "équipes : lecture" on admin_teams;
create policy "équipes : lecture" on admin_teams for select to authenticated using (auth.uid() is not null);
drop policy if exists "permissions : lecture" on admin_permissions;
create policy "permissions : lecture" on admin_permissions for select to authenticated using (auth.uid() is not null);
drop policy if exists "membres d'équipe : soi-même et administrateur" on admin_team_members;
create policy "membres d'équipe : soi-même et administrateur" on admin_team_members for select to authenticated
  using (user_id = auth.uid() or coalesce(current_role_name()::text, '') = 'admin');
drop policy if exists "historique d'équipe : administrateur" on admin_team_history;
create policy "historique d'équipe : administrateur" on admin_team_history for select to authenticated
  using (coalesce(current_role_name()::text, '') = 'admin');

-- ============================================================ 2. Catalogue des équipes et des permissions
insert into admin_teams (code, name, description, position) values
  ('finance', 'Finance', 'Paiements, transactions, commissions, répartitions, remboursements, retraits, factures, rapprochements et rapports financiers.', 1),
  ('support', 'Support', 'Tickets, assistance, réclamations, litiges, commandes problématiques, demandes des utilisateurs et historique des interventions.', 2),
  ('security', 'Sécurité et modération', 'Surveillance, signalements, fraudes et abus, comptes suspects, protection des utilisateurs et modération des contenus.', 3),
  ('tech', 'Technique', 'Supervision technique, configuration, intégrations, services, journaux techniques, maintenance et diagnostic.', 4)
on conflict (code) do update set name = excluded.name, description = excluded.description, position = excluded.position;

insert into admin_permissions (code, team_code, label, description, sensitive, position) values
  ('finance.read', 'finance', 'Consulter les tableaux financiers', 'Vue d''ensemble, paiements, versements, séquestre et registre financier en lecture.', false, 1),
  ('finance.payments', 'finance', 'Valider les paiements', 'Confirmer ou refuser un paiement déclaré (paiements manuels et messagerie de paiement).', true, 2),
  ('finance.payouts', 'finance', 'Traiter les retraits et versements', 'Créer, accepter, verser ou rejeter les retraits des vendeurs et des parrains.', true, 3),
  ('finance.refunds', 'finance', 'Rembourser', 'Décider les remboursements, les verser et gérer les remboursements d''événements et de campagnes.', true, 4),
  ('finance.transfers', 'finance', 'Virements Mobile Money', 'Préparer un virement depuis le compte marchand de la plateforme (rapprochements).', true, 5),
  ('finance.split', 'finance', 'Répartition et séquestre', 'Modifier la règle de répartition, bloquer, débloquer ou forcer la libération d''un montant en séquestre.', true, 6),
  ('support.tickets', 'support', 'Répondre aux demandes d''aide', 'Lire et traiter les tickets d''assistance des utilisateurs.', false, 1),
  ('support.claims', 'support', 'Réclamations', 'Lire, répondre et trancher les réclamations d''achat (la décision de remboursement exige en plus une permission de remboursement).', false, 2),
  ('support.disputes', 'support', 'Litiges', 'Instruire et clore les litiges de commande.', false, 3),
  ('support.orders', 'support', 'Commandes problématiques et bornes', 'Retraits en borne, livraisons échouées, codes QR, suivi des commandes à problème.', false, 4),
  ('support.requests', 'support', 'Demandes des utilisateurs', 'Pièces justificatives, propositions d''établissements, suppressions de compte, certifications et mentors à examiner.', false, 5),
  ('support.refunds', 'support', 'Décider un remboursement', 'Accepter ou refuser une demande de remboursement et l''inclure dans la décision d''une réclamation (sans effectuer le versement).', true, 6),
  ('security.moderation', 'security', 'Modérer les contenus', 'Publications, stories, boutiques, annonces, communautés et lives : valider, masquer, retirer.', false, 1),
  ('security.reports', 'security', 'Traiter les signalements', 'Lire et clore les signalements d''annonces, de boutiques, de conversations, de commentaires et de lives.', false, 2),
  ('security.accounts', 'security', 'Comptes suspects et double authentification', 'Signaler un compte suspect à l''administrateur, réinitialiser une double authentification après vérification d''identité.', true, 3),
  ('security.audit', 'security', 'Journal d''audit', 'Consulter le journal d''audit global (lecture seule).', false, 4),
  ('tech.config', 'tech', 'Configuration', 'Lire les réglages de la plateforme et modifier les réglages techniques et les modèles de notification.', true, 1),
  ('tech.integrations', 'tech', 'Intégrations et clés d''API', 'Superviser le hub d''intégrations, créer et révoquer des clés d''API.', true, 2),
  ('tech.logs', 'tech', 'Journaux techniques', 'Consulter le journal d''audit et les files d''envoi et de synchronisation (lecture seule).', false, 3),
  ('tech.maintenance', 'tech', 'Maintenance et diagnostic', 'Supervision des bornes, incidents, planification et état technique des services.', false, 4)
on conflict (code) do update set team_code = excluded.team_code, label = excluded.label, description = excluded.description, sensitive = excluded.sensitive, position = excluded.position;

-- Droits de base d'un nouvel agent : ni opération sensible, ni droit d'une autre équipe.
create or replace function _admin_team_defaults(p_team text) returns text[]
language sql immutable set search_path = public as $$
  select case p_team
    when 'finance' then array['finance.read', 'finance.payments', 'finance.payouts', 'finance.refunds', 'finance.transfers']
    when 'support' then array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests']
    when 'security' then array['security.moderation', 'security.reports']
    when 'tech' then array['tech.logs', 'tech.maintenance']
    else array[]::text[] end
$$;
revoke all on function _admin_team_defaults(text) from public, anon, authenticated;

-- Les permissions d'une ligne appartiennent toutes à l'équipe de la ligne.
create or replace function _admin_team_members_check() returns trigger
language plpgsql set search_path = public as $$
declare bad text;
begin
  select p into bad from unnest(new.permissions) p
    where not exists (select 1 from admin_permissions a where a.code = p and a.team_code = new.team_code) limit 1;
  if bad is not null then raise exception 'Permission inconnue ou d''une autre équipe : %', bad; end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists trg_admin_team_members_check on admin_team_members;
create trigger trg_admin_team_members_check before insert or update on admin_team_members for each row execute function _admin_team_members_check();

-- ============================================================ 3. Fonctions de permission
create or replace function _admin_perm_check(p_uid uuid, p_perms text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select p_uid is not null and (
    exists (select 1 from profiles p where p.id = p_uid and not coalesce(p.suspended, false) and p.role::text = 'admin')
    or exists (select 1 from profiles p join admin_team_members m on m.user_id = p.id
               where p.id = p_uid and not coalesce(p.suspended, false) and p.role::text in ('finance', 'support') and m.permissions && p_perms)
  )
$$;
revoke all on function _admin_perm_check(uuid, text[]) from public, anon, authenticated;

create or replace function has_admin_permission(p_perm text) returns boolean
language sql stable security definer set search_path = public as $$
  select _admin_perm_check(auth.uid(), array[p_perm])
$$;
create or replace function has_any_admin_permission(p_perms text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select _admin_perm_check(auth.uid(), p_perms)
$$;
create or replace function is_admin_team_member() returns boolean
language sql stable security definer set search_path = public as $$
  select _admin_perm_check(auth.uid(), (select coalesce(array_agg(code), array[]::text[]) from admin_permissions))
$$;
revoke all on function has_admin_permission(text), has_any_admin_permission(text[]), is_admin_team_member() from public, anon;
grant execute on function has_admin_permission(text), has_any_admin_permission(text[]), is_admin_team_member() to authenticated;

-- is_platform_staff() : l'administrateur, ou un agent qui a au moins une permission de support, de sécurité ou de maintenance.
create or replace function is_platform_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select _admin_perm_check(auth.uid(), array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds',
                                             'security.moderation', 'security.reports', 'security.accounts', 'tech.maintenance'])
$$;

-- Mes accès : rôle, équipes et permissions de la personne connectée (le client s'en sert pour afficher le bon centre d'administration).
create or replace function my_admin_access() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'role', v_role,
    'is_admin', v_role = 'admin',
    'teams', case when v_role = 'admin'
      then (select coalesce(jsonb_object_agg(t.code, (select coalesce(jsonb_agg(a.code order by a.position), '[]'::jsonb) from admin_permissions a where a.team_code = t.code)), '{}'::jsonb) from admin_teams t)
      when v_role in ('finance', 'support')
      then (select coalesce(jsonb_object_agg(m.team_code, to_jsonb(m.permissions)), '{}'::jsonb) from admin_team_members m where m.user_id = auth.uid() and cardinality(m.permissions) > 0)
      else '{}'::jsonb end);
end $$;
revoke all on function my_admin_access() from public, anon;
grant execute on function my_admin_access() to authenticated;

-- ============================================================ 4. Gestion par l'administrateur global
create or replace function _admin_only() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
end $$;
revoke all on function _admin_only() from public, anon, authenticated;

create or replace function _admin_team_log(p_user uuid, p_team text, p_action text, p_before text[], p_after text[], p_note text) returns void
language plpgsql security definer set search_path = public as $$
declare v_name text; v_target text;
begin
  insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
  values (auth.uid(), p_user, p_team, p_action, coalesce(p_before, '{}'), coalesce(p_after, '{}'), nullif(left(btrim(coalesce(p_note, '')), 300), ''));
  if p_action in ('grant', 'update', 'revoke') then
    select name into v_name from profiles where id = auth.uid();
    select name into v_target from profiles where id = p_user;
    insert into audit_log (actor, actor_id, action, target, category, level)
    values (coalesce(v_name, 'Administrateur'),
            auth.uid(),
            case p_action when 'grant' then 'Équipe : agent ajouté' when 'update' then 'Équipe : permissions modifiées' else 'Équipe : agent retiré' end,
            left(coalesce(v_target, p_user::text) || ' · ' || p_team || ' · ' || array_to_string(coalesce(p_after, '{}'), ', '), 200),
            'Équipes', 'Critique');
  end if;
end $$;
revoke all on function _admin_team_log(uuid, text, text, text[], text[], text) from public, anon, authenticated;

create or replace function admin_team_member_set(p_user uuid, p_team text, p_permissions text[], p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_susp boolean; v_name text; v_before text[]; v_after text[]; v_exists boolean; v_bad text;
begin
  perform _admin_only();
  if p_user is null or p_user = auth.uid() then raise exception 'Vous ne pouvez pas modifier vos propres droits d''équipe'; end if;
  if not exists (select 1 from admin_teams where code = p_team) then raise exception 'Équipe inconnue'; end if;
  select role::text, coalesce(suspended, false), name into v_role, v_susp, v_name from profiles where id = p_user;
  if v_role is null then raise exception 'Compte introuvable'; end if;
  if v_role not in ('finance', 'support') then
    raise exception 'Seuls les comptes de rôle Finance ou Support rejoignent une équipe : changez d''abord le rôle du compte dans « Comptes, rôles et permissions »';
  end if;
  if v_susp then raise exception 'Ce compte est suspendu'; end if;
  select coalesce(array_agg(distinct x order by x), '{}') into v_after from unnest(coalesce(p_permissions, '{}')) x where nullif(btrim(x), '') is not null;
  if cardinality(v_after) = 0 then raise exception 'Choisissez au moins une permission, ou retirez l''agent de l''équipe'; end if;
  select x into v_bad from unnest(v_after) x where not exists (select 1 from admin_permissions a where a.code = x and a.team_code = p_team) limit 1;
  if v_bad is not null then raise exception 'Permission inconnue ou d''une autre équipe : %', v_bad; end if;
  select permissions, true into v_before, v_exists from admin_team_members where user_id = p_user and team_code = p_team for update;
  v_exists := coalesce(v_exists, false);
  if v_exists and v_before = v_after then
    return jsonb_build_object('user', p_user, 'team', p_team, 'permissions', to_jsonb(v_after), 'changed', false);
  end if;
  insert into admin_team_members (user_id, team_code, permissions, granted_by) values (p_user, p_team, v_after, auth.uid())
  on conflict (user_id, team_code) do update set permissions = excluded.permissions, granted_by = auth.uid(), updated_at = now();
  perform _admin_team_log(p_user, p_team, case when v_exists then 'update' else 'grant' end, v_before, v_after, p_note);
  insert into notifications (user_id, kind, title, body, data)
  values (p_user, 'security', case when v_exists then 'Vos permissions d''équipe ont changé' else 'Vous rejoignez une équipe d''administration' end,
          'Équipe ' || (select name from admin_teams where code = p_team) || ' : ' || (select string_agg(a.label, ', ' order by a.position) from admin_permissions a where a.code = any(v_after)) || '.',
          jsonb_build_object('team', p_team));
  return jsonb_build_object('user', p_user, 'team', p_team, 'permissions', to_jsonb(v_after), 'changed', true);
end $$;

create or replace function admin_team_member_remove(p_user uuid, p_team text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_before text[];
begin
  perform _admin_only();
  if p_user is null or p_user = auth.uid() then raise exception 'Vous ne pouvez pas modifier vos propres droits d''équipe'; end if;
  delete from admin_team_members where user_id = p_user and team_code = p_team returning permissions into v_before;
  if not found then raise exception 'Cet agent ne fait pas partie de cette équipe'; end if;
  perform _admin_team_log(p_user, p_team, 'revoke', v_before, '{}', p_note);
  insert into notifications (user_id, kind, title, body, data)
  values (p_user, 'security', 'Vous quittez une équipe d''administration', 'Vos permissions de l''équipe ' || coalesce((select name from admin_teams where code = p_team), p_team) || ' ont été retirées.', jsonb_build_object('team', p_team));
  return jsonb_build_object('user', p_user, 'team', p_team, 'removed', true);
end $$;

create or replace function admin_teams_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _admin_only();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', t.code, 'name', t.name, 'description', t.description,
      'members', (select count(*)::int from admin_team_members m join profiles p on p.id = m.user_id where m.team_code = t.code),
      'permissions', (select coalesce(jsonb_agg(jsonb_build_object('code', a.code, 'label', a.label, 'description', a.description, 'sensitive', a.sensitive) order by a.position), '[]'::jsonb)
                      from admin_permissions a where a.team_code = t.code),
      'defaults', to_jsonb(_admin_team_defaults(t.code))) order by t.position)
    from admin_teams t), '[]'::jsonb);
end $$;

create or replace function admin_team_members_list(p_team text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _admin_only();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id', m.user_id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'suspended', coalesce(p.suspended, false),
      'permissions', to_jsonb(m.permissions), 'granted_by', (select g.name from profiles g where g.id = m.granted_by), 'updated_at', m.updated_at) order by p.name)
    from admin_team_members m join profiles p on p.id = m.user_id where m.team_code = p_team), '[]'::jsonb);
end $$;

-- Agents recrutables : comptes de rôle finance ou support (recherche par nom ou e-mail).
create or replace function admin_team_candidates(p_query text default '') returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_q text := btrim(coalesce(p_query, ''));
begin
  perform _admin_only();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'suspended', coalesce(p.suspended, false),
      'teams', (select coalesce(jsonb_agg(m.team_code order by m.team_code), '[]'::jsonb) from admin_team_members m where m.user_id = p.id)) order by p.name)
    from (select * from profiles x where x.role::text in ('finance', 'support')
            and (v_q = '' or x.name ilike '%' || replace(replace(v_q, '%', ''), '_', '') || '%' or x.email ilike '%' || replace(replace(v_q, '%', ''), '_', '') || '%')
          order by x.name limit 30) p), '[]'::jsonb);
end $$;

create or replace function admin_team_history_list(p_user uuid default null, p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _admin_only();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', h.id, 'at', h.created_at, 'action', h.action, 'team', h.team_code, 'user_id', h.user_id, 'user', u.name,
      'actor', (select a.name from profiles a where a.id = h.actor_id), 'before', to_jsonb(h.before_permissions), 'after', to_jsonb(h.after_permissions), 'note', h.note) order by h.id desc)
    from (select * from admin_team_history where p_user is null or user_id = p_user order by id desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) h
    join profiles u on u.id = h.user_id), '[]'::jsonb);
end $$;

revoke all on function admin_team_member_set(uuid, text, text[], text), admin_team_member_remove(uuid, text, text), admin_teams_overview(),
  admin_team_members_list(text), admin_team_candidates(text), admin_team_history_list(uuid, integer) from public, anon;
grant execute on function admin_team_member_set(uuid, text, text[], text), admin_team_member_remove(uuid, text, text), admin_teams_overview(),
  admin_team_members_list(text), admin_team_candidates(text), admin_team_history_list(uuid, integer) to authenticated;

-- ============================================================ 5. Migration des comptes existants et inscription automatique
-- Les comptes finance et support existants reçoivent exactement les droits qu'ils avaient avant la mise en place des équipes
-- (le support garde la modération, le journal d'audit et les décisions de remboursement) ; l'administrateur peut ensuite les retirer.
insert into admin_team_members (user_id, team_code, permissions)
select p.id, 'finance', _admin_team_defaults('finance') from profiles p where p.role::text = 'finance'
on conflict (user_id, team_code) do nothing;
insert into admin_team_members (user_id, team_code, permissions)
select p.id, 'support', _admin_team_defaults('support') || array['support.refunds'] from profiles p where p.role::text = 'support'
on conflict (user_id, team_code) do nothing;
insert into admin_team_members (user_id, team_code, permissions)
select p.id, 'security', array['security.accounts', 'security.audit', 'security.moderation', 'security.reports'] from profiles p where p.role::text = 'support'
on conflict (user_id, team_code) do nothing;
insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
select null, m.user_id, m.team_code, 'migration', '{}', m.permissions, 'Migration des comptes Finance et Support existants vers leur équipe'
from admin_team_members m
where not exists (select 1 from admin_team_history h where h.user_id = m.user_id and h.team_code = m.team_code);

create or replace function _admin_team_autoenroll() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_team text;
begin
  if tg_op = 'UPDATE' and new.role is not distinct from old.role then return new; end if;
  if new.role::text in ('finance', 'support') then
    v_team := new.role::text;
    if not exists (select 1 from admin_team_members where user_id = new.id) then
      insert into admin_team_members (user_id, team_code, permissions, granted_by) values (new.id, v_team, _admin_team_defaults(v_team), auth.uid());
      insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
      values (auth.uid(), new.id, v_team, 'auto_enroll', '{}', _admin_team_defaults(v_team), 'Rôle attribué : inscription dans l''équipe correspondante');
    end if;
  elsif tg_op = 'UPDATE' then
    insert into admin_team_history (actor_id, user_id, team_code, action, before_permissions, after_permissions, note)
    select auth.uid(), m.user_id, m.team_code, 'auto_revoke', m.permissions, '{}', 'Le compte n''a plus de rôle d''équipe interne'
    from admin_team_members m where m.user_id = new.id;
    delete from admin_team_members where user_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists trg_admin_team_autoenroll on profiles;
create trigger trg_admin_team_autoenroll after insert or update of role on profiles for each row execute function _admin_team_autoenroll();
