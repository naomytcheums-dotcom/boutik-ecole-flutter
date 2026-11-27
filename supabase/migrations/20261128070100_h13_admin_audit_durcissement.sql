-- H13 · Administration, sécurité, performance (2/7) : durcissement issu de l'audit h13_audit.mjs.
--  1. audit_log : plus aucun droit d'écriture direct pour les rôles de l'API (les entrées viennent des fonctions serveur) et journal en ajout seul (ni modification ni suppression ni vidage).
--  2. kiosk_sessions : table héritée, supplantée par kiosk_pairings (jeton d'appareil) ; ses trois politiques (lecture des codes par tout compte connecté, marquage « utilisé » par n'importe qui) sont retirées.
--  3. Suspension d'un compte : QUEL QUE SOIT le chemin (fonction d'administration, éditeur SQL, service), blocage de connexion + fermeture de toutes les sessions ouvertes ;
--     la réactivation lève le blocage posé par la suspension. admin_account_sessions_revoke(compte, motif) : fermeture manuelle des sessions (permission security.accounts), journalisée.
--  4. Journal d'audit ajouté (enveloppe « _au_<nom> » + écriture au journal après succès) aux actions d'administration sensibles qui n'écrivaient pas au journal : réglage du moteur de commission et de
--     la répartition (valeurs inchangées), remboursement d'un prix d'annonce, décisions d'annonces/offres/réalisations/communautés, virements Mobile Money, réinitialisation d'authentification par e-mail,
--     traitement des suppressions de compte, équipes d'administration, contenus de la plateforme.
-- Strictement additive : rien n'est supprimé hors les trois politiques de kiosk_sessions (resserrement). Retour arrière : voir _h13_wrap_fn (20261128070000) ; recréer les politiques de kiosk_sessions depuis schema.sql ; supprimer les déclencheurs audit_log_append_only_*.

-- ============================================================ 1. journal d'audit
revoke insert, update, delete, truncate on audit_log from public, anon, authenticated;
revoke select on audit_log from anon;

create or replace function _audit_log_append_only() returns trigger
language plpgsql set search_path = public as $$
begin
  raise exception 'Le journal d''audit est en ajout seul : modification et suppression interdites' using errcode = '42501';
end $$;
revoke all on function _audit_log_append_only() from public, anon, authenticated;

drop trigger if exists audit_log_append_only_row on audit_log;
create trigger audit_log_append_only_row before update or delete on audit_log for each row execute function _audit_log_append_only();
drop trigger if exists audit_log_append_only_stmt on audit_log;
create trigger audit_log_append_only_stmt before truncate on audit_log for each statement execute function _audit_log_append_only();

-- ============================================================ 2. table héritée des bornes
drop policy if exists "sessions borne lisibles par les connectés" on kiosk_sessions;
drop policy if exists "sessions borne créées par les connectés" on kiosk_sessions;
drop policy if exists "usage unique du code" on kiosk_sessions;
revoke all on kiosk_sessions from public, anon, authenticated;

-- ============================================================ 3. suspension et sessions
create or replace function _profile_suspension_sessions() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.suspended, false) and not coalesce(old.suspended, false) then
    update auth.users set banned_until = '2999-01-01'::timestamptz where id = new.id and (banned_until is null or banned_until < '2999-01-01'::timestamptz);
    delete from auth.sessions where user_id = new.id;
  elsif not coalesce(new.suspended, false) and coalesce(old.suspended, false) then
    update auth.users set banned_until = null where id = new.id and banned_until = '2999-01-01'::timestamptz;
  end if;
  return null;
end $$;
revoke all on function _profile_suspension_sessions() from public, anon, authenticated;

drop trigger if exists profiles_suspension_sessions on profiles;
create trigger profiles_suspension_sessions after update of suspended on profiles
  for each row when (old.suspended is distinct from new.suspended) execute function _profile_suspension_sessions();

create or replace function admin_account_sessions_revoke(p_user uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('security.accounts') then raise exception 'Réservé : exige la permission security.accounts'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 5 then raise exception 'Motif obligatoire (5 caractères minimum)'; end if;
  if p_user is null or p_user = auth.uid() then raise exception 'Vous ne pouvez pas fermer vos propres sessions ici'; end if;
  select role::text, name into v_role, v_name from profiles where id = p_user;
  if not found then raise exception 'Compte introuvable'; end if;
  if v_role = 'admin' and coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Seul un administrateur global ferme les sessions d''un administrateur'; end if;
  with d as (delete from auth.sessions where user_id = p_user returning 1) select count(*)::int into v_n from d;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Sessions fermées', left(coalesce(v_name, '') || ' : ' || v_n || ' session(s) — ' || btrim(p_reason), 200), 'Comptes', 'Sensible');
  return jsonb_build_object('revoked', v_n);
end $$;
revoke all on function admin_account_sessions_revoke(uuid, text) from public, anon;
grant execute on function admin_account_sessions_revoke(uuid, text) to authenticated;

-- ============================================================ 4. journal des actions d'administration sensibles
do $$
declare r record; v_sig regprocedure;
begin
  for r in
    select * from (values
      ('commission_engine_set', 'Moteur de commission modifié', 'Finances'),
      ('money_split_set', 'Répartition des paiements modifiée', 'Finances'),
      ('ann_prize_refund', 'Prix d''annonce remboursé', 'Finances'),
      ('momo_prepare_transfer', 'Virement Mobile Money préparé', 'Finances'),
      ('ann_decide', 'Annonce de concours décidée', 'Modération'),
      ('ann_win_decide', 'Réalisation de concours décidée', 'Modération'),
      ('opp_decide', 'Offre décidée', 'Modération'),
      ('community_decide', 'Communauté décidée', 'Modération'),
      ('victory_moderate', 'Réussite modérée', 'Modération'),
      ('delete_referral_rule', 'Barème de parrainage supprimé', 'Paramètres'),
      ('cms_delete', 'Contenu de la plateforme supprimé', 'Paramètres'),
      ('mate_category_delete', 'Catégorie de coéquipiers supprimée', 'Paramètres'),
      ('admin_mfa_reset_by_email', 'Authentification forte réinitialisée', 'Comptes'),
      ('admin_process_account_deletions', 'Suppressions de comptes traitées', 'Comptes'),
      ('admin_team_member_set', 'Droits d''équipe modifiés', 'Comptes'),
      ('admin_team_member_remove', 'Membre d''équipe retiré', 'Comptes')
    ) as t(fn, label, cat)
  loop
    for v_sig in select p.oid::regprocedure from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = r.fn and p.prokind = 'f' loop
      perform _h13_wrap_fn(v_sig, 'audit', r.label, r.cat);
    end loop;
  end loop;
end $$;
