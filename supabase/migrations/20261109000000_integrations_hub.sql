-- Hub universel d'intégrations : réseaux, productivité, collaboration, Mobile Money (MTN MoMo, Orange Money).
-- Écrans concernés : 271 Mes liens et réseaux, 280 Intégrations, P3 Avis et outils connectés, P5 Connecter mes outils.
--
-- Principes de sécurité :
--  * les jetons OAuth (accès, rafraîchissement) sont chiffrés (AES-256-GCM) par les Edge Functions et stockés dans `integration_tokens`,
--    table SANS aucune politique et sans droit pour anon/authenticated : seule la clé de service (Edge Functions) y accède ;
--  * aucun PIN Mobile Money n'est jamais reçu, transmis ni stocké : la validation du paiement se fait sur le téléphone du titulaire ;
--  * toutes les tables sont en RLS ; les écritures sensibles passent par des fonctions security definer ou par les Edge Functions.
-- Retour arrière : drop table integration_publication_targets, integration_publications, integration_imported_items, integration_sync_logs,
--   integration_permissions, integration_tokens, integration_oauth_states, integration_accounts, integration_connections, integration_providers,
--   momo_verifications, momo_transactions, momo_numbers cascade; drop sequence momo_ref_seq;
--   drop function momo_add_number, momo_set_primary, momo_rename_number, momo_remove_number, momo_confirm_verification, momo_prepare_transfer,
--   momo_cancel_transfer, momo_dashboard, integrations_set_item_visibility, integrations_delete_item;

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ fournisseurs (catalogue)
create table if not exists integration_providers (
  id text primary key,
  family text not null check (family in ('reseaux', 'productivite', 'collaboration', 'telecom')),
  name text not null,
  auth_kind text not null check (auth_kind in ('oauth2', 'oauth1a', 'mobile_money', 'link_only')),
  pkce boolean not null default false,
  default_scopes text[] not null default '{}',
  can_import boolean not null default false,
  can_publish boolean not null default false,
  has_webhook boolean not null default false,
  review_required text,          -- approbation / audit exigé par le fournisseur avant l'usage public
  limits_note text,              -- limite officielle de l'API (ce que la plateforme ne permet pas)
  alternative_note text,         -- alternative officielle proposée
  docs_url text,
  sort_order int not null default 100
);
alter table integration_providers enable row level security;
drop policy if exists "fournisseurs : lecture" on integration_providers;
create policy "fournisseurs : lecture" on integration_providers for select to authenticated using (true);

insert into integration_providers (id, family, name, auth_kind, pkce, default_scopes, can_import, can_publish, has_webhook, review_required, limits_note, alternative_note, docs_url, sort_order) values
 ('facebook', 'reseaux', 'Facebook', 'oauth2', false, '{public_profile,pages_show_list,pages_read_engagement,pages_manage_posts}', true, true, true,
   'Revue d''application Meta (autorisations pages_*) et vérification de l''entreprise.',
   'L''API officielle ne permet de lire et publier que sur les Pages Facebook que vous administrez, jamais sur un profil personnel.',
   'Profil personnel : publier via la fenêtre de partage Facebook (lien) ou copier le texte.', 'https://developers.facebook.com/docs/pages-api', 10),
 ('instagram', 'reseaux', 'Instagram', 'oauth2', false, '{instagram_business_basic,instagram_business_content_publish}', true, true, true,
   'Revue d''application Meta ; compte professionnel (Business ou Créateur) obligatoire.',
   'Seuls les comptes professionnels sont gérés par l''API ; une publication exige une image ou une vidéo (pas de texte seul).',
   'Compte personnel : ajouter le lien de profil ; publier en copiant la légende.', 'https://developers.facebook.com/docs/instagram-platform', 20),
 ('linkedin', 'reseaux', 'LinkedIn', 'oauth2', false, '{openid,profile,email,w_member_social}', false, true, false,
   'Produit « Share on LinkedIn » à demander dans l''application développeur ; la lecture des publications relève de la Community Management API, sur approbation LinkedIn.',
   'La lecture des publications d''un membre n''est pas ouverte sans approbation LinkedIn : import désactivé.',
   'Lien de profil + fenêtre de partage LinkedIn pour publier.', 'https://learn.microsoft.com/linkedin/', 30),
 ('tiktok', 'reseaux', 'TikTok', 'oauth2', true, '{user.info.basic,video.list}', true, false, false,
   'Login Kit et Display API : revue de l''application. Content Posting API : audit TikTok obligatoire.',
   'Sans audit, les contenus publiés par une application restent privés ; la publication n''est donc pas proposée tant que l''audit n''est pas passé.',
   'Import des vidéos publiques (Display API) ; publication manuelle depuis l''application TikTok.', 'https://developers.tiktok.com/', 40),
 ('youtube', 'reseaux', 'YouTube', 'oauth2', true, '{https://www.googleapis.com/auth/youtube.readonly}', true, false, false,
   'Vérification Google de l''écran de consentement ; quota API par défaut de 10 000 unités par jour (un envoi de vidéo coûte 1 600). Les envois d''une application non auditée sont forcés en privé.',
   'Aucune API pour les publications « communauté » : seul l''envoi de vidéos existe, et il est soumis à audit.',
   'Import de la chaîne et des vidéos publiques ; publier en partageant le lien d''une vidéo.', 'https://developers.google.com/youtube/v3', 50),
 ('behance', 'reseaux', 'Behance', 'link_only', false, '{}', false, false, false,
   'Adobe n''ouvre plus de nouvelles clés pour l''API Behance.',
   'Aucune API utilisable : enregistrer l''adresse publique de votre portfolio Behance (affichée sur votre profil).',
   'Lien de portfolio public.', 'https://www.behance.net/dev', 60),

 ('google_drive', 'productivite', 'Google Drive', 'oauth2', true, '{https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/userinfo.profile}', true, false, false,
   'Portée limitée « drive.file » (fichiers choisis ou créés par l''application) : pas de vérification de sécurité lourde. L''accès à tout le Drive relève d''une portée restreinte soumise à audit.',
   'Les fichiers sont partagés un par un via le sélecteur Google.',
   'Lien de partage Drive collé dans le portfolio.', 'https://developers.google.com/drive/api', 110),
 ('google_docs', 'productivite', 'Google Docs', 'oauth2', true, '{https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/userinfo.profile}', true, true, false,
   'Portée « drive.file » : seuls les documents créés ou ouverts avec l''application sont accessibles.',
   NULL, 'Lien de partage d''un document.', 'https://developers.google.com/docs/api', 120),
 ('google_sheets', 'productivite', 'Google Sheets', 'oauth2', true, '{https://www.googleapis.com/auth/drive.file,https://www.googleapis.com/auth/userinfo.profile}', true, true, false,
   'Portée « drive.file » : seuls les classeurs créés ou ouverts avec l''application sont accessibles.',
   NULL, 'Lien de partage d''un classeur.', 'https://developers.google.com/sheets/api', 130),
 ('gmail', 'productivite', 'Gmail', 'oauth2', true, '{https://www.googleapis.com/auth/gmail.send,https://www.googleapis.com/auth/userinfo.profile}', false, false, false,
   'Envoi seul (« gmail.send », portée sensible : vérification Google). La lecture des courriels est une portée restreinte soumise à un audit de sécurité annuel : non demandée.',
   'Aucune lecture de la boîte de réception.', 'Envoi depuis votre propre adresse, sans lecture de vos messages.', 'https://developers.google.com/gmail/api', 140),
 ('google_calendar', 'productivite', 'Google Agenda', 'oauth2', true, '{https://www.googleapis.com/auth/calendar.events,https://www.googleapis.com/auth/userinfo.profile}', true, false, false,
   'Portée sensible : vérification Google de l''écran de consentement.',
   NULL, 'Export iCal d''un événement.', 'https://developers.google.com/calendar/api', 150),
 ('onedrive', 'productivite', 'OneDrive', 'oauth2', true, '{offline_access,User.Read,Files.Read}', true, false, false,
   'Application Microsoft Entra à enregistrer ; comptes personnels et professionnels (le consentement administrateur peut être exigé en entreprise).',
   NULL, 'Lien de partage OneDrive.', 'https://learn.microsoft.com/graph/onedrive-concept-overview', 160),
 ('dropbox', 'productivite', 'Dropbox', 'oauth2', true, '{account_info.read,files.metadata.read}', true, false, true,
   'Application Dropbox à enregistrer ; passage en production après revue si plus de 50 utilisateurs.',
   NULL, 'Lien de partage Dropbox.', 'https://www.dropbox.com/developers', 170),

 ('slack', 'collaboration', 'Slack', 'oauth2', false, '{chat:write,chat:write.public,channels:read}', false, true, false,
   'Application Slack à installer dans chaque espace de travail ; Slack n''accepte pas PKCE pour l''échange du code (secret serveur utilisé).',
   NULL, 'Webhook entrant de l''espace de travail.', 'https://api.slack.com/authentication/oauth-v2', 210),
 ('discord', 'collaboration', 'Discord', 'oauth2', true, '{identify,guilds,webhook.incoming}', false, true, false,
   'Publication par le webhook que vous autorisez dans un salon (portée officielle webhook.incoming).',
   'Un bot n''est pas nécessaire : un webhook par salon suffit.', NULL, 'https://discord.com/developers/docs/topics/oauth2', 220),
 ('github', 'collaboration', 'GitHub', 'oauth2', true, '{read:user,user:email}', true, false, false,
   'Application OAuth GitHub à enregistrer ; seuls vos dépôts publics sont importés (aucune portée « repo »).',
   NULL, 'Lien de profil GitHub.', 'https://docs.github.com/apps/oauth-apps', 230),
 ('notion', 'collaboration', 'Notion', 'oauth2', false, '{}', true, true, false,
   'Intégration publique Notion : vous choisissez les pages partagées avec l''application lors de l''autorisation.',
   'L''API ne voit que les pages que vous partagez explicitement.', 'Lien de page publique Notion.', 'https://developers.notion.com/docs/authorization', 240),
 ('trello', 'collaboration', 'Trello', 'oauth1a', false, '{read,write}', true, false, false,
   'Trello n''offre pas OAuth 2.0 : OAuth 1.0a officiel (signature HMAC-SHA1) côté serveur.',
   NULL, 'Lien de tableau Trello public.', 'https://developer.atlassian.com/cloud/trello/guides/rest-api/authorization/', 250),
 ('teams', 'collaboration', 'Microsoft Teams', 'oauth2', true, '{offline_access,User.Read,Team.ReadBasic.All,Channel.ReadBasic.All,ChannelMessage.Send}', false, true, false,
   'Envoi dans un canal (ChannelMessage.Send) : consentement d''un administrateur du locataire Microsoft requis.',
   NULL, 'Webhook / flux de travail Teams du canal.', 'https://learn.microsoft.com/graph/teams-concept-overview', 260),

 ('mtn_momo', 'telecom', 'MTN Mobile Money', 'mobile_money', false, '{}', false, false, false,
   'Contrat marchand MTN (API Collection / Disbursement) et clés d''abonnement du portail MTN MoMo Developer.',
   'Sans contrat, les numéros peuvent être enregistrés et vérifiés, mais aucun envoi n''est exécuté.',
   NULL, 'https://momodeveloper.mtn.com/', 310),
 ('orange_money', 'telecom', 'Orange Money', 'mobile_money', false, '{}', false, false, false,
   'Contrat marchand Orange Money (Orange Developer) et identifiants d''API fournis par Orange.',
   'Sans contrat, les numéros peuvent être enregistrés et vérifiés, mais aucun envoi n''est exécuté.',
   NULL, 'https://developer.orange.com/', 320)
on conflict (id) do update set family = excluded.family, name = excluded.name, auth_kind = excluded.auth_kind, pkce = excluded.pkce,
  default_scopes = excluded.default_scopes, can_import = excluded.can_import, can_publish = excluded.can_publish, has_webhook = excluded.has_webhook,
  review_required = excluded.review_required, limits_note = excluded.limits_note, alternative_note = excluded.alternative_note,
  docs_url = excluded.docs_url, sort_order = excluded.sort_order;

-- ------------------------------------------------------------------ connexions
create table if not exists integration_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null references integration_providers (id),
  external_id text not null,                 -- identifiant du compte chez le fournisseur
  display_name text not null default '',
  profile_url text,
  status text not null default 'connected' check (status in ('connected', 'expired', 'revoked', 'error')),
  last_error text,
  connected_at timestamptz not null default now(),
  expires_at timestamptz,                    -- fin de validité du jeton d'accès
  last_sync_at timestamptz,
  next_sync_at timestamptz,                  -- quotas : pas de nouvelle synchronisation avant cette date
  sync_cursor text,
  unique (user_id, provider, external_id)
);
create index if not exists integration_connections_user on integration_connections (user_id, provider);
alter table integration_connections enable row level security;
drop policy if exists "connexions : propriétaire" on integration_connections;
create policy "connexions : propriétaire" on integration_connections for select to authenticated using (user_id = auth.uid());

-- Comptes externes rattachés : pages Facebook, chaînes, dépôts, salons, numéros…
create table if not exists integration_accounts (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references integration_connections (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null references integration_providers (id),
  external_id text not null,
  kind text not null default 'account',      -- page, channel, repo, workspace, webhook…
  name text not null default '',
  url text,
  is_primary boolean not null default false,
  publish_enabled boolean not null default false,
  unique (connection_id, external_id)
);
create index if not exists integration_accounts_user on integration_accounts (user_id);
alter table integration_accounts enable row level security;
drop policy if exists "comptes externes : propriétaire" on integration_accounts;
create policy "comptes externes : propriétaire" on integration_accounts for select to authenticated using (user_id = auth.uid());

-- Permissions réellement accordées par le fournisseur (affichées à l'utilisateur).
create table if not exists integration_permissions (
  connection_id uuid not null references integration_connections (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  scope text not null,
  granted_at timestamptz not null default now(),
  primary key (connection_id, scope)
);
alter table integration_permissions enable row level security;
drop policy if exists "permissions : propriétaire" on integration_permissions;
create policy "permissions : propriétaire" on integration_permissions for select to authenticated using (user_id = auth.uid());

-- Jetons chiffrés : AUCUNE politique, AUCUN droit pour les rôles de l'API. Lecture/écriture par la clé de service uniquement.
create table if not exists integration_tokens (
  connection_id uuid primary key references integration_connections (id) on delete cascade,
  access_enc text not null,
  refresh_enc text,
  extra_enc text,                            -- secret OAuth 1.0a, URL de webhook (Discord)…
  updated_at timestamptz not null default now()
);
alter table integration_tokens enable row level security;
revoke all on integration_tokens from anon, authenticated;

-- États OAuth en cours (anti-CSRF + vérificateur PKCE chiffré) : service uniquement, durée de vie 10 minutes.
create table if not exists integration_oauth_states (
  state text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null references integration_providers (id),
  verifier_enc text,
  extra_enc text,
  return_to text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes'
);
alter table integration_oauth_states enable row level security;
revoke all on integration_oauth_states from anon, authenticated;

-- Journal de synchronisation (sans contenu sensible).
create table if not exists integration_sync_logs (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references integration_connections (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null,
  trigger text not null default 'manual' check (trigger in ('manual', 'webhook', 'schedule', 'connect')),
  status text not null check (status in ('ok', 'partial', 'error', 'throttled')),
  imported int not null default 0,
  skipped int not null default 0,
  message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);
create index if not exists integration_sync_logs_conn on integration_sync_logs (connection_id, started_at desc);
alter table integration_sync_logs enable row level security;
drop policy if exists "journal sync : propriétaire" on integration_sync_logs;
create policy "journal sync : propriétaire" on integration_sync_logs for select to authenticated using (user_id = auth.uid());

-- Contenus importés : jamais en double (clé unique par connexion + identifiant externe).
create table if not exists integration_imported_items (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references integration_connections (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  provider text not null references integration_providers (id),
  external_id text not null,
  kind text not null default 'post',         -- post, video, repo, file, page
  title text not null default '',
  body text,
  url text,
  media_url text,
  published_at timestamptz,
  visibility text not null default 'private' check (visibility in ('private', 'portfolio', 'public')),
  imported_at timestamptz not null default now(),
  unique (connection_id, external_id)
);
create index if not exists integration_items_user on integration_imported_items (user_id, imported_at desc);
alter table integration_imported_items enable row level security;
drop policy if exists "contenus importés : propriétaire" on integration_imported_items;
create policy "contenus importés : propriétaire" on integration_imported_items for select to authenticated using (user_id = auth.uid());
drop policy if exists "contenus importés : publics" on integration_imported_items;
create policy "contenus importés : publics" on integration_imported_items for select to authenticated using (visibility = 'public');

-- Publications Boutik-École → plateformes.
create table if not exists integration_publications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  content text not null check (length(content) between 1 and 5000),
  link_url text,
  media_url text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
alter table integration_publications enable row level security;
drop policy if exists "publications : propriétaire" on integration_publications;
create policy "publications : propriétaire" on integration_publications for select to authenticated using (user_id = auth.uid());

create table if not exists integration_publication_targets (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references integration_publications (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  connection_id uuid not null references integration_connections (id) on delete cascade,
  account_id uuid references integration_accounts (id) on delete set null,
  provider text not null,
  adapted_text text not null,
  status text not null default 'queued' check (status in ('queued', 'sent', 'failed', 'unsupported')),
  result_url text,
  external_id text,
  error text,
  sent_at timestamptz,
  unique (publication_id, connection_id, account_id)
);
alter table integration_publication_targets enable row level security;
drop policy if exists "cibles de publication : propriétaire" on integration_publication_targets;
create policy "cibles de publication : propriétaire" on integration_publication_targets for select to authenticated using (user_id = auth.uid());

-- Actions de l'utilisateur sur ses propres contenus importés.
create or replace function integrations_set_item_visibility(p_item uuid, p_visibility text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_visibility not in ('private', 'portfolio', 'public') then raise exception 'Visibilité invalide'; end if;
  update integration_imported_items set visibility = p_visibility where id = p_item and user_id = auth.uid();
  if not found then raise exception 'Contenu introuvable'; end if;
end $$;

create or replace function integrations_delete_item(p_item uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from integration_imported_items where id = p_item and user_id = auth.uid();
end $$;

-- Choix des comptes (pages, salons…) sur lesquels publier.
create or replace function integrations_set_account_publish(p_account uuid, p_enabled boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update integration_accounts set publish_enabled = p_enabled where id = p_account and user_id = auth.uid();
  if not found then raise exception 'Compte introuvable'; end if;
end $$;

-- Lien de portfolio saisi à la main (fournisseurs « link_only », ex. Behance) : adresse https:// obligatoire.
create or replace function integrations_save_link(p_provider text, p_url text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_kind text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select auth_kind into v_kind from integration_providers where id = p_provider;
  if v_kind is distinct from 'link_only' then raise exception 'Ce fournisseur se connecte par autorisation officielle'; end if;
  if p_url !~* '^https://[^\s/]+\.[^\s/]+/?\S{0,250}$' then raise exception 'Adresse https:// attendue'; end if;
  insert into integration_connections (user_id, provider, external_id, display_name, profile_url, status)
    values (auth.uid(), p_provider, lower(p_url), p_url, p_url, 'connected')
    on conflict (user_id, provider, external_id) do update set status = 'connected'
    returning id into v_id;
  return v_id;
end $$;

-- ------------------------------------------------------------------ Mobile Money
create sequence if not exists momo_ref_seq;

create table if not exists momo_numbers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  operator text not null check (operator in ('MTN', 'ORANGE')),
  phone text not null check (phone ~ '^2376[0-9]{8}$'),
  label text not null default '',
  is_primary boolean not null default false,
  verification_status text not null default 'unverified' check (verification_status in ('unverified', 'pending', 'verified', 'failed')),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, phone)
);
create unique index if not exists momo_numbers_one_primary on momo_numbers (user_id) where is_primary;
alter table momo_numbers enable row level security;
drop policy if exists "numéros momo : propriétaire" on momo_numbers;
create policy "numéros momo : propriétaire" on momo_numbers for select to authenticated using (user_id = auth.uid());

-- Codes de vérification : jamais en clair (empreinte SHA-256), à usage unique, 10 minutes, 5 essais. Service uniquement.
create table if not exists momo_verifications (
  id uuid primary key default gen_random_uuid(),
  number_id uuid not null references momo_numbers (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  code_hash text not null,
  attempts int not null default 0,
  expires_at timestamptz not null default now() + interval '10 minutes',
  used boolean not null default false,
  created_at timestamptz not null default now()
);
alter table momo_verifications enable row level security;
revoke all on momo_verifications from anon, authenticated;

create table if not exists momo_transactions (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  user_id uuid not null references auth.users (id) on delete cascade,
  number_id uuid references momo_numbers (id) on delete set null,
  operator text not null check (operator in ('MTN', 'ORANGE')),
  direction text not null default 'out' check (direction in ('out', 'in')),
  counterparty_phone text not null check (counterparty_phone ~ '^2376[0-9]{8}$'),
  counterparty_name text,
  amount int not null check (amount > 0),
  currency text not null default 'XAF',
  fee int,
  note text,
  status text not null default 'awaiting_confirmation'
    check (status in ('awaiting_confirmation', 'pending', 'confirmed', 'failed', 'cancelled')),
  idempotency_key text not null,
  provider_ref text,                         -- identifiant renvoyé par l'opérateur
  failure_reason text,
  confirmed_by_user_at timestamptz,          -- confirmation explicite de l'utilisateur
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index if not exists momo_tx_user on momo_transactions (user_id, created_at desc);
create index if not exists momo_tx_provider_ref on momo_transactions (provider_ref);
alter table momo_transactions enable row level security;
drop policy if exists "transactions momo : propriétaire" on momo_transactions;
create policy "transactions momo : propriétaire" on momo_transactions for select to authenticated using (user_id = auth.uid());

create or replace function momo_normalize(p text) returns text language sql immutable as $$
  select case
    when regexp_replace(coalesce(p, ''), '\D', '', 'g') ~ '^6[0-9]{8}$' then '237' || regexp_replace(p, '\D', '', 'g')
    else regexp_replace(coalesce(p, ''), '\D', '', 'g') end $$;

create or replace function momo_add_number(p_operator text, p_phone text, p_label text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_phone text := momo_normalize(p_phone); v_id uuid; v_first boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if upper(p_operator) not in ('MTN', 'ORANGE') then raise exception 'Opérateur inconnu (MTN ou ORANGE)'; end if;
  if v_phone !~ '^2376[0-9]{8}$' then raise exception 'Numéro attendu : 6XX XX XX XX'; end if;
  if (select count(*) from momo_numbers where user_id = auth.uid()) >= 10 then raise exception 'Dix numéros au maximum'; end if;
  v_first := not exists (select 1 from momo_numbers where user_id = auth.uid());
  insert into momo_numbers (user_id, operator, phone, label, is_primary)
    values (auth.uid(), upper(p_operator), v_phone, left(trim(coalesce(p_label, '')), 40), v_first) returning id into v_id;
  return v_id;
exception when unique_violation then raise exception 'Ce numéro est déjà enregistré';
end $$;

create or replace function momo_set_primary(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from momo_numbers where id = p_id and user_id = auth.uid()) then raise exception 'Numéro introuvable'; end if;
  update momo_numbers set is_primary = false where user_id = auth.uid() and is_primary and id <> p_id;
  update momo_numbers set is_primary = true where id = p_id and user_id = auth.uid();
end $$;

create or replace function momo_rename_number(p_id uuid, p_label text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update momo_numbers set label = left(trim(coalesce(p_label, '')), 40) where id = p_id and user_id = auth.uid();
  if not found then raise exception 'Numéro introuvable'; end if;
end $$;

create or replace function momo_remove_number(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_primary boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select is_primary into v_primary from momo_numbers where id = p_id and user_id = auth.uid();
  if not found then raise exception 'Numéro introuvable'; end if;
  if exists (select 1 from momo_transactions where number_id = p_id and status in ('awaiting_confirmation', 'pending')) then
    raise exception 'Une transaction est en cours sur ce numéro';
  end if;
  delete from momo_numbers where id = p_id and user_id = auth.uid();
  if v_primary then
    update momo_numbers set is_primary = true where id = (select id from momo_numbers where user_id = auth.uid() order by created_at limit 1);
  end if;
end $$;

-- Vérification du code reçu par SMS (le code est créé et envoyé par l'Edge Function « momo »).
create or replace function momo_confirm_verification(p_id uuid, p_code text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare v momo_verifications%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into v from momo_verifications where number_id = p_id and user_id = auth.uid() and not used order by created_at desc limit 1 for update;
  if not found or v.expires_at < now() then raise exception 'Code expiré : demandez-en un nouveau'; end if;
  if v.attempts >= 5 then raise exception 'Trop d''essais : demandez un nouveau code'; end if;
  if encode(digest(coalesce(p_code, ''), 'sha256'), 'hex') <> v.code_hash then
    update momo_verifications set attempts = attempts + 1 where id = v.id;
    return false;
  end if;
  update momo_verifications set used = true where id = v.id;
  update momo_numbers set verification_status = 'verified', verified_at = now() where id = p_id and user_id = auth.uid();
  return true;
end $$;

-- Prépare un envoi : AUCUN débit. L'envoi n'a lieu qu'après la confirmation explicite (Edge Function « momo », action confirm_transfer).
create or replace function momo_prepare_transfer(p_number uuid, p_to text, p_amount int, p_note text, p_idem text) returns text
language plpgsql security definer set search_path = public as $$
declare n momo_numbers%rowtype; v_to text := momo_normalize(p_to); v_ref text; v_max int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(length(p_idem), 0) < 8 then raise exception 'Clé d''unicité manquante'; end if;
  select reference into v_ref from momo_transactions where user_id = auth.uid() and idempotency_key = p_idem;
  if found then return v_ref; end if;                       -- même demande rejouée : même transaction, jamais un second envoi
  select * into n from momo_numbers where id = p_number and user_id = auth.uid();
  if not found then raise exception 'Numéro introuvable'; end if;
  if n.verification_status <> 'verified' then raise exception 'Vérifiez ce numéro avant d''envoyer de l''argent'; end if;
  if v_to !~ '^2376[0-9]{8}$' then raise exception 'Numéro du destinataire invalide'; end if;
  if v_to = n.phone then raise exception 'Le destinataire doit être différent de l''expéditeur'; end if;
  v_max := coalesce((select (value #>> '{}')::int from platform_settings where key = 'momo.transfer_max'), 500000);
  if p_amount is null or p_amount < 1 or p_amount > v_max then raise exception 'Montant invalide (1 à % FCFA)', v_max; end if;
  if exists (select 1 from momo_transactions where user_id = auth.uid() and number_id = p_number and counterparty_phone = v_to and amount = p_amount
             and status in ('awaiting_confirmation', 'pending') and created_at > now() - interval '5 minutes') then
    raise exception 'Un envoi identique est déjà en cours';
  end if;
  v_ref := 'MM' || to_char(now(), 'YYMMDD') || lpad(nextval('momo_ref_seq')::text, 6, '0');
  insert into momo_transactions (reference, user_id, number_id, operator, direction, counterparty_phone, amount, note, idempotency_key)
    values (v_ref, auth.uid(), p_number, n.operator, 'out', v_to, p_amount, left(trim(coalesce(p_note, '')), 120), p_idem);
  return v_ref;
end $$;

create or replace function momo_cancel_transfer(p_ref text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update momo_transactions set status = 'cancelled', decided_at = now()
    where reference = p_ref and user_id = auth.uid() and status = 'awaiting_confirmation';
  if not found then raise exception 'Transaction introuvable ou déjà engagée'; end if;
end $$;

create or replace function momo_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m timestamptz := date_trunc('month', now());
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'sent_month', (select coalesce(sum(amount), 0) from momo_transactions where user_id = auth.uid() and direction = 'out' and status = 'confirmed' and created_at >= m),
    'received_month', (select coalesce(sum(amount), 0) from momo_transactions where user_id = auth.uid() and direction = 'in' and status = 'confirmed' and created_at >= m),
    'pending', (select count(*) from momo_transactions where user_id = auth.uid() and status in ('awaiting_confirmation', 'pending')),
    'failed_month', (select count(*) from momo_transactions where user_id = auth.uid() and status = 'failed' and created_at >= m),
    'count_month', (select count(*) from momo_transactions where user_id = auth.uid() and status = 'confirmed' and created_at >= m),
    'numbers', (select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'sent', coalesce(s.sent, 0), 'received', coalesce(s.received, 0))), '[]'::jsonb)
                from momo_numbers n left join lateral (
                  select sum(amount) filter (where direction = 'out') sent, sum(amount) filter (where direction = 'in') received
                  from momo_transactions t where t.number_id = n.id and t.status = 'confirmed' and t.created_at >= m) s on true
                where n.user_id = auth.uid()));
end $$;

-- Droits : seules les fonctions de l'utilisateur connecté sont exposées.
revoke all on function integrations_set_item_visibility(uuid, text), integrations_delete_item(uuid), integrations_set_account_publish(uuid, boolean),
  integrations_save_link(text, text), momo_add_number(text, text, text), momo_set_primary(uuid), momo_rename_number(uuid, text), momo_remove_number(uuid),
  momo_confirm_verification(uuid, text), momo_prepare_transfer(uuid, text, int, text, text), momo_cancel_transfer(text), momo_dashboard() from public, anon;
grant execute on function integrations_set_item_visibility(uuid, text), integrations_delete_item(uuid), integrations_set_account_publish(uuid, boolean),
  integrations_save_link(text, text), momo_add_number(text, text, text), momo_set_primary(uuid), momo_rename_number(uuid, text), momo_remove_number(uuid),
  momo_confirm_verification(uuid, text), momo_prepare_transfer(uuid, text, int, text, text), momo_cancel_transfer(text), momo_dashboard() to authenticated;
