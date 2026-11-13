-- Séquestre 70 / 20 / 10 : l'argent payé par un client ou une entreprise est conservé par Boutik-École ; il n'est débloqué qu'à la livraison / réponse du prestataire,
-- puis réparti : 70 % au prestataire (étudiant), 20 % au fonds de l'institution, 10 % à la plateforme. Un étudiant ne reçoit JAMAIS l'argent directement :
-- ses gains passent par son solde, et seuls l'administrateur et la finance déclenchent les versements, dans la limite du solde disponible.
-- La règle (70/20/10 par défaut) est modifiable par l'administrateur avec historique ; elle ne s'applique qu'aux paiements futurs.
-- Cette migration couvre les commandes (produits et devis) et les forfaits ; les autres flux (missions, campagnes, événements, cadeaux de live) sont listés dans l'inventaire.
-- Retour arrière : drop triggers trg_money_order_paid, trg_money_order_cancelled sur orders et trg_money_release sur order_lines ; drop function money_* ; drop table money_entries, money_split_rules ;
--   recréer payout_create et seller_revenue depuis 20261105000500 et 20261105000800 ; recréer on_subscription_paid depuis 20261114002700.

create table if not exists money_split_rules (
  id bigint generated always as identity primary key,
  beneficiary_pct integer not null check (beneficiary_pct between 0 and 100),
  institution_pct integer not null check (institution_pct between 0 and 100),
  platform_pct integer not null check (platform_pct between 0 and 100),
  note text check (note is null or char_length(note) <= 200),
  set_by uuid references profiles(id) on delete set null,
  set_at timestamptz not null default now(),
  check (beneficiary_pct + institution_pct + platform_pct = 100)
);
insert into money_split_rules (beneficiary_pct, institution_pct, platform_pct, note) select 70, 20, 10, 'Règle de départ' where not exists (select 1 from money_split_rules);

create table if not exists money_entries (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('order', 'subscription', 'mission', 'campaign', 'event', 'gift', 'other')),
  ref text not null default '',
  order_id uuid references orders(id) on delete set null,
  payer_id uuid references profiles(id) on delete set null,
  beneficiary_id uuid references profiles(id) on delete set null,
  gross integer not null check (gross >= 0),
  beneficiary_amount integer not null default 0 check (beneficiary_amount >= 0),
  institution_amount integer not null default 0 check (institution_amount >= 0),
  platform_amount integer not null default 0 check (platform_amount >= 0),
  split text not null default '',
  status text not null default 'held' check (status in ('held', 'released', 'frozen', 'refunded', 'cod_due')),
  frozen_reason text check (frozen_reason is null or char_length(frozen_reason) <= 300),
  created_at timestamptz not null default now(),
  released_at timestamptz,
  check (beneficiary_amount + institution_amount + platform_amount = gross)
);
create unique index if not exists money_entries_order_seller on money_entries (order_id, beneficiary_id) where kind = 'order' and order_id is not null and beneficiary_id is not null;
create unique index if not exists money_entries_order_platform on money_entries (order_id) where kind = 'order' and order_id is not null and beneficiary_id is null;
create index if not exists money_entries_beneficiary on money_entries (beneficiary_id, status);
alter table money_split_rules enable row level security;
alter table money_entries enable row level security;
revoke all on money_split_rules, money_entries from anon, authenticated;

create or replace function money_split_amounts(p_gross integer, out b integer, out i integer, out p integer)
language plpgsql stable security definer set search_path = public as $$
declare r money_split_rules%rowtype;
begin
  select * into r from money_split_rules order by id desc limit 1;
  b := (p_gross::bigint * r.beneficiary_pct / 100)::int;
  i := (p_gross::bigint * r.institution_pct / 100)::int;
  p := p_gross - b - i; -- le reliquat d'arrondi va à la plateforme
end $$;

create or replace function money_split_label() returns text
language sql stable security definer set search_path = public as $$
  select beneficiary_pct || '/' || institution_pct || '/' || platform_pct from money_split_rules order by id desc limit 1
$$;

create or replace function money_split_get() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('current', (select to_jsonb(r) from (select * from money_split_rules order by id desc limit 1) r),
    'history', coalesce((select jsonb_agg(to_jsonb(h) order by h.id desc) from (select id, beneficiary_pct, institution_pct, platform_pct, note, set_at from money_split_rules order by id desc limit 10) h), '[]'::jsonb))
  where auth.uid() is not null
$$;

create or replace function money_split_set(p_beneficiary integer, p_institution integer, p_platform integer, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_beneficiary + p_institution + p_platform <> 100 then raise exception 'Les trois parts doivent faire 100 %% au total'; end if;
  if p_beneficiary < 0 or p_institution < 0 or p_platform < 0 then raise exception 'Une part ne peut pas être négative'; end if;
  insert into money_split_rules (beneficiary_pct, institution_pct, platform_pct, note, set_by) values (p_beneficiary, p_institution, p_platform, nullif(left(btrim(coalesce(p_note, '')), 200), ''), auth.uid());
  return p_beneficiary || '/' || p_institution || '/' || p_platform;
end $$;

-- Commande payée : une ligne de séquestre par vendeur (et une pour la plateforme si elle vend elle-même). Paiement à la livraison : l'argent est déjà chez le vendeur, la part à reverser est « à recouvrer ».
create or replace function money_order_paid(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; g record; v_b integer; v_i integer; v_p integer; v_split text := money_split_label();
begin
  select * into o from orders where id = p_order;
  if not found then return; end if;
  for g in
    select l.seller_id, sum(ol.unit_price * ol.qty)::int as gross
    from order_lines ol left join listings l on l.id = ol.listing_id where ol.order_id = p_order group by l.seller_id
  loop
    continue when g.gross <= 0;
    if g.seller_id is null then
      insert into money_entries (kind, ref, order_id, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
      values ('order', o.number, o.id, o.buyer_id, null, g.gross, g.gross, 'plateforme', 'released', now()) on conflict do nothing;
    else
      select b, i, p into v_b, v_i, v_p from money_split_amounts(g.gross);
      insert into money_entries (kind, ref, order_id, payer_id, beneficiary_id, gross, beneficiary_amount, institution_amount, platform_amount, split, status)
      values ('order', o.number, o.id, o.buyer_id, g.seller_id, g.gross, v_b, v_i, v_p, v_split, case when o.cod then 'cod_due' else 'held' end) on conflict do nothing;
    end if;
  end loop;
  perform money_try_release(p_order);
end $$;

-- Déblocage : tous les articles du vendeur sont livrés et aucune réclamation ni litige n'est ouvert sur la commande.
create or replace function money_try_release(p_order uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype; n integer := 0;
begin
  if exists (select 1 from claims where order_id = p_order and status = 'open') or exists (select 1 from order_disputes where order_id = p_order and status = 'open') then return 0; end if;
  for e in select * from money_entries where order_id = p_order and status = 'held' and beneficiary_id is not null loop
    if exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = p_order and l.seller_id = e.beneficiary_id and ol.fulfillment < 4) then continue; end if;
    update money_entries set status = 'released', released_at = now() where id = e.id;
    insert into notifications (user_id, kind, title, body, data)
      values (e.beneficiary_id, 'money', 'Argent débloqué', e.beneficiary_amount || ' FCFA sont disponibles sur votre solde (commande ' || e.ref || ', part de ' || split_part(e.split, '/', 1) || ' %).', jsonb_build_object('entry', e.id));
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function trg_money_order_paid() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.paid and not old.paid then perform money_order_paid(new.id); end if;
  return null;
end $$;
drop trigger if exists trg_money_order_paid on orders;
create trigger trg_money_order_paid after update of paid on orders for each row execute function trg_money_order_paid();

create or replace function trg_money_order_cancelled() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.cancelled_at is not null and old.cancelled_at is null then
    update money_entries set status = 'refunded' where order_id = new.id and status in ('held', 'frozen');
  end if;
  return null;
end $$;
drop trigger if exists trg_money_order_cancelled on orders;
create trigger trg_money_order_cancelled after update of cancelled_at on orders for each row execute function trg_money_order_cancelled();

create or replace function trg_money_release() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.fulfillment >= 4 and old.fulfillment < 4 then perform money_try_release(new.order_id); end if;
  return null;
end $$;
drop trigger if exists trg_money_release on order_lines;
create trigger trg_money_release after update of fulfillment on order_lines for each row execute function trg_money_release();

-- Forfaits payés : recette de la plateforme (aucun bénéficiaire).
create or replace function on_subscription_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'subscription' and new.subject like 'plan:%' then
    select * into pl from company_plans where code = substr(new.subject, 6);
    if found and new.amount >= pl.price_fcfa and exists (select 1 from company_profiles where owner_id = new.payer_id and status = 'approved') then
      perform company_activate_internal(new.payer_id, pl.code, null, 'Payé par Mobile Money (' || new.reference || ')', null);
      insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
      values ('subscription', new.reference, new.payer_id, null, new.amount, new.amount, 'plateforme', 'released', now());
    end if;
  end if;
  return null;
end $$;

-- Solde d'une personne : débloqué - versé - prévu - à recouvrer (paiements à la livraison).
create or replace function money_wallet(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'held', coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status in ('held', 'frozen')), 0)::int,
    'frozen', coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status = 'frozen'), 0)::int,
    'released', coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status = 'released'), 0)::int,
    'paid_out', coalesce((select sum(amount) from payout_batches where seller_id = p_user and status = 'verse'), 0)::int,
    'scheduled', coalesce((select sum(amount) from payout_batches where seller_id = p_user and status = 'prevu'), 0)::int,
    'owed', coalesce((select sum(institution_amount + platform_amount) from money_entries where beneficiary_id = p_user and status = 'cod_due'), 0)::int,
    'available', greatest(
      coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status = 'released'), 0)
      - coalesce((select sum(amount) from payout_batches where seller_id = p_user and status in ('verse', 'prevu')), 0)
      - coalesce((select sum(institution_amount + platform_amount) from money_entries where beneficiary_id = p_user and status = 'cod_due'), 0), 0)::int)
$$;
revoke all on function money_wallet(uuid) from public, anon, authenticated;

create or replace function my_money() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return money_wallet(auth.uid()) || jsonb_build_object('rule', money_split_label(),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'ref', e.ref, 'kind', e.kind, 'gross', e.gross, 'mine', e.beneficiary_amount, 'status', e.status, 'created_at', e.created_at, 'released_at', e.released_at) order by e.created_at desc)
      from (select * from money_entries where beneficiary_id = auth.uid() order by created_at desc limit 30) e), '[]'::jsonb));
end $$;

-- Versement : seules la finance et l'administration le créent, jamais au-delà du solde disponible du bénéficiaire.
create or replace function payout_create(p_seller uuid, p_amount int, p_method text default 'Mobile Money', p_on date default current_date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_avail integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  if not exists (select 1 from profiles where id = p_seller) then raise exception 'Bénéficiaire introuvable'; end if;
  v_avail := (money_wallet(p_seller)->>'available')::int;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_amount > v_avail then raise exception 'Montant supérieur au solde disponible (% FCFA) : l''argent n''est débloqué qu''après livraison', v_avail; end if;
  insert into payout_batches (number, seller_id, amount, method, scheduled_on, created_by)
  values ('RV-' || nextval('payout_number_seq'), p_seller, p_amount, coalesce(nullif(trim(p_method), ''), 'Mobile Money'), coalesce(p_on, current_date), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

-- Revenus du vendeur : parts nettes (après 70/20/10), en séquestre et disponibles.
create or replace function seller_revenue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare w jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  w := money_wallet(auth.uid());
  return jsonb_build_object(
    'total', (w->>'held')::int + (w->>'released')::int,
    'held', (w->>'held')::int,
    'paid_out', (w->>'paid_out')::int,
    'scheduled', (w->>'scheduled')::int,
    'available', (w->>'available')::int,
    'owed', (w->>'owed')::int,
    'rule', money_split_label(),
    'orders', (select count(distinct order_id)::int from money_entries where beneficiary_id = auth.uid() and kind = 'order' and status <> 'refunded'),
    'pending_count', (select count(distinct o.id)::int from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id where l.seller_id = auth.uid() and not o.paid and o.cancelled_at is null and o.reference is not null),
    'pending_amount', (select coalesce(sum(ol.unit_price * ol.qty), 0)::bigint from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id where l.seller_id = auth.uid() and not o.paid and o.cancelled_at is null and o.reference is not null),
    'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'amount', a) order by m), '[]'::jsonb) from (
                 select to_char(date_trunc('month', created_at), 'YYYY-MM') m, sum(beneficiary_amount)::bigint a from money_entries where beneficiary_id = auth.uid() and status in ('held', 'frozen', 'released') group by 1) x));
end $$;

-- Administration : vue d'ensemble, liste, blocage, déblocage forcé.
create or replace function money_admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Réservé à l''administration et à la finance'; end if;
  return jsonb_build_object('rule', money_split_label(),
    'held', coalesce((select sum(gross) from money_entries where status = 'held'), 0)::int,
    'frozen', coalesce((select sum(gross) from money_entries where status = 'frozen'), 0)::int,
    'released_beneficiaries', coalesce((select sum(beneficiary_amount) from money_entries where status = 'released'), 0)::int,
    'institution_fund', coalesce((select sum(institution_amount) from money_entries where status in ('released', 'cod_due')), 0)::int,
    'platform', coalesce((select sum(platform_amount) from money_entries where status in ('released', 'cod_due')), 0)::int,
    'cod_due', coalesce((select sum(institution_amount + platform_amount) from money_entries where status = 'cod_due'), 0)::int);
end $$;

create or replace function money_admin_list(p_status text default null, p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Réservé à l''administration et à la finance'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'ref', e.ref, 'kind', e.kind, 'gross', e.gross, 'beneficiary', coalesce(p.name, 'Plateforme'), 'beneficiary_amount', e.beneficiary_amount,
      'institution_amount', e.institution_amount, 'platform_amount', e.platform_amount, 'split', e.split, 'status', e.status, 'frozen_reason', e.frozen_reason, 'created_at', e.created_at) order by e.created_at desc)
    from (select * from money_entries where p_status is null or status = p_status order by created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) e left join profiles p on p.id = e.beneficiary_id), '[]'::jsonb);
end $$;

create or replace function money_freeze(p_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if char_length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'Indiquez le motif du blocage'; end if;
  update money_entries set status = 'frozen', frozen_reason = left(btrim(p_reason), 300) where id = p_id and status = 'held';
  if not found then raise exception 'Seul un montant en séquestre peut être bloqué'; end if;
end $$;

create or replace function money_unfreeze(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  update money_entries set status = 'held', frozen_reason = null where id = p_id and status = 'frozen';
  if not found then raise exception 'Montant introuvable ou non bloqué'; end if;
  perform money_try_release((select order_id from money_entries where id = p_id));
end $$;

-- Déblocage forcé par l'administrateur (prestation réalisée sans que la livraison soit enregistrée).
create or replace function money_release_now(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e money_entries%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into e from money_entries where id = p_id and status in ('held', 'frozen') and beneficiary_id is not null for update;
  if not found then raise exception 'Montant introuvable'; end if;
  update money_entries set status = 'released', released_at = now(), frozen_reason = null where id = p_id;
  insert into notifications (user_id, kind, title, body, data)
    values (e.beneficiary_id, 'money', 'Argent débloqué', e.beneficiary_amount || ' FCFA sont disponibles sur votre solde (commande ' || e.ref || ').', jsonb_build_object('entry', e.id));
end $$;

revoke all on function money_split_get(), money_split_set(integer, integer, integer, text), my_money(), money_admin_overview(), money_admin_list(text, integer), money_freeze(uuid, text), money_unfreeze(uuid), money_release_now(uuid) from public, anon;
grant execute on function money_split_get(), money_split_set(integer, integer, integer, text), my_money(), money_admin_overview(), money_admin_list(text, integer), money_freeze(uuid, text), money_unfreeze(uuid), money_release_now(uuid) to authenticated;
revoke all on function money_split_amounts(integer), money_split_label(), money_order_paid(uuid), money_try_release(uuid) from public, anon, authenticated;
