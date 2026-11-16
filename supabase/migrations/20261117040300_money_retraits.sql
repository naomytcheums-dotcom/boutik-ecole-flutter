-- Lot MONEY (4/6) : retraits des ventes. S4-1 (demande de retrait du vendeur), S4-82 (numéro Mobile Money lié), S4-123 (notifications, machine d'états, verrou, audit, référence), S4-3 / S4-2.
-- Une demande du vendeur réserve son montant (statut « demande ») : il ne peut pas être demandé deux fois. La finance la traite : « prevu » (accepté, en cours), « verse » (référence de la
-- transaction Mobile Money obligatoire) ou « rejete » (motif obligatoire). Un lot versé ou rejeté ne change plus jamais d'état (plus de double versement possible).
-- Le numéro de destination est TOUJOURS l'un des moyens de paiement enregistrés du vendeur (payment_methods). Plafonds réglables : « payouts.min » (1 000) et « payouts.max » (500 000).
-- Retour arrière : drop function request_seller_payout(integer, text, text), payout_cancel_request(uuid), my_payouts(), payout_set_status(uuid, text, text, text) ; recréer payout_set_status(uuid, text) (20261105000500), payout_create et money_wallet (20261114002800),
--   finance_payouts et finance_overview (20261105000500) ; alter table payout_batches drop column source, provider, phone, reference, note, decided_by, decided_at ; remettre le contrôle de statut (prevu, verse, rejete).

alter table payout_batches drop constraint if exists payout_batches_status_check;
alter table payout_batches add constraint payout_batches_status_check check (status in ('demande', 'prevu', 'verse', 'rejete'));
alter table payout_batches add column if not exists source text not null default 'finance';
alter table payout_batches drop constraint if exists payout_batches_source_check;
alter table payout_batches add constraint payout_batches_source_check check (source in ('finance', 'seller'));
alter table payout_batches add column if not exists provider text;
alter table payout_batches add column if not exists phone text;
alter table payout_batches add column if not exists reference text;
alter table payout_batches add column if not exists note text;
alter table payout_batches add column if not exists decided_by uuid references profiles(id) on delete set null;
alter table payout_batches add column if not exists decided_at timestamptz;
create unique index if not exists payout_batches_one_request on payout_batches (seller_id) where status = 'demande';

-- Solde : débloqué - versé - prévu - demandé - à recouvrer (paiements à la livraison). « requested » = montant réservé par une demande en attente.
create or replace function money_wallet(p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'held', coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status in ('held', 'frozen')), 0)::int,
    'frozen', coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status = 'frozen'), 0)::int,
    'released', coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status = 'released'), 0)::int,
    'paid_out', coalesce((select sum(amount) from payout_batches where seller_id = p_user and status = 'verse'), 0)::int,
    'scheduled', coalesce((select sum(amount) from payout_batches where seller_id = p_user and status = 'prevu'), 0)::int,
    'requested', coalesce((select sum(amount) from payout_batches where seller_id = p_user and status = 'demande'), 0)::int,
    'owed', coalesce((select sum(institution_amount + platform_amount) from money_entries where beneficiary_id = p_user and status = 'cod_due'), 0)::int,
    'available', greatest(
      coalesce((select sum(beneficiary_amount) from money_entries where beneficiary_id = p_user and status = 'released'), 0)
      - coalesce((select sum(amount) from payout_batches where seller_id = p_user and status in ('verse', 'prevu', 'demande')), 0)
      - coalesce((select sum(institution_amount + platform_amount) from money_entries where beneficiary_id = p_user and status = 'cod_due'), 0), 0)::int)
$$;
revoke all on function money_wallet(uuid) from public, anon, authenticated;

create or replace function _payout_limit(p_key text, p_default integer) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::numeric::int from platform_settings where key = p_key and jsonb_typeof(value) = 'number'), p_default)
$$;
revoke all on function _payout_limit(text, integer) from public, anon, authenticated;

create or replace function _payout_provider_label(p_provider text) returns text
language sql immutable as $$ select case p_provider when 'orange_money' then 'Orange Money' when 'mtn_momo' then 'MTN MoMo' else 'Mobile Money' end $$;

-- ============================================================ demande du vendeur
create or replace function request_seller_payout(p_amount integer, p_phone text default null, p_provider text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_avail integer; v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g'); pm payment_methods%rowtype; v_min integer := _payout_limit('payouts.min', 1000); v_max integer := _payout_limit('payouts.max', 500000); v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  perform 1 from profiles where id = auth.uid() and not suspended for update;
  if not found then raise exception 'Compte inactif ou introuvable'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_amount < v_min then raise exception 'Retrait minimum : % FCFA', v_min; end if;
  if p_amount > v_max then raise exception 'Retrait maximum par demande : % FCFA', v_max; end if;
  if left(v_phone, 3) = '237' and char_length(v_phone) = 12 then v_phone := substr(v_phone, 4); end if;
  if v_phone = '' then
    select * into pm from payment_methods where owner_id = auth.uid() order by is_default desc, created_at limit 1;
    if not found then raise exception 'Enregistrez d''abord un numéro Orange Money ou MTN MoMo dans « Moyens de paiement » : c''est là que votre retrait sera versé'; end if;
  else
    select * into pm from payment_methods where owner_id = auth.uid() and phone = v_phone and (nullif(p_provider, '') is null or provider = p_provider) order by is_default desc limit 1;
    if not found then raise exception 'Ce numéro n''est pas enregistré dans vos moyens de paiement : ajoutez-le d''abord'; end if;
  end if;
  if exists (select 1 from payout_batches where seller_id = auth.uid() and status = 'demande') then raise exception 'Une demande de retrait est déjà en cours de traitement'; end if;
  v_avail := (money_wallet(auth.uid())->>'available')::int;
  if p_amount > v_avail then raise exception 'Montant supérieur à votre solde disponible (% FCFA) : l''argent n''est débloqué qu''après livraison confirmée', v_avail; end if;
  v_num := 'RV-' || nextval('payout_number_seq');
  insert into payout_batches (number, seller_id, amount, method, status, scheduled_on, created_by, source, provider, phone)
  values (v_num, auth.uid(), p_amount, _payout_provider_label(pm.provider), 'demande', current_date, auth.uid(), 'seller', pm.provider, pm.phone)
  returning id into v_id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Demande de retrait', v_num, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (auth.uid(), 'payout', 'Demande de retrait enregistrée', p_amount || ' FCFA seront versés sur ' || _payout_provider_label(pm.provider) || ' ' || pm.phone || ' après traitement par la finance.', jsonb_build_object('payout', v_id, 'number', v_num));
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'payout', 'Retrait à traiter', p_amount || ' FCFA demandés (' || v_num || ') par ' || display_name(auth.uid()) || '.', jsonb_build_object('payout', v_id, 'number', v_num)
    from profiles p where p.role::text in ('finance', 'admin') and not p.suspended;
  return v_id;
end $$;

create or replace function payout_cancel_request(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update payout_batches set status = 'rejete', note = 'Annulée par le vendeur', decided_by = auth.uid(), decided_at = now() where id = p_id and seller_id = auth.uid() and status = 'demande';
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  return 'cancelled';
end $$;

create or replace function my_payouts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return jsonb_build_object(
    'min', _payout_limit('payouts.min', 1000), 'max', _payout_limit('payouts.max', 500000),
    'methods', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'provider', m.provider, 'phone', m.phone, 'is_default', m.is_default) order by m.is_default desc, m.created_at) from payment_methods m where m.owner_id = auth.uid()), '[]'::jsonb),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id', b.id, 'number', b.number, 'amount', b.amount, 'status', b.status, 'method', b.method, 'phone', b.phone, 'reference', b.reference, 'note', b.note,
        'created_at', b.created_at, 'paid_on', b.paid_on, 'source', b.source) order by b.created_at desc)
      from (select * from payout_batches where seller_id = auth.uid() order by created_at desc limit 30) b), '[]'::jsonb));
end $$;

-- ============================================================ versements par la finance
create or replace function payout_create(p_seller uuid, p_amount int, p_method text default 'Mobile Money', p_on date default current_date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_avail integer; pm payment_methods%rowtype; v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  perform 1 from profiles where id = p_seller for update;
  if not found then raise exception 'Bénéficiaire introuvable'; end if;
  v_avail := (money_wallet(p_seller)->>'available')::int;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_amount > v_avail then raise exception 'Montant supérieur au solde disponible (% FCFA) : l''argent n''est débloqué qu''après livraison', v_avail; end if;
  select * into pm from payment_methods where owner_id = p_seller order by is_default desc, created_at limit 1;
  v_num := 'RV-' || nextval('payout_number_seq');
  insert into payout_batches (number, seller_id, amount, method, scheduled_on, created_by, provider, phone)
  values (v_num, p_seller, p_amount, coalesce(nullif(trim(p_method), ''), 'Mobile Money'), coalesce(p_on, current_date), auth.uid(), pm.provider, pm.phone)
  returning id into v_id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Versement créé', v_num, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (p_seller, 'payout', 'Versement prévu', p_amount || ' FCFA vous seront versés (' || v_num || ').', jsonb_build_object('payout', v_id, 'number', v_num));
  return v_id;
end $$;

drop function if exists payout_set_status(uuid, text);
create or replace function payout_set_status(p_id uuid, p_status text, p_reference text default null, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare b payout_batches%rowtype; v_ref text := nullif(left(btrim(coalesce(p_reference, '')), 80), ''); v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('prevu', 'verse', 'rejete') then raise exception 'Statut invalide'; end if;
  select * into b from payout_batches where id = p_id for update;
  if not found then raise exception 'Versement introuvable'; end if;
  if not ((b.status = 'demande' and p_status in ('prevu', 'verse', 'rejete')) or (b.status = 'prevu' and p_status in ('verse', 'rejete'))) then
    raise exception 'Transition impossible : un versement « % » ne peut pas passer à « % »', b.status, p_status;
  end if;
  if p_status = 'verse' and v_ref is null then raise exception 'Indiquez la référence de la transaction Mobile Money'; end if;
  if p_status = 'rejete' and v_note is null then raise exception 'Indiquez le motif du rejet'; end if;
  update payout_batches set status = p_status, paid_on = case when p_status = 'verse' then current_date else null end, reference = coalesce(v_ref, reference), note = coalesce(v_note, note),
    decided_by = auth.uid(), decided_at = now() where id = b.id;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case p_status when 'verse' then 'Versement effectué' when 'rejete' then 'Versement rejeté' else 'Versement accepté' end, b.number, 'Finance', 'Sensible');
  insert into notifications (user_id, kind, title, body, data)
    values (b.seller_id, 'payout',
            case p_status when 'verse' then 'Retrait versé' when 'rejete' then 'Retrait rejeté' else 'Retrait accepté' end,
            case p_status when 'verse' then b.amount || ' FCFA versés' || case when b.phone is not null then ' sur ' || _payout_provider_label(b.provider) || ' ' || b.phone else '' end || ' (réf. ' || v_ref || ').'
                          when 'rejete' then 'Votre retrait de ' || b.amount || ' FCFA est rejeté : ' || v_note || ' Le montant est de nouveau disponible.'
                          else 'Votre retrait de ' || b.amount || ' FCFA est accepté et sera versé sous peu.' end,
            jsonb_build_object('payout', b.id, 'number', b.number));
end $$;

-- File de traitement de la finance : demandes d'abord, puis historique.
create or replace function finance_payouts(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', b.id, 'number', b.number, 'seller', coalesce(p.name, 'Vendeur'), 'amount', b.amount, 'method', b.method, 'date', coalesce(b.paid_on, b.scheduled_on), 'status', b.status,
        'source', b.source, 'phone', b.phone, 'provider', b.provider, 'reference', b.reference, 'note', b.note, 'requested_at', b.created_at,
        'available', (money_wallet(b.seller_id)->>'available')::int)
      order by (b.status = 'demande') desc, b.created_at desc)
    from (select * from payout_batches order by (status = 'demande') desc, created_at desc limit least(greatest(p_limit, 1), 300)) b left join profiles p on p.id = b.seller_id
  ), '[]'::jsonb);
end $$;

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
      'payout_requests', (select count(*)::int from payout_batches where status = 'demande'),
      'payout_requests_amount', (select coalesce(sum(amount), 0)::bigint from payout_batches where status = 'demande'),
      'refunds_to_pay', (select count(*)::int from order_refunds where status = 'approved'),
      'paid_out_30d', (select coalesce(sum(amount), 0)::bigint from payout_batches where status = 'verse' and paid_on >= current_date - 30),
      'months', (select coalesce(jsonb_agg(jsonb_build_object('month', m, 'amount', a) order by m), '[]'::jsonb)
                 from (select to_char(date_trunc('month', created_at), 'YYYY-MM') m, sum(subtotal + fee)::bigint a from orders
                       where paid and cancelled_at is null and created_at >= date_trunc('month', now()) - interval '5 months' group by 1) x)
    )
  );
end $$;

revoke all on function request_seller_payout(integer, text, text), payout_cancel_request(uuid), my_payouts(), payout_create(uuid, int, text, date), payout_set_status(uuid, text, text, text), finance_payouts(int), finance_overview() from public, anon;
grant execute on function request_seller_payout(integer, text, text), payout_cancel_request(uuid), my_payouts(), payout_create(uuid, int, text, date), payout_set_status(uuid, text, text, text), finance_payouts(int), finance_overview() to authenticated;
