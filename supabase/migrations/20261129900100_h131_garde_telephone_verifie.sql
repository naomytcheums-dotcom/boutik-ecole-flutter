-- H13.1 · Doublon de numéro de téléphone vérifié : protection TEMPORAIRE au niveau de la base, sans toucher aux comptes existants.
-- Constat (production, 27/11/2026, lecture seule) : deux profils vérifiés (un administrateur, un étudiant, sans activité, créés les 01 et 04/11) partagent les 9 derniers chiffres
-- d'un même numéro, écrit sous deux formes (+237… et 9 chiffres). Leur « vérification » vient du marquage en masse de 20261117990100 (« les comptes existants gardent leur numéro,
-- considéré vérifié »), pas d'un code SMS. L'index unique `profiles_phone_verified_uk` n'a donc pas pu être créé en production.
-- Protection déjà en place côté application : `profile_set_phone` et `phone_verify_apply` refusent un numéro vérifié ailleurs ; `auth-recovery` n'envoie aucun code et n'ouvre aucune
-- connexion par téléphone quand deux comptes vérifiés portent le numéro (ambigu). Ce déclencheur ferme le reste (écriture directe, RPC d'administration, import) :
-- il refuse de POSER un numéro vérifié déjà vérifié sur un AUTRE compte (mêmes 9 derniers chiffres). Il ne se déclenche que si `phone` ou `phone_verified` CHANGE : les deux comptes
-- existants ne sont ni modifiés, ni bloqués. Aucune donnée n'est modifiée ; la décision (quel compte garde le numéro) reste au propriétaire, puis l'index unique pourra être créé.
-- Retour arrière : drop trigger profiles_phone_verified_guard on profiles ; drop function _profiles_phone_verified_guard().
create or replace function _profiles_phone_verified_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare k text;
begin
  if not coalesce(new.phone_verified, false) or coalesce(new.phone, '') = '' then return new; end if;
  if tg_op = 'UPDATE' and new.phone is not distinct from old.phone and new.phone_verified is not distinct from old.phone_verified then return new; end if;
  k := right(regexp_replace(new.phone, '\D', '', 'g'), 9);
  if exists (select 1 from profiles p where p.id <> new.id and p.phone_verified and coalesce(p.phone, '') <> '' and right(regexp_replace(p.phone, '\D', '', 'g'), 9) = k) then
    raise exception 'Ce numéro est déjà utilisé' using errcode = '23505';
  end if;
  return new;
end $$;
revoke all on function _profiles_phone_verified_guard() from public, anon, authenticated;

drop trigger if exists profiles_phone_verified_guard on profiles;
create trigger profiles_phone_verified_guard before insert or update of phone, phone_verified on profiles for each row execute function _profiles_phone_verified_guard();
