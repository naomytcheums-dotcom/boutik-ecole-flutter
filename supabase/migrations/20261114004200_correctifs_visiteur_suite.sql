-- Correctifs complémentaires du profil Visiteur (suite de 20261114004100) :
--  1. comptes suspendus : privilèges retirés immédiatement (jeton encore valide), blocage des écritures de contenu, messages exacts ;
--  2. lectures sans écriture : les rappels de date limite ne sont plus créés à l'ouverture des listes d'annonces et d'offres (tâche planifiée) ;
--  3. vendeurs : noms d'affichage des vendeurs d'annonces, profil par identifiant, homonymes signalés au lieu d'être confondus ;
--  4. projets validés et publics lisibles par les visiteurs (sans coordonnées de contact) ;
--  5. alerte de filière désactivable sans filière ; titres de produits des collections tenus à jour.
-- Aucune donnée existante n'est modifiée ni supprimée. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Comptes suspendus
-- Jusqu'ici, un compte suspendu gardait ses droits jusqu'à l'expiration de son jeton (la suspension ferme les sessions et bloque la connexion,
-- mais un jeton déjà émis reste valide) : le rôle effectif d'un compte suspendu est désormais nul, donc toutes les politiques et fonctions
-- réservées à un rôle le refusent.
create or replace function current_role_name() returns app_role
language sql stable security definer set search_path = public as $$
  select case when coalesce(suspended, false) then null else role end from profiles where id = auth.uid()
$$;

-- Les écritures de contenu qui ne dépendent d'aucun rôle (commentaires, mentions j'aime, messages, avis…) sont refusées à un compte suspendu,
-- y compris lorsqu'elles passent par une fonction SECURITY DEFINER.
create or replace function block_suspended_author() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_uid uuid;
begin
  v_uid := nullif(to_jsonb(new) ->> tg_argv[0], '')::uuid;
  if v_uid is not null and exists (select 1 from profiles where id = v_uid and coalesce(suspended, false)) then
    raise exception 'Compte suspendu : cette action est impossible';
  end if;
  return new;
end $$;

do $$
declare t record;
begin
  for t in
    select * from (values
      ('posts', 'author_id'), ('post_comments', 'author_id'), ('post_likes', 'user_id'), ('post_saves', 'user_id'), ('post_shares', 'user_id'),
      ('post_reactions', 'user_id'), ('post_reports', 'reporter_id'), ('stories', 'author_id'), ('story_answers', 'user_id'),
      ('messages', 'sender_id'), ('reviews', 'reviewer_id'), ('claims', 'claimant_id'), ('product_questions', 'asker_id'),
      ('orders', 'buyer_id'), ('listings', 'seller_id'), ('community_members', 'user_id'), ('live_comments', 'user_id'),
      ('event_registrations', 'user_id'), ('opportunity_applications', 'applicant_id'), ('teammate_invites', 'from_user')
    ) v(tbl, col)
  loop
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = t.tbl and column_name = t.col) then
      execute format('drop trigger if exists trg_block_suspended on %I', t.tbl);
      execute format('create trigger trg_block_suspended before insert on %I for each row execute function block_suspended_author(%L)', t.tbl, t.col);
    end if;
  end loop;
end $$;

-- Messages exacts des fonctions de publication : elles refusaient bien les comptes suspendus, mais disaient « réservé aux étudiants et au département ».
do $$
declare r record; d text;
begin
  for r in
    select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.prosrc like '%Publication réservée aux étudiants et au département%'
        or p.prosrc like '%Histoires réservées aux étudiants et au département%'
        or p.prosrc like '%Les Lives sont réservés aux étudiants et au département%')
  loop
    d := pg_get_functiondef(r.oid);
    d := replace(d, 'Publication réservée aux étudiants et au département', 'Compte suspendu : publication impossible');
    d := replace(d, 'Histoires réservées aux étudiants et au département', 'Compte suspendu : publication des histoires impossible');
    d := replace(d, 'Les Lives sont réservés aux étudiants et au département', 'Compte suspendu : création de live impossible');
    execute d;
  end loop;
end $$;

-- ============================================================ 2. Rappels de date limite : tâche planifiée au lieu d'une écriture à chaque lecture
create or replace function send_due_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in select rm.user_id, o.id, o.title, o.org_name from opportunity_reminders rm join opportunities o on o.id = rm.opportunity_id
           where not rm.notified and o.deadline is not null and o.deadline <= current_date + 2 and o.deadline >= current_date and o.status = 'published' loop
    insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'opportunity_reminder', 'Rappel : la date limite approche', left(r.org_name || ' : ' || r.title || ' se termine bientôt.', 500), jsonb_build_object('opportunity', r.id));
    update opportunity_reminders set notified = true where opportunity_id = r.id and user_id = r.user_id;
    n := n + 1;
  end loop;
  for r in select rm.user_id, a.id, a.title from contest_ann_reminders rm join contest_announcements a on a.id = rm.announcement_id
           where not rm.notified and a.deadline is not null and a.deadline <= current_date + 3 and a.deadline >= current_date and a.status = 'published' loop
    insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'contest_reminder', 'Rappel : la date limite approche', left('« ' || r.title || ' » se termine dans moins de 3 jours.', 500), jsonb_build_object('announcement', r.id));
    update contest_ann_reminders set notified = true where announcement_id = r.id and user_id = r.user_id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function send_due_reminders() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('send-due-reminders', '*/15 * * * *', 'select public.send_due_reminders()');
exception when others then
  raise notice 'pg_cron indisponible : les rappels de date limite ne partent pas tant que send_due_reminders() n''est pas planifiée (%).', sqlerrm;
end $$;

-- Les listes redeviennent de simples lectures.
create or replace function opps_list(p_kind text default null, p_q text default null, p_mode text default null, p_paid_only boolean default false, p_iut_only boolean default false,
  p_department text default null, p_section text default null, p_limit integer default 40) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_dept text;
begin
  if uid is not null then
    select lower(coalesce(department, '')) into v_dept from profiles where id = uid;
  end if;
  return coalesce((select jsonb_agg(c order by (c->>'pay_kind' = 'paid') desc, (c->>'deadline') nulls last, c->>'created_at' desc) from (
    select _opp_card(o, uid) c from opportunities o
    where o.status = 'published' and (o.deadline is null or o.deadline >= current_date)
      and (nullif(btrim(coalesce(p_kind, '')), '') is null or o.kind = p_kind)
      and (nullif(btrim(coalesce(p_mode, '')), '') is null or o.mode = p_mode)
      and (not coalesce(p_paid_only, false) or o.pay_kind = 'paid')
      and (not coalesce(p_iut_only, false) or o.iut_only)
      and (nullif(btrim(coalesce(p_department, '')), '') is null or o.department_target = '' or lower(o.department_target) like '%' || lower(btrim(p_department)) || '%')
      and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(o.title || ' ' || o.org_name || ' ' || o.description || ' ' || array_to_string(o.skills, ' ') || ' ' || o.location) like '%' || lower(btrim(p_q)) || '%')
      and case coalesce(p_section, '')
            when 'foryou' then coalesce(v_dept, '') <> '' and (o.department_target = '' or lower(o.department_target) like '%' || v_dept || '%' or v_dept like '%' || lower(o.department_target) || '%')
            when 'closing' then o.deadline is not null and o.deadline <= current_date + 3
            when 'new' then o.created_at > now() - interval '7 days'
            when 'iut' then o.iut_only
            when 'saved' then exists (select 1 from opportunity_saves s where s.opportunity_id = o.id and s.user_id = uid)
            else true end
    limit least(greatest(coalesce(p_limit, 40), 1), 100)) x), '[]'::jsonb);
end $$;

create or replace function anns_list(p_q text default null, p_country text default null, p_domain text default null, p_free text default null, p_place text default null,
  p_within_days integer default null, p_kind text default null, p_saved boolean default false, p_limit integer default 40) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  return coalesce((select jsonb_agg(c order by (c->>'deadline') nulls last, c->>'created_at' desc) from (
    select _ann_card(a, uid) c from contest_announcements a
    where a.status = 'published' and (a.deadline is null or a.deadline >= current_date)
      and (nullif(btrim(coalesce(p_kind, '')), '') is null or a.kind = p_kind)
      and (nullif(btrim(coalesce(p_domain, '')), '') is null or a.domain = p_domain)
      and (nullif(btrim(coalesce(p_place, '')), '') is null or a.place_kind = p_place)
      and (nullif(btrim(coalesce(p_country, '')), '') is null or lower(a.country) like '%' || lower(btrim(p_country)) || '%')
      and (nullif(btrim(coalesce(p_free, '')), '') is null or a.free = (p_free = 'free'))
      and (p_within_days is null or (a.deadline is not null and a.deadline <= current_date + p_within_days))
      and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(a.title || ' ' || a.organizer || ' ' || a.description || ' ' || a.country || ' ' || a.reward) like '%' || lower(btrim(p_q)) || '%')
      and (not coalesce(p_saved, false) or exists (select 1 from contest_ann_saves s where s.announcement_id = a.id and s.user_id = uid))
    limit least(greatest(coalesce(p_limit, 40), 1), 100)) x), '[]'::jsonb);
end $$;

-- ============================================================ 3. Vendeurs : noms d'affichage, profil par identifiant, homonymes
-- Noms abrégés (« Prénom N. ») des vendeurs d'annonces publiées ; aucun vendeur sans annonce approuvée, aucun compte suspendu.
create or replace function public_sellers(p_ids uuid[]) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(p.id::text, display_name(p.id)), '{}'::jsonb)
  from profiles p
  where p.id = any (coalesce(p_ids[1:300], '{}'::uuid[])) and not coalesce(p.suspended, false)
    and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')
$$;
revoke all on function public_sellers(uuid[]) from public;
grant execute on function public_sellers(uuid[]) to anon, authenticated;

-- Profil public du vendeur : par identifiant (fiable) ou par nom ; deux vendeurs de même nom ne sont plus confondus (« ambiguous »).
drop function if exists seller_public(text);
create or replace function seller_public(p_name text default null, p_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid; v_p profiles%rowtype; v_n integer;
begin
  if p_id is not null then
    select * into v_p from profiles where id = p_id;
  else
    if nullif(trim(coalesce(p_name, '')), '') is null then return jsonb_build_object('found', false); end if;
    select count(*) into v_n from profiles p where lower(p.name) = lower(trim(p_name))
      and exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved');
    if v_n > 1 then return jsonb_build_object('found', false, 'ambiguous', true); end if;
    select * into v_p from profiles p where lower(p.name) = lower(trim(p_name))
      order by (exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')) desc, p.created_at limit 1;
  end if;
  if v_p.id is null or coalesce(v_p.suspended, false) then return jsonb_build_object('found', false); end if;
  v_id := v_p.id;
  return jsonb_build_object(
    'found', true,
    'id', v_id,
    'name', v_p.name,
    'department', coalesce(v_p.department, ''),
    'institution', coalesce(v_p.institution, ''),
    'verified', v_p.certification::text = 'approved',
    'since', v_p.created_at,
    'shop_slug', (select s.slug from shops s where s.owner_id = v_id and s.status = 'active'),
    'shop_name', (select s.name from shops s where s.owner_id = v_id and s.status = 'active'),
    'products', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category <> 'Services'),
    'services', (select count(*)::int from listings l where l.seller_id = v_id and l.status = 'approved' and l.category = 'Services'),
    'sales', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id
              where l.seller_id = v_id and o.paid and o.cancelled_at is null),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'rating_avg', (select round(avg(r.rating)::numeric, 1) from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id),
    'stars', (select coalesce(jsonb_object_agg(s::text, c), '{}'::jsonb) from (select r.rating s, count(*)::int c from reviews r join listings l on l.id = r.listing_id where l.seller_id = v_id group by 1) x)
  );
end $$;
revoke all on function seller_public(text, uuid) from public;
grant execute on function seller_public(text, uuid) to anon, authenticated;

-- ============================================================ 4. Projets validés et publics, lisibles par les visiteurs (coordonnées de contact retirées)
create or replace function public_projects(p_kind text default null, p_limit integer default 50) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'kind', p.kind, 'title', p.title, 'summary', p.summary, 'department', p.department,
      'details', coalesce(p.details, '{}'::jsonb) - 'contact_email' - 'contact_phone', 'media', p.media, 'status', p.status, 'created_at', p.created_at)
    order by p.created_at desc), '[]'::jsonb)
  from (select * from projects where status = 'approved' and visibility = 'public' and (nullif(trim(coalesce(p_kind, '')), '') is null or kind = p_kind)
        order by created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 100)) p
$$;
revoke all on function public_projects(text, integer) from public;
grant execute on function public_projects(text, integer) to anon, authenticated;

-- ============================================================ 5. Alerte de filière désactivable sans filière ; collections : le titre suit l'annonce
create or replace function opp_alert_set(p_department text, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_on, true) then
    if char_length(btrim(coalesce(p_department, ''))) < 2 then raise exception 'Indiquez votre filière dans votre profil'; end if;
    insert into opportunity_alerts (user_id, department) values (auth.uid(), btrim(p_department)) on conflict do nothing;
  elsif char_length(btrim(coalesce(p_department, ''))) < 2 then
    delete from opportunity_alerts where user_id = auth.uid();
  else
    delete from opportunity_alerts where user_id = auth.uid() and lower(department) = lower(btrim(p_department));
  end if;
end $$;

create or replace function sync_collection_item_title() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.title is distinct from old.title then
    update user_collection_items i set title = new.title
    where i.title = old.title and not exists (select 1 from user_collection_items j where j.collection_id = i.collection_id and j.title = new.title);
  end if;
  return null;
end $$;
drop trigger if exists trg_sync_collection_item_title on listings;
create trigger trg_sync_collection_item_title after update of title on listings for each row execute function sync_collection_item_title();

-- RETOUR ARRIÈRE : recréer current_role_name() depuis schema.sql (select role from profiles where id = auth.uid()) ; drop trigger trg_block_suspended sur les tables concernées ;
--   drop function block_suspended_author(), send_due_reminders(), public_sellers(uuid[]), public_projects(text, integer), sync_collection_item_title(), seller_public(text, uuid) ;
--   select cron.unschedule('send-due-reminders') ; recréer seller_public(text) (20261107000000), opps_list (20261114001300), anns_list (20261114001400), opp_alert_set (20261114001300).
