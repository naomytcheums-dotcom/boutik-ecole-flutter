-- Lot H1 (Organisation) 4/5 — fusion du rôle « other » dans Organisation, inscription et libellés.
-- Décision : l'ancien rôle « Autre » disparaît comme acteur autonome ; il est intégré à Organisation (type « autre_reconnue »). L'enum app_role GARDE la valeur
-- « other » (des centaines de fonctions et politiques en dépendent et la traitent déjà comme « company »).
--   · migration des données : chaque profil « other » devient « company » avec une fiche de type « autre_reconnue » (créée en brouillon si elle n'existait pas) ;
--   · l'inscription n'accepte plus que client, étudiant et organisation (politique « profil créé à l'inscription ») : « other » n'est plus attribuable ;
--     un changement de rôle vers « other » (administration) donne lui aussi Organisation (déclencheur trg_a_profile_role_no_other) ;
--   · _need_poster : « Organisation non vérifiée » pour les deux rôles.
-- Idempotente (rejouable). Retour arrière : drop trigger trg_a_profile_role_no_other on profiles; drop function profile_role_no_other(); recréer la politique depuis supabase/schema.sql et _need_poster depuis 20261118010400 ;
--   les profils déjà migrés restent « company » (alter table profiles disable trigger trg_a_profile_role_no_other puis update profiles set role = 'other' where id in (select owner_id from company_profiles where org_type = 'autre_reconnue') pour revenir).

update company_profiles c set org_type = 'autre_reconnue', updated_at = now()
  from profiles p where p.id = c.owner_id and p.role::text = 'other' and c.org_type = 'entreprise_commerciale';

insert into company_profiles (owner_id, company_name, org_type, status)
  select p.id, left(btrim(p.name), 120), 'autre_reconnue', 'draft'
  from profiles p
  where p.role::text = 'other' and char_length(btrim(coalesce(p.name, ''))) >= 2
    and not exists (select 1 from company_profiles c where c.owner_id = p.id);

update profiles set role = 'company' where role::text = 'other';

drop policy if exists "profil créé à l'inscription" on profiles;
create policy "profil créé à l'inscription" on profiles for insert
  with check (id = auth.uid() and role in ('client', 'student', 'company'));

-- Le rôle « other » n'est plus attribuable non plus par un changement de rôle (administration) : il devient Organisation, avec une fiche « autre organisation reconnue ».
create or replace function profile_role_no_other() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role::text = 'other' and old.role::text is distinct from 'other' then
    new.role := 'company';
    insert into company_profiles (owner_id, company_name, org_type, status)
      select new.id, left(btrim(new.name), 120), 'autre_reconnue', 'draft'
      where char_length(btrim(coalesce(new.name, ''))) >= 2
      on conflict (owner_id) do nothing;
  end if;
  return new;
end $$;
revoke all on function profile_role_no_other() from public, anon, authenticated;
drop trigger if exists trg_a_profile_role_no_other on profiles;
create trigger trg_a_profile_role_no_other before update of role on profiles for each row execute function profile_role_no_other();

create or replace function _need_poster(p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case
    when p.role::text in ('company', 'other') and (c.status = 'approved' or p.is_test) and nullif(btrim(coalesce(c.company_name, '')), '') is not null
      then jsonb_build_object('label', btrim(c.company_name), 'verified', true, 'role', p.role::text, 'id', p.id)
    else jsonb_build_object('label', _short_name(p.name) || ' · ' || case p.role::text
        when 'client' then 'Client' when 'student' then 'Étudiant' when 'company' then 'Organisation non vérifiée' when 'other' then 'Organisation non vérifiée'
        when 'dept' then 'Département' when 'admin' then 'Administration' else 'Membre' end,
      'verified', false, 'role', p.role::text) end
  from profiles p left join company_profiles c on c.owner_id = p.id
  where p.id = p_owner and not coalesce(p.suspended, false)
$$;
revoke all on function _need_poster(uuid) from public, anon, authenticated;
