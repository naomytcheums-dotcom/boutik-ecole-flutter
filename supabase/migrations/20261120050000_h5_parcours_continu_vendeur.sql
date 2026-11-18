-- Lot H5 (visiteur / client continu + capacité vendeur) : un seul parcours public -> inscription -> espace personnel -> achat ; le vendeur est une CAPACITÉ.
--   1. my_seller_capability() : capacité vendeur d'un compte connecté. Conditions réunies = rôle étudiant + étudiant vérifié (is_verified_student) + téléphone
--      vérifié + compte non suspendu. Tous les autres rôles : non. Aucun compte supplémentaire : la capacité se lit sur le profil existant.
--      La réponse liste chaque condition (clé, libellé, état) pour que l'application affiche l'écran explicatif des conditions.
--   2. Création d'une boutique : déjà réservée au rôle étudiant par le déclencheur shops_owner_must_be_student (20261114003200) ; la capacité vendeur s'aligne dessus.
--   3. Espace personnel du client : my_client_space() (compteurs réels : favoris, adresses, avis, litiges et réclamations ouverts), my_reviews() et review_delete().
-- Additive et rejouable. Retour arrière :
--   drop function if exists my_seller_capability(), _seller_capability(uuid), my_client_space(), my_reviews(), review_delete(text, uuid) ;

-- ============================================================ 1. Capacité vendeur
create or replace function _seller_capability(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype; c_role boolean; c_verified boolean; c_phone boolean; c_active boolean; v_missing jsonb := '[]'::jsonb;
begin
  select * into p from profiles where id = p_user;
  if p.id is null then
    return jsonb_build_object('can_sell', false, 'role', null, 'can_publish', false, 'missing', jsonb_build_array('profile'),
      'conditions', jsonb_build_array(jsonb_build_object('key', 'profile', 'label', 'Profil complété', 'ok', false)));
  end if;
  c_role := p.role::text = 'student';
  c_active := not coalesce(p.suspended, false);
  c_verified := c_role and is_verified_student(p.id);
  c_phone := coalesce(p.phone_verified, false);
  if not c_role then v_missing := v_missing || '"student"'::jsonb; end if;
  if not c_verified then v_missing := v_missing || '"student_verified"'::jsonb; end if;
  if not c_phone then v_missing := v_missing || '"phone_verified"'::jsonb; end if;
  if not c_active then v_missing := v_missing || '"not_suspended"'::jsonb; end if;
  return jsonb_build_object(
    'can_sell', c_role and c_verified and c_phone and c_active,
    'role', p.role::text,
    'can_publish', p.certification::text = 'approved' and c_active,
    'missing', v_missing,
    'conditions', jsonb_build_array(
      jsonb_build_object('key', 'student', 'label', 'Compte étudiant', 'ok', c_role),
      jsonb_build_object('key', 'student_verified', 'label', 'Statut d''étudiant vérifié (pièce validée ou compte certifié)', 'ok', c_verified),
      jsonb_build_object('key', 'phone_verified', 'label', 'Numéro de téléphone vérifié par un code', 'ok', c_phone),
      jsonb_build_object('key', 'not_suspended', 'label', 'Compte non suspendu', 'ok', c_active)));
end $$;
revoke all on function _seller_capability(uuid) from public, anon, authenticated;

create or replace function my_seller_capability() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return _seller_capability(auth.uid());
end $$;
revoke all on function my_seller_capability() from public, anon;
grant execute on function my_seller_capability() to authenticated;

-- ============================================================ 2. Création d'une boutique
-- Déjà verrouillée par le déclencheur shops_owner_must_be_student (20261114003200) : seul un compte au rôle étudiant crée une boutique,
-- le client, l'organisation, le département, la direction et les équipes de la plateforme sont refusés. Rien à ajouter ici.

-- ============================================================ 3. Espace personnel du client
create or replace function my_client_space() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'favorites', (select count(*) from favorites where user_id = uid),
    'addresses', (select count(*) from addresses where user_id = uid),
    'reviews', (select count(*) from reviews where reviewer_id = uid) + (select count(*) from shop_reviews where reviewer_id = uid),
    'disputes_open', (select count(*) from order_disputes where (buyer_id = uid or opened_by = uid) and status <> 'resolved'),
    'claims_open', (select count(*) from claims where claimant_id = uid and status <> 'closed'));
end $$;
revoke all on function my_client_space() from public, anon;
grant execute on function my_client_space() to authenticated;

-- Avis publiés par la personne connectée : articles (commande payée) et boutiques.
create or replace function my_reviews() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(x order by (x->>'created_at') desc) from (
      select jsonb_build_object('kind', 'product', 'id', r.id, 'title', l.title, 'rating', r.rating, 'comment', r.comment, 'created_at', r.created_at, 'order_number', o.number) x
        from reviews r join listings l on l.id = r.listing_id join orders o on o.id = r.order_id where r.reviewer_id = uid
      union all
      select jsonb_build_object('kind', 'shop', 'id', s.id, 'title', sh.name, 'rating', s.rating, 'comment', s.comment, 'created_at', s.created_at, 'order_number', null)
        from shop_reviews s join shops sh on sh.id = s.shop_id where s.reviewer_id = uid
      limit 100) q), '[]'::jsonb);
end $$;
revoke all on function my_reviews() from public, anon;
grant execute on function my_reviews() to authenticated;

-- Retrait d'un avis par son auteur (jamais l'avis d'un autre).
create or replace function review_delete(p_kind text, p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte inactif ou introuvable'; end if;
  if p_kind = 'product' then
    delete from reviews where id = p_id and reviewer_id = auth.uid();
  elsif p_kind = 'shop' then
    delete from shop_reviews where id = p_id and reviewer_id = auth.uid();
  else
    raise exception 'Type d''avis inconnu';
  end if;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'Avis introuvable'; end if;
  return 'deleted';
end $$;
revoke all on function review_delete(text, uuid) from public, anon;
grant execute on function review_delete(text, uuid) to authenticated;
