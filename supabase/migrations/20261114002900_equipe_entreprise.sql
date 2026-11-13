-- Équipe de l'entreprise : plusieurs comptes pour une même entreprise, avec la même interface et des niveaux de droits.
--   · propriétaire : le compte qui a créé la fiche (tout, y compris pièces justificatives et envoi pour vérification) ;
--   · administrateur : modifie la fiche, gère l'équipe, paie le forfait ;
--   · finance : consulte, paie le forfait ;
--   · lecteur : consulte l'accueil, la fiche et l'équipe.
-- L'administrateur de la plateforme vérifie l'entreprise (une seule fois, sur la fiche du propriétaire) ; les membres héritent de cette vérification.
-- La publication de besoins, d'offres et de concours au nom de l'entreprise reste liée au compte propriétaire (étape suivante : délégation aux recruteurs).
-- Retour arrière : recréer company_get(), company_save(jsonb), company_dashboard(), company_plan_status(), company_plan_checkout(text) et on_subscription_paid()
--   depuis 20261114002500, 20261114002600, 20261114002700 et 20261114002800 ; drop function company_role_of(uuid), company_effective_owner(uuid), company_invite(text, text, uuid),
--   company_member_respond(uuid, boolean), company_member_set_role(uuid, text, uuid), company_member_remove(uuid, uuid), company_members_list(uuid), my_company_memberships() ; drop table company_members.

create table if not exists company_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references company_profiles(owner_id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'viewer' check (role in ('admin', 'finance', 'viewer')),
  status text not null default 'invited' check (status in ('invited', 'active')),
  invited_by uuid references profiles(id) on delete set null,
  invited_at timestamptz not null default now(),
  joined_at timestamptz,
  unique (owner_id, user_id),
  check (owner_id <> user_id)
);
create index if not exists company_members_user on company_members (user_id, status);
alter table company_members enable row level security;
revoke all on company_members from anon, authenticated;

-- Rôle de la personne connectée dans une entreprise : 'owner', 'admin', 'finance', 'viewer' ou null.
create or replace function company_role_of(p_owner uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when p_owner = auth.uid() then 'owner'
              else (select role from company_members where owner_id = p_owner and user_id = auth.uid() and status = 'active') end
$$;

-- Entreprise visée : la sienne par défaut, ou celle dont on est membre actif.
create or replace function company_effective_owner(p_owner uuid) returns uuid
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_owner is null or p_owner = auth.uid() then return auth.uid(); end if;
  if company_role_of(p_owner) is null then raise exception 'Accès refusé à cette entreprise'; end if;
  return p_owner;
end $$;
revoke all on function company_role_of(uuid), company_effective_owner(uuid) from public, anon, authenticated;

drop function if exists company_get();
create or replace function company_get(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); c company_profiles%rowtype; v_role text;
begin
  select * into c from company_profiles where owner_id = v_owner;
  if not found then return null; end if;
  v_role := company_role_of(v_owner);
  return to_jsonb(c) || jsonb_build_object('my_role', v_role, 'documents', case when v_role in ('owner', 'admin') then coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime, 'size_bytes', d.size_bytes, 'created_at', d.created_at) order by d.created_at desc)
    from company_documents d where d.owner_id = v_owner), '[]'::jsonb) else '[]'::jsonb end);
end $$;

drop function if exists company_save(jsonb);
create or replace function company_save(p jsonb, p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner)); c company_profiles%rowtype;
        v_name text := btrim(coalesce(p->>'company_name', '')); v_site text := nullif(btrim(coalesce(p->>'website', '')), ''); v_status text; v_reg text := btrim(coalesce(p->>'registration_number', ''));
begin
  if v_role not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if v_owner = auth.uid() and not company_is_org() then raise exception 'Réservé aux entreprises et organisations'; end if;
  if v_owner <> auth.uid() and not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Fiche introuvable'; end if;
  if char_length(v_name) < 2 then raise exception 'Indiquez le nom de l''entreprise'; end if;
  if v_site is not null and v_site !~* '^https?://[^ ]+$' then raise exception 'Le site doit commencer par https://'; end if;
  if coalesce(p->>'size', '') not in ('', '1-10', '11-50', '51-200', '201-1000', '1000+') then raise exception 'Taille inconnue'; end if;
  if nullif(p->>'logo_path', '') is not null and split_part(p->>'logo_path', '/', 1) <> auth.uid()::text then raise exception 'Logo invalide : déposez-le d''abord dans votre dossier'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  v_status := coalesce(c.status, 'draft');
  if found and c.status = 'approved' and (c.company_name is distinct from v_name or c.registration_number is distinct from v_reg) then v_status := 'pending'; end if;
  insert into company_profiles (owner_id, company_name, sector, size, city, website, phone, contact_name, contact_role, description, founded_year, registration_number, logo_path, status, submitted_at)
  values (v_owner, v_name, left(btrim(coalesce(p->>'sector', '')), 80), coalesce(p->>'size', ''), left(btrim(coalesce(p->>'city', '')), 80), v_site, left(btrim(coalesce(p->>'phone', '')), 30),
          left(btrim(coalesce(p->>'contact_name', '')), 80), left(btrim(coalesce(p->>'contact_role', '')), 80), left(btrim(coalesce(p->>'description', '')), 1500), nullif(p->>'founded_year', '')::int, left(v_reg, 60),
          nullif(p->>'logo_path', ''), 'draft', null)
  on conflict (owner_id) do update set company_name = excluded.company_name, sector = excluded.sector, size = excluded.size, city = excluded.city, website = excluded.website, phone = excluded.phone,
    contact_name = excluded.contact_name, contact_role = excluded.contact_role, description = excluded.description, founded_year = excluded.founded_year, registration_number = excluded.registration_number,
    logo_path = coalesce(excluded.logo_path, company_profiles.logo_path), status = v_status, updated_at = now();
  if v_status = 'pending' and c.status = 'approved' then
    insert into notifications (user_id, kind, title, body, data)
      select a.id, 'company_review', 'Entreprise à revérifier', v_name || ' a modifié son nom ou son numéro d''immatriculation.', jsonb_build_object('owner', v_owner) from profiles a where a.role::text = 'admin';
  end if;
  return v_status;
end $$;

drop function if exists company_plan_status();
create or replace function company_plan_status(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; s company_subscriptions%rowtype;
begin
  select * into pl from company_current_plan(v_owner);
  select * into s from company_subscriptions where owner_id = v_owner and status = 'active' and ends_at > now() order by ends_at desc limit 1;
  return jsonb_build_object('plan', to_jsonb(pl), 'ends_at', s.ends_at, 'my_role', company_role_of(v_owner),
    'requested', (select plan_code from company_subscriptions where owner_id = v_owner and status = 'requested'),
    'used_needs', (select count(*)::int from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress')),
    'used_offers', (select count(*)::int from opportunities where poster_id = v_owner and status in ('pending', 'published')),
    'used_contests', (select count(*)::int from contest_announcements where poster_id = v_owner and status in ('pending', 'published')));
end $$;

drop function if exists company_dashboard();
create or replace function company_dashboard(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); c company_profiles%rowtype; pl company_plans%rowtype;
begin
  select * into c from company_profiles where owner_id = v_owner;
  select * into pl from company_current_plan(v_owner);
  return jsonb_build_object(
    'owner_id', v_owner, 'my_role', company_role_of(v_owner),
    'company_name', c.company_name, 'status', coalesce(c.status, 'none'), 'review_note', c.review_note, 'plan_name', pl.name,
    'plan_ends_at', (select max(ends_at) from company_subscriptions where owner_id = v_owner and status = 'active' and ends_at > now()),
    'needs_open', (select count(*)::int from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress')),
    'needs_draft', (select count(*)::int from missions where client_id = v_owner and status = 'draft'),
    'proposals_new', (select count(*)::int from mission_proposals mp join missions m on m.id = mp.mission_id where m.client_id = v_owner and mp.status = 'submitted'),
    'offers_active', (select count(*)::int from opportunities where poster_id = v_owner and status in ('pending', 'published')),
    'applications_new', (select count(*)::int from opportunity_applications a join opportunities o on o.id = a.opportunity_id where o.poster_id = v_owner and a.status = 'sent'),
    'recruits', (select count(*)::int from opportunity_applications a join opportunities o on o.id = a.opportunity_id where o.poster_id = v_owner and a.status = 'hired'),
    'contests_active', (select count(*)::int from contest_announcements where poster_id = v_owner and status in ('pending', 'published')),
    'members', (select count(*)::int from company_members where owner_id = v_owner and status = 'active') + 1);
end $$;

-- Paiement d'un forfait : le propriétaire, un administrateur ou la finance de l'entreprise. Le sujet porte l'entreprise visée (« plan:code » ou « plan:code:uuid »).
drop function if exists company_plan_checkout(text);
create or replace function company_plan_checkout(p_plan text, p_owner uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; v_id uuid; v_ref text;
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner and status = 'approved') then raise exception 'Faites d''abord vérifier votre entreprise'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa <= 0 then raise exception 'Forfait introuvable'; end if;
  v_id := payment_start('subscription', 'plan:' || pl.code || case when v_owner <> auth.uid() then ':' || v_owner::text else '' end, pl.price_fcfa, 'tara');
  select reference into v_ref from payment_transactions where id = v_id;
  return jsonb_build_object('id', v_id, 'reference', v_ref, 'amount', pl.price_fcfa, 'plan', pl.name);
end $$;

create or replace function on_subscription_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; v_owner uuid; v_ok boolean;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'subscription' and new.subject like 'plan:%' then
    select * into pl from company_plans where code = split_part(substr(new.subject, 6), ':', 1);
    v_owner := coalesce(nullif(split_part(new.subject, ':', 3), '')::uuid, new.payer_id);
    v_ok := v_owner = new.payer_id or exists (select 1 from company_members where owner_id = v_owner and user_id = new.payer_id and status = 'active' and role in ('admin', 'finance'));
    if found and v_ok and new.amount >= pl.price_fcfa and exists (select 1 from company_profiles where owner_id = v_owner and status = 'approved') then
      perform company_activate_internal(v_owner, pl.code, null, 'Payé par Mobile Money (' || new.reference || ')', null);
      insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
      values ('subscription', new.reference, new.payer_id, null, new.amount, new.amount, 'plateforme', 'released', now());
    end if;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------- gestion de l'équipe
create or replace function company_invite(p_email text, p_role text default 'viewer', p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_target uuid; v_name text; v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if company_role_of(v_owner) not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if p_role not in ('admin', 'finance', 'viewer') then raise exception 'Rôle inconnu'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner) then raise exception 'Enregistrez d''abord la fiche de l''entreprise'; end if;
  select id into v_target from profiles where lower(email) = v_email and not suspended;
  if v_target is null then raise exception 'Aucun compte avec cet e-mail : la personne doit d''abord créer son compte'; end if;
  if v_target = v_owner then raise exception 'Cette personne est le propriétaire de l''entreprise'; end if;
  if (select count(*) from company_members where owner_id = v_owner) >= 10 then raise exception 'Dix membres au plus'; end if;
  if exists (select 1 from company_members where owner_id = v_owner and user_id = v_target and status = 'active') then raise exception 'Cette personne fait déjà partie de l''équipe'; end if;
  insert into company_members (owner_id, user_id, role, status, invited_by) values (v_owner, v_target, p_role, 'invited', auth.uid())
  on conflict (owner_id, user_id) do update set role = excluded.role, status = 'invited', invited_by = auth.uid(), invited_at = now();
  select company_name into v_name from company_profiles where owner_id = v_owner;
  insert into notifications (user_id, kind, title, body, data)
    values (v_target, 'company_team', 'Invitation à rejoindre une entreprise', display_name(auth.uid()) || ' vous invite à rejoindre l''équipe de « ' || v_name || ' ».', jsonb_build_object('owner', v_owner));
  return 'invited';
end $$;

create or replace function company_member_respond(p_owner uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from company_members where owner_id = p_owner and user_id = auth.uid() and status = 'invited') then raise exception 'Invitation introuvable'; end if;
  select company_name into v_name from company_profiles where owner_id = p_owner;
  if p_accept then
    update company_members set status = 'active', joined_at = now() where owner_id = p_owner and user_id = auth.uid();
  else
    delete from company_members where owner_id = p_owner and user_id = auth.uid();
  end if;
  insert into notifications (user_id, kind, title, body, data)
    values (p_owner, 'company_team', case when p_accept then 'Nouveau membre' else 'Invitation déclinée' end,
            display_name(auth.uid()) || case when p_accept then ' a rejoint l''équipe de « ' || v_name || ' ».' else ' a décliné l''invitation.' end, jsonb_build_object('user', auth.uid()));
  return case when p_accept then 'active' else 'declined' end;
end $$;

create or replace function company_member_set_role(p_user uuid, p_role text, p_owner uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner);
begin
  if company_role_of(v_owner) not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  if p_role not in ('admin', 'finance', 'viewer') then raise exception 'Rôle inconnu'; end if;
  update company_members set role = p_role where owner_id = v_owner and user_id = p_user;
  if not found then raise exception 'Membre introuvable'; end if;
end $$;

-- Retirer un membre (propriétaire ; administrateur pour les non-administrateurs) ou quitter l'équipe soi-même.
create or replace function company_member_remove(p_user uuid, p_owner uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner)); m company_members%rowtype;
begin
  select * into m from company_members where owner_id = v_owner and user_id = p_user;
  if not found then raise exception 'Membre introuvable'; end if;
  if p_user <> auth.uid() then
    if v_role not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
    if v_role = 'admin' and m.role = 'admin' then raise exception 'Seul le propriétaire retire un administrateur'; end if;
  end if;
  delete from company_members where id = m.id;
end $$;

create or replace function company_members_list(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); v_role text := company_role_of(company_effective_owner(p_owner));
begin
  return jsonb_build_object('my_role', v_role, 'owner', jsonb_build_object('user_id', v_owner, 'name', display_name(v_owner)),
    'members', coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'name', display_name(m.user_id), 'email', case when v_role in ('owner', 'admin') then (select email from profiles where id = m.user_id) end,
        'role', m.role, 'status', m.status, 'joined_at', m.joined_at) order by m.status, m.invited_at) from company_members m where m.owner_id = v_owner), '[]'::jsonb));
end $$;

-- Mes entreprises : celles dont je suis membre et mes invitations en attente.
create or replace function my_company_memberships() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('owner_id', m.owner_id, 'company_name', c.company_name, 'role', m.role, 'status', m.status, 'logo_path', c.logo_path, 'verified', c.status = 'approved') order by m.status, c.company_name)
    from company_members m join company_profiles c on c.owner_id = m.owner_id where m.user_id = auth.uid()), '[]'::jsonb);
end $$;

revoke all on function company_get(uuid), company_save(jsonb, uuid), company_plan_status(uuid), company_dashboard(uuid), company_plan_checkout(text, uuid), company_invite(text, text, uuid),
  company_member_respond(uuid, boolean), company_member_set_role(uuid, text, uuid), company_member_remove(uuid, uuid), company_members_list(uuid), my_company_memberships() from public, anon;
grant execute on function company_get(uuid), company_save(jsonb, uuid), company_plan_status(uuid), company_dashboard(uuid), company_plan_checkout(text, uuid), company_invite(text, text, uuid),
  company_member_respond(uuid, boolean), company_member_set_role(uuid, text, uuid), company_member_remove(uuid, uuid), company_members_list(uuid), my_company_memberships() to authenticated;
