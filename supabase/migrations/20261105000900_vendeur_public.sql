-- Profil public, réputation et confiance d'un vendeur (écrans 24, 38, 172) : chiffres calculés sur ses annonces publiées, ses ventes payées
-- et les avis de ses annonces. Lisible par toute personne connectée ou non (aucune donnée privée : ni e-mail, ni téléphone, ni adresse).
-- Retour arrière : drop function seller_public(text);

create or replace function seller_public(p_name text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_p profiles%rowtype;
begin
  select * into v_p from profiles where lower(name) = lower(trim(p_name)) order by created_at limit 1;
  if not found then return jsonb_build_object('found', false); end if;
  v_id := v_p.id;
  return jsonb_build_object(
    'found', true,
    'name', v_p.name,
    'department', coalesce(v_p.department, ''),
    'institution', coalesce(v_p.institution, ''),
    'verified', v_p.certification::text = 'approved',
    'since', v_p.created_at,
    'products', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category <> 'Services'),
    'services', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category = 'Services'),
    'sales', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = v_id and o.paid and o.cancelled_at is null),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'stars', (select coalesce(jsonb_object_agg(s::text, c), '{}'::jsonb) from (select r.rating s, count(*)::int c from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id group by 1) x)
  );
end $$;

revoke all on function seller_public(text) from public;
grant execute on function seller_public(text) to anon, authenticated;
