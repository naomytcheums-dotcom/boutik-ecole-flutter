-- Produits d'exemple (décision du propriétaire, 01/11) : les 11 annonces de la plateforme sont FICTIVES. Elles restent
-- visibles pour montrer le rendu du catalogue (photos, fiches), mais ne peuvent JAMAIS être commandées ni payées.
-- Le refus est fait par le serveur, à l'insertion d'une ligne de commande : aucune commande ne peut les contenir.

alter table listings add column if not exists showcase boolean not null default false;

-- Les 11 annonces sans vendeur créées par 20261029000000 (et elles seules) deviennent des exemples.
update listings set showcase = true where seller_id is null and not showcase and title in ('Lampe en bois recyclé', 'Drone éducatif', 'Sac à dos design', 'Pots connectés', 'Support téléphone', 'Tableau décoratif', 'Ordinateur portable prototype', 'Logo et identité visuelle', 'Cours de soutien en maths', 'Confiture artisanale', 'Jus de bissap');

create or replace function refuse_showcase_order_line() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from listings where id = new.listing_id and showcase) then
    raise exception 'Produit d''exemple : non disponible à la vente';
  end if;
  return new;
end $$;
drop trigger if exists trg_refuse_showcase_order_line on order_lines;
create trigger trg_refuse_showcase_order_line before insert on order_lines for each row execute function refuse_showcase_order_line();
revoke execute on function refuse_showcase_order_line() from public, anon, authenticated;

-- Seul le département ou l'administrateur peut transformer un exemple en vrai produit (ou l'inverse).
create or replace function set_listing_showcase(p_listing uuid, p_showcase boolean) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  update listings set showcase = p_showcase where id = p_listing;
  if not found then raise exception 'Annonce introuvable'; end if;
  insert into audit_log (actor, action, target, category, level)
    values (auth.uid()::text, case when p_showcase then 'Annonce passée en exemple' else 'Exemple passé en vente réelle' end, p_listing::text, 'Validations', 'Sensible');
  return p_showcase;
end $$;
revoke all on function set_listing_showcase(uuid, boolean) from public, anon;
grant execute on function set_listing_showcase(uuid, boolean) to authenticated;

-- Retour arrière (manuel) : drop trigger trg_refuse_showcase_order_line on order_lines; drop function refuse_showcase_order_line();
-- drop function set_listing_showcase(uuid, boolean); alter table listings drop column showcase;
