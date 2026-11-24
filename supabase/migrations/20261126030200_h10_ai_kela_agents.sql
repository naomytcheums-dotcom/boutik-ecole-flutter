-- Lot H10 / AI (3/3) : contexte Kéla limité au compte connecté, agents spécialisés déclarés « non actif », journal des actions d'agents avec confirmation humaine (CDC 20).
--  1. kela_context() : lit UNIQUEMENT les données du compte connecté (aucun paramètre « utilisateur »), refusée à l'anonyme ;
--  2. ai_agents : les 20 agents du CDC 20.2, tous « non_actif » à la livraison ; activation réservée à l'administrateur global (2FA, audit) et refusée sans fournisseur « chat » actif ;
--  3. ai_action_log : toute action d'un agent est journalisée ; une action SENSIBLE (paiement, suppression, modification sensible, envoi, publication, virement, changement de droits)
--     reste « en_attente_confirmation » jusqu'à la confirmation de la personne concernée ; l'agent ne peut ni se confirmer lui-même ni exécuter sans autorisation ;
--     quota : 30 propositions par heure et par personne.
-- Aucun agent n'agit à la livraison : sans agent actif, ai_action_propose() refuse. Additive et rejouable. Retour arrière :
--   drop function kela_context(), _ai_sensitive_actions(), ai_agent_set_status(text, text), ai_agents_list(), ai_action_propose(text, text, jsonb, boolean), ai_action_confirm(uuid, boolean), ai_action_my_list(), ai_action_record_result(uuid, boolean, text), _ai_action_guard();
--   drop table ai_action_log, ai_agents;

create table if not exists ai_agents (
  code text primary key check (code ~ '^[a-z_]{3,40}$'),
  label text not null,
  status text not null default 'non_actif' check (status in ('non_actif', 'actif', 'suspendu')),
  activated_at timestamptz,
  updated_by uuid references profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into ai_agents (code, label) values
  ('talent', 'Agent Talent'), ('recrutement', 'Agent Recrutement'), ('evaluation', 'Agent Évaluation'), ('carriere', 'Agent Carrière'),
  ('commerce', 'Agent Commerce'), ('vendeur', 'Agent Vendeur'), ('client', 'Agent Client'), ('entreprise', 'Agent Entreprise'),
  ('procurement', 'Agent Procurement'), ('innovation', 'Agent Innovation'), ('projet', 'Agent Projet'), ('createur', 'Agent Créateur'),
  ('contenu', 'Agent Contenu'), ('traduction', 'Agent Traduction'), ('formation', 'Agent Formation'), ('support', 'Agent Support'),
  ('finance', 'Agent Finance'), ('institution', 'Agent Institution'), ('administration', 'Agent Administration'), ('securite_conformite', 'Agent Sécurité et conformité')
on conflict (code) do nothing;

create table if not exists ai_action_log (
  id uuid primary key default gen_random_uuid(),
  agent_code text not null references ai_agents (code),
  user_id uuid not null references profiles (id) on delete cascade,
  action text not null check (char_length(btrim(action)) between 2 and 80),
  payload jsonb not null default '{}' check (jsonb_typeof(payload) = 'object'),
  sensitive boolean not null default false,
  status text not null check (status in ('en_attente_confirmation', 'autorisee', 'refusee', 'executee', 'echouee')),
  confirmed_at timestamptz,
  result_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ai_action_log_user on ai_action_log (user_id, created_at desc);

alter table ai_agents enable row level security;
alter table ai_action_log enable row level security;
revoke all on ai_agents, ai_action_log from public, anon, authenticated;
grant select on ai_agents, ai_action_log to authenticated;
drop policy if exists "agents : catalogue connectés" on ai_agents;
create policy "agents : catalogue connectés" on ai_agents for select to authenticated using (auth.uid() is not null);
drop policy if exists "actions d'agents : les miennes" on ai_action_log;
create policy "actions d'agents : les miennes" on ai_action_log for select to authenticated using (user_id = auth.uid());

create or replace function _ai_sensitive_actions() returns text[]
language sql immutable set search_path = public as $$
  select array['paiement', 'virement', 'remboursement', 'suppression', 'modification_sensible', 'envoi_message', 'publication', 'changement_droits', 'signature']::text[]
$$;
revoke all on function _ai_sensitive_actions() from public, anon;
grant execute on function _ai_sensitive_actions() to authenticated;

-- Une action exécutée l'a été après autorisation : transition contrôlée même pour un accès direct.
create or replace function _ai_action_guard() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id or new.agent_code <> old.agent_code or new.action <> old.action or new.sensitive <> old.sensitive or new.payload <> old.payload then
      raise exception 'Journal des actions d''agents : champs immuables';
    end if;
    if old.status in ('refusee', 'executee', 'echouee') and new.status <> old.status then raise exception 'Action déjà clôturée'; end if;
    if new.status in ('executee', 'echouee') and old.status <> 'autorisee' then raise exception 'Exécution sans autorisation refusée'; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_ai_action_guard on ai_action_log;
create trigger trg_ai_action_guard before update on ai_action_log for each row execute function _ai_action_guard();

-- ============================================================ 1. Contexte Kéla : le compte connecté, rien d'autre
create or replace function kela_context() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); p profiles;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  select * into p from profiles where id = v_uid;
  if p.id is null then raise exception 'Profil introuvable'; end if;
  return jsonb_build_object(
    'user_id', p.id, 'name', p.name, 'role', p.role::text,
    'unread_notifications', (select count(*)::int from notifications n where n.user_id = v_uid and n.read_at is null),
    'conversations', (select count(*)::int from conversation_participants c where c.user_id = v_uid),
    'pending_transcriptions', (select count(*)::int from ai_transcription_jobs j where j.owner_id = v_uid and j.status in ('en_attente_fournisseur', 'en_file')),
    'pending_agent_actions', (select count(*)::int from ai_action_log a where a.user_id = v_uid and a.status = 'en_attente_confirmation'),
    'capabilities', (select jsonb_object_agg(c, exists (select 1 from ai_providers x where x.capability = c and x.status = 'actif')) from unnest(ai_capabilities()) c));
end $$;

-- ============================================================ 2. Agents
create or replace function ai_agents_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('code', a.code, 'label', a.label, 'status', a.status) order by a.label) from ai_agents a), '[]'::jsonb);
end $$;

create or replace function ai_agent_set_status(p_code text, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare a ai_agents;
begin
  perform _ai_admin_only();
  if p_status is null or p_status not in ('non_actif', 'actif', 'suspendu') then raise exception 'Statut d''agent inconnu'; end if;
  select * into a from ai_agents where code = p_code for update;
  if a.code is null then raise exception 'Agent introuvable'; end if;
  if p_status = 'actif' and not exists (select 1 from ai_providers where capability = 'chat' and status = 'actif') then
    raise exception 'Activation refusée : aucun fournisseur de conversation (chat) actif';
  end if;
  update ai_agents set status = p_status, activated_at = case when p_status = 'actif' then now() else activated_at end, updated_by = auth.uid(), updated_at = now() where code = a.code;
  perform _ai_audit('Statut d''agent IA : ' || p_status, a.code || ' (avant : ' || a.status || ')', case when p_status = 'actif' then 'Critique' else 'Sensible' end);
end $$;

-- ============================================================ 3. Actions d'agents et confirmation humaine
create or replace function ai_action_propose(p_agent text, p_action text, p_payload jsonb default '{}', p_sensitive boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); a ai_agents; v_action text := lower(btrim(coalesce(p_action, ''))); v_sens boolean; v_status text; v_id uuid;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  select * into a from ai_agents where code = p_agent;
  if a.code is null then raise exception 'Agent introuvable'; end if;
  if a.status <> 'actif' then raise exception 'Agent non actif'; end if;
  if char_length(v_action) < 2 then raise exception 'Action invalide'; end if;
  if (select count(*) from ai_action_log where user_id = v_uid and created_at > now() - interval '1 hour') >= 30 then raise exception 'Quota d''actions d''agents atteint (30 par heure)'; end if;
  -- un agent ne peut pas déclasser une action sensible
  v_sens := coalesce(p_sensitive, false) or v_action = any (_ai_sensitive_actions());
  v_status := case when v_sens then 'en_attente_confirmation' else 'autorisee' end;
  insert into ai_action_log (agent_code, user_id, action, payload, sensitive, status) values (a.code, v_uid, v_action, coalesce(p_payload, '{}'), v_sens, v_status) returning id into v_id;
  return jsonb_build_object('id', v_id, 'status', v_status, 'sensitive', v_sens);
end $$;

-- Seule la personne concernée confirme ou refuse (jamais le service ni un autre compte).
create or replace function ai_action_confirm(p_id uuid, p_approve boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_approve is null then raise exception 'Choix manquant'; end if;
  v_status := case when p_approve then 'autorisee' else 'refusee' end;
  update ai_action_log set status = v_status, confirmed_at = now(), updated_at = now() where id = p_id and user_id = auth.uid() and status = 'en_attente_confirmation';
  if not found then raise exception 'Action introuvable ou déjà traitée'; end if;
  return jsonb_build_object('id', p_id, 'status', v_status);
end $$;

create or replace function ai_action_my_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'agent', a.agent_code, 'action', a.action, 'sensitive', a.sensitive, 'status', a.status, 'created_at', a.created_at)
    order by a.created_at desc) from ai_action_log a where a.user_id = auth.uid()), '[]'::jsonb);
end $$;

-- Résultat d'exécution déclaré par l'orchestrateur serveur : possible seulement depuis « autorisee ».
create or replace function ai_action_record_result(p_id uuid, p_ok boolean, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  update ai_action_log set status = case when coalesce(p_ok, false) then 'executee' else 'echouee' end, result_note = left(p_note, 500), updated_at = now() where id = p_id;
  if not found then raise exception 'Action introuvable'; end if;
end $$;

revoke all on function kela_context(), ai_agents_list(), ai_agent_set_status(text, text), ai_action_propose(text, text, jsonb, boolean), ai_action_confirm(uuid, boolean), ai_action_my_list() from public, anon;
grant execute on function kela_context(), ai_agents_list(), ai_agent_set_status(text, text), ai_action_propose(text, text, jsonb, boolean), ai_action_confirm(uuid, boolean), ai_action_my_list() to authenticated;
revoke all on function ai_action_record_result(uuid, boolean, text) from public, anon, authenticated;
grant execute on function ai_action_record_result(uuid, boolean, text) to service_role;
