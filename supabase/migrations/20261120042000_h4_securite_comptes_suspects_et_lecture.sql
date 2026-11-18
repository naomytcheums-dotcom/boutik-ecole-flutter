-- Lot H4 : équipe Sécurité et modération (comptes suspects) et cloisonnement de la lecture directe des tables entre équipes.
--  1. account_flags : un agent de sécurité signale un compte suspect (fraude, abus) ; l'administrateur global reste seul à suspendre (admin_set_account) ;
--     RPC security_accounts_search, security_flag_account, security_flags_list, security_flag_decide (permission security.accounts, audit, notification des administrateurs) ;
--  2. politiques RESTRICTIVES de lecture : un agent finance ou support ne lit les tables d'une autre équipe (paiements, retraits, remboursements, réclamations,
--     tickets, signalements, journal d'audit, réglages…) que s'il en a la permission ; les lignes dont il est lui-même propriétaire restent lisibles ; les autres
--     rôles (administrateur, département, direction, étudiants…) ne sont pas concernés. Les politiques permissives existantes ne sont pas modifiées.
-- Retour arrière : drop policy "équipes : …" sur chaque table listée ; drop function security_accounts_search(text), security_flag_account(uuid, text), security_flags_list(text),
--   security_flag_decide(uuid, text, text), _team_row_ok(text[]); drop table account_flags.

-- ============================================================ 1. Comptes suspects
create table if not exists account_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  reason text not null check (char_length(reason) between 5 and 500),
  status text not null default 'open' check (status in ('open', 'cleared', 'escalated')),
  flagged_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  decided_by uuid references profiles (id) on delete set null,
  decided_at timestamptz,
  decision_note text check (decision_note is null or char_length(decision_note) <= 500)
);
create unique index if not exists account_flags_one_open on account_flags (user_id) where status = 'open';
create index if not exists account_flags_status on account_flags (status, created_at desc);
alter table account_flags enable row level security;
revoke all on account_flags from public, anon, authenticated;
grant select on account_flags to authenticated;
drop policy if exists "comptes suspects : sécurité et administrateur" on account_flags;
create policy "comptes suspects : sécurité et administrateur" on account_flags for select to authenticated using (has_admin_permission('security.accounts'));

create or replace function _security_accounts_guard() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('security.accounts') then raise exception 'Réservé à l''équipe Sécurité et modération'; end if;
end $$;
revoke all on function _security_accounts_guard() from public, anon, authenticated;

create or replace function security_accounts_search(p_query text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_q text := replace(replace(btrim(coalesce(p_query, '')), '%', ''), '_', '');
begin
  perform _security_accounts_guard();
  if char_length(v_q) < 3 then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'email', p.email, 'role', p.role::text, 'suspended', coalesce(p.suspended, false),
                                        'open_flag', exists (select 1 from account_flags f where f.user_id = p.id and f.status = 'open')) order by p.name)
    from (select * from profiles x where x.role::text not in ('admin', 'dept', 'direction', 'finance', 'support', 'visitor')
            and (x.name ilike '%' || v_q || '%' or x.email ilike '%' || v_q || '%') order by x.name limit 20) p), '[]'::jsonb);
end $$;

create or replace function security_flag_account(p_user uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_id uuid; v_reason text := btrim(coalesce(p_reason, '')); v_who text; a record;
begin
  perform _security_accounts_guard();
  if p_user is null or p_user = auth.uid() then raise exception 'Compte invalide'; end if;
  if char_length(v_reason) < 5 or char_length(v_reason) > 500 then raise exception 'Décrivez le motif en 5 à 500 caractères'; end if;
  select role::text, name into v_role, v_name from profiles where id = p_user;
  if v_role is null then raise exception 'Compte introuvable'; end if;
  if v_role in ('admin', 'dept', 'direction', 'finance', 'support') then raise exception 'Les comptes de l''équipe ne se signalent pas ici : prévenez l''administrateur global'; end if;
  if exists (select 1 from account_flags where user_id = p_user and status = 'open') then raise exception 'Ce compte est déjà signalé et en cours d''examen'; end if;
  insert into account_flags (user_id, reason, flagged_by) values (p_user, v_reason, auth.uid()) returning id into v_id;
  select name into v_who from profiles where id = auth.uid();
  insert into audit_log (actor, actor_id, action, target, category, level) values (coalesce(v_who, 'Sécurité'), auth.uid(), 'Compte signalé comme suspect', left(coalesce(v_name, p_user::text), 200), 'Sécurité', 'Sensible');
  for a in select id from profiles where role::text = 'admin' and not coalesce(suspended, false) limit 20 loop
    insert into notifications (user_id, kind, title, body, data)
    values (a.id, 'security', 'Compte suspect signalé', left(coalesce(v_name, 'Un compte') || ' : ' || v_reason, 300), jsonb_build_object('flag', v_id, 'user', p_user));
  end loop;
  return v_id;
end $$;

create or replace function security_flags_list(p_status text default 'open') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _security_accounts_guard();
  if p_status is not null and p_status not in ('open', 'cleared', 'escalated', '') then raise exception 'Statut inconnu'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', f.id, 'user_id', f.user_id, 'name', u.name, 'email', u.email, 'role', u.role::text, 'suspended', coalesce(u.suspended, false),
      'reason', f.reason, 'status', f.status, 'created_at', f.created_at, 'flagged_by', (select b.name from profiles b where b.id = f.flagged_by),
      'decided_at', f.decided_at, 'decision_note', f.decision_note) order by f.created_at desc)
    from (select * from account_flags where nullif(p_status, '') is null or status = p_status order by created_at desc limit 100) f
    join profiles u on u.id = f.user_id), '[]'::jsonb);
end $$;

create or replace function security_flag_decide(p_id uuid, p_decision text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare f account_flags%rowtype; v_note text := nullif(left(btrim(coalesce(p_note, '')), 500), ''); v_who text; v_name text; a record;
begin
  perform _security_accounts_guard();
  if p_decision not in ('clear', 'escalate') then raise exception 'Décision inconnue'; end if;
  select * into f from account_flags where id = p_id for update;
  if not found or f.status <> 'open' then raise exception 'Signalement introuvable ou déjà traité'; end if;
  if p_decision = 'clear' and v_note is null then raise exception 'Indiquez pourquoi le compte est mis hors de cause'; end if;
  update account_flags set status = case p_decision when 'clear' then 'cleared' else 'escalated' end, decided_by = auth.uid(), decided_at = now(), decision_note = v_note where id = f.id;
  select name into v_who from profiles where id = auth.uid();
  select name into v_name from profiles where id = f.user_id;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(v_who, 'Sécurité'), auth.uid(), case p_decision when 'clear' then 'Compte suspect mis hors de cause' else 'Compte suspect transmis à l''administrateur' end, left(coalesce(v_name, f.user_id::text), 200), 'Sécurité', 'Sensible');
  if p_decision = 'escalate' then
    for a in select id from profiles where role::text = 'admin' and not coalesce(suspended, false) limit 20 loop
      insert into notifications (user_id, kind, title, body, data)
      values (a.id, 'security', 'Suspension à décider', left(coalesce(v_name, 'Un compte') || ' : ' || f.reason || coalesce(' — ' || v_note, ''), 300), jsonb_build_object('flag', f.id, 'user', f.user_id));
    end loop;
  end if;
  return p_decision;
end $$;

revoke all on function security_accounts_search(text), security_flag_account(uuid, text), security_flags_list(text), security_flag_decide(uuid, text, text) from public, anon;
grant execute on function security_accounts_search(text), security_flag_account(uuid, text), security_flags_list(text), security_flag_decide(uuid, text, text) to authenticated;

-- ============================================================ 2. Politiques restrictives de lecture
-- Vrai pour tout rôle autre que finance / support (leurs règles propres s'appliquent) ; pour un agent finance / support : vrai s'il a l'une des permissions.
create or replace function _team_row_ok(p_perms text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name()::text, '') not in ('finance', 'support') or _admin_perm_check(auth.uid(), p_perms)
$$;
revoke all on function _team_row_ok(text[]) from public, anon;
grant execute on function _team_row_ok(text[]) to authenticated;

create or replace function _h4_team_policy(p_table text, p_perms text[], p_own text default null) returns void
language plpgsql set search_path = public as $$
declare v_perms text := 'array[' || (select string_agg('''' || x || '''', ', ') from unnest(p_perms) x) || ']';
begin
  if to_regclass('public.' || p_table) is null then return; end if;
  execute format('drop policy if exists %I on public.%I', 'équipes : ' || p_table, p_table);
  execute format('create policy %I on public.%I as restrictive for select to authenticated using ((select _team_row_ok(%s))%s)', 'équipes : ' || p_table, p_table, v_perms,
                 case when p_own is null then '' else ' or (' || p_own || ')' end);
end $$;

do $$
begin
  perform _h4_team_policy('audit_log', array['security.audit', 'tech.logs']);
  perform _h4_team_policy('payment_transactions', array['finance.read', 'finance.payments', 'support.claims', 'support.disputes'], 'payer_id = auth.uid()');
  perform _h4_team_policy('payment_messages', array['finance.read', 'finance.payments', 'support.claims', 'support.disputes'],
                          'exists (select 1 from payment_transactions t where t.id = transaction_id and t.payer_id = auth.uid())');
  perform _h4_team_policy('payout_batches', array['finance.read', 'finance.payouts'], 'seller_id = auth.uid()');
  perform _h4_team_policy('earnings', array['finance.read'], 'user_id = auth.uid()');
  perform _h4_team_policy('referral_payouts', array['finance.read', 'finance.payouts'], 'user_id = auth.uid()');
  perform _h4_team_policy('event_receipts', array['finance.read'], 'user_id = auth.uid()');
  perform _h4_team_policy('subscriptions', array['finance.read'], 'user_id = auth.uid()');
  perform _h4_team_policy('ad_campaigns', array['finance.read'], 'owner_id = auth.uid()');
  perform _h4_team_policy('order_refunds', array['finance.read', 'finance.refunds', 'support.refunds', 'support.claims'],
                          'requested_by = auth.uid() or exists (select 1 from orders o where o.id = order_id and o.buyer_id = auth.uid())');
  perform _h4_team_policy('orders', array['finance.read', 'finance.payments', 'finance.refunds', 'finance.payouts', 'support.orders', 'support.claims', 'support.disputes', 'support.refunds', 'support.tickets'],
                          'buyer_id = auth.uid()');
  perform _h4_team_policy('claims', array['support.claims', 'support.refunds'], 'claimant_id = auth.uid() or seller_id = auth.uid()');
  perform _h4_team_policy('support_tickets', array['support.tickets'], 'user_id = auth.uid()');
  perform _h4_team_policy('order_disputes', array['support.disputes', 'support.claims'], 'opened_by = auth.uid() or buyer_id = auth.uid()');
  perform _h4_team_policy('kiosk_incidents', array['support.orders', 'tech.maintenance']);
  perform _h4_team_policy('listing_reports', array['security.reports', 'security.moderation'], 'reporter_id = auth.uid()');
  perform _h4_team_policy('post_reports', array['security.reports', 'security.moderation'], 'reporter_id = auth.uid()');
  perform _h4_team_policy('message_reports', array['security.reports', 'security.moderation'], 'reporter_id = auth.uid()');
  perform _h4_team_policy('shop_reports', array['security.reports', 'security.moderation'], 'reporter_id = auth.uid()');
  perform _h4_team_policy('notification_templates', array['tech.config']);
  perform _h4_team_policy('notification_outbox', array['tech.logs', 'support.tickets'], 'user_id = auth.uid()');
  perform _h4_team_policy('user_documents', array['support.requests'], 'owner_id = auth.uid()');
  perform _h4_team_policy('account_deletion_requests', array['support.requests'], 'user_id = auth.uid()');
end $$;

drop function if exists _h4_team_policy(text, text[], text);
