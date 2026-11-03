-- 20261031b — Paramètres de l'établissement, modèles de notifications, clés d'intégration (empreintes), fichiers de projet et de mission,
-- messagerie des missions, liens de CV, codes de retrait, invitations d'équipe du département.
-- Dépend de 20261031a (missions, propositions). Mêmes principes : RLS partout, écritures par fonctions serveur, idempotente.

-- ============================================================ établissement et identité visuelle (118)
create table if not exists institution_settings (
  id text primary key default 'iut-douala',
  name text not null check (char_length(name) between 3 and 120),
  acronym text not null check (char_length(acronym) between 2 and 20),
  address text check (address is null or char_length(address) <= 200),
  email text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$'),
  phone text check (phone is null or char_length(phone) <= 30),
  primary_color text not null default '#12253F' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  accent_color text not null default '#FBB52B' check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  font text check (font is null or char_length(font) <= 60),
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table institution_settings enable row level security;
revoke all on institution_settings from anon, authenticated;
grant select on institution_settings to anon, authenticated;
drop policy if exists "établissement : identité publique" on institution_settings;
create policy "établissement : identité publique" on institution_settings for select using (true);
insert into institution_settings (id, name, acronym, address, email, phone, primary_color, accent_color, font)
values ('iut-douala', 'IUT de Douala', 'IUT-D', 'Bonabéri, Douala', 'contact@iut-douala.cm', null, '#12253F', '#FBB52B', 'Sans-serif professionnelle')
on conflict (id) do nothing;

create or replace function save_institution(p_name text, p_acronym text, p_address text, p_email text, p_phone text,
                                            p_primary text, p_accent text, p_font text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('direction', 'admin') then raise exception 'Réservé à la direction ou à l''administrateur'; end if;
  if p_primary !~ '^#[0-9A-Fa-f]{6}$' or p_accent !~ '^#[0-9A-Fa-f]{6}$' then raise exception 'Couleurs au format #RRVVBB'; end if;
  if nullif(trim(coalesce(p_email, '')), '') is not null and trim(p_email) !~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$' then raise exception 'Adresse e-mail invalide'; end if;
  update institution_settings set name = trim(p_name), acronym = trim(p_acronym), address = nullif(trim(coalesce(p_address, '')), ''),
    email = nullif(trim(coalesce(p_email, '')), ''), phone = nullif(trim(coalesce(p_phone, '')), ''), primary_color = upper(p_primary),
    accent_color = upper(p_accent), font = nullif(trim(coalesce(p_font, '')), ''), updated_by = auth.uid(), updated_at = now()
  where id = 'iut-douala';
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Identité de l''établissement modifiée', 'iut-douala', 'Administration', 'Sensible');
  return 'saved';
end $$;

-- ============================================================ modèles de notifications (265)
create table if not exists notification_templates (
  key text primary key check (key ~ '^[a-z_]{3,40}$'),
  label text not null check (char_length(label) between 3 and 80),
  channels text[] not null default '{email}' check (channels <@ array['email', 'sms', 'whatsapp', 'app']::text[] and cardinality(channels) between 1 and 4),
  subject text check (subject is null or char_length(subject) <= 150),
  body text not null check (char_length(body) between 5 and 2000),
  active boolean not null default true,
  updated_by uuid references profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table notification_templates enable row level security;
revoke all on notification_templates from anon, authenticated;
grant select on notification_templates to authenticated;
drop policy if exists "modèles : administration" on notification_templates;
create policy "modèles : administration" on notification_templates for select using (current_role_name() in ('admin', 'support'));
insert into notification_templates (key, label, channels, subject, body) values
  ('order_confirmed', 'Commande confirmée', '{email,sms}', 'Votre commande {{numero}} est confirmée', 'Bonjour {{nom}}, votre commande {{numero}} est confirmée. Retrait : {{point_retrait}}.'),
  ('payment_failed', 'Paiement échoué', '{sms,whatsapp}', null, 'Le paiement de la commande {{numero}} a échoué. Réessayez depuis l''application.'),
  ('order_ready', 'Commande prête au retrait', '{sms,app}', null, 'Votre commande {{numero}} est prête. Code de retrait : {{code}}.'),
  ('quote_received', 'Devis reçu', '{email,app}', 'Nouveau devis pour {{service}}', 'Vous avez reçu un devis de {{montant}} FCFA pour « {{service}} ».')
on conflict (key) do nothing;

create or replace function save_notification_template(p_key text, p_subject text, p_body text, p_channels text[], p_active boolean) returns text
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_body is null or char_length(trim(p_body)) < 5 then raise exception 'Le message doit comporter au moins 5 caractères'; end if;
  if p_channels is null or cardinality(p_channels) = 0 or not (p_channels <@ array['email', 'sms', 'whatsapp', 'app']::text[]) then raise exception 'Canaux : email, sms, whatsapp, app'; end if;
  update notification_templates set subject = nullif(trim(coalesce(p_subject, '')), ''), body = trim(p_body), channels = p_channels,
    active = coalesce(p_active, true), updated_by = auth.uid(), updated_at = now() where key = p_key;
  if not found then raise exception 'Modèle introuvable'; end if;
  return 'saved';
end $$;

-- ============================================================ clés d'intégration (280) : seule l'empreinte SHA-256 est conservée
create table if not exists api_keys (
  id uuid primary key default gen_random_uuid(),
  label text not null check (char_length(label) between 3 and 60),
  prefix text not null,
  key_hash text not null unique,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
alter table api_keys enable row level security;
revoke all on api_keys from anon, authenticated;
grant select (id, label, prefix, created_at, revoked_at) on api_keys to authenticated;
drop policy if exists "clés : administration" on api_keys;
create policy "clés : administration" on api_keys for select using (current_role_name() = 'admin');

create or replace function create_api_key(p_label text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare k text;
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_label is null or char_length(trim(p_label)) not between 3 and 60 then raise exception 'Nom de la clé : 3 à 60 caractères'; end if;
  k := 'be_live_' || encode(gen_random_bytes(24), 'hex');
  insert into api_keys (label, prefix, key_hash, created_by) values (trim(p_label), left(k, 12), encode(digest(k, 'sha256'), 'hex'), auth.uid());
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Clé d''intégration créée', trim(p_label), 'Sécurité', 'Critique');
  return k;  -- affichée une seule fois ; jamais stockée en clair
end $$;

create or replace function revoke_api_key(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  update api_keys set revoked_at = now() where id = p_id and revoked_at is null;
  if not found then raise exception 'Clé introuvable ou déjà révoquée'; end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Clé d''intégration révoquée', p_id::text, 'Sécurité', 'Critique');
  return 'revoked';
end $$;

-- ============================================================ missions : participants, messagerie (196)
create or replace function is_mission_participant(p_mission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from missions m where m.id = p_mission and (m.client_id = auth.uid()
           or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')))
      or coalesce(current_role_name()::text, '') in ('dept', 'admin');
$$;

create table if not exists mission_messages (
  id bigint generated always as identity primary key,
  mission_id uuid not null references missions(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  file_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists mission_messages_mission_idx on mission_messages (mission_id, created_at);
alter table mission_messages enable row level security;
revoke all on mission_messages from anon, authenticated;
grant select on mission_messages to authenticated;
drop policy if exists "dossier : participants de la mission" on mission_messages;
create policy "dossier : participants de la mission" on mission_messages for select using (is_mission_participant(mission_id));

create or replace function send_mission_message(p_mission uuid, p_body text, p_file uuid default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid bigint; who uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or not is_mission_participant(p_mission) then raise exception 'Dossier introuvable'; end if;
  if m.status not in ('assigned', 'in_progress', 'delivered') then raise exception 'Le dossier s''ouvre une fois la mission attribuée'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  insert into mission_messages (mission_id, sender_id, body, file_id) values (m.id, auth.uid(), left(trim(p_body), 2000), p_file) returning id into mid;
  -- l'autre partie est notifiée (client <-> prestataire retenu)
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

-- ============================================================ fichiers (263 médiathèque, 83 et 279 projet, 196 dossier de mission)
-- Compartiment privé ; chemin « <uid>/<portée>/<fichier> » ; types autorisés et taille plafonnés par le stockage lui-même.
-- (Pas d'antivirus côté serveur : les exécutables et archives non listées sont refusés par type ; documenté.)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('project-files', 'project-files', false, 52428800,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4', 'application/zip'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create table if not exists files (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  scope text not null check (scope in ('media', 'project', 'mission')),
  ref uuid,
  path text not null unique,
  name text not null check (char_length(name) between 1 and 160),
  mime text not null check (mime in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4', 'application/zip')),
  size_bytes integer not null check (size_bytes between 1 and 52428800),
  created_at timestamptz not null default now()
);
alter table files enable row level security;
revoke all on files from anon, authenticated;
grant select on files to authenticated;
drop policy if exists "fichiers : propriétaire, mission, département" on files;
create policy "fichiers : propriétaire, mission, département" on files for select
  using (owner_id = auth.uid() or (scope = 'mission' and ref is not null and is_mission_participant(ref)) or current_role_name() in ('dept', 'admin'));

create or replace function storage_file_allowed(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select (storage.foldername(p_name))[1] = auth.uid()::text
      or coalesce(current_role_name()::text, '') in ('dept', 'admin')
      or exists (select 1 from files f where f.path = p_name and f.scope = 'mission' and f.ref is not null and is_mission_participant(f.ref));
$$;
drop policy if exists "fichiers projet : lecture autorisée" on storage.objects;
create policy "fichiers projet : lecture autorisée" on storage.objects for select to authenticated
  using (bucket_id = 'project-files' and storage_file_allowed(name));
drop policy if exists "fichiers projet : dépôt dans son dossier" on storage.objects;
create policy "fichiers projet : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'project-files' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "fichiers projet : suppression par le propriétaire" on storage.objects;
create policy "fichiers projet : suppression par le propriétaire" on storage.objects for delete to authenticated
  using (bucket_id = 'project-files' and owner_id = auth.uid()::text);

-- Enregistre un fichier déposé : le chemin doit être dans le dossier de l'auteur, le type et la taille conformes, la portée autorisée.
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
  if p_scope = 'mission' and (p_ref is null or not is_mission_participant(p_ref)) then raise exception 'Dossier introuvable'; end if;
  insert into files (owner_id, scope, ref, path, name, mime, size_bytes) values (auth.uid(), p_scope, p_ref, p_path, left(p_name, 160), p_mime, p_size) returning id into fid;
  return fid;
end $$;

-- ============================================================ lien de CV partageable (228)
create table if not exists cv_links (
  token text primary key check (token ~ '^[0-9a-f]{32}$'),
  owner_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
alter table cv_links enable row level security;
revoke all on cv_links from anon, authenticated;
grant select on cv_links to authenticated;
drop policy if exists "liens de CV : propriétaire" on cv_links;
create policy "liens de CV : propriétaire" on cv_links for select using (owner_id = auth.uid());

-- Régénérer : l'ancien lien cesse immédiatement de fonctionner.
create or replace function regenerate_cv_link() returns text
language plpgsql security definer set search_path = public, extensions as $$
declare t text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update cv_links set revoked_at = now() where owner_id = auth.uid() and revoked_at is null;
  t := encode(gen_random_bytes(16), 'hex');
  insert into cv_links (token, owner_id) values (t, auth.uid());
  return t;
end $$;

-- Consultation publique d'un CV partagé : uniquement ce que la personne montre (pas de téléphone ni d'e-mail).
create or replace function shared_cv(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('nom', p.name, 'departement', p.department, 'etablissement', p.institution, 'bio', p.bio, 'competences', p.skills,
           'certifie', p.certification::text = 'approved', 'liens', p.links)
  from cv_links c join profiles p on p.id = c.owner_id
  where c.token = p_token and c.revoked_at is null and not p.suspended;
$$;

-- ============================================================ code de retrait (46 acheteur, 146-2 kiosque)
alter table orders add column if not exists pickup_code text check (pickup_code is null or pickup_code ~ '^[0-9]{6}$');
alter table orders add column if not exists picked_up_at timestamptz;

create or replace function my_pickup_code(p_number text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  select * into o from orders where number = p_number and buyer_id = auth.uid();
  if not found then raise exception 'Commande introuvable'; end if;
  if not o.paid or o.cancelled or o.cancelled_at is not null then raise exception 'Le code de retrait est délivré une fois la commande payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà retirée'; end if;
  if o.pickup_code is null then
    update orders set pickup_code = lpad((floor(random() * 1000000))::int::text, 6, '0') where id = o.id returning pickup_code into o.pickup_code;
  end if;
  return o.pickup_code;
end $$;

-- Remise au kiosque : le code présenté doit correspondre ; la commande passe « livrée ».
create or replace function confirm_pickup(p_number text, p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au personnel du kiosque'; end if;
  select * into o from orders where number = p_number for update;
  if not found or not o.paid or o.cancelled then raise exception 'Commande introuvable ou non payée'; end if;
  if o.picked_up_at is not null then raise exception 'Commande déjà remise'; end if;
  if o.pickup_code is null or o.pickup_code <> trim(coalesce(p_code, '')) then
    insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Code de retrait erroné', o.number, 'Kiosques', 'Sensible');
    raise exception 'Code de retrait incorrect';
  end if;
  update orders set picked_up_at = now(), status = 3 where id = o.id;
  update order_lines set fulfillment = 4 where order_id = o.id;
  insert into notifications (user_id, kind, title, body, data) values (o.buyer_id, 'order', 'Commande retirée', o.number, jsonb_build_object('order_number', o.number));
  return 'delivered';
end $$;

-- ============================================================ invitations d'équipe du département (286)
create table if not exists department_invitations (
  id uuid primary key default gen_random_uuid(),
  email text not null check (email ~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$'),
  role text not null check (role in ('validator', 'moderator', 'member')),
  invited_by uuid not null references profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'revoked')),
  created_at timestamptz not null default now(),
  unique (email, invited_by)
);
alter table department_invitations enable row level security;
revoke all on department_invitations from anon, authenticated;
grant select on department_invitations to authenticated;
drop policy if exists "invitations : département et invité" on department_invitations;
create policy "invitations : département et invité" on department_invitations for select
  using (invited_by = auth.uid() or current_role_name() = 'admin' or lower(email) = lower(coalesce((select email from profiles where id = auth.uid()), '')));

create or replace function invite_department_member(p_email text, p_role text) returns text
language plpgsql security definer set search_path = public as $$
declare target uuid;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au responsable de département'; end if;
  if p_role not in ('validator', 'moderator', 'member') then raise exception 'Rôle inconnu'; end if;
  if trim(coalesce(p_email, '')) !~* '^[^@\s]+@[^@\s]+\.[a-z]{2,}$' then raise exception 'Adresse e-mail invalide'; end if;
  insert into department_invitations (email, role, invited_by) values (lower(trim(p_email)), p_role, auth.uid())
  on conflict (email, invited_by) do update set role = excluded.role, status = 'pending', created_at = now();
  select id into target from profiles where lower(email) = lower(trim(p_email));
  if target is not null then
    insert into notifications (user_id, kind, title, body, data) values (target, 'team', 'Invitation dans l''équipe du département', 'Rôle proposé : ' || p_role, jsonb_build_object('role', p_role));
  end if;
  return case when target is null then 'invited' else 'notified' end;
end $$;

-- ============================================================ droits d'exécution
revoke all on function save_institution(text, text, text, text, text, text, text, text), save_notification_template(text, text, text, text[], boolean),
  create_api_key(text), revoke_api_key(uuid), send_mission_message(uuid, text, uuid), register_file(text, uuid, text, text, text, integer),
  regenerate_cv_link(), my_pickup_code(text), confirm_pickup(text, text), invite_department_member(text, text),
  is_mission_participant(uuid), storage_file_allowed(text) from public, anon;
grant execute on function save_institution(text, text, text, text, text, text, text, text), save_notification_template(text, text, text, text[], boolean),
  create_api_key(text), revoke_api_key(uuid), send_mission_message(uuid, text, uuid), register_file(text, uuid, text, text, text, integer),
  regenerate_cv_link(), my_pickup_code(text), confirm_pickup(text, text), invite_department_member(text, text),
  is_mission_participant(uuid), storage_file_allowed(text) to authenticated;
revoke all on function shared_cv(text) from public;
grant execute on function shared_cv(text) to anon, authenticated;

-- ============================================================ RETOUR ARRIÈRE (manuel)
-- drop function if exists save_institution(text,text,text,text,text,text,text,text), save_notification_template(text,text,text,text[],boolean),
--   create_api_key(text), revoke_api_key(uuid), send_mission_message(uuid,text,uuid), register_file(text,uuid,text,text,text,integer),
--   regenerate_cv_link(), shared_cv(text), my_pickup_code(text), confirm_pickup(text,text), invite_department_member(text,text);
-- drop policy if exists "fichiers projet : lecture autorisée" on storage.objects; drop policy if exists "fichiers projet : dépôt dans son dossier" on storage.objects;
-- drop policy if exists "fichiers projet : suppression par le propriétaire" on storage.objects; drop function if exists storage_file_allowed(text);
-- drop table if exists department_invitations, cv_links, files, mission_messages, api_keys, notification_templates, institution_settings;
-- drop function if exists is_mission_participant(uuid);
-- alter table orders drop column if exists pickup_code, drop column if exists picked_up_at;
-- (le compartiment « project-files » se supprime depuis le tableau de bord après vidage)
