-- Découverte dans la marketplace : par filière, par besoin ou problème (mots-clés classés par pertinence) et « Recommandés pour toi ».
-- Retour arrière : drop function recommended_offers(integer); drop function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[]);
--                   puis recréer marketplace_search depuis 20261114000100_types_offres.sql.

drop function if exists marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text);
create or replace function marketplace_search(p_q text default null, p_category text default null, p_city text default null, p_min integer default null, p_max integer default null,
  p_sort text default 'popular', p_shop uuid default null, p_limit integer default 24, p_offset integer default 0, p_offer_type text default null,
  p_department text default null, p_terms text[] default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_q text := nullif(trim(coalesce(p_q, '')), '');
  v_t text := nullif(trim(coalesce(p_offer_type, '')), '');
  v_d text := nullif(trim(coalesce(p_department, '')), '');
  v_terms text[] := (select nullif(array_agg(distinct lower(trim(x))), '{}') from unnest(coalesce(p_terms, '{}'::text[])) x where char_length(trim(x)) between 3 and 30 limit 12);
  r jsonb;
begin
  select coalesce(jsonb_agg(q.c order by
      case when v_terms is not null then q.score end desc nulls last,
      case p_sort when 'price_asc' then (q.c->>'price')::numeric end asc nulls last,
      case p_sort when 'price_desc' then (q.c->>'price')::numeric end desc nulls last,
      case p_sort when 'recent' then q.c->>'created_at' end desc nulls last,
      case p_sort when 'rating' then coalesce((q.c->>'rating_avg')::numeric, 0) end desc nulls last,
      ((q.c->>'sales')::int * 3 + (q.c->>'favs')::int) desc, q.c->>'created_at' desc), '[]'::jsonb)
  into r from (
    select _listing_card(l) c,
           case when v_terms is null then 0 else (select count(*)::int from unnest(v_terms) t where lower(l.title || ' ' || coalesce(l.description, '') || ' ' || l.category) like '%' || t || '%') end score
    from listings l
    left join shops s on s.id = l.shop_id
    left join profiles sp on sp.id = l.seller_id
    where l.status = 'approved' and (l.shop_id is null or s.status = 'active')
      and (case
             when v_t is not null then offer_type_of(l.category) = v_t and (p_category is null or p_category = '' or lower(l.category) = lower(p_category))
             when p_category is null or p_category = '' then true
             else lower(l.category) = lower(p_category) end)
      and (v_q is null or l.title ilike '%' || v_q || '%' or coalesce(l.description, '') ilike '%' || v_q || '%' or coalesce(s.name, '') ilike '%' || v_q || '%')
      and (v_d is null or lower(coalesce(l.department, '')) like '%' || lower(v_d) || '%')
      and (p_city is null or p_city = '' or lower(coalesce(s.city, sp.city, '')) = lower(p_city))
      and (p_min is null or l.price >= p_min) and (p_max is null or l.price <= p_max)
      and (p_shop is null or l.shop_id = p_shop)
  ) q
  where v_terms is null or q.score > 0;
  -- pagination appliquée après le classement par pertinence
  select coalesce(jsonb_agg(e), '[]'::jsonb) into r from (
    select e from jsonb_array_elements(r) with ordinality t(e, n)
    order by n limit least(greatest(coalesce(p_limit, 24), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) z;
  return r;
end $$;
revoke all on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[]) from public;
grant execute on function marketplace_search(text, text, text, integer, integer, text, uuid, integer, integer, text, text, text[]) to anon, authenticated;

-- « Recommandés pour toi » : offres de la filière de la personne connectée (jamais les siennes), les plus populaires d'abord ;
-- sans filière connue ou sans offre de sa filière, les offres les plus populaires de la plateforme.
create or replace function recommended_offers(p_limit integer default 10) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_dept text; r jsonb; v_lim integer := least(greatest(coalesce(p_limit, 10), 1), 30);
begin
  select nullif(trim(department), '') into v_dept from profiles where id = uid;
  if v_dept is not null then
    select coalesce(jsonb_agg(c order by ((c->>'sales')::int * 3 + (c->>'favs')::int) desc, c->>'created_at' desc), '[]'::jsonb) into r from (
      select _listing_card(l) c from listings l left join shops s on s.id = l.shop_id
      where l.status = 'approved' and (l.shop_id is null or s.status = 'active') and l.seller_id is distinct from uid
        and lower(coalesce(l.department, '')) = lower(v_dept)
      limit v_lim) q;
    if jsonb_array_length(r) > 0 then return r; end if;
  end if;
  select coalesce(jsonb_agg(c order by ((c->>'sales')::int * 3 + (c->>'favs')::int) desc, c->>'created_at' desc), '[]'::jsonb) into r from (
    select _listing_card(l) c from listings l left join shops s on s.id = l.shop_id
    where l.status = 'approved' and (l.shop_id is null or s.status = 'active') and l.seller_id is distinct from uid
    limit v_lim) q;
  return r;
end $$;
revoke all on function recommended_offers(integer) from public;
grant execute on function recommended_offers(integer) to anon, authenticated;
