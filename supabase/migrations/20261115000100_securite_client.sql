-- Sécurité et confidentialité du profil Client (suite de 20261114004300).
--  1. messagerie : blocages respectés par les trois fonctions de création de conversation + plafond de débit, is_blocked_between ne révèle plus les blocages d'autrui
--  2. profils publics : public_profile et seller_public ne servent plus d'annuaire (plus d'oracle nom → identifiant, plus de profil client ou équipe)
--  3. profiles : longueurs bornées, e-mail et téléphone protégés, colonnes modifiables limitées, numéro unique, procédure profile_set_phone
--  4. projets, étapes, compétences : lecture réservée à ce qui est publiquement validé ou à son propriétaire ; dépôt de médias de projet réservé aux porteurs de projet
--  5. mentors et communautés éphémères : plus de publication immédiate ouverte à tous les rôles
--  6. publish_due_posts : réservée à la tâche planifiée
--  7. file de notifications : clé interne (plus d'appel anonyme), prise en charge atomique des messages
-- Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Messagerie
create or replace function is_blocked_between(p_a uuid, p_b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null or auth.uid() in (p_a, p_b)
    then exists (select 1 from user_blocks where (blocker_id = p_a and blocked_id = p_b) or (blocker_id = p_b and blocked_id = p_a))
    else false end
$$;

create or replace function chat_guard(p_other uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_other is not null and exists (select 1 from user_blocks where (blocker_id = auth.uid() and blocked_id = p_other) or (blocker_id = p_other and blocked_id = auth.uid())) then
    raise exception 'Cette personne ne peut pas recevoir vos messages';
  end if;
  if (select count(*) from messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then
    raise exception 'Trop de messages : patientez un instant';
  end if;
end $$;
revoke all on function chat_guard(uuid) from public, anon, authenticated;

create or replace function start_conversation(p_listing uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found then raise exception 'Annonce introuvable'; end if;
  if l.seller_id is null then raise exception 'Annonce de la plateforme : contactez le support'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  perform chat_guard(l.seller_id);
  select c.id into cid from conversations c
    where c.listing_id = l.id
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = l.seller_id)
    limit 1;
  if cid is null then
    if (select count(*) from conversations where created_by = auth.uid() and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Trop de nouvelles conversations aujourd''hui';
    end if;
    insert into conversations (listing_id, created_by) values (l.id, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, l.seller_id, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;

create or replace function start_order_conversation(p_order text, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; seller uuid; other uuid; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  select * into o from orders where number = p_order;
  if not found then raise exception 'Commande introuvable'; end if;
  select l.seller_id into seller from order_lines ol join listings l on l.id = ol.listing_id
    where ol.order_id = o.id and l.seller_id is not null order by ol.id limit 1;
  if auth.uid() = o.buyer_id then
    if seller is null then raise exception 'Commande de la plateforme : pas de vendeur étudiant à qui écrire'; end if;
    other := seller;
  elsif exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id = auth.uid()) then
    other := o.buyer_id;
  else
    raise exception 'Commande introuvable';
  end if;
  perform chat_guard(other);
  select c.id into cid from conversations c
    where c.order_number = o.number
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = other)
    limit 1;
  if cid is null then
    insert into conversations (order_number, created_by) values (o.number, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, other, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;

create or replace function start_direct_conversation(p_user uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user and not coalesce(suspended, false)) then raise exception 'Destinataire introuvable'; end if;
  perform chat_guard(p_user);
  select c.id into cid from conversations c
    where c.listing_id is null and c.order_number is null
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = p_user)
      and (select count(*) from conversation_participants p where p.conversation_id = c.id) = 2
    limit 1;
  if cid is null then
    if (select count(*) from conversations where created_by = auth.uid() and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Trop de nouvelles conversations aujourd''hui';
    end if;
    insert into conversations (listing_id, created_by) values (null, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, p_user, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), left(trim(p_body), 4000));
  return cid;
end $$;

-- ============================================================ 2. Profils publics
create or replace function public_profile(p_user uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'role', case when p.role::text in ('student', 'company', 'other') then p.role::text else 'student' end,
    'city', coalesce(p.city, ''),
    'institution', coalesce(p.institution, ''),
    'department', coalesce(p.department, ''),
    'bio', coalesce(p.bio, ''),
    'skills', coalesce(p.skills, ''),
    'avatar_url', p.avatar_url,
    'certified', p.certification::text = 'approved',
    'posts_count', (select count(*)::int from posts x where x.author_id = p.id and x.status = 'published' and x.kind = 'media' and x.community_id is null),
    'followers_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.ref = p.id::text and e.status = 'active'),
    'following_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.user_id = p.id and e.status = 'active'),
    'rating', coalesce((select round(avg(r.rating)::numeric, 2) from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id), 0),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id)
  )
  from profiles p
  where p.id = p_user and not coalesce(p.suspended, false)
    and (
      p.id = auth.uid()
      or (p.role::text in ('student', 'company', 'other'))
      or (p.role::text not in ('admin', 'direction', 'finance', 'support', 'client', 'visitor')
          and (exists (select 1 from posts x where x.author_id = p.id and x.status = 'published' and x.community_id is null)
            or exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')))
    );
$$;

drop function if exists seller_public(text, uuid);
create or replace function seller_public(p_name text default null, p_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_p profiles%rowtype; v_n integer;
begin
  if p_id is not null then
    select * into v_p from profiles p where p.id = p_id and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved');
  else
    if nullif(trim(coalesce(p_name, '')), '') is null then return jsonb_build_object('found', false); end if;
    select count(*) into v_n from profiles p where lower(p.name) = lower(trim(p_name))
      and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved');
    if v_n > 1 then return jsonb_build_object('found', false, 'ambiguous', true); end if;
    if v_n = 0 then return jsonb_build_object('found', false); end if;
    select * into v_p from profiles p where lower(p.name) = lower(trim(p_name))
      and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved') limit 1;
  end if;
  if v_p.id is null or coalesce(v_p.suspended, false) then return jsonb_build_object('found', false); end if;
  v_id := v_p.id;
  return jsonb_build_object(
    'found', true,
    'id', v_id,
    'name', v_p.name,
    'department', coalesce(v_p.department, ''),
    'institution', coalesce(v_p.institution, ''),
    'verified', v_p.certification::text = 'approved',
    'since', v_p.created_at,
    'shop_slug', (select s.slug from shops s where s.owner_id = v_id and s.status = 'active'),
    'shop_name', (select s.name from shops s where s.owner_id = v_id and s.status = 'active'),
    'products', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category <> 'Services'),
    'services', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category = 'Services'),
    'sales', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = v_id and o.paid and o.cancelled_at is null),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'stars', (select coalesce(jsonb_object_agg(s::text, c), '{}'::jsonb) from (select r.rating s, count(*)::int c from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id group by 1) x)
  );
end $$;
revoke all on function seller_public(text, uuid) from public;
grant execute on function seller_public(text, uuid) to anon, authenticated;

-- ============================================================ 3. profiles
do $$ begin
  alter table profiles add constraint profiles_longueurs_check check (
    char_length(coalesce(name, '')) <= 120 and char_length(coalesce(bio, '')) <= 2000 and char_length(coalesce(city, '')) <= 120
    and char_length(coalesce(skills, '')) <= 1500 and char_length(coalesce(phone, '')) <= 30) not valid;
exception when duplicate_object then null; end $$;
do $$ begin
  alter table profiles validate constraint profiles_longueurs_check;
exception when others then raise notice 'profiles_longueurs_check non validée (données existantes trop longues) : %', sqlerrm;
end $$;

do $$ begin
  create unique index if not exists profiles_phone_norm_uk on profiles ((right(regexp_replace(phone, '\D', '', 'g'), 9))) where phone is not null and phone <> '';
exception when others then raise notice 'index unique des numéros non créé (doublons existants) : %', sqlerrm;
end $$;

create or replace function protect_profile_authority() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
      new.certification := 'none';
      new.certification_decided_by := null;
      new.certification_decided_at := null;
      new.is_test := false;
    end if;
    return new;
  end if;
  if auth.uid() is not null and coalesce(current_setting('app.cert_rpc', true), '') <> '1'
     and (new.certification is distinct from old.certification
          or new.certification_decided_by is distinct from old.certification_decided_by
          or new.certification_decided_at is distinct from old.certification_decided_at) then
    raise exception 'La certification ne peut être modifiée que par la procédure de certification';
  end if;
  if auth.uid() is not null
     and (new.role is distinct from old.role or new.suspended is distinct from old.suspended or new.is_test is distinct from old.is_test)
     and coalesce(current_role_name()::text, '') <> 'admin' then
    raise exception 'Modification du rôle ou du statut réservée à l''administrateur';
  end if;
  if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
    if new.email is distinct from old.email then
      raise exception 'L''adresse e-mail se change depuis la sécurité du compte';
    end if;
    if new.phone is distinct from old.phone and coalesce(old.phone, '') <> '' and coalesce(current_setting('app.phone_rpc', true), '') <> '1' then
      raise exception 'Pour changer de numéro, contactez le support';
    end if;
  end if;
  return new;
end $$;

create or replace function profile_set_phone(p_phone text) returns void
language plpgsql security definer set search_path = public as $$
declare v text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v ~ '^237[0-9]{9}$' then v := substr(v, 4); end if;
  if v !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide : 9 chiffres commençant par 6'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(phone, '') <> '') then raise exception 'Pour changer de numéro, contactez le support'; end if;
  if exists (select 1 from profiles where id <> auth.uid() and right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9) = v) then raise exception 'Ce numéro est déjà utilisé'; end if;
  perform set_config('app.phone_rpc', '1', true);
  update profiles set phone = v where id = auth.uid();
end $$;
revoke all on function profile_set_phone(text) from public, anon;
grant execute on function profile_set_phone(text) to authenticated;

-- Seules les colonnes éditables par la personne passent en écriture directe ; tout le reste (avatar, couverture, matricule, rôle, certification…) passe par des procédures.
revoke update on profiles from anon, authenticated;
grant update (name, city, birth, bio, skills, links, study_level) on profiles to authenticated;

-- ============================================================ 4. Projets, étapes, compétences, stockage
drop policy if exists "projets : porteur, approuvés, département" on projects;
drop policy if exists "projets : porteur et département" on projects;
create policy "projets : porteur et département" on projects for select
  using (owner_id = auth.uid() or current_role_name() in ('dept', 'admin'));

drop policy if exists "étapes : avec le projet" on project_steps;
create policy "étapes : avec le projet" on project_steps for select
  using (exists (select 1 from projects p where p.id = project_id));

drop policy if exists "compétences : lecture connectée" on talent_skills;
drop policy if exists "compétences : propriétaire et équipe" on talent_skills;
create policy "compétences : propriétaire et équipe" on talent_skills for select to authenticated
  using (owner_id = auth.uid() or current_role_name() in ('dept', 'admin', 'support'));

drop policy if exists "projets médias : dépôt dans son dossier" on storage.objects;
create policy "projets médias : dépôt dans son dossier" on storage.objects for insert to authenticated
  with check (bucket_id = 'project-media' and (storage.foldername(name))[1] = (auth.uid())::text and current_role_name() in ('student', 'dept', 'admin'));

-- ============================================================ 5. Mentors et communautés éphémères
create or replace function mentor_save(p_works_at text, p_promo text, p_topics text[], p_bio text, p_availability text default 'available', p_evening boolean default false, p_active boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare v_topics text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') in ('client', 'visitor', '') then raise exception 'Réservé aux étudiants, anciens et professionnels'; end if;
  if char_length(btrim(coalesce(p_works_at, ''))) < 2 then raise exception 'Indiquez où vous travaillez ou étudiez maintenant'; end if;
  select array_agg(btrim(t)) into v_topics from unnest(coalesce(p_topics, '{}'::text[])) t where char_length(btrim(t)) between 2 and 60;
  if v_topics is null or cardinality(v_topics) not between 1 and 10 then raise exception 'Indiquez de 1 à 10 sujets sur lesquels vous pouvez aider'; end if;
  if p_availability not in ('this_week', 'available', 'busy') then raise exception 'Disponibilité inconnue'; end if;
  insert into mentor_profiles (user_id, works_at, promo, topics, bio, availability, evening, active)
  values (auth.uid(), btrim(p_works_at), left(btrim(coalesce(p_promo, '')), 40), v_topics, left(btrim(coalesce(p_bio, '')), 600), p_availability, coalesce(p_evening, false), coalesce(p_active, true))
  on conflict (user_id) do update set works_at = excluded.works_at, promo = excluded.promo, topics = excluded.topics, bio = excluded.bio, availability = excluded.availability, evening = excluded.evening, active = excluded.active;
end $$;

create or replace function create_ephemeral_community(p_name text, p_description text default '', p_days integer default 7, p_privacy text default 'public') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Compte suspendu : création de communauté impossible'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_days is null or p_days not between 1 and 14 then raise exception 'Une communauté éphémère dure de 1 à 14 jours'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and expires_at is not null and expires_at > now()) >= 3 then raise exception 'Trois communautés éphémères actives au plus'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name))) then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, privacy, owner_id, status, kind, interest, expires_at)
    values (btrim(p_name), left(btrim(coalesce(p_description, '')), 2000), p_privacy, auth.uid(), 'pending', 'project', 'Éphémère', now() + make_interval(days => p_days)) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  for r in select id from profiles where role::text in ('admin', 'support') loop
    perform notify_user(r.id, 'community_validation', 'Communauté à valider', display_name(auth.uid()) || ' propose la communauté éphémère « ' || btrim(p_name) || ' ».', jsonb_build_object('community', v_id));
  end loop;
  return v_id;
end $$;

-- ============================================================ 6. publish_due_posts : tâche planifiée uniquement
revoke execute on function publish_due_posts() from public, anon, authenticated;

-- ============================================================ 7. File de notifications : clé interne et prise en charge atomique
create table if not exists internal_secrets (
  name text primary key,
  value text not null,
  created_at timestamptz not null default now()
);
alter table internal_secrets enable row level security;
revoke all on internal_secrets from public, anon, authenticated;
insert into internal_secrets (name, value) values ('dispatch_key', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')) on conflict (name) do nothing;

alter table notification_outbox drop constraint if exists notification_outbox_status_check;
alter table notification_outbox add constraint notification_outbox_status_check check (status in ('queued', 'sending', 'sent', 'failed', 'skipped'));

create or replace function dispatch_key_check(p_key text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(p_key, '') <> '' and exists (select 1 from internal_secrets where name = 'dispatch_key' and value = p_key)
$$;
revoke all on function dispatch_key_check(text) from public, anon, authenticated;
grant execute on function dispatch_key_check(text) to service_role;

create or replace function dispatch_claim(p_limit integer, p_channels text[]) returns setof notification_outbox
language plpgsql security definer set search_path = public as $$
begin
  update notification_outbox set status = 'queued', last_error = 'reprise après interruption'
    where status = 'sending' and created_at < now() - interval '10 minutes';
  return query
    update notification_outbox o set status = 'sending', attempts = attempts + 1
    where o.id in (select q.id from notification_outbox q where q.status = 'queued' and q.channel = any (p_channels) order by q.created_at limit greatest(p_limit, 1) for update skip locked)
    returning o.*;
end $$;
revoke all on function dispatch_claim(integer, text[]) from public, anon, authenticated;
grant execute on function dispatch_claim(integer, text[]) to service_role;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('dispatch-notifications') where exists (select 1 from cron.job where jobname = 'dispatch-notifications');
  perform cron.schedule('dispatch-notifications', '* * * * *',
    $cron$select net.http_post(url := 'https://zxqcnmgwhtbxkdpjqtlr.supabase.co/functions/v1/dispatch-notifications', headers := jsonb_build_object('Content-Type', 'application/json', 'x-dispatch-key', (select value from public.internal_secrets where name = 'dispatch_key')), body := '{}'::jsonb)$cron$);
exception when others then
  raise notice 'pg_cron indisponible : la file de notifications ne part pas tant que dispatch-notifications n''est pas planifiée (%).', sqlerrm;
end $$;

-- RETOUR ARRIÈRE : recréer is_blocked_between (20261106000100), start_conversation (20261030000400), start_order_conversation (20261030000600), start_direct_conversation (20261104000300),
--   public_profile (20261104000400), seller_public (20261114004200), protect_profile_authority (20261114002300), mentor_save (20261114001100), create_ephemeral_community (20261114001200) ;
--   drop function chat_guard(uuid), profile_set_phone(text), dispatch_key_check(text), dispatch_claim(integer, text[]) ; alter table profiles drop constraint profiles_longueurs_check ; drop index profiles_phone_norm_uk ;
--   grant update on profiles to authenticated ; recréer les politiques projects/project_steps/talent_skills/storage d'origine ; grant execute on function publish_due_posts() to authenticated ;
--   remettre le cron dispatch-notifications sans en-tête (20261106000100).
