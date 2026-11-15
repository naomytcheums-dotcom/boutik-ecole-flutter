-- Double authentification (2FA) appliquée côté serveur.
-- Jusqu'ici le code TOTP n'était exigé que par l'application : une session ouverte avec le seul mot de passe (niveau aal1) pouvait appeler
-- toutes les fonctions. Cette garde, branchée sur chaque requête PostgREST (db_pre_request), refuse les opérations sensibles
-- (paiement, commande, suppression ou export de compte, téléphone, retraits, décisions financières) à toute session qui n'est pas aal2
-- alors que le compte possède un facteur vérifié. Les comptes sans facteur ne sont pas concernés.
-- Retour arrière : alter role authenticator reset pgrst.db_pre_request; notify pgrst, 'reload config'; drop function enforce_mfa_on_sensitive();

create or replace function enforce_mfa_on_sensitive() returns void
language plpgsql stable security definer set search_path = public, auth as $$
declare
  v_path text := coalesce(current_setting('request.path', true), '');
  v_claims jsonb;
  v_uid uuid;
  v_deny boolean := false;
begin
  if v_path !~ '^/rpc/(request_account_deletion|export_my_data|profile_set_phone|set_whatsapp_number|payment_start|payment_declare|payment_set_status|marketplace_checkout|create_order|cancel_order|confirm_cod_order|company_plan_checkout|subscription_start|campaign_contribute|event_checkout|ann_prize_checkout|ann_prize_set|ann_prize_award|ann_prize_refund|request_referral_payout|referral_payout_decide|payout_create|payout_set_status|money_release_now|dispute_decide|admin_set_account)$' then
    return;
  end if;
  -- Toute erreur de lecture laisse passer la requête : la garde ne doit jamais rendre l'API indisponible.
  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    v_uid := nullif(v_claims ->> 'sub', '')::uuid;
    if v_uid is not null and coalesce(v_claims ->> 'aal', 'aal1') <> 'aal2'
       and exists (select 1 from auth.mfa_factors where user_id = v_uid and status = 'verified') then
      v_deny := true;
    end if;
  exception when others then
    v_deny := false;
  end;
  if v_deny then
    raise exception 'Confirmez votre identité avec votre code de double authentification pour effectuer cette opération.' using errcode = '42501';
  end if;
end $$;

grant execute on function enforce_mfa_on_sensitive() to anon, authenticated, service_role;

do $$ begin
  alter role authenticator set pgrst.db_pre_request = 'public.enforce_mfa_on_sensitive';
  notify pgrst, 'reload config';
exception when others then
  raise notice 'Garde 2FA non branchée (alter role authenticator refusé : %). À faire dans le tableau de bord : alter role authenticator set pgrst.db_pre_request = ''public.enforce_mfa_on_sensitive''.', sqlerrm;
end $$;
