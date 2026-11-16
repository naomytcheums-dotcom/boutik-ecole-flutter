-- Showroom national (S9-46) : option « tous les établissements » (dont celui de la personne et ses propres créations), image et pagination.
-- Retour arrière : drop function if exists listings_other_institutions(int, boolean, int); puis recréer la version (int) de 20261105000100_impact_sponsoring.sql.

drop function if exists listings_other_institutions(int);
create or replace function listings_other_institutions(p_limit int default 20, p_all boolean default false, p_offset int default 0) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title, 'price', t.price, 'department', coalesce(t.department, ''), 'institution', t.institution,
                                               'image', t.image, 'is_mine', t.is_mine) order by t.created_at desc, t.id), '[]'::jsonb)
  from (
    select l.id, l.title, l.price, l.department, l.created_at, p.institution, coalesce(l.images[1], l.image_url) as image,
           coalesce(l.seller_id = auth.uid(), false) as is_mine
    from listings l join profiles p on p.id = l.seller_id
    where l.status = 'approved' and l.seller_id is not null and coalesce(trim(p.institution), '') <> ''
      and (coalesce(p_all, false) or auth.uid() is null or lower(p.institution) <> lower(coalesce((select institution from profiles where id = auth.uid()), '')))
    order by l.created_at desc, l.id
    offset greatest(coalesce(p_offset, 0), 0) limit least(greatest(coalesce(p_limit, 20), 1), 50)
  ) t;
$$;
revoke all on function listings_other_institutions(int, boolean, int) from public;
grant execute on function listings_other_institutions(int, boolean, int) to anon, authenticated;

-- Messagerie (S9-3) : lire une conversation marque aussi lues ses notifications « message », et le compteur de la cloche ne double plus
-- compte les messages (ils ont leur propre compteur).
-- Retour arrière : recréer mark_conversation_read (20261030000300) et unread_counts (20261115160000).
create or replace function mark_conversation_read(cid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update conversation_participants set last_read_at = now() where conversation_id = cid and user_id = auth.uid();
  update notifications set read_at = now()
    where user_id = auth.uid() and kind = 'message' and read_at is null and data ->> 'conversation_id' = cid::text;
end $$;
revoke all on function mark_conversation_read(uuid) from public, anon;
grant execute on function mark_conversation_read(uuid) to authenticated;

create or replace function unread_counts() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'notifications', (select count(*) from notifications where user_id = auth.uid() and read_at is null and kind <> 'message'),
    'messages', (select count(*) from messages m join conversation_participants p on p.conversation_id = m.conversation_id and p.user_id = auth.uid()
                  where m.sender_id <> auth.uid() and m.created_at >= p.last_read_at))
$$;
revoke all on function unread_counts() from public, anon;
grant execute on function unread_counts() to authenticated;

-- Favoris (S10-9) : on ne met pas ses propres annonces en favoris (cela gonflait le classement « populaire » sans aucun acheteur).
-- Les lignes de ce type déjà présentes sont retirées.
-- Retour arrière : drop trigger if exists trg_favorite_not_own on favorites; drop function if exists favorite_not_own();
create or replace function favorite_not_own() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from listings where id = new.listing_id and seller_id = new.user_id) then
    raise exception 'Vous ne pouvez pas mettre votre propre annonce en favoris';
  end if;
  return new;
end $$;
revoke all on function favorite_not_own() from public, anon, authenticated;
drop trigger if exists trg_favorite_not_own on favorites;
create trigger trg_favorite_not_own before insert or update on favorites for each row execute function favorite_not_own();
delete from favorites f using listings l where l.id = f.listing_id and l.seller_id = f.user_id;
