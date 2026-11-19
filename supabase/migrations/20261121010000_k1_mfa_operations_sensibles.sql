-- Lot K1 (1/4) : garde 2FA serveur (enforce_mfa_on_sensitive) étendue aux décisions et écritures sensibles ajoutées par les lots H1 à H5.
-- La garde est redéfinie depuis sa DERNIÈRE définition en base (celle de 20261120043000, ou celle d'un lot plus récent) : le corps est relu avec pg_get_functiondef
-- puis la seule liste des chemins RPC est complétée ; aucune opération n'est retirée, la garde « compte suspendu » et la lecture tolérante aux erreurs sont conservées.
-- Opérations ajoutées (compte avec un facteur TOTP vérifié : session aal2 exigée, sinon refus ; sans facteur : inchangé) :
--   partnership_decide, institutional_validation_decide (H3 : la direction engage l'établissement : accord ou refus d'un partenariat, validation institutionnelle) ;
--   admin_dept_assign, admin_dept_unassign (H2 : rattachement d'un compte département = accès aux données d'un département) ;
--   claim_decide (décision de remboursement d'une réclamation : mouvement d'argent), campaign_refund_done, event_refund_done (remboursements versés) ;
--   save_notification_template (permission technique sensible tech.config) ; admin_process_account_deletions (suppression de compte forcée, irréversible) ;
--   admin_mfa_reset, admin_mfa_reset_by_email (réinitialisation de la 2FA d'un compte : aussi vérifiée dans la fonction ; garde ajoutée en défense en profondeur).
-- Justifié comme NON ajouté : security_flag_account (simple signalement à l'administrateur, sans effet sur le compte), partnership_save / institutional_validation_request /
--   dept_partnership_save (propositions soumises à décision), dept_report et direction_* (lectures agrégées : exiger aal2 rendrait les tableaux de bord inutilisables),
--   admin_team_dashboard / my_admin_access (lectures).
-- Idempotent (rejouable sans doublon). Retour arrière : redéfinir enforce_mfa_on_sensitive depuis 20261120043000.

do $$
declare
  r record; v_def text; v_new text; v_list text; v_name text; v_add text[] := '{}';
  c_all constant text[] := array['partnership_decide', 'institutional_validation_decide', 'admin_dept_assign', 'admin_dept_unassign', 'claim_decide',
    'campaign_refund_done', 'event_refund_done', 'save_notification_template', 'admin_process_account_deletions', 'admin_mfa_reset', 'admin_mfa_reset_by_email'];
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
