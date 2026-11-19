-- Lot K1 (2/4) : notifications « à toute l'équipe Finance / Support » ciblées par PERMISSION.
-- Jusqu'ici une alerte (paiement à vérifier, retrait à traiter, signalement, litige, ticket…) partait à TOUS les comptes de rôle finance ou support, même sans
-- permission correspondante (ou après révocation). Désormais le destinataire doit détenir la permission d'équipe qui lui permet de traiter l'alerte :
--   _team_recipients(perms[])          : administrateur global (toujours) + agents finance/support NON suspendus ayant AU MOINS UNE des permissions (effet immédiat : lu à l'envoi) ;
--   notify_team_permission(perms[], kind, titre, corps, data, exclure)  : insère la notification pour ces destinataires (point d'entrée unique pour les nouveaux envois).
-- Les fonctions existantes sont relues depuis leur DERNIÈRE définition (pg_get_functiondef) et réécrites en ne remplaçant que le filtre de destinataires
-- « role in ('finance' | 'support' | 'admin') » ; tous les autres garde-fous (suspension, département, quotas, audit) sont conservés.
-- Cartographie : finance.payments (paiement à vérifier, forfait non activé) ; finance.payouts (retraits vendeur / gains) ; finance.refunds (+ support.refunds pour la demande) ;
--   support.tickets ; support.claims ; support.disputes ; support.requests (suppressions de compte, propositions d'établissement ou de département, mentors) ;
--   security.reports (signalements) ; security.moderation (publications, boutiques à valider, communautés, victoires).
-- Retour arrière : redéfinir les fonctions listées depuis leurs migrations d'origine ; drop function notify_team_permission(text[], text, text, text, jsonb, uuid), _team_recipients(text[]).

create or replace function _team_recipients(p_perms text[]) returns setof uuid
language sql stable security definer set search_path = public as $$
  select p.id from profiles p
  where not coalesce(p.suspended, false)
    and (p.role::text = 'admin'
         or (p.role::text in ('finance', 'support')
             and exists (select 1 from admin_team_members m where m.user_id = p.id and m.permissions && coalesce(p_perms, '{}'))))
$$;
revoke all on function _team_recipients(text[]) from public, anon, authenticated;

create or replace function notify_team_permission(p_perms text[], p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb, p_exclude uuid default null) returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  insert into notifications (user_id, kind, title, body, data)
  select r, p_kind, p_title, p_body, coalesce(p_data, '{}'::jsonb) from _team_recipients(p_perms) r where r is distinct from p_exclude;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function notify_team_permission(text[], text, text, text, jsonb, uuid) from public, anon, authenticated;

create or replace function _notify_finance(p_title text, p_body text, p_data jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = public as $$
  select notify_team_permission(array['finance.refunds'], 'refund', p_title, p_body, p_data)
$$;
revoke all on function _notify_finance(text, text, jsonb) from public, anon, authenticated;

-- Réécrit le filtre de destinataires d'une fonction : « [alias.]role::text in ('admin', 'support'…) » devient « [alias.]id in (destinataires de la permission) ».
create or replace function _k1_patch_recipients(p_name text, p_perms text[], p_custom text[] default '{}') returns integer
language plpgsql set search_path = public as $$
declare
  r record; v_def text; v_new text; n integer := 0; i integer;
  v_expr text := 'select * from _team_recipients(array[' || (select string_agg('''' || x || '''', ', ') from unnest(p_perms) x) || '])';
  c_re constant text := '(\y(?:\w+\.)?)role::text\s+in\s*\(\s*''(?:admin|finance|support)''(?:\s*,\s*''(?:admin|finance|support)'')*\s*\)';
begin
  for r in select p.oid, p.prosecdef from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name and p.prokind = 'f' loop
    if not r.prosecdef then raise exception 'K1 : % doit être security definer pour appeler _team_recipients', p_name; end if;
    v_def := pg_get_functiondef(r.oid);
    v_new := regexp_replace(v_def, c_re, '\1id in (' || v_expr || ')', 'g');
    if cardinality(p_custom) >= 2 then
      for i in 1..cardinality(p_custom) / 2 loop
        v_new := replace(v_new, p_custom[2 * i - 1], replace(p_custom[2 * i], '{EXPR}', v_expr));
      end loop;
    end if;
    if v_new <> v_def then execute v_new; n := n + 1; end if;
  end loop;
  return n;
end $$;

do $$
begin
  perform _k1_patch_recipients('payment_declare', array['finance.payments']);
  perform _k1_patch_recipients('on_subscription_paid', array['finance.payments']);
  perform _k1_patch_recipients('request_referral_payout', array['finance.payouts']);
  perform _k1_patch_recipients('request_seller_payout', array['finance.payouts']);
  perform _k1_patch_recipients('campaign_close_due', array['finance.refunds']);
  perform _k1_patch_recipients('event_cancel', array['finance.refunds']);
  perform _k1_patch_recipients('on_campaign_paid', array['finance.refunds']);
  perform _k1_patch_recipients('on_event_paid', array['finance.refunds']);
  perform _k1_patch_recipients('order_refund_request', array['finance.refunds', 'support.refunds']);
  perform _k1_patch_recipients('support_ticket_create', array['support.tickets']);
  perform _k1_patch_recipients('submit_claim', array['support.claims']);
  perform _k1_patch_recipients('dispute_open', array['support.disputes']);
  perform _k1_patch_recipients('dispute_reply', array['support.disputes']);
  perform _k1_patch_recipients('request_account_deletion', array['support.requests']);
  perform _k1_patch_recipients('cancel_account_deletion', array['support.requests']);
  perform _k1_patch_recipients('department_propose', array['support.requests']);
  perform _k1_patch_recipients('institution_propose', array['support.requests']);
  perform _k1_patch_recipients('mentor_save', array['support.requests']);
  perform _k1_patch_recipients('report_comment', array['security.reports']);
  perform _k1_patch_recipients('report_conversation', array['security.reports']);
  perform _k1_patch_recipients('report_listing', array['security.reports']);
  perform _k1_patch_recipients('report_live', array['security.reports']);
  perform _k1_patch_recipients('report_post', array['security.reports']);
  perform _k1_patch_recipients('report_shop', array['security.reports']);
  perform _k1_patch_recipients('report_story', array['security.reports']);
  perform _k1_patch_recipients('_notify_shop_validators', array['security.moderation']);
  perform _k1_patch_recipients('create_community', array['security.moderation']);
  perform _k1_patch_recipients('create_ephemeral_community', array['security.moderation']);
  perform _k1_patch_recipients('trg_notify_pending_post', array['security.moderation']);
  perform _k1_patch_recipients('victory_report', array['security.moderation']);
  -- Notifications de revue des demandes d'un département : l'équipe Support n'est prévenue que si elle a la permission de traiter les demandes.
  perform _k1_patch_recipients('_scope_recipients', array['support.requests'], array['a.role::text = ''support''', 'a.id in ({EXPR})']);
end $$;

drop function if exists _k1_patch_recipients(text, text[], text[]);
