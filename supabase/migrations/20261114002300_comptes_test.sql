-- Comptes de test de l'administrateur : un compte par profil (client, étudiant-vendeur, entreprise, autre rôle, responsable de département, direction, finance, support),
-- marqués « test » pour que le système les reconnaisse. Ils sont créés et ouverts uniquement par l'administrateur depuis l'application (fonction « admin-test-accounts »).
-- Aucun mot de passe n'est connu ni stocké : l'administrateur ouvre un compte de test par lien à usage unique, et chaque ouverture est journalisée.
-- Retour arrière : drop function test_accounts_list(); drop table test_login_log; alter table profiles drop column is_test ; recréer protect_profile_authority depuis 20261030000100.

alter table profiles add column if not exists is_test boolean not null default false;
create index if not exists profiles_is_test on profiles (is_test) where is_test;

create table if not exists test_login_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null references profiles(id) on delete cascade,
  target_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table test_login_log enable row level security;
revoke all on test_login_log from anon, authenticated;

-- Le marquage « test » ne peut être posé ou retiré que par l'administrateur (ou le serveur) : un compte ne se déclare jamais « test » lui-même.
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
  return new;
end $$;

-- Liste des comptes de test (administrateur seulement) avec leur dernier accès.
create or replace function test_accounts_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'role', p.role::text, 'name', p.name, 'email', p.email,
      'last_login', (select max(l.created_at) from test_login_log l where l.target_id = p.id)) order by p.role::text)
    from profiles p where p.is_test), '[]'::jsonb);
end $$;
revoke all on function test_accounts_list() from public, anon;
grant execute on function test_accounts_list() to authenticated;
