-- Finance (écrans 139 Tableau de bord financier, 140 Paiements déclarés, 141 Journal financier, 142 Rapports financiers, 143 Versements) :
-- chiffres calculés sur les commandes payées ; lots de reversement aux vendeurs saisis par la finance. Lecture et saisie réservées aux rôles
-- finance, administrateur, direction (lecture) et support (lecture). Aucun paiement réel n'est déclenché : un lot enregistre une décision.
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur la base locale (supabase/tests/finance_local.sql).
-- Retour arrière : drop function finance_overview(), finance_payments(text, int), finance_journal(int), finance_by_department(), finance_payouts(int), payout_create(uuid, int, text, date), payout_set_status(uuid, text);
--                   drop table payout_batches;

create table if not exists payout_batches (
  id uuid primary key default gen_random_uuid(),
  number text not null unique,
  seller_id uuid not null references profiles(id) on delete restrict,
  amount integer not null check (amount > 0),
  method text not null default 'Mobile Money' check (char_length(method) between 2 and 40),
  status text not null default 'prevu' check (status in ('prevu', 'verse', 'rejete')),
  scheduled_on date not null default current_date,
  paid_on date,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create sequence if not exists payout_number_seq start 1000;
create index if not exists payout_batches_seller on payout_batches (seller_id, created_at desc);

alter table payout_batches enable row level security;
revoke all on payout_batches from anon, authenticated;
grant select on payout_batches to authenticated;
drop policy if exists "lots : finance, administrateur, direction ou bénéficiaire" on payout_batches;
create policy "lots : finance, administrateur, direction ou bénéficiaire" on payout_batches for select
  using (seller_id = auth.uid() or coalesce(current_role_name()::text, '') in ('finance', 'admin', 'direction', 'support'));

create or replace function _finance_read() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin', 'direction', 'support') then raise exception 'Action non autorisée'; end if;
end $$;
revoke all on function _finance_read() from public, anon, authenticated;

-- Vue d'ensemble : encaissé, commandes payées, paiements à vérifier, montant dû aux vendeurs, versé sur 30 jours, et encaissements des 6 derniers mois.
create or replace function finance_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return (
    select jsonb_build_object(
      'collected', (select coalesce(sum(subtotal + fee), 0)::bigint from orders where paid and cancelled_at is null),
      'orders_paid', (select count(*)::int from orders where paid and cancelled_at is null),
      'to_verify', (select count(*)::int from orders where not paid and cancelled_at is null and reference is not null),
      'due', (select coalesce(sum(amount), 0)::bigint from payout_batches where status = 'prevu'),
      'paid_out_30d', (select coalesce(sum(amount), 0)::bigint from payout_batches where status = 'verse' and paid_on >= current_date - 30),
      'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'amount', a) order by m), '[]'::jsonb)
                 from (select to_char(date_trunc('month', created_at), 'YYYY-MM') m, sum(subtotal + fee)::bigint a from orders
                       where paid and cancelled_at is null and created_at >= date_trunc('month', now()) - interval '5 months' group by 1) x)
    )
  );
end $$;

-- Paiements déclarés : une commande avec référence de paiement est « à vérifier » tant qu'elle n'est pas marquée payée, « vérifiée » une fois payée, « rejetée » si annulée.
create or replace function finance_payments(p_state text default null, p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return coalesce((
    select jsonb_agg(jsonb_build_object('reference', t.reference, 'order', t.number, 'method', t.method, 'amount', t.amount, 'declared_at', t.created_at, 'state', t.state) order by t.created_at desc)
    from (
      select o.reference, o.number, o.method, (o.subtotal + o.fee) as amount, o.created_at,
             case when o.cancelled_at is not null then 'rejected' when o.paid then 'verified' else 'to_verify' end as state
      from orders o where o.reference is not null
      order by o.created_at desc limit least(greatest(p_limit, 1), 200)
    ) t
    where p_state is null or t.state = p_state
  ), '[]'::jsonb);
end $$;

-- Journal : encaissements (commandes payées), commissions (frais) et reversements versés, du plus récent au plus ancien.
create or replace function finance_journal(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return (
    with j as (
      select o.created_at::date as d, 'Encaissement ' || o.number as label, 0::bigint as debit, (o.subtotal + o.fee)::bigint as credit, true as reconciled, o.created_at as ts
      from orders o where o.paid and o.cancelled_at is null
      union all
      select o.created_at::date, 'Commission ' || o.number, 0, o.fee::bigint, true, o.created_at from orders o where o.paid and o.cancelled_at is null and o.fee > 0
      union all
      select coalesce(b.paid_on, b.scheduled_on), 'Reversement ' || b.number, b.amount::bigint, 0, b.status = 'verse', b.created_at from payout_batches b where b.status <> 'rejete'
    )
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(jsonb_build_object('date', d, 'label', label, 'debit', debit, 'credit', credit, 'reconciled', reconciled) order by ts desc)
                        from (select * from j order by ts desc limit least(greatest(p_limit, 1), 300)) x), '[]'::jsonb),
      'total_credit', (select coalesce(sum(credit), 0)::bigint from j),
      'total_debit', (select coalesce(sum(debit), 0)::bigint from j),
      'to_reconcile', (select count(*)::int from j where not reconciled)
    )
  );
end $$;

-- Encaissements et commissions par département du vendeur.
create or replace function finance_by_department() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return coalesce((
    select jsonb_agg(jsonb_build_object('department', dep, 'sales', sales, 'orders', n, 'sellers', s) order by sales desc)
    from (
      select coalesce(nullif(trim(p.department), ''), 'Sans département') dep, sum(ol.unit_price * ol.qty)::bigint sales, count(distinct o.id)::int n, count(distinct l.seller_id)::int s
      from order_lines ol join orders o on o.id = ol.order_id join listings l on l.id = ol.listing_id join profiles p on p.id = l.seller_id
      where o.paid and o.cancelled_at is null group by 1
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function finance_payouts(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return coalesce((
    select jsonb_agg(jsonb_build_object('number', b.number, 'seller', coalesce(p.name, 'Vendeur'), 'amount', b.amount, 'method', b.method, 'date', coalesce(b.paid_on, b.scheduled_on), 'status', b.status) order by b.created_at desc)
    from (select * from payout_batches order by created_at desc limit least(greatest(p_limit, 1), 300)) b left join profiles p on p.id = b.seller_id
  ), '[]'::jsonb);
end $$;

create or replace function payout_create(p_seller uuid, p_amount int, p_method text default 'Mobile Money', p_on date default current_date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  if not exists (select 1 from profiles where id = p_seller) then raise exception 'Bénéficiaire introuvable'; end if;
  insert into payout_batches (number, seller_id, amount, method, scheduled_on, created_by)
  values ('RV-' || nextval('payout_number_seq'), p_seller, p_amount, coalesce(nullif(trim(p_method), ''), 'Mobile Money'), coalesce(p_on, current_date), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create or replace function payout_set_status(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('prevu', 'verse', 'rejete') then raise exception 'Statut invalide'; end if;
  update payout_batches set status = p_status, paid_on = case when p_status = 'verse' then current_date else null end where id = p_id;
  if not found then raise exception 'Lot introuvable'; end if;
end $$;

revoke all on function finance_overview(), finance_payments(text, int), finance_journal(int), finance_by_department(), finance_payouts(int), payout_create(uuid, int, text, date), payout_set_status(uuid, text) from public, anon;
grant execute on function finance_overview(), finance_payments(text, int), finance_journal(int), finance_by_department(), finance_payouts(int), payout_create(uuid, int, text, date), payout_set_status(uuid, text) to authenticated;
