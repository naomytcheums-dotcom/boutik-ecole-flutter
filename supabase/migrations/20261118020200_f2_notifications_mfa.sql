-- Lot F2 (profil Entreprise) — notifications et garde 2FA.
--  E5-20  Les notifications d'entreprise (vérification, forfait, équipe) ne sont plus rangées dans « Avis et questions » (désactivable) : catégorie « other », jamais filtrée.
--         Elles sont « importantes » (e-mail, SMS et WhatsApp pour qui a activé le canal), comme talent_contact et cv_shared.
--  E5-24  company_decide, company_plan_save et company_subscription_activate rejoignent les opérations sensibles soumises à la 2FA (enforce_mfa_on_sensitive).
-- Les trois fonctions sont modifiées à partir de leur DERNIÈRE définition (lue dans la base) : aucun autre chemin, règle ou type n'est perdu.
-- Retour arrière : recréer notification_category (20261117050300), enqueue_notification (20261117080100) et enforce_mfa_on_sensitive (20261117000100).

do $$
declare v_def text; v_new text;
begin
  -- 1. catégorie : company_review n'est plus dans « reviews »
  select pg_get_functiondef('public.notification_category(text)'::regprocedure) into v_def;
  if position('''review'', ''company_review'', ''question''' in v_def) > 0 then
    v_new := replace(v_def, '''review'', ''company_review'', ''question''', '''review'', ''question''');
    execute v_new;
  elsif position('company_review' in v_def) > 0 then
    raise exception 'notification_category : motif inattendu, correction manuelle nécessaire';
  end if;

  -- 2. types importants (canaux e-mail / SMS / WhatsApp activés en « * »)
  select pg_get_functiondef('public.enqueue_notification()'::regprocedure) into v_def;
  if position('company_review' in v_def) = 0 then
    if position('''verification'', ''mentor_request''' in v_def) = 0 then
      raise exception 'enqueue_notification : liste des types importants introuvable, correction manuelle nécessaire';
    end if;
    v_new := replace(v_def, '''verification'', ''mentor_request''', '''verification'', ''company_review'', ''company_plan'', ''company_team'', ''talent_contact'', ''cv_shared'', ''mentor_request''');
    execute v_new;
  end if;

  -- 3. 2FA : opérations d'entreprise sensibles
  select pg_get_functiondef('public.enforce_mfa_on_sensitive()'::regprocedure) into v_def;
  if position('company_decide' in v_def) = 0 then
    if position('company_plan_checkout|' in v_def) = 0 then
      raise exception 'enforce_mfa_on_sensitive : liste des opérations sensibles introuvable, correction manuelle nécessaire';
    end if;
    v_new := replace(v_def, 'company_plan_checkout|', 'company_plan_checkout|company_decide|company_plan_save|company_subscription_activate|');
    execute v_new;
  end if;
end $$;
