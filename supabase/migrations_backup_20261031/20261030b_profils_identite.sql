-- Incident « profil hérité » : identité des profils et procédure de certification (badge bleu).
-- Cause : l'écran Profil mélangeait le nom du compte avec le contenu fixe de la maquette (photo, description, badge) et retombait sur le compte de démonstration.
-- À exécuter dans l'éditeur SQL Supabase.

do $$ begin
  create type certification_status as enum ('none', 'pending', 'review', 'approved', 'rejected', 'revoked');
exception when duplicate_object then null; end $$;

alter table profiles add column if not exists bio text not null default '';
alter table profiles add column if not exists skills text not null default '';
alter table profiles add column if not exists avatar_url text;
alter table profiles add column if not exists certification certification_status not null default 'none';
alter table profiles add column if not exists certification_decided_by uuid references profiles(id);
alter table profiles add column if not exists certification_decided_at timestamptz;

-- Un utilisateur ne peut ni s'attribuer un rôle, ni modifier sa certification : seule la procédure serveur le peut.
create or replace function protect_profile_authority() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
      new.certification := 'none';
      new.certification_decided_by := null;
      new.certification_decided_at := null;
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
     and (new.role is distinct from old.role or new.suspended is distinct from old.suspended)
     and coalesce(current_role_name()::text, '') <> 'admin' then
    raise exception 'Modification du rôle ou du statut réservée à l''administrateur';
  end if;
  return new;
end $$;

drop trigger if exists trg_protect_profile on profiles;
create trigger trg_protect_profile before insert or update on profiles for each row execute function protect_profile_authority();

-- Demande de certification : le titulaire passe de « aucune »/« refusée » à « en attente », jamais plus loin.
create or replace function request_certification() returns text
language plpgsql security definer set search_path = public as $$
declare c certification_status;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select certification into c from profiles where id = auth.uid();
  if c is null then raise exception 'Profil introuvable'; end if;
  if c not in ('none', 'rejected') then raise exception 'Une demande est déjà en cours ou le compte est déjà certifié'; end if;
  perform set_config('app.cert_rpc', '1', true);
  update profiles set certification = 'pending', certification_decided_by = null, certification_decided_at = null where id = auth.uid();
  perform set_config('app.cert_rpc', '', true);
  return 'pending';
end $$;

-- Décision de certification : département ou administrateur uniquement, jamais sur son propre compte, transitions contrôlées.
create or replace function decide_certification(p_user uuid, p_status text) returns text
language plpgsql security definer set search_path = public as $$
declare c certification_status; who text; target text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas décider de votre propre certification'; end if;
  if p_status not in ('review', 'approved', 'rejected', 'revoked') then raise exception 'Statut invalide'; end if;
  select certification, name into c, target from profiles where id = p_user;
  if c is null then raise exception 'Profil introuvable'; end if;
  if not ((p_status = 'review' and c = 'pending')
       or (p_status in ('approved', 'rejected') and c in ('pending', 'review'))
       or (p_status = 'revoked' and c = 'approved')) then
    raise exception 'Transition impossible de % vers %', c, p_status;
  end if;
  perform set_config('app.cert_rpc', '1', true);
  update profiles set certification = p_status::certification_status, certification_decided_by = auth.uid(), certification_decided_at = now() where id = p_user;
  perform set_config('app.cert_rpc', '', true);
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Valideur'), 'Certification : ' || p_status, coalesce(target, p_user::text), 'Certification', 'Sensible');
  return p_status;
end $$;

revoke all on function request_certification() from public, anon;
revoke all on function decide_certification(uuid, text) from public, anon;
grant execute on function request_certification() to authenticated;
grant execute on function decide_certification(uuid, text) to authenticated;

select (select count(*) from profiles) as profils,
       (select count(*) from profiles where certification <> 'none') as certifies_ou_demandes,
       (select count(*) from pg_trigger where tgname = 'trg_protect_profile') as declencheur;
