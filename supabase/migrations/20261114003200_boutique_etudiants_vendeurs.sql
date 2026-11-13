-- Boutique réservée aux étudiants-vendeurs : aucun autre profil (client, entreprise, responsable de département, équipe) ne peut en créer une,
-- quel que soit l'écran ou l'appel utilisé. Les boutiques déjà existantes ne sont pas touchées.
create or replace function shops_owner_must_be_student() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from profiles p where p.id = new.owner_id and p.role::text = 'student') then
    raise exception 'La boutique est réservée aux étudiants-vendeurs.';
  end if;
  return new;
end $$;
revoke all on function shops_owner_must_be_student() from public, anon, authenticated;

drop trigger if exists shops_owner_must_be_student_trg on shops;
create trigger shops_owner_must_be_student_trg before insert on shops for each row execute function shops_owner_must_be_student();
