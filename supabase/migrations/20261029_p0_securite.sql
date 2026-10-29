-- Correctifs P0 de l'audit (AN-001, AN-002, AN-003) — à exécuter dans l'éditeur SQL Supabase.

-- AN-001 : seul un administrateur peut modifier le rôle ou le statut de suspension d'un profil.
create or replace function protect_profile_authority() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and (new.role is distinct from old.role or new.suspended is distinct from old.suspended)
     and coalesce(current_role_name()::text, '') <> 'admin' then
    raise exception 'Modification du rôle ou du statut réservée à l''administrateur';
  end if;
  return new;
end $$;

drop trigger if exists trg_protect_profile on profiles;
create trigger trg_protect_profile before update on profiles for each row execute function protect_profile_authority();

drop policy if exists "profil modifiable par soi" on profiles;
create policy "profil modifiable par soi" on profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- AN-003 : catalogue de la plateforme côté serveur + création de commande calculée par le serveur.
alter table listings alter column seller_id drop not null;
create unique index if not exists listings_plateforme_titre on listings (title) where seller_id is null;

insert into listings (seller_id, title, department, category, price, stock, description, status) values
 (null,'Lampe en bois recyclé','Génie civil','Maison',25000,100,'Lampe décorative fabriquée à partir de bois de récupération, avec éclairage LED économe.','approved'),
 (null,'Drone éducatif','Génie électrique','Tech',150000,100,'Drone pédagogique programmable, idéal pour l''apprentissage de la robotique.','approved'),
 (null,'Sac à dos design','Design – MMI','Mode',25000,100,'Sac à dos en toile recyclée, dessiné et cousu par les étudiants.','approved'),
 (null,'Pots connectés','Agronomie','Maison',15000,100,'Pots de plantes connectés avec capteur d''humidité.','approved'),
 (null,'Support téléphone','Génie industriel','Tech',8000,100,'Support de téléphone imprimé en 3D, plusieurs coloris.','approved'),
 (null,'Tableau décoratif','Arts – Génie civil','Art',18000,100,'Tableau décoratif peint à la main.','approved'),
 (null,'Ordinateur portable prototype','Informatique','Tech',250000,100,'Prototype d''ordinateur portable conçu et assemblé par les étudiants du département.','approved'),
 (null,'Logo et identité visuelle','MMI','Art',50000,100,'Création d''un logo et d''une identité visuelle complète pour votre projet.','approved'),
 (null,'Cours de soutien en maths','Informatique','Tech',10000,100,'Cours de soutien en mathématiques pour lycéens et étudiants de première année.','approved'),
 (null,'Confiture artisanale','Agronomie','Alimentation',3000,100,'Confiture de fruits locaux préparée au laboratoire de transformation.','approved'),
 (null,'Jus de bissap','Agronomie','Alimentation',1500,100,'Jus de bissap frais, sans conservateur.','approved')
on conflict (title) where seller_id is null do nothing;

create sequence if not exists order_seq start 143;

create or replace function create_order(p_items jsonb, p_home boolean, p_method text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  sub int := 0;
  v_fee int := case when p_home then 5000 else 0 end;
  num text;
  oid uuid;
  it jsonb;
  l listings%rowtype;
  q int;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = uid and not suspended) then raise exception 'Compte inactif ou introuvable'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid)
    values (num, uid, 0, v_fee, coalesce(nullif(p_method, ''), 'Mobile Money'), 0, false) returning id into oid;
  for it in select * from jsonb_array_elements(p_items) loop
    q := coalesce((it->>'qty')::int, 1);
    if q < 1 or q > 20 then raise exception 'Quantité invalide'; end if;
    select * into l from listings where title = it->>'title' and status = 'approved' order by (seller_id is null) desc limit 1;
    if not found then raise exception 'Produit indisponible : %', it->>'title'; end if;
    sub := sub + l.price * q;
    insert into order_lines (order_id, listing_id, title, unit_price, qty) values (oid, l.id, l.title, l.price, q);
  end loop;
  update orders set subtotal = sub where id = oid;
  return jsonb_build_object('number', num, 'subtotal', sub, 'fee', v_fee);
end $$;

revoke all on function create_order(jsonb, boolean, text) from public, anon;
grant execute on function create_order(jsonb, boolean, text) to authenticated;

-- Plus d'insertion directe de commandes par le client : tout passe par create_order.
drop policy if exists "un client passe sa commande" on orders;
drop policy if exists "lignes ajoutees par l acheteur" on order_lines;
drop policy if exists "lignes ajoutées par l'acheteur" on order_lines;

-- AN-002 : comptes de démonstration neutralisés en production (rôle retiré, suspendus, bannis, mot de passe invalidé, sessions coupées).
update profiles set role = 'client', suspended = true
 where email in ('mariam@iut-douala.cm','mbarga@iut-douala.cm','contact@orange.cm','support@boutik-ecole.cm','carine@iut-douala.cm','direction@iut-douala.cm','finance@iut-douala.cm','admin@boutik-ecole.cm');
update auth.users set banned_until = '2999-01-01'::timestamptz, encrypted_password = crypt(gen_random_uuid()::text, gen_salt('bf'))
 where email in ('mariam@iut-douala.cm','mbarga@iut-douala.cm','contact@orange.cm','support@boutik-ecole.cm','carine@iut-douala.cm','direction@iut-douala.cm','finance@iut-douala.cm','admin@boutik-ecole.cm');
delete from auth.sessions where user_id in (select id from auth.users where email in ('mariam@iut-douala.cm','mbarga@iut-douala.cm','contact@orange.cm','support@boutik-ecole.cm','carine@iut-douala.cm','direction@iut-douala.cm','finance@iut-douala.cm','admin@boutik-ecole.cm'));

select (select count(*) from listings where seller_id is null) as catalogue,
       (select count(*) from profiles where role <> 'client') as profils_privilegies,
       (select count(*) from auth.users where banned_until > now()) as comptes_bannis;
