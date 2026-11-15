-- Lot L10 (4/5) : CV vivant et partage du CV (écrans 227, 228, 229).
--  1. lien de CV stable : le lien existant est relu et copié sans être régénéré ; « Régénérer » est une action explicite qui invalide l'ancien lien ;
--  2. consentement obligatoire avant la création du lien, expiration facultative, désactivation du lien, réglages de ce que voient les recruteurs ;
--  3. shared_cv expose, selon ces réglages, les réalisations, les missions menées à terme et les avis reçus (jamais le téléphone ni l'e-mail) ;
--  4. cv_public(p_user) : CV d'un talent qui a publié son lien (écran 229) ;
--  5. send_cv_to_recruiter : envoi du CV à une entreprise (destinataire réel, notification) ;
--  6. talent_contact_request : proposition de stage ou demande de contact adressée à un talent (destinataire réel, notification).
-- Retour arrière : voir le bas du fichier.

alter table cv_links add column if not exists expires_at timestamptz;
alter table cv_links add column if not exists consent_at timestamptz;
alter table cv_links add column if not exists show_missions boolean not null default true;
alter table cv_links add column if not exists show_reviews boolean not null default true;
alter table cv_links add column if not exists show_links boolean not null default true;
alter table cv_links add column if not exists show_portfolio boolean not null default true;
update cv_links c set revoked_at = now() where revoked_at is null and exists (select 1 from cv_links o where o.owner_id = c.owner_id and o.revoked_at is null and (o.created_at, o.token) > (c.created_at, c.token));
create unique index if not exists cv_links_un_actif on cv_links (owner_id) where revoked_at is null;

create or replace function _cv_build(p_owner uuid, p_missions boolean, p_reviews boolean, p_links boolean, p_portfolio boolean, p_expires timestamptz) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('nom', p.name, 'departement', p.department, 'etablissement', p.institution, 'bio', p.bio, 'competences', p.skills,
      'certifie', p.certification::text = 'approved', 'liens', case when p_links then p.links else '[]'::jsonb end,
      'expire', p_expires,
      'realisations', case when p_portfolio then coalesce((select jsonb_agg(jsonb_build_object('titre', x.title, 'description', left(x.description, 300), 'categorie', x.category, 'date', x.happened_on, 'lien', x.url) order by x.featured desc, x.created_at desc)
          from (select * from portfolio_items where owner_id = p_owner and kind = 'realisation' order by featured desc, created_at desc limit 8) x), '[]'::jsonb) else '[]'::jsonb end,
      'missions', case when p_missions then coalesce((select jsonb_agg(jsonb_build_object('titre', m.title, 'statut', m.status) order by m.updated_at desc)
          from (select m.title, m.status, m.updated_at from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = p_owner and mp.status = 'accepted'
                where m.status in ('delivered', 'closed') and m.title is not null order by m.updated_at desc limit 8) m), '[]'::jsonb) else '[]'::jsonb end,
      'avis', case when p_reviews then jsonb_build_object(
          'nombre', (select count(*)::int from reviews r join listings li on li.id = r.listing_id where li.seller_id = p_owner),
          'moyenne', (select round(avg(r.rating)::numeric, 1) from reviews r join listings li on li.id = r.listing_id where li.seller_id = p_owner),
          'derniers', coalesce((select jsonb_agg(jsonb_build_object('note', q.rating, 'commentaire', q.comment) order by q.created_at desc)
              from (select r.rating, r.comment, r.created_at from reviews r join listings li on li.id = r.listing_id
                    where li.seller_id = p_owner and nullif(btrim(coalesce(r.comment, '')), '') is not null order by r.created_at desc limit 3) q), '[]'::jsonb))
        else null end)
  from profiles p where p.id = p_owner and not coalesce(p.suspended, false)
$$;
revoke all on function _cv_build(uuid, boolean, boolean, boolean, boolean, timestamptz) from public, anon, authenticated;

create or replace function _cv_payload(l cv_links) returns jsonb
language sql stable security definer set search_path = public as $$
  select _cv_build(l.owner_id, l.show_missions, l.show_reviews, l.show_links, l.show_portfolio, l.expires_at)
$$;
revoke all on function _cv_payload(cv_links) from public, anon, authenticated;

-- Aperçu de MON CV (écran 227) : ce que verra un recruteur avec tous les réglages ouverts, lien publié ou non.
create or replace function cv_preview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return _cv_build(auth.uid(), true, true, true, true, null);
end $$;

create or replace function shared_cv(p_token text) returns jsonb
language sql stable security definer set search_path = public as $$
  select _cv_payload(c) from cv_links c
  where c.token = p_token and c.revoked_at is null and (c.expires_at is null or c.expires_at > now());
$$;

create or replace function cv_public(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c cv_links%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from cv_links where owner_id = p_user and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then return null; end if;
  return _cv_payload(c) || jsonb_build_object('user_id', p_user);
end $$;

create or replace function cv_link_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c cv_links%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from cv_links where owner_id = auth.uid() and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then return null; end if;
  return jsonb_build_object('token', c.token, 'created_at', c.created_at, 'expires_at', c.expires_at, 'consent', c.consent_at is not null,
    'show_missions', c.show_missions, 'show_reviews', c.show_reviews, 'show_links', c.show_links, 'show_portfolio', c.show_portfolio);
end $$;

-- Crée le lien (consentement obligatoire) ou met à jour ses réglages ; le jeton ne change jamais ici.
-- p_expires_days : null = inchangé (aucune expiration à la création), 0 = sans expiration, 1 à 365 = expire dans ce nombre de jours.
create or replace function cv_link_save(p_consent boolean default false, p_expires_days integer default null, p_show_missions boolean default true, p_show_reviews boolean default true,
  p_show_links boolean default true, p_show_portfolio boolean default true) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare c cv_links%rowtype; t text; v_exp timestamptz;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : partage du CV impossible'; end if;
  if p_expires_days is not null and p_expires_days not between 0 and 365 then raise exception 'Durée de validité : 0 à 365 jours'; end if;
  select * into c from cv_links where owner_id = auth.uid() and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then
    if not coalesce(p_consent, false) then raise exception 'Acceptez que toute personne qui a le lien puisse voir votre CV'; end if;
    update cv_links set revoked_at = now() where owner_id = auth.uid() and revoked_at is null;
    t := encode(gen_random_bytes(16), 'hex');
    insert into cv_links (token, owner_id, consent_at, expires_at, show_missions, show_reviews, show_links, show_portfolio)
    values (t, auth.uid(), now(), case when coalesce(p_expires_days, 0) > 0 then now() + make_interval(days => p_expires_days) end,
            coalesce(p_show_missions, true), coalesce(p_show_reviews, true), coalesce(p_show_links, true), coalesce(p_show_portfolio, true));
    return t;
  end if;
  v_exp := case when p_expires_days is null then c.expires_at when p_expires_days = 0 then null else now() + make_interval(days => p_expires_days) end;
  update cv_links set expires_at = v_exp, consent_at = coalesce(consent_at, case when coalesce(p_consent, false) then now() end),
    show_missions = coalesce(p_show_missions, show_missions), show_reviews = coalesce(p_show_reviews, show_reviews),
    show_links = coalesce(p_show_links, show_links), show_portfolio = coalesce(p_show_portfolio, show_portfolio)
  where token = c.token;
  return c.token;
end $$;

-- Action explicite : l'ancien lien cesse immédiatement de fonctionner ; les réglages et l'expiration sont repris.
create or replace function regenerate_cv_link() returns text
language plpgsql security definer set search_path = public, extensions as $$
declare c cv_links%rowtype; t text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : partage du CV impossible'; end if;
  select * into c from cv_links where owner_id = auth.uid() order by (revoked_at is null) desc, created_at desc limit 1;
  if not found or c.consent_at is null then raise exception 'Créez d''abord votre lien en acceptant la publication de votre CV'; end if;
  update cv_links set revoked_at = now() where owner_id = auth.uid() and revoked_at is null;
  t := encode(gen_random_bytes(16), 'hex');
  insert into cv_links (token, owner_id, consent_at, expires_at, show_missions, show_reviews, show_links, show_portfolio)
  values (t, auth.uid(), now(), case when c.expires_at is not null and c.expires_at > now() then c.expires_at end, c.show_missions, c.show_reviews, c.show_links, c.show_portfolio);
  return t;
end $$;

create or replace function cv_link_disable() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update cv_links set revoked_at = now() where owner_id = auth.uid() and revoked_at is null;
end $$;

-- ============================================================ envois et contacts
create table if not exists cv_sends (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  token text not null,
  message text not null default '' check (char_length(message) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists cv_sends_sender on cv_sends (sender_id, created_at desc);
alter table cv_sends enable row level security;
revoke all on cv_sends from anon, authenticated;
grant select on cv_sends to authenticated;
drop policy if exists "envois de CV : l'expéditeur" on cv_sends;
create policy "envois de CV : l'expéditeur" on cv_sends for select using (sender_id = auth.uid());

create or replace function send_cv_to_recruiter(p_email text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c cv_links%rowtype; r profiles%rowtype; v_msg text := left(btrim(coalesce(p_message, '')), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : envoi impossible'; end if;
  select * into c from cv_links where owner_id = auth.uid() and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then raise exception 'Créez d''abord le lien de votre CV (écran « Partager mon CV »)'; end if;
  select * into r from profiles where lower(email) = lower(btrim(coalesce(p_email, ''))) and role::text = 'company' and not coalesce(suspended, false);
  if not found then raise exception 'Aucune entreprise ne correspond à cette adresse'; end if;
  if (select count(*) from cv_sends where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq envois de CV par jour au plus'; end if;
  insert into cv_sends (sender_id, recipient_id, token, message) values (auth.uid(), r.id, c.token, v_msg);
  perform notify_user(r.id, 'cv_shared', 'CV reçu', left(display_name(auth.uid()) || ' vous envoie son CV' || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('cv_token', c.token, 'from', auth.uid()));
  return 'sent';
end $$;

create table if not exists talent_contacts (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  target_id uuid not null references profiles(id) on delete cascade,
  kind text not null check (kind in ('internship_offer', 'contact')),
  message text not null default '' check (char_length(message) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists talent_contacts_sender on talent_contacts (sender_id, created_at desc);
create unique index if not exists talent_contacts_un_par_jour on talent_contacts (sender_id, target_id, kind, ((created_at at time zone 'UTC')::date));
alter table talent_contacts enable row level security;
revoke all on talent_contacts from anon, authenticated;
grant select on talent_contacts to authenticated;
drop policy if exists "contacts de talent : expéditeur ou destinataire" on talent_contacts;
create policy "contacts de talent : expéditeur ou destinataire" on talent_contacts for select using (sender_id = auth.uid() or target_id = auth.uid());

create or replace function talent_contact_request(p_user uuid, p_kind text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare v_msg text := left(btrim(coalesce(p_message, '')), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('company', 'client', 'other', 'dept', 'admin') then raise exception 'Cette demande est réservée aux entreprises, aux clients et au département'; end if;
  if p_kind not in ('internship_offer', 'contact') then raise exception 'Type de demande inconnu'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not exists (select 1 from profiles where id = p_user and role::text = 'student' and not coalesce(suspended, false)) then raise exception 'Talent introuvable'; end if;
  if not exists (select 1 from cv_links where owner_id = p_user and revoked_at is null and (expires_at is null or expires_at > now())) then raise exception 'Ce talent n''a pas publié son CV'; end if;
  if (select count(*) from talent_contacts where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix demandes par jour au plus'; end if;
  begin
    insert into talent_contacts (sender_id, target_id, kind, message) values (auth.uid(), p_user, p_kind, v_msg);
  exception when unique_violation then
    raise exception 'Vous avez déjà adressé cette demande à ce talent aujourd''hui';
  end;
  perform notify_user(p_user, 'talent_contact', case p_kind when 'internship_offer' then 'Proposition de stage' else 'Demande de contact' end,
    left(display_name(auth.uid()) || case p_kind when 'internship_offer' then ' vous propose un stage' else ' souhaite vous contacter' end || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('from', auth.uid(), 'kind', p_kind));
  return 'sent';
end $$;

revoke all on function shared_cv(text) from public;
grant execute on function shared_cv(text) to anon, authenticated;
revoke all on function cv_preview(), cv_public(uuid), cv_link_get(), cv_link_save(boolean, integer, boolean, boolean, boolean, boolean), regenerate_cv_link(), cv_link_disable(),
  send_cv_to_recruiter(text, text), talent_contact_request(uuid, text, text) from public, anon;
grant execute on function cv_preview(), cv_public(uuid), cv_link_get(), cv_link_save(boolean, integer, boolean, boolean, boolean, boolean), regenerate_cv_link(), cv_link_disable(),
  send_cv_to_recruiter(text, text), talent_contact_request(uuid, text, text) to authenticated;

-- Retour arrière : recréer regenerate_cv_link et shared_cv depuis 20261031000100 ;
--   drop function _cv_payload(cv_links), _cv_build(uuid, boolean, boolean, boolean, boolean, timestamptz), cv_preview(), cv_public(uuid), cv_link_get(), cv_link_save(boolean, integer, boolean, boolean, boolean, boolean), cv_link_disable(), send_cv_to_recruiter(text, text), talent_contact_request(uuid, text, text) ;
--   drop table cv_sends, talent_contacts ; drop index cv_links_un_actif ;
--   alter table cv_links drop column expires_at, drop column consent_at, drop column show_missions, drop column show_reviews, drop column show_links, drop column show_portfolio.
