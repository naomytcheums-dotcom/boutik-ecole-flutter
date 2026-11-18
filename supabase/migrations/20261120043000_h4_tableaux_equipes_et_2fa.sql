-- Lot H4 : tableaux de bord des équipes internes (Finance, Support, Sécurité et modération, Technique) et garde 2FA des nouvelles opérations sensibles.
--  1. admin_team_dashboard(p_team) : indicateurs RÉELS de l'équipe (aucun chiffre inventé). Chaque indicateur n'est renvoyé que si l'appelant détient la permission
--     correspondante ; l'administrateur global voit tout ; un agent d'une autre équipe est refusé.
--  2. enforce_mfa_on_sensitive : la liste des opérations qui exigent une session aal2 (compte avec 2FA) est étendue SANS rien retirer :
--     attribution / retrait de permissions, gel du séquestre, règle de répartition, décisions de remboursement, réglages, clés d'API, décision sur un compte suspect.
-- Retour arrière : drop function admin_team_dashboard(text) ; remettre la définition de enforce_mfa_on_sensitive de 20261117000100.

create or replace function _admin_team_perms(p_team text) returns text[]
language sql stable set search_path = public as $$
  select coalesce(array_agg(code), array[]::text[]) from admin_permissions where team_code = p_team
$$;
revoke all on function _admin_team_perms(text) from public, anon, authenticated;

create or replace function admin_team_dashboard(p_team text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v jsonb := '[]'::jsonb;
  v_team jsonb;
  n bigint;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select to_jsonb(t) into v_team from (select code, name, description from admin_teams where code = p_team) t;
  if v_team is null then raise exception 'Équipe inconnue'; end if;
  if not has_any_admin_permission(_admin_team_perms(p_team)) then raise exception 'Réservé aux agents de cette équipe'; end if;

  if p_team = 'finance' then
    if has_admin_permission('finance.payments') then
      select count(*) into n from payment_transactions where status = 'pending';
      v := v || jsonb_build_object('key', 'payments_pending', 'label', 'Paiements à vérifier', 'value', n, 'permission', 'finance.payments');
    end if;
    if has_admin_permission('finance.payouts') then
      select count(*) into n from payout_batches where status = 'demande';
      v := v || jsonb_build_object('key', 'payouts_requested', 'label', 'Retraits demandés', 'value', n, 'permission', 'finance.payouts');
      select count(*) into n from payout_batches where status = 'prevu';
      v := v || jsonb_build_object('key', 'payouts_planned', 'label', 'Versements acceptés à effectuer', 'value', n, 'permission', 'finance.payouts');
      select count(*) into n from referral_payouts where status = 'requested';
      v := v || jsonb_build_object('key', 'referral_requested', 'label', 'Retraits de parrainage', 'value', n, 'permission', 'finance.payouts');
    end if;
    if has_any_admin_permission(array['finance.refunds', 'support.refunds']) then
      select count(*) into n from order_refunds where status = 'requested';
      v := v || jsonb_build_object('key', 'refunds_requested', 'label', 'Remboursements à décider', 'value', n, 'permission', 'finance.refunds');
    end if;
    if has_admin_permission('finance.refunds') then
      select count(*) into n from order_refunds where status = 'approved';
      v := v || jsonb_build_object('key', 'refunds_to_pay', 'label', 'Remboursements à verser', 'value', n, 'permission', 'finance.refunds');
    end if;
    if has_admin_permission('finance.read') then
      select coalesce(sum(gross), 0) into n from money_entries where status = 'held';
      v := v || jsonb_build_object('key', 'escrow_held', 'label', 'Montants en séquestre (FCFA)', 'value', n, 'permission', 'finance.read', 'unit', 'FCFA');
      select count(*) into n from money_entries where status = 'frozen';
      v := v || jsonb_build_object('key', 'escrow_frozen', 'label', 'Montants bloqués', 'value', n, 'permission', 'finance.read');
      select coalesce(sum(amount), 0) into n from payment_transactions where status = 'confirmed' and decided_at > now() - interval '30 days';
      v := v || jsonb_build_object('key', 'confirmed_30d', 'label', 'Paiements confirmés sur 30 jours (FCFA)', 'value', n, 'permission', 'finance.read', 'unit', 'FCFA');
    end if;
  elsif p_team = 'support' then
    if has_admin_permission('support.tickets') then
      select count(*) into n from support_tickets where status = 'open';
      v := v || jsonb_build_object('key', 'tickets_open', 'label', 'Demandes d''aide ouvertes', 'value', n, 'permission', 'support.tickets');
    end if;
    if has_admin_permission('support.claims') then
      select count(*) into n from claims where status <> 'closed';
      v := v || jsonb_build_object('key', 'claims_open', 'label', 'Réclamations en cours', 'value', n, 'permission', 'support.claims');
    end if;
    if has_admin_permission('support.disputes') then
      select count(*) into n from order_disputes where status = 'open';
      v := v || jsonb_build_object('key', 'disputes_open', 'label', 'Litiges ouverts', 'value', n, 'permission', 'support.disputes');
    end if;
    if has_admin_permission('support.orders') then
      select count(*) into n from kiosk_incidents where resolved_at is null;
      v := v || jsonb_build_object('key', 'kiosk_incidents_open', 'label', 'Incidents de bornes non résolus', 'value', n, 'permission', 'support.orders');
    end if;
    if has_admin_permission('support.requests') then
      select count(*) into n from user_documents where status = 'pending';
      v := v || jsonb_build_object('key', 'documents_pending', 'label', 'Pièces justificatives à examiner', 'value', n, 'permission', 'support.requests');
      select count(*) into n from account_deletion_requests where status = 'pending';
      v := v || jsonb_build_object('key', 'deletions_pending', 'label', 'Suppressions de compte programmées', 'value', n, 'permission', 'support.requests');
    end if;
  elsif p_team = 'security' then
    if has_admin_permission('security.moderation') then
      select count(*) into n from posts where status = 'pending';
      v := v || jsonb_build_object('key', 'posts_pending', 'label', 'Publications à valider', 'value', n, 'permission', 'security.moderation');
    end if;
    if has_admin_permission('security.reports') then
      select (select count(*) from post_reports where status = 'open') + (select count(*) from listing_reports where status = 'open')
           + (select count(*) from message_reports where status = 'open') + (select count(*) from shop_reports where status = 'open')
           + (select count(*) from comment_reports where status = 'open') into n;
      v := v || jsonb_build_object('key', 'reports_open', 'label', 'Signalements ouverts', 'value', n, 'permission', 'security.reports');
    end if;
    if has_admin_permission('security.accounts') then
      select count(*) into n from account_flags where status = 'open';
      v := v || jsonb_build_object('key', 'flags_open', 'label', 'Comptes suspects à examiner', 'value', n, 'permission', 'security.accounts');
      select count(*) into n from profiles where coalesce(suspended, false);
      v := v || jsonb_build_object('key', 'accounts_suspended', 'label', 'Comptes suspendus', 'value', n, 'permission', 'security.accounts');
    end if;
    if has_admin_permission('security.audit') then
      select count(*) into n from audit_log where level in ('Sensible', 'Critique') and created_at > now() - interval '24 hours';
      v := v || jsonb_build_object('key', 'audit_sensitive_24h', 'label', 'Actions sensibles des dernières 24 h', 'value', n, 'permission', 'security.audit');
    end if;
  elsif p_team = 'tech' then
    if has_admin_permission('tech.maintenance') then
      select count(*) into n from kiosk_incidents where resolved_at is null;
      v := v || jsonb_build_object('key', 'kiosk_incidents_open', 'label', 'Incidents de bornes non résolus', 'value', n, 'permission', 'tech.maintenance');
    end if;
    if has_admin_permission('tech.config') then
      select count(*) into n from platform_settings;
      v := v || jsonb_build_object('key', 'settings_count', 'label', 'Réglages enregistrés', 'value', n, 'permission', 'tech.config');
    end if;
    if has_admin_permission('tech.integrations') then
      select count(*) into n from api_keys where revoked_at is null;
      v := v || jsonb_build_object('key', 'api_keys_active', 'label', 'Clés d''API actives', 'value', n, 'permission', 'tech.integrations');
      select count(*) into n from integration_sync_logs where status = 'error' and started_at > now() - interval '24 hours';
      v := v || jsonb_build_object('key', 'sync_errors_24h', 'label', 'Erreurs de synchronisation (24 h)', 'value', n, 'permission', 'tech.integrations');
    end if;
    if has_admin_permission('tech.logs') then
      select count(*) into n from notification_outbox where status = 'failed' and created_at > now() - interval '24 hours';
      v := v || jsonb_build_object('key', 'outbox_failed_24h', 'label', 'Envois de notification en échec (24 h)', 'value', n, 'permission', 'tech.logs');
      select count(*) into n from audit_log where created_at > now() - interval '24 hours';
      v := v || jsonb_build_object('key', 'audit_24h', 'label', 'Événements du journal (24 h)', 'value', n, 'permission', 'tech.logs');
    end if;
  end if;
  return jsonb_build_object('team', v_team, 'counters', v);
end $$;
revoke all on function admin_team_dashboard(text) from public, anon;
grant execute on function admin_team_dashboard(text) to authenticated;

-- ============================================================ 2FA des nouvelles opérations sensibles (liste étendue, rien n'est retiré)
do $$
declare r record; v_def text; v_new text;
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'enforce_mfa_on_sensitive' loop
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;
    if position('admin_team_member_set' in v_new) = 0 then
      v_new := replace(v_new, '|momo_prepare_transfer)$''',
        '|momo_prepare_transfer|admin_team_member_set|admin_team_member_remove|money_freeze|money_unfreeze|money_split_set|order_refund_decide|order_refund_set_paid|setting_set|create_api_key|revoke_api_key|security_flag_decide)$''');
    end if;
    if v_new <> v_def then execute v_new; end if;
  end loop;
end $$;
