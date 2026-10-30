-- Décision métier : à l'inscription, chacun choisit librement son rôle PUBLIC (client, étudiant, entreprise, autre) et peut en changer.
-- Aucun rôle privilégié (département, direction, finance, support, administrateur) ne peut être obtenu ou quitté sans l'administrateur,
-- et la suspension reste réservée à l'administrateur. La validation des annonces par le département protège la plateforme contre un faux « étudiant ».
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
  if auth.uid() is not null and new.suspended is distinct from old.suspended and coalesce(current_role_name()::text, '') <> 'admin' then
    raise exception 'Modification du statut de suspension réservée à l''administrateur';
  end if;
  if auth.uid() is not null and new.role is distinct from old.role and coalesce(current_role_name()::text, '') <> 'admin'
     and not (old.id = auth.uid()
              and old.role in ('client', 'student', 'company', 'other')
              and new.role in ('client', 'student', 'company', 'other')) then
    raise exception 'Seul le choix entre client, étudiant, entreprise et autre est libre ; les autres rôles relèvent de l''administrateur';
  end if;
  return new;
end $$;
