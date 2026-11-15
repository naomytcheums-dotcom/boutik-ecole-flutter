-- Lot L10 (1/5) : marché des vœux (écrans 216, 217, 218).
--  1. un vœu « planifié » n'est visible qu'à sa date de mise en ligne (publish_at) ; la fin des précommandes se calcule depuis l'ouverture ;
--  2. précommandes réelles sur LE vœu choisi (table wish_preorders) : intention enregistrée, sans paiement ni séquestre ; le créateur est notifié ;
--  3. publication d'un vœu : rôles client, étudiant, département, administrateur ; cinq vœux par jour ; rattachement à l'établissement et au département de l'auteur ;
--     notification des départements concernés (à défaut des administrateurs) ; description jamais tronquée en silence ;
--  4. validation : date de mise en ligne réelle, établissement vérifié.
-- Aucune donnée existante n'est supprimée. Les vœux déjà « planifiés » sans date exploitable restent masqués jusqu'à une nouvelle décision du département.
-- Retour arrière : voir le bas du fichier.

alter table wishes add column if not exists publish_at timestamptz;
alter table wishes add column if not exists opened_at timestamptz;
alter table wishes add column if not exists institution_id uuid references institutions(id) on delete set null;
alter table wishes add column if not exists department_id uuid references departments(id) on delete set null;

update wishes set opened_at = coalesce(updated_at, created_at) where status = 'approved' and opened_at is null;
do $$
declare r record;
begin
  for r in select id, scheduled_for from wishes where status = 'scheduled' and publish_at is null and scheduled_for is not null loop
    begin
      update wishes set publish_at = btrim(r.scheduled_for)::timestamptz, opened_at = btrim(r.scheduled_for)::timestamptz where id = r.id;
    exception when others then null;
    end;
  end loop;
end $$;
update wishes w set institution_id = p.institution_id, department_id = p.department_id from profiles p where p.id = w.author_id and w.institution_id is null and w.department_id is null;

create or replace function _wish_is_open(p_status text, p_publish_at timestamptz) returns boolean
language sql stable as $$
  select p_status = 'approved' or (p_status = 'scheduled' and p_publish_at is not null and p_publish_at <= now())
$$;
revoke all on function _wish_is_open(text, timestamptz) from public, anon, authenticated;

drop policy if exists "vœux : publics une fois validés, auteur, département" on wishes;
drop policy if exists "vœux : publics à leur date, auteur, département" on wishes;
create policy "vœux : publics à leur date, auteur, département" on wishes for select
  using ((status = 'approved' or (status = 'scheduled' and publish_at is not null and publish_at <= now()))
         or author_id = auth.uid() or current_role_name() in ('dept', 'admin'));

-- ============================================================ précommandes (intentions)
create table if not exists wish_preorders (
  wish_id uuid not null references wishes(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (wish_id, user_id)
);
create index if not exists wish_preorders_user on wish_preorders (user_id, created_at desc);
alter table wish_preorders enable row level security;
revoke all on wish_preorders from anon, authenticated;
grant select on wish_preorders to authenticated;
drop policy if exists "précommandes : les siennes" on wish_preorders;
create policy "précommandes : les siennes" on wish_preorders for select using (user_id = auth.uid());

-- Carte d'un vœu pour les listes et la fiche : compteur réel, état de MA précommande, fin des précommandes.
create or replace function _wish_card(w wishes, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', w.id, 'title', w.title, 'description', coalesce(w.description, ''), 'price', w.price, 'threshold', w.threshold, 'duration_days', w.duration_days,
    'status', w.status, 'author', display_name(w.author_id), 'created_at', w.created_at, 'opened_at', w.opened_at,
    'ends_at', case when w.opened_at is not null and w.duration_days is not null then w.opened_at + make_interval(days => w.duration_days) end,
    'count', (select count(*)::int from wish_preorders x where x.wish_id = w.id),
    'mine', p_user is not null and exists (select 1 from wish_preorders x where x.wish_id = w.id and x.user_id = p_user),
    'is_author', p_user is not null and w.author_id = p_user)
$$;
revoke all on function _wish_card(wishes, uuid) from public, anon, authenticated;

create or replace function wishes_market(p_filter text default 'all', p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); f text := coalesce(nullif(btrim(p_filter), ''), 'all');
begin
  return coalesce((select jsonb_agg(c order by
      case when f = 'near' then (c->>'count')::int end desc nulls last,
      case when f = 'new' then c->>'opened_at' end desc nulls last,
      c->>'created_at' desc)
    from (
      select _wish_card(w, uid) c
      from wishes w
      where _wish_is_open(w.status, w.publish_at)
        and (w.opened_at is null or w.duration_days is null or w.opened_at + make_interval(days => w.duration_days) > now())
        and (f <> 'new' or coalesce(w.opened_at, w.created_at) >= now() - interval '7 days')
        and (f <> 'mine' or (uid is not null and exists (select 1 from wish_preorders x where x.wish_id = w.id and x.user_id = uid)))
        and (f <> 'near' or (coalesce(w.threshold, 0) > 0
             and (select count(*) from wish_preorders x where x.wish_id = w.id) * 10 >= w.threshold * 7
             and (select count(*) from wish_preorders x where x.wish_id = w.id) < w.threshold))
      order by w.created_at desc
      limit least(greatest(coalesce(p_limit, 50), 1), 100)) q), '[]'::jsonb);
end $$;

create or replace function wish_get(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); w wishes%rowtype;
begin
  select * into w from wishes where id = p_id;
  if not found then return null; end if;
  if not (_wish_is_open(w.status, w.publish_at) or (uid is not null and w.author_id = uid) or coalesce(current_role_name()::text, '') in ('dept', 'admin')) then return null; end if;
  return _wish_card(w, uid) || jsonb_build_object('open', _wish_is_open(w.status, w.publish_at), 'review_note', case when uid is not null and w.author_id = uid then w.review_note end);
end $$;

create or replace function wish_preorder(p_wish uuid, p_on boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); w wishes%rowtype; n integer; added boolean := false;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : précommande impossible'; end if;
  select * into w from wishes where id = p_wish;
  if not found or not _wish_is_open(w.status, w.publish_at) then raise exception 'Ce vœu n''est pas ouvert aux précommandes'; end if;
  if coalesce(p_on, true) then
    if w.author_id = uid then raise exception 'Vous ne pouvez pas précommander votre propre vœu'; end if;
    if w.opened_at is not null and w.duration_days is not null and w.opened_at + make_interval(days => w.duration_days) <= now() then raise exception 'Les précommandes de ce vœu sont closes'; end if;
    if (select count(*) from wish_preorders where user_id = uid and created_at > now() - interval '1 day') >= 30 then raise exception 'Trente précommandes par jour au plus'; end if;
    insert into wish_preorders (wish_id, user_id) values (w.id, uid) on conflict do nothing;
    get diagnostics n = row_count;
    added := n > 0;
  else
    delete from wish_preorders where wish_id = w.id and user_id = uid;
  end if;
  select count(*)::int into n from wish_preorders where wish_id = w.id;
  if added and (n = 1 or n = w.threshold or n % 10 = 0) then
    perform notify_user(w.author_id, 'wish', case when w.threshold is not null and n >= w.threshold then 'Seuil de précommandes atteint' else 'Nouvelle précommande' end,
      left('« ' || w.title || ' » : ' || n || case when w.threshold is not null then ' / ' || w.threshold else '' end || ' intention(s) de précommande.', 500),
      jsonb_build_object('wish_id', w.id, 'count', n));
  end if;
  return jsonb_build_object('mine', coalesce(p_on, true), 'count', n, 'threshold', w.threshold, 'reached', w.threshold is not null and n >= w.threshold);
end $$;

-- ============================================================ publication d'un vœu
create or replace function save_wish(p_id uuid, p_title text, p_description text, p_price integer, p_threshold integer, p_duration_days integer, p_submit boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare w wishes%rowtype; wid uuid; me profiles%rowtype; v_role text := coalesce(current_role_name()::text, ''); v_to uuid[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if coalesce(me.suspended, false) then raise exception 'Compte suspendu : publication impossible'; end if;
  if v_role not in ('client', 'student', 'dept', 'admin') then raise exception 'Les vœux sont réservés aux clients, aux étudiants et au département'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if char_length(trim(coalesce(p_description, ''))) > 2000 then raise exception 'Description : 2 000 caractères au plus'; end if;
  if p_submit and (p_price is null or p_price <= 0 or p_threshold is null or p_threshold < 1) then raise exception 'Indiquez le prix et le seuil de précommandes'; end if;
  if p_price is not null and p_price < 0 or p_threshold is not null and p_threshold < 1 or p_duration_days is not null and p_duration_days not between 1 and 180 then raise exception 'Valeurs invalides'; end if;
  if p_submit and p_duration_days is null then raise exception 'Indiquez la durée de la campagne (1 à 180 jours)'; end if;
  if p_id is null then
    if (select count(*) from wishes where author_id = auth.uid() and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq vœux par jour au plus'; end if;
    insert into wishes (author_id, title, description, price, threshold, duration_days, status, institution_id, department_id)
    values (auth.uid(), trim(p_title), nullif(trim(coalesce(p_description, '')), ''), p_price, p_threshold, p_duration_days, case when p_submit then 'submitted' else 'draft' end, me.institution_id, me.department_id)
    returning id into wid;
  else
    select * into w from wishes where id = p_id and author_id = auth.uid();
    if not found then raise exception 'Vœu introuvable'; end if;
    if w.status not in ('draft', 'rejected') then raise exception 'Ce vœu est déjà en validation ou publié'; end if;
    update wishes set title = trim(p_title), description = nullif(trim(coalesce(p_description, '')), ''), price = p_price, threshold = p_threshold,
      duration_days = p_duration_days, status = case when p_submit then 'submitted' else 'draft' end, review_note = case when p_submit then null else review_note end,
      institution_id = coalesce(institution_id, me.institution_id), department_id = coalesce(department_id, me.department_id), updated_at = now()
      where id = w.id returning id into wid;
  end if;
  if p_submit then
    select array_agg(id) into v_to from profiles where role::text = 'dept' and not coalesce(suspended, false) and me.department_id is not null and department_id = me.department_id;
    if v_to is null and me.institution_id is not null then
      select array_agg(id) into v_to from profiles where role::text = 'dept' and not coalesce(suspended, false) and institution_id = me.institution_id;
    end if;
    if v_to is null then
      select array_agg(id) into v_to from profiles where role::text = 'admin' and not coalesce(suspended, false);
    end if;
    insert into notifications (user_id, kind, title, body, data)
    select u, 'wish', 'Vœu à valider', left(trim(p_title), 200), jsonb_build_object('wish_id', wid) from unnest(coalesce(v_to, '{}'::uuid[])) u where u <> auth.uid();
  end if;
  return wid;
end $$;

create or replace function review_wish(p_id uuid, p_decision text, p_note text, p_scheduled_for text default null) returns text
language plpgsql security definer set search_path = public as $$
declare w wishes%rowtype; v_at timestamptz; me profiles%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into w from wishes where id = p_id;
  if not found or w.status not in ('submitted', 'scheduled') then raise exception 'Aucun vœu à valider'; end if;
  select * into me from profiles where id = auth.uid();
  if me.role::text = 'dept' and w.institution_id is not null and me.institution_id is not null and w.institution_id <> me.institution_id then raise exception 'Ce vœu relève d''un autre établissement'; end if;
  if p_decision not in ('approved', 'rejected', 'scheduled') then raise exception 'Décision inconnue'; end if;
  if p_decision = 'rejected' and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  if p_decision = 'scheduled' then
    begin
      v_at := btrim(coalesce(p_scheduled_for, ''))::timestamptz;
    exception when others then
      raise exception 'Date de mise en ligne invalide : écrivez AAAA-MM-JJ ou AAAA-MM-JJ HH:MM';
    end;
    if v_at <= now() then raise exception 'La date de mise en ligne doit être dans le futur'; end if;
  end if;
  update wishes set status = p_decision, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), reviewed_by = auth.uid(),
    scheduled_for = case when p_decision = 'scheduled' then left(btrim(p_scheduled_for), 60) end,
    publish_at = case when p_decision = 'scheduled' then v_at end,
    opened_at = case p_decision when 'approved' then now() when 'scheduled' then v_at else opened_at end,
    updated_at = now() where id = w.id;
  insert into notifications (user_id, kind, title, body, data)
  values (w.author_id, 'wish', case p_decision when 'rejected' then 'Vœu refusé' when 'scheduled' then 'Vœu planifié' else 'Vœu validé' end,
          case when p_decision = 'scheduled' then left(w.title || ' · en ligne le ' || to_char(v_at at time zone 'Africa/Douala', 'DD/MM/YYYY HH24:MI'), 500) else w.title end, jsonb_build_object('wish_id', w.id));
  return p_decision;
end $$;

revoke all on function wishes_market(text, integer), wish_get(uuid) from public;
grant execute on function wishes_market(text, integer), wish_get(uuid) to anon, authenticated;
revoke all on function wish_preorder(uuid, boolean), save_wish(uuid, text, text, integer, integer, integer, boolean), review_wish(uuid, text, text, text) from public, anon;
grant execute on function wish_preorder(uuid, boolean), save_wish(uuid, text, text, integer, integer, integer, boolean), review_wish(uuid, text, text, text) to authenticated;

-- Retour arrière : recréer save_wish et review_wish depuis 20261031000000, recréer la politique « vœux : publics une fois validés, auteur, département » ;
--   drop function wishes_market(text, integer), wish_get(uuid), wish_preorder(uuid, boolean), _wish_card(wishes, uuid), _wish_is_open(text, timestamptz) ;
--   drop table wish_preorders ; alter table wishes drop column publish_at, drop column opened_at, drop column institution_id, drop column department_id.
