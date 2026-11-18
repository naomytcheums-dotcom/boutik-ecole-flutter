-- Lot H4 : gardes SQL par permission sur les opérations sensibles des équipes internes (Finance, Support, Sécurité et modération, Technique).
-- Jusqu'ici une opération était ouverte à tout compte de rôle finance ou support. Elle exige désormais la permission d'équipe correspondante
-- (has_admin_permission / has_any_admin_permission, voir 20261120040000) ; l'administrateur global garde tout ; un agent n'a pas les droits d'une autre équipe.
-- Méthode (comme le lot H3) : la DERNIÈRE définition en base fait foi ; elle est relue (pg_get_functiondef) et réécrite en remplaçant seulement
-- les rôles « finance », « support » et « admin » des contrôles de rôle par l'appel de permission : tous les autres garde-fous (suspension, audit, quotas,
-- rôles dept / direction, déclarations des autres lots) sont conservés. Idempotent : rejouable sans effet.
-- Cartographie :
--   finance.read      _finance_read, _finance_read_consolidated, money_admin_*, campaign_backers, campaigns_overview, events_managed, event_registrants
--   finance.payments  payment_set_status, payments_to_verify
--   finance.payouts   payout_create, payout_set_status, referral_payout_decide, referral_payouts_list
--   finance.refunds   order_refund_set_paid, campaign_refund_done, event_refund_done ; order_refund_decide (ou support.refunds)
--   finance.transfers momo_prepare_transfer
--   finance.split     money_split_set, money_freeze, money_unfreeze, money_release_now
--   support.*         tickets, réclamations, litiges, commandes et bornes, demandes (pièces, établissements, suppressions de compte, mentors)
--   security.*        modération des contenus, signalements, réinitialisation 2FA
--   tech.*            réglages (setting_set, settings_all, modèles de notification), clés d'API ; bornes (tech.maintenance)
-- Retour arrière : réappliquer les définitions d'origine des fonctions listées ci-dessus (migrations citées dans leur en-tête).

create or replace function _h4_has_expr(p_perms text[]) returns text
language sql immutable set search_path = public as $$
  select case
    when p_perms = array['*'] then 'is_admin_team_member()'
    when cardinality(p_perms) = 1 then 'has_admin_permission(''' || p_perms[1] || ''')'
    else 'has_any_admin_permission(array[' || (select string_agg('''' || x || '''', ', ') from unnest(p_perms) x) || '])' end
$$;

create or replace function _h4_guard_fn(p_name text, p_perms text[], p_custom text[] default '{}') returns int
language plpgsql set search_path = public as $$
declare
  r record; v_def text; v_new text; m text[]; v_items text[]; v_rest text[]; v_h text := _h4_has_expr(p_perms); v_inner text; v_repl text; v_n int := 0; i int;
  c_in constant text := '(coalesce\(current_role_name\(\)::text,\s*''''\)|\yv_role\y|\yr\y)\s+(not\s+)?in\s*\(\s*((?:''[a-z_]+''\s*,?\s*)+)\)';
  c_ne constant text := 'coalesce\(current_role_name\(\)::text,\s*''''\)\s*<>\s*''admin''';
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = p_name and p.prokind = 'f' loop
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;
    for m in select x from regexp_matches(v_def, '(' || c_in || ')', 'g') x loop
      select array_agg(x[1]) into v_items from regexp_matches(m[4], '''([a-z_]+)''', 'g') x;
      if not (v_items && array['finance', 'support', 'admin']) then continue; end if;
      select coalesce(array_agg(it), '{}') into v_rest from unnest(v_items) it where it not in ('finance', 'support', 'admin');
      v_inner := case when cardinality(v_rest) = 0 then v_h
                      else '(' || v_h || ' or ' || m[2] || ' in (' || (select string_agg('''' || z || '''', ', ') from unnest(v_rest) z) || '))' end;
      v_repl := case when m[3] is not null then 'not ' || v_inner else v_inner end;
      v_new := replace(v_new, m[1], v_repl);
    end loop;
    v_new := regexp_replace(v_new, c_ne, 'not ' || v_h, 'g');
    if cardinality(p_custom) >= 2 then
      for i in 1..cardinality(p_custom) / 2 loop
        v_new := replace(v_new, p_custom[2 * i - 1], p_custom[2 * i]);
      end loop;
    end if;
    if v_new <> v_def then execute v_new; v_n := v_n + 1; end if;
  end loop;
  return v_n;
end $$;

-- ============================================================ Finance
do $$
begin
  perform _h4_guard_fn('_finance_read', array['finance.read']);
  perform _h4_guard_fn('_finance_read_consolidated', array['finance.read']);
  perform _h4_guard_fn('campaign_backers', array['finance.read']);
  perform _h4_guard_fn('campaigns_overview', array['finance.read']);
  perform _h4_guard_fn('campaign_refund_done', array['finance.refunds']);
  perform _h4_guard_fn('event_refund_done', array['finance.refunds']);
  perform _h4_guard_fn('events_managed', array['finance.read']);
  perform _h4_guard_fn('event_registrants', array['finance.read']);
  perform _h4_guard_fn('momo_prepare_transfer', array['finance.transfers']);
  perform _h4_guard_fn('money_admin_list', array['finance.read']);
  perform _h4_guard_fn('money_admin_overview', array['finance.read']);
  perform _h4_guard_fn('money_freeze', array['finance.split']);
  perform _h4_guard_fn('money_unfreeze', array['finance.split']);
  perform _h4_guard_fn('money_release_now', array['finance.split']);
  perform _h4_guard_fn('money_split_set', array['finance.split']);
  perform _h4_guard_fn('my_refunds', array['finance.refunds', 'support.refunds', 'support.claims']);
  perform _h4_guard_fn('order_refund_decide', array['finance.refunds', 'support.refunds']);
  perform _h4_guard_fn('order_refund_set_paid', array['finance.refunds']);
  perform _h4_guard_fn('payment_set_status', array['finance.payments']);
  perform _h4_guard_fn('payments_to_verify', array['finance.payments']);
  perform _h4_guard_fn('payment_thread', array['finance.read', 'finance.payments', 'support.claims', 'support.disputes']);
  perform _h4_guard_fn('payout_create', array['finance.payouts']);
  perform _h4_guard_fn('payout_set_status', array['finance.payouts']);
  perform _h4_guard_fn('referral_payout_decide', array['finance.payouts']);
  perform _h4_guard_fn('referral_payouts_list', array['finance.payouts', 'finance.read']);
  perform _h4_guard_fn('settings_all', array['tech.config', 'finance.read']);
  perform _h4_guard_fn('staff_missions', array['support.requests', 'finance.read']);
  perform _h4_guard_fn('staff_mission_proposals', array['support.requests', 'finance.read']);
  perform _h4_guard_fn('platform_overview', array['*']);
end $$;

-- ============================================================ Support
do $$
begin
  perform _h4_guard_fn('answer_claim', array['support.claims']);
  perform _h4_guard_fn('claim_thread', array['support.claims']);
  -- Une décision de remboursement est une opération financière : elle exige en plus une permission de remboursement.
  perform _h4_guard_fn('claim_decide', array['support.claims'], array[
    $q$if p_decision not in ('release', 'refund') then raise exception 'Décision inconnue'; end if;$q$,
    $q$if p_decision not in ('release', 'refund') then raise exception 'Décision inconnue'; end if;
  if p_decision = 'refund' and not has_any_admin_permission(array['support.refunds', 'finance.refunds']) then raise exception 'Une décision de remboursement exige la permission de remboursement'; end if;$q$]);
  perform _h4_guard_fn('dispute_close', array['support.disputes']);
  perform _h4_guard_fn('dispute_decide', array['support.disputes'], array['if not is_platform_staff() then', $q$if not has_admin_permission('support.disputes') then$q$]);
  perform _h4_guard_fn('support_ticket_reply', array['support.tickets'], array['if not is_platform_staff() then', $q$if not has_admin_permission('support.tickets') then$q$]);
  perform _h4_guard_fn('support_ticket_close', array['support.tickets'], array['is_platform_staff()', $q$has_admin_permission('support.tickets')$q$]);
  perform _h4_guard_fn('confirm_pickup', array['support.orders']);
  perform _h4_guard_fn('delivery_failed', array['support.orders']);
  perform _h4_guard_fn('start_delivery', array['support.orders']);
  perform _h4_guard_fn('pickup_collect', array['support.orders']);
  perform _h4_guard_fn('pickup_register', array['support.orders']);
  perform _h4_guard_fn('pickups_list', array['support.orders']);
  perform _h4_guard_fn('qr_resolve', array['support.orders']);
  perform _h4_guard_fn('qr_issue', array['support.orders']);
  perform _h4_guard_fn('kiosk_provision', array['support.orders', 'tech.maintenance']);
  perform _h4_guard_fn('report_kiosk_incident', array['support.orders', 'tech.maintenance']);
  perform _h4_guard_fn('schedule_kiosk_event', array['support.orders', 'tech.maintenance']);
  -- Demandes des utilisateurs : pièces justificatives, référentiels proposés, suppressions de compte, mentors.
  perform _h4_guard_fn('documents_to_review', array['support.requests']);
  perform _h4_guard_fn('_review_scope_ok', array['support.requests'], array['(p_support and r = ''support'')', $q$(p_support and has_admin_permission('support.requests'))$q$]);
  perform _h4_guard_fn('admin_departments', array['support.requests']);
  perform _h4_guard_fn('admin_users', array['support.requests', 'support.tickets', 'security.accounts', 'security.moderation']);
  perform _h4_guard_fn('skills_radar', array['support.requests']);
end $$;

do $$
declare f text;
begin
  foreach f in array array['document_review', 'reference_review', 'references_to_review', 'catalog_review', 'account_deletions_pending', 'mentors_pending', 'mentor_validate'] loop
    perform _h4_guard_fn(f, array['support.requests'], array['is_platform_staff()', $q$has_admin_permission('support.requests')$q$]);
  end loop;
end $$;

-- ============================================================ Sécurité et modération
do $$
declare f text;
begin
  foreach f in array array['moderate_post', 'moderate_story', 'moderation_posts_list', 'moderation_stories_list', 'moderate_live_viewer', 'end_live', 'marketplace_moderation',
                           'shop_decide', 'victory_moderate', 'delete_post_comment', 'hide_story'] loop
    perform _h4_guard_fn(f, array['security.moderation']);
  end loop;
  foreach f in array array['post_reports_dismiss', 'comment_report_close', 'comment_reports_list', 'live_report_close', 'live_reports_list', 'shop_report_set_status', 'set_report_status'] loop
    perform _h4_guard_fn(f, array['security.reports']);
  end loop;
  foreach f in array array['message_reports_list', 'message_report_set_status'] loop
    perform _h4_guard_fn(f, array['security.reports'], array['is_platform_staff()', $q$has_admin_permission('security.reports')$q$]);
  end loop;
  foreach f in array array['communities_pending', 'community_decide', 'community_set_official', 'community_hidden_posts', 'community_report_close', 'community_reports_list',
                           'moderate_community_post', '_community_content_remove'] loop
    perform _h4_guard_fn(f, array['security.moderation'], array['not is_platform_staff()', $q$not has_admin_permission('security.moderation')$q$,
                                                               'and is_platform_staff()', $q$and has_admin_permission('security.moderation')$q$]);
  end loop;
  perform _h4_guard_fn('admin_mfa_reset', array['security.accounts'], array['if r = ''support'' and t in', 'if r <> ''admin'' and t in']);
  perform _h4_guard_fn('admin_mfa_reset_by_email', array['security.accounts']);
end $$;

-- ============================================================ Technique
do $$
begin
  -- Un agent technique modifie les réglages techniques ; les réglages financiers restent à l'administrateur global.
  perform _h4_guard_fn('setting_set', array['tech.config'], array[
    $q$if p_key is null or p_key !~ '^[a-z0-9_.]{3,60}$' then raise exception 'Clé invalide'; end if;$q$,
    $q$if p_key is null or p_key !~ '^[a-z0-9_.]{3,60}$' then raise exception 'Clé invalide'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' and p_key ~ '^(payments|money|split|commission|finance)[._]' then raise exception 'Les réglages financiers sont réservés à l''administrateur global'; end if;$q$]);
  perform _h4_guard_fn('save_notification_template', array['tech.config']);
  perform _h4_guard_fn('create_api_key', array['tech.integrations']);
  perform _h4_guard_fn('revoke_api_key', array['tech.integrations']);
end $$;

drop function if exists _h4_guard_fn(text, text[], text[]);
drop function if exists _h4_has_expr(text[]);
