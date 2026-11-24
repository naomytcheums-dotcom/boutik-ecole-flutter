-- Lot H10 (FIN) : état RÉEL de rapprochement du journal financier (écrans 134 et 141).
-- Avant : finance_journal (20261105000500, 20261117040400) marquait toujours « rapproché » les encaissements. Désormais une ligne n'est rapprochée que si une PREUVE existe :
--   1. confirmation serveur du prestataire : événement signé de payment_events (outcome = 'confirmed' : signature vérifiée, relecture chez le prestataire, montant contrôlé)
--      dont la référence est celle de la commande                                             -> source « webhook_prestataire » ;
--   2. confirmation de la finance d'un paiement déclaré (payment_transactions confirmé, référence de transaction du payeur, décideur et date journalisés)
--      -> source « confirmation_finance » ;
--   3. versement marqué « versé » par la finance AVEC la référence de l'opérateur (payout_batches.reference, décideur, date) -> source « versement_finance » ;
--   4. action explicite finance_reconcile_record (relevé du prestataire, reçu de l'opérateur, remise en caisse) : permission finance.payments (encaissements)
--      ou finance.payouts (versements), double authentification (aal2), refus de la référence déjà utilisée ailleurs, rejeu sans doublon, journal d'audit.
-- Sinon la ligne est « à rapprocher ». Compteurs calculés côté serveur sur toutes les lignes (jamais 0 sur erreur : l'erreur est remontée à l'écran).
-- AUCUN montant ni aucune règle n'est modifié (70/20/10, commissions, séquestre, seuils, durées, remboursements).
-- Retour arrière : drop function finance_reconcile_record(text, text, text, text, date, text); remettre finance_journal et finance_payments depuis
--   20261117040400 et 20261105000500 ; drop view finance_entry_proofs ; drop table finance_reconciliation_proofs.

create table if not exists finance_reconciliation_proofs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('order', 'payout')),
  order_id uuid references orders(id) on delete restrict,
  payout_id uuid references payout_batches(id) on delete restrict,
  provider_reference text not null check (char_length(provider_reference) between 4 and 80),
  source text not null check (source in ('releve_prestataire', 'recu_operateur', 'remise_caisse')),
  proof_date date not null,
  note text check (note is null or char_length(note) <= 300),
  recorded_by uuid references profiles(id) on delete set null,
  recorded_at timestamptz not null default now(),
  check ((kind = 'order' and order_id is not null and payout_id is null) or (kind = 'payout' and payout_id is not null and order_id is null))
);
create unique index if not exists finance_reconciliation_proofs_order on finance_reconciliation_proofs (order_id) where order_id is not null;
create unique index if not exists finance_reconciliation_proofs_payout on finance_reconciliation_proofs (payout_id) where payout_id is not null;
create unique index if not exists finance_reconciliation_proofs_ref on finance_reconciliation_proofs (kind, lower(provider_reference));
alter table finance_reconciliation_proofs enable row level security;
revoke all on finance_reconciliation_proofs from anon, authenticated;

-- Preuves de toute origine, une par écriture (la plus forte : prestataire, puis relevé saisi, puis confirmation de la finance).
create or replace view finance_entry_proofs as
select distinct on (kind, ref_id) kind, ref_id, provider_reference, source, proof_at, author_id
from (
  select 'order'::text as kind, o.id as ref_id, e.reference as provider_reference, 'webhook_prestataire'::text as source, e.received_at as proof_at, null::uuid as author_id, 1 as prio
    from payment_events e join orders o on o.reference = e.reference
   where e.outcome = 'confirmed' and coalesce(e.reference, '') <> ''
  union all
  select 'order', pr.order_id, pr.provider_reference, pr.source, pr.proof_date::timestamptz, pr.recorded_by, 2
    from finance_reconciliation_proofs pr where pr.order_id is not null
  union all
  select 'order', o.id, p.provider_ref, 'confirmation_finance', p.decided_at, p.decided_by, 3
    from payment_transactions p join orders o on o.number = substring(p.subject from '#BE-[0-9]{4}-[0-9]+') and o.buyer_id = p.payer_id
   where p.status = 'confirmed' and p.kind = 'order' and coalesce(p.provider_ref, '') <> ''
  union all
  select 'payout', pr.payout_id, pr.provider_reference, pr.source, pr.proof_date::timestamptz, pr.recorded_by, 2
    from finance_reconciliation_proofs pr where pr.payout_id is not null
  union all
  select 'payout', b.id, b.reference, 'versement_finance', b.decided_at, b.decided_by, 3
    from payout_batches b where b.status = 'verse' and coalesce(b.reference, '') <> '' and b.decided_by is not null
) x
order by kind, ref_id, prio;
revoke all on finance_entry_proofs from public, anon, authenticated;

-- Journal : mêmes lignes, mêmes montants ; « reconciled » ne vaut vrai que si une preuve existe. Compteurs sur toutes les lignes.
create or replace function finance_journal(p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return (
    with j as (
      select o.created_at::date as d, 'Encaissement ' || o.number as label, 0::bigint as debit, (o.subtotal + o.fee)::bigint as credit, (p.ref_id is not null) as reconciled, o.created_at as ts,
             'order'::text as kind, o.number as ref, p.source as psrc, p.provider_reference as pref, p.proof_at as pat, p.author_id as pauth
      from orders o left join finance_entry_proofs p on p.kind = 'order' and p.ref_id = o.id
      where o.paid and o.cancelled_at is null
      union all
      select o.created_at::date, 'Dont frais de livraison ' || o.number, 0, o.fee::bigint, (p.ref_id is not null), o.created_at, 'order', o.number, p.source, p.provider_reference, p.proof_at, p.author_id
      from orders o left join finance_entry_proofs p on p.kind = 'order' and p.ref_id = o.id
      where o.paid and o.cancelled_at is null and o.fee > 0
      union all
      select coalesce(b.paid_on, b.scheduled_on), 'Reversement ' || b.number, b.amount::bigint, 0, (p.ref_id is not null), b.created_at, 'payout', b.number, p.source, p.provider_reference, p.proof_at, p.author_id
      from payout_batches b left join finance_entry_proofs p on p.kind = 'payout' and p.ref_id = b.id
      where b.status in ('prevu', 'verse')
    )
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(jsonb_build_object('date', d, 'label', label, 'debit', debit, 'credit', credit, 'reconciled', reconciled, 'kind', kind, 'ref', ref,
                          'proof', case when pref is null then null else jsonb_build_object('source', psrc, 'reference', pref, 'date', pat::date,
                                    'author', case when pauth is null then null else (select pr.name from profiles pr where pr.id = pauth) end) end) order by ts desc)
                        from (select * from j order by ts desc limit least(greatest(p_limit, 1), 300)) x), '[]'::jsonb),
      'total_credit', (select coalesce(sum(credit), 0)::bigint from j where label like 'Encaissement %'),
      'total_debit', (select coalesce(sum(debit), 0)::bigint from j),
      'to_reconcile', (select count(*)::int from j where not reconciled),
      'reconciled', (select count(*)::int from j where reconciled),
      'total_rows', (select count(*)::int from j)
    )
  );
end $$;

-- Paiements déclarés (écran 134) : même liste, avec l'état de rapprochement réel de chaque commande vérifiée.
create or replace function finance_payments(p_state text default null, p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _finance_read();
  return coalesce((
    select jsonb_agg(jsonb_build_object('reference', t.reference, 'order', t.number, 'method', t.method, 'amount', t.amount, 'declared_at', t.created_at, 'state', t.state,
                                        'reconciled', t.proof_source is not null, 'proof_source', t.proof_source, 'proof_reference', t.proof_reference) order by t.created_at desc)
    from (
      select o.reference, o.number, o.method, (o.subtotal + o.fee) as amount, o.created_at,
             case when o.cancelled_at is not null then 'rejected' when o.paid then 'verified' else 'to_verify' end as state,
             p.source as proof_source, p.provider_reference as proof_reference
      from orders o left join finance_entry_proofs p on p.kind = 'order' and p.ref_id = o.id
      where o.reference is not null
      order by o.created_at desc limit least(greatest(p_limit, 1), 200)
    ) t
    where p_state is null or t.state = p_state
  ), '[]'::jsonb);
end $$;

-- Action explicite de la finance : enregistre la preuve d'un encaissement (numéro de commande) ou d'un versement (numéro de lot).
create or replace function finance_reconcile_record(p_kind text, p_ref text, p_provider_ref text, p_source text default 'releve_prestataire', p_date date default current_date, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_ref text := nullif(left(btrim(coalesce(p_provider_ref, '')), 80), '');
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
  v_id uuid; v_target text := btrim(coalesce(p_ref, '')); v_have record; v_new uuid; v_who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('order', 'payout') then raise exception 'Type d''écriture invalide'; end if;
  if not _staff_perm(array[case when p_kind = 'order' then 'finance.payments' else 'finance.payouts' end]) then raise exception 'Action non autorisée'; end if;
  perform _require_staff_aal2();
  if v_ref is null or char_length(v_ref) < 4 then raise exception 'Référence du prestataire invalide (4 caractères au moins)'; end if;
  if p_source not in ('releve_prestataire', 'recu_operateur', 'remise_caisse') then raise exception 'Source de preuve invalide'; end if;
  if p_date is null or p_date > current_date then raise exception 'Date de preuve invalide'; end if;
  if p_kind = 'order' then
    select id into v_id from orders where number = v_target and paid and cancelled_at is null;
    if v_id is null then raise exception 'Commande introuvable ou non encaissée'; end if;
  else
    select id into v_id from payout_batches where number = v_target and status = 'verse';
    if v_id is null then raise exception 'Versement introuvable ou non versé'; end if;
  end if;
  select provider_reference, source into v_have from finance_entry_proofs where kind = p_kind and ref_id = v_id;
  if found then
    if lower(v_have.provider_reference) = lower(v_ref) then
      return jsonb_build_object('state', 'already', 'reference', v_have.provider_reference, 'source', v_have.source);
    end if;
    raise exception 'Cette écriture est déjà rapprochée (référence %)', v_have.provider_reference;
  end if;
  if exists (select 1 from finance_entry_proofs where kind = p_kind and lower(provider_reference) = lower(v_ref) and ref_id <> v_id) then
    raise exception 'Cette référence du prestataire est déjà utilisée pour une autre écriture';
  end if;
  insert into finance_reconciliation_proofs (kind, order_id, payout_id, provider_reference, source, proof_date, note, recorded_by)
  values (p_kind, case when p_kind = 'order' then v_id end, case when p_kind = 'payout' then v_id end, v_ref, p_source, p_date, v_note, auth.uid())
  on conflict do nothing returning id into v_new;
  if v_new is null then raise exception 'Cette écriture vient d''être rapprochée : actualisez la liste'; end if;
  select name into v_who from profiles where id = auth.uid();
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(v_who, 'Finance'), auth.uid(), 'Rapprochement enregistré (' || p_source || ')', left(v_target || ' · ' || v_ref, 200), 'Finance', 'Sensible');
  return jsonb_build_object('state', 'recorded', 'reference', v_ref, 'source', p_source);
end $$;

revoke all on function finance_journal(int), finance_payments(text, int), finance_reconcile_record(text, text, text, text, date, text) from public, anon;
grant execute on function finance_journal(int), finance_payments(text, int), finance_reconcile_record(text, text, text, text, date, text) to authenticated;

-- 2FA serveur : la nouvelle écriture de rapprochement est une opération sensible (liste complétée, rien n'est retiré ; même procédé que 20261121010000).
do $$
declare
  r record; v_def text; v_new text; v_list text; v_name text; v_add text[] := '{}';
  c_all constant text[] := array['finance_reconcile_record'];
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'enforce_mfa_on_sensitive' loop
    v_def := pg_get_functiondef(r.oid);
    v_list := substring(v_def from '\^/rpc/\(request_account_deletion\|([^'')]*)\)\$''');
    if v_list is null then raise exception 'enforce_mfa_on_sensitive : liste des opérations sensibles introuvable'; end if;
    v_add := '{}';
    foreach v_name in array c_all loop
      if not (v_name = any(string_to_array(v_list, '|'))) then v_add := v_add || v_name; end if;
    end loop;
    if cardinality(v_add) = 0 then continue; end if;
    v_new := replace(v_def, '^/rpc/(request_account_deletion|' || v_list || ')$''', '^/rpc/(request_account_deletion|' || v_list || '|' || array_to_string(v_add, '|') || ')$''');
    if v_new = v_def then raise exception 'enforce_mfa_on_sensitive : remplacement sans effet'; end if;
    execute v_new;
  end loop;
end $$;
