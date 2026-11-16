-- Vérification des numéros de téléphone (SQL2-2) : un numéro saisi à l'inscription ou aux réglages n'a aucun pouvoir tant qu'un code reçu par SMS
-- n'a pas été saisi. Seuls les numéros VÉRIFIÉS servent à la connexion par téléphone, à la récupération de mot de passe et aux notifications SMS/WhatsApp.
-- Les comptes existants gardent leur numéro (considéré vérifié) ; un numéro non vérifié peut être évincé par la personne qui le prouve.
-- Retour arrière : drop function phone_verify_apply(uuid, text), phone_is_taken(text) ; alter table auth_recovery_codes drop column purpose ;
--   alter table profiles drop column phone_verified ; recréer profiles_phone_norm_uk et profile_set_phone depuis 20261115000100_securite_client.sql.

alter table profiles add column if not exists phone_verified boolean not null default false;
update profiles set phone_verified = true where phone is not null and phone <> '' and not phone_verified;

alter table auth_recovery_codes add column if not exists purpose text not null default 'recovery' check (purpose in ('recovery', 'phone_verify'));

-- L'unicité ne protège que les numéros vérifiés : un numéro seulement déclaré ne peut plus bloquer son vrai propriétaire.
drop index if exists profiles_phone_norm_uk;
do $$ begin
  create unique index if not exists profiles_phone_verified_uk on profiles ((right(regexp_replace(phone, '\D', '', 'g'), 9))) where phone is not null and phone <> '' and phone_verified;
exception when others then raise notice 'index unique des numéros vérifiés non créé : %', sqlerrm;
end $$;

create or replace function protect_profile_authority() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
      new.certification := 'none';
      new.certification_decided_by := null;
      new.certification_decided_at := null;
      new.is_test := false;
      new.email := (select u.email from auth.users u where u.id = auth.uid());
      new.phone_verified := false;
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
    -- Le drapeau « vérifié » ne se pose que par la procédure de vérification ; changer de numéro l'efface.
    if new.phone_verified is distinct from old.phone_verified and coalesce(current_setting('app.phone_verify_rpc', true), '') <> '1' then
      new.phone_verified := old.phone_verified;
    end if;
    if new.phone is distinct from old.phone and coalesce(current_setting('app.phone_verify_rpc', true), '') <> '1' then
      new.phone_verified := false;
    end if;
  end if;
  return new;
end $$;

-- Enregistre (sans la vérifier) le numéro du compte. Un numéro déjà VÉRIFIÉ par un autre compte est refusé ; un simple numéro déclaré est évincé.
create or replace function profile_set_phone(p_phone text) returns void
language plpgsql security definer set search_path = public as $$
declare v text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v ~ '^237[0-9]{9}$' then v := substr(v, 4); end if;
  if v !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide : 9 chiffres commençant par 6'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(phone, '') <> '') then raise exception 'Pour changer de numéro, contactez le support'; end if;
  if exists (select 1 from profiles where id <> auth.uid() and phone_verified and right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9) = v) then raise exception 'Ce numéro est déjà utilisé'; end if;
  perform set_config('app.phone_rpc', '1', true);
  update profiles set phone = null where id <> auth.uid() and not phone_verified and right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9) = v;
  update profiles set phone = v where id = auth.uid();
end $$;
revoke all on function profile_set_phone(text) from public, anon;
grant execute on function profile_set_phone(text) to authenticated;

-- Appelée uniquement par l'Edge Function auth-recovery (service_role) après contrôle du code reçu par SMS.
create or replace function phone_verify_apply(p_user uuid, p_phone text) returns void
language plpgsql security definer set search_path = public as $$
declare v text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if v ~ '^237[0-9]{9}$' then v := substr(v, 4); end if;
  if v !~ '^6[0-9]{8}$' then raise exception 'Numéro invalide'; end if;
  if exists (select 1 from profiles where id <> p_user and phone_verified and right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9) = v) then raise exception 'Ce numéro est déjà utilisé'; end if;
  perform set_config('app.phone_verify_rpc', '1', true);
  perform set_config('app.phone_rpc', '1', true);
  update profiles set phone = null where id <> p_user and not phone_verified and right(regexp_replace(coalesce(phone, ''), '\D', '', 'g'), 9) = v;
  update profiles set phone = v, phone_verified = true where id = p_user;
end $$;
revoke all on function phone_verify_apply(uuid, text) from public, anon, authenticated;
grant execute on function phone_verify_apply(uuid, text) to service_role;
