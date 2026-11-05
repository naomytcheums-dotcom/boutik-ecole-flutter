-- Paiement par messagerie (interface type WhatsApp / Dikalo) : transactions, fil de messages généré par le serveur, vérification par la finance.
-- Aucun prestataire n'est appelé : le champ « provider » prépare le raccordement (dikalo, tara) ; tant qu'aucune API n'est branchée, le paiement est
-- DÉCLARÉ par le payeur puis VÉRIFIÉ par la finance, comme les paiements Mobile Money existants. Aucune clé n'est stockée dans la base.
-- Retour arrière : drop function payment_start(text, text, int, text), payment_declare(uuid, text), payment_set_status(uuid, text, text), payment_thread(uuid), my_payments();
--   drop table payment_messages, payment_transactions; drop sequence payment_ref_seq;

create sequence if not exists payment_ref_seq start 10000;
create table if not exists payment_transactions (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  payer_id uuid not null references profiles(id) on delete restrict,
  provider text not null default 'manual' check (provider in ('manual', 'dikalo', 'tara')),
  kind text not null check (kind in ('order', 'subscription', 'campaign', 'event', 'other')),
  subject text not null default '' check (char_length(subject) <= 120),
  amount integer not null check (amount > 0 and amount <= 100000000),
  currency text not null default 'XAF',
  status text not null default 'created' check (status in ('created', 'pending', 'confirmed', 'failed', 'cancelled')),
  provider_ref text check (provider_ref is null or char_length(provider_ref) <= 80),
  note text check (note is null or char_length(note) <= 300),
  created_at timestamptz not null default now(),
  declared_at timestamptz,
  decided_at timestamptz,
  decided_by uuid references profiles(id) on delete set null
);
create index if not exists payment_transactions_payer on payment_transactions (payer_id, created_at desc);
create table if not exists payment_messages (
  id bigint generated always as identity primary key,
  transaction_id uuid not null references payment_transactions(id) on delete cascade,
  sender text not null check (sender in ('system', 'payer', 'finance')),
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists payment_messages_tx on payment_messages (transaction_id, created_at);

alter table payment_transactions enable row level security;
alter table payment_messages enable row level security;
revoke all on payment_transactions, payment_messages from anon, authenticated;
grant select on payment_transactions, payment_messages to authenticated;
drop policy if exists "paiements : payeur ou finance" on payment_transactions;
create policy "paiements : payeur ou finance" on payment_transactions for select
  using (payer_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance', 'direction', 'support'));
drop policy if exists "messages de paiement : payeur ou finance" on payment_messages;
create policy "messages de paiement : payeur ou finance" on payment_messages for select
  using (exists (select 1 from payment_transactions t where t.id = transaction_id
                 and (t.payer_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance', 'direction', 'support'))));

create or replace function payment_start(p_kind text, p_subject text, p_amount int, p_provider text default 'manual') returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; ref text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('order', 'subscription', 'campaign', 'event', 'other') then raise exception 'Type invalide'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if p_provider not in ('manual', 'dikalo', 'tara') then raise exception 'Prestataire invalide'; end if;
  if p_provider <> 'manual' and coalesce((select value from platform_settings where key = 'payments.' || p_provider || '_enabled'), 'false'::jsonb) <> 'true'::jsonb then
    raise exception 'Ce prestataire n''est pas encore activé';
  end if;
  ref := 'PAY-' || nextval('payment_ref_seq');
  insert into payment_transactions (reference, payer_id, provider, kind, subject, amount) values (ref, auth.uid(), p_provider, p_kind, coalesce(left(trim(p_subject), 120), ''), p_amount) returning id into v;
  insert into payment_messages (transaction_id, sender, body) values
    (v, 'system', 'Demande de paiement ' || ref || ' : ' || p_amount || ' FCFA' || case when coalesce(trim(p_subject), '') = '' then '' else ' · ' || left(trim(p_subject), 120) end),
    (v, 'system', 'Effectuez le paiement Mobile Money puis touchez « J''ai payé » en indiquant la référence de la transaction reçue par SMS.');
  return v;
end $$;

create or replace function payment_declare(p_id uuid, p_provider_ref text) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from payment_transactions where id = p_id and payer_id = auth.uid();
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status not in ('created', 'failed') then raise exception 'Ce paiement n''est plus modifiable'; end if;
  if p_provider_ref is null or char_length(trim(p_provider_ref)) < 4 then raise exception 'Référence de transaction invalide'; end if;
  update payment_transactions set status = 'pending', provider_ref = left(trim(p_provider_ref), 80), declared_at = now() where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'payer', 'J''ai payé. Référence : ' || left(trim(p_provider_ref), 80));
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'system', 'Paiement déclaré. La finance le vérifie ; vous serez notifié.');
end $$;

create or replace function payment_set_status(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'finance') then raise exception 'Action non autorisée'; end if;
  if p_status not in ('confirmed', 'failed', 'cancelled') then raise exception 'Statut invalide'; end if;
  select * into t from payment_transactions where id = p_id;
  if not found then raise exception 'Paiement introuvable'; end if;
  if t.status = 'confirmed' then raise exception 'Paiement déjà confirmé'; end if;
  update payment_transactions set status = p_status, decided_at = now(), decided_by = auth.uid(), note = left(p_note, 300) where id = p_id;
  insert into payment_messages (transaction_id, sender, body) values (p_id, 'finance',
    case p_status when 'confirmed' then 'Paiement confirmé. Merci !' when 'failed' then 'Paiement non retrouvé' || coalesce(' : ' || left(p_note, 200), '') || '. Vous pouvez le redéclarer.' else 'Paiement annulé.' end);
  insert into notifications (user_id, kind, title, body, data) values (t.payer_id, 'payment', 'Paiement ' || t.reference,
    case p_status when 'confirmed' then 'Confirmé' when 'failed' then 'Non retrouvé' else 'Annulé' end, jsonb_build_object('payment_id', p_id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Paiement ' || p_status, t.reference, 'Finance', 'Info');
end $$;

create or replace function payment_thread(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from payment_transactions where id = p_id and (payer_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance', 'direction', 'support'));
  if not found then raise exception 'Paiement introuvable'; end if;
  return jsonb_build_object(
    'id', t.id, 'reference', t.reference, 'amount', t.amount, 'status', t.status, 'provider', t.provider, 'subject', t.subject, 'provider_ref', t.provider_ref,
    'messages', coalesce((select jsonb_agg(jsonb_build_object('sender', m.sender, 'body', m.body, 'created_at', m.created_at) order by m.created_at, m.id) from payment_messages m where m.transaction_id = t.id), '[]'::jsonb));
end $$;

create or replace function my_payments() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'reference', reference, 'amount', amount, 'status', status, 'subject', subject, 'created_at', created_at) order by created_at desc)
                   from (select * from payment_transactions where payer_id = auth.uid() order by created_at desc limit 50) x), '[]'::jsonb);
end $$;

revoke all on function payment_start(text, text, int, text), payment_declare(uuid, text), payment_set_status(uuid, text, text), payment_thread(uuid), my_payments() from public, anon;
grant execute on function payment_start(text, text, int, text), payment_declare(uuid, text), payment_set_status(uuid, text, text), payment_thread(uuid), my_payments() to authenticated;
