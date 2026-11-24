-- Lot H10 / AI (1/3) : registre des fournisseurs d'IA PAR CAPACITÉ et traduction de messages (CDC 11, 20, 21.6, 30).
-- AUCUN fournisseur n'est développé, choisi ni appelé : le registre est VIDE (aucune ligne insérée). Sans fournisseur actif, rien n'est traduit :
-- la RPC répond « not_configured » (jamais un texte). Aucune clé n'est stockée : l'adaptateur serveur lit ses secrets dans l'environnement de la fonction Edge.
--  1. ai_providers (capacité : chat | translate_text | stt | tts | vision ; statut : candidat | en_test | actif | suspendu) + ai_provider_tests ;
--     activation réservée à l'administrateur global (2FA, journal d'audit) et REFUSÉE sans test d'intégration réussi enregistré ; un seul fournisseur actif par capacité ;
--  2. ai_capability_status() : état par capacité (configuré oui/non) pour les comptes connectés, sans nom de fournisseur ;
--  3. ai_translations (cache) + translate_request() (appartenance du message à la conversation de l'appelant) + translate_store() (service_role seulement).
-- RLS stricte, aucun accès anonyme. Additive et rejouable. Retour arrière :
--   drop function ai_capabilities(), _ai_admin_only(), _ai_audit(text, text, text), ai_provider_register(text, text, text), ai_provider_record_test(text, text, boolean, text),
--     ai_provider_set_status(text, text, text), ai_providers_admin_list(), ai_capability_status(), translate_request(bigint, text), translate_store(uuid, bigint, text, text, text, text), _ai_lang_ok(text);
--   drop table ai_translations, ai_provider_tests, ai_providers;

create or replace function ai_capabilities() returns text[]
language sql immutable set search_path = public as $$
  select array['chat', 'translate_text', 'stt', 'tts', 'vision']::text[]
$$;
revoke all on function ai_capabilities() from public, anon;
grant execute on function ai_capabilities() to authenticated;

-- ============================================================ 1. Registre (VIDE) et tests d'intégration enregistrés
create table if not exists ai_providers (
  capability text not null check (capability = any (ai_capabilities())),
  code text not null check (code ~ '^[a-z0-9_]{2,40}$'),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  status text not null default 'candidat' check (status in ('candidat', 'en_test', 'actif', 'suspendu')),
  activated_at timestamptz,
  created_by uuid references profiles (id) on delete set null,
  updated_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (capability, code)
);
-- un seul fournisseur actif par capacité : aucune ambiguïté sur celui qui reçoit les données
create unique index if not exists ai_providers_one_active on ai_providers (capability) where status = 'actif';

create table if not exists ai_provider_tests (
  id bigint generated always as identity primary key,
  capability text not null,
  provider_code text not null,
  ok boolean not null,
  note text not null default '',
  tested_by uuid references profiles (id) on delete set null,
  tested_at timestamptz not null default now(),
  foreign key (capability, provider_code) references ai_providers (capability, code) on delete cascade
);
create index if not exists ai_provider_tests_provider on ai_provider_tests (capability, provider_code, tested_at desc);

alter table ai_providers enable row level security;
alter table ai_provider_tests enable row level security;
revoke all on ai_providers, ai_provider_tests from public, anon, authenticated;
grant select on ai_providers, ai_provider_tests to authenticated;
drop policy if exists "fournisseurs d'IA : permission technique" on ai_providers;
create policy "fournisseurs d'IA : permission technique" on ai_providers for select to authenticated using (has_admin_permission('tech.integrations'));
drop policy if exists "tests de fournisseur d'IA : permission technique" on ai_provider_tests;
create policy "tests de fournisseur d'IA : permission technique" on ai_provider_tests for select to authenticated using (has_admin_permission('tech.integrations'));

create or replace function _ai_audit(p_action text, p_target text, p_level text default 'Sensible') returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), left(p_action, 120), left(p_target, 200), 'Intelligence artificielle', p_level);
end $$;
revoke all on function _ai_audit(text, text, text) from public, anon, authenticated;

-- Garde commune : administrateur global, 2FA (session aal2 si un facteur est vérifié).
create or replace function _ai_admin_only() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
  perform _require_staff_aal2();
end $$;
revoke all on function _ai_admin_only() from public, anon, authenticated;

create or replace function ai_provider_register(p_capability text, p_code text, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare v_code text := lower(btrim(coalesce(p_code, '')));
begin
  perform _ai_admin_only();
  if p_capability is null or not (p_capability = any (ai_capabilities())) then raise exception 'Capacité inconnue'; end if;
  if v_code !~ '^[a-z0-9_]{2,40}$' then raise exception 'Code fournisseur invalide (2 à 40 caractères : a-z, 0-9, _)'; end if;
  insert into ai_providers (capability, code, name, status, created_by, updated_by)
  values (p_capability, v_code, btrim(coalesce(p_name, '')), 'candidat', auth.uid(), auth.uid())
  on conflict (capability, code) do update set name = excluded.name, updated_by = auth.uid(), updated_at = now();
  perform _ai_audit('Fournisseur d''IA enregistré', p_capability || '/' || v_code);
end $$;

create or replace function ai_provider_record_test(p_capability text, p_code text, p_ok boolean, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
declare p ai_providers;
begin
  perform _ai_admin_only();
  select * into p from ai_providers where capability = p_capability and code = p_code for update;
  if p.code is null then raise exception 'Fournisseur introuvable'; end if;
  insert into ai_provider_tests (capability, provider_code, ok, note, tested_by) values (p.capability, p.code, coalesce(p_ok, false), left(btrim(coalesce(p_note, '')), 500), auth.uid());
  -- un test échoué retire un fournisseur actif du service
  if not coalesce(p_ok, false) and p.status = 'actif' then update ai_providers set status = 'suspendu', updated_by = auth.uid(), updated_at = now() where capability = p.capability and code = p.code;
  elsif p.status = 'candidat' then update ai_providers set status = 'en_test', updated_by = auth.uid(), updated_at = now() where capability = p.capability and code = p.code; end if;
  perform _ai_audit('Test d''intégration de fournisseur d''IA enregistré', p.capability || '/' || p.code || ' : ' || case when coalesce(p_ok, false) then 'réussi' else 'échoué' end);
end $$;

create or replace function ai_provider_set_status(p_capability text, p_code text, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare p ai_providers; v_last boolean;
begin
  perform _ai_admin_only();
  if p_status is null or p_status not in ('candidat', 'en_test', 'actif', 'suspendu') then raise exception 'Statut de fournisseur inconnu'; end if;
  select * into p from ai_providers where capability = p_capability and code = p_code for update;
  if p.code is null then raise exception 'Fournisseur introuvable'; end if;
  if p_status = 'actif' then
    select t.ok into v_last from ai_provider_tests t where t.capability = p.capability and t.provider_code = p.code order by t.tested_at desc, t.id desc limit 1;
    if v_last is distinct from true then raise exception 'Activation refusée : aucun test d''intégration réussi enregistré pour ce fournisseur'; end if;
    if exists (select 1 from ai_providers o where o.capability = p.capability and o.status = 'actif' and o.code <> p.code) then
      raise exception 'Activation refusée : un autre fournisseur est déjà actif pour cette capacité (suspendez-le d''abord)';
    end if;
  end if;
  update ai_providers set status = p_status, activated_at = case when p_status = 'actif' then now() else activated_at end, updated_by = auth.uid(), updated_at = now()
    where capability = p.capability and code = p.code;
  perform _ai_audit('Statut de fournisseur d''IA : ' || p_status, p.capability || '/' || p.code || ' (avant : ' || p.status || ')', case when p_status = 'actif' then 'Critique' else 'Sensible' end);
end $$;

create or replace function ai_providers_admin_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('tech.integrations') then raise exception 'Accès refusé'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('capability', p.capability, 'code', p.code, 'name', p.name, 'status', p.status, 'activated_at', p.activated_at,
      'last_test', (select jsonb_build_object('ok', t.ok, 'note', t.note, 'tested_at', t.tested_at) from ai_provider_tests t where t.capability = p.capability and t.provider_code = p.code order by t.tested_at desc, t.id desc limit 1))
    order by p.capability, p.code) from ai_providers p), '[]'::jsonb);
end $$;

-- État par capacité pour les comptes connectés : jamais de nom de fournisseur ni de réglage.
create or replace function ai_capability_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return (select jsonb_object_agg(c, exists (select 1 from ai_providers p where p.capability = c and p.status = 'actif')) from unnest(ai_capabilities()) c);
end $$;

revoke all on function ai_provider_register(text, text, text), ai_provider_record_test(text, text, boolean, text), ai_provider_set_status(text, text, text),
  ai_providers_admin_list(), ai_capability_status() from public, anon;
grant execute on function ai_provider_register(text, text, text), ai_provider_record_test(text, text, boolean, text), ai_provider_set_status(text, text, text),
  ai_providers_admin_list(), ai_capability_status() to authenticated;

-- ============================================================ 3. Traductions (cache par message et langue cible)
create or replace function _ai_lang_ok(p text) returns boolean
language sql immutable set search_path = public as $$
  select p is not null and p ~ '^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$'
$$;

create table if not exists ai_translations (
  message_id bigint not null references messages (id) on delete cascade,
  target_lang text not null check (_ai_lang_ok(target_lang)),
  source_lang text check (source_lang is null or _ai_lang_ok(source_lang)),
  provider_code text not null,
  body text not null check (char_length(body) between 1 and 12000),
  created_at timestamptz not null default now(),
  primary key (message_id, target_lang)
);

create or replace function _ai_msg_visible(p_message bigint) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from messages m where m.id = p_message and is_participant(m.conversation_id))
$$;
revoke all on function _ai_msg_visible(bigint) from public, anon;
grant execute on function _ai_msg_visible(bigint) to authenticated;

alter table ai_translations enable row level security;
revoke all on ai_translations from public, anon, authenticated;
grant select on ai_translations to authenticated;
drop policy if exists "traductions : participants de la conversation" on ai_translations;
create policy "traductions : participants de la conversation" on ai_translations for select to authenticated using (_ai_msg_visible(message_id));

-- Demande de traduction d'un message. Aucune requête vers l'extérieur : la fonction Edge « translate » appelle cette RPC avec le jeton de l'utilisateur,
-- puis interroge le fournisseur, puis enregistre via translate_store. Sans fournisseur actif : statut « not_configured », jamais un texte.
create or replace function translate_request(p_message bigint, p_target text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare m messages; t ai_translations; v_provider text; v_target text := lower(btrim(coalesce(p_target, '')));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _ai_lang_ok(v_target) then raise exception 'Langue cible invalide'; end if;
  select * into m from messages where id = p_message;
  -- même réponse pour un message inexistant et pour un message d'une conversation étrangère
  if m.id is null or not is_participant(m.conversation_id) then raise exception 'Message introuvable'; end if;
  select * into t from ai_translations where message_id = m.id and target_lang = v_target;
  if t.message_id is not null then
    return jsonb_build_object('status', 'translated', 'text', t.body, 'source_lang', t.source_lang, 'target_lang', t.target_lang, 'cached', true);
  end if;
  select code into v_provider from ai_providers where capability = 'translate_text' and status = 'actif' limit 1;
  if v_provider is null then return jsonb_build_object('status', 'not_configured'); end if;
  return jsonb_build_object('status', 'pending', 'message_id', m.id, 'target_lang', v_target, 'text', m.body, 'provider', v_provider);
end $$;

-- Enregistrement du résultat par la fonction Edge (service_role) : l'utilisateur doit toujours appartenir à la conversation, le fournisseur doit être actif.
create or replace function translate_store(p_user uuid, p_message bigint, p_target text, p_source text, p_provider text, p_text text) returns void
language plpgsql security definer set search_path = public as $$
declare m messages; v_target text := lower(btrim(coalesce(p_target, '')));
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'Réservé au service'; end if;
  if not _ai_lang_ok(v_target) then raise exception 'Langue cible invalide'; end if;
  if p_text is null or char_length(btrim(p_text)) = 0 then raise exception 'Traduction vide refusée'; end if;
  select * into m from messages where id = p_message;
  if m.id is null or not exists (select 1 from conversation_participants where conversation_id = m.conversation_id and user_id = p_user) then raise exception 'Message introuvable'; end if;
  if not exists (select 1 from ai_providers where capability = 'translate_text' and code = p_provider and status = 'actif') then raise exception 'Aucun fournisseur de traduction actif'; end if;
  insert into ai_translations (message_id, target_lang, source_lang, provider_code, body)
  values (m.id, v_target, nullif(lower(btrim(coalesce(p_source, ''))), ''), p_provider, left(p_text, 12000))
  on conflict (message_id, target_lang) do nothing;
end $$;

revoke all on function translate_request(bigint, text) from public, anon;
grant execute on function translate_request(bigint, text) to authenticated;
revoke all on function translate_store(uuid, bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function translate_store(uuid, bigint, text, text, text, text) to service_role;
