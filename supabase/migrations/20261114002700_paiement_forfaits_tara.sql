-- Paiement des forfaits entreprise par Mobile Money (MTN / Orange) via Tara Money, déjà configuré côté serveur (fonctions tara-pay et tara-webhook).
-- Le montant vient toujours de la base ; le forfait s'active tout seul quand Tara Money confirme le paiement (webhook), jamais sur la parole du client.
-- Retour arrière : drop trigger trg_subscription_paid on payment_transactions; drop function on_subscription_paid(), company_plan_checkout(text), company_activate_internal(uuid, text, integer, text, uuid);
--   delete from platform_settings where key = 'payments.tara_enabled'.

insert into platform_settings (key, value) values ('payments.tara_enabled', 'true'::jsonb)
on conflict (key) do update set value = 'true'::jsonb, updated_at = now();

-- Activation (interne) d'un forfait : un seul abonnement actif par entreprise ; la demande en attente est remplacée.
create or replace function company_activate_internal(p_owner uuid, p_plan text, p_days integer, p_note text, p_by uuid) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; v_days integer; v_end timestamptz;
begin
  select * into pl from company_plans where code = p_plan;
  if not found then raise exception 'Forfait introuvable'; end if;
  v_days := coalesce(p_days, nullif(pl.period_days, 0), 30);
  v_end := now() + make_interval(days => v_days);
  update company_subscriptions set status = 'expired' where owner_id = p_owner and status = 'active';
  delete from company_subscriptions where owner_id = p_owner and status = 'requested';
  insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at, note, activated_by) values (p_owner, pl.code, 'active', now(), v_end, nullif(left(btrim(coalesce(p_note, '')), 300), ''), p_by);
  insert into notifications (user_id, kind, title, body, data)
    values (p_owner, 'company_plan', 'Forfait activé', 'Votre forfait « ' || pl.name || ' » est actif jusqu''au ' || to_char(v_end, 'DD/MM/YYYY') || '.', jsonb_build_object('plan', pl.code));
  return v_end;
end $$;
revoke all on function company_activate_internal(uuid, text, integer, text, uuid) from public, anon, authenticated;

-- Démarre le paiement d'un forfait : crée la transaction Tara Money (montant lu en base) et renvoie sa référence.
create or replace function company_plan_checkout(p_plan text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; v_id uuid; v_ref text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from company_profiles where owner_id = auth.uid() and status = 'approved') then raise exception 'Faites d''abord vérifier votre entreprise'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa <= 0 then raise exception 'Forfait introuvable'; end if;
  v_id := payment_start('subscription', 'plan:' || pl.code, pl.price_fcfa, 'tara');
  select reference into v_ref from payment_transactions where id = v_id;
  return jsonb_build_object('id', v_id, 'reference', v_ref, 'amount', pl.price_fcfa, 'plan', pl.name);
end $$;
revoke all on function company_plan_checkout(text) from public, anon;
grant execute on function company_plan_checkout(text) to authenticated;

-- Paiement confirmé par le fournisseur -> forfait activé (une seule fois par transaction ; le montant doit couvrir le prix du forfait).
create or replace function on_subscription_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'subscription' and new.subject like 'plan:%' then
    select * into pl from company_plans where code = substr(new.subject, 6);
    if found and new.amount >= pl.price_fcfa and exists (select 1 from company_profiles where owner_id = new.payer_id and status = 'approved') then
      perform company_activate_internal(new.payer_id, pl.code, null, 'Payé par Mobile Money (' || new.reference || ')', null);
    end if;
  end if;
  return null;
end $$;
drop trigger if exists trg_subscription_paid on payment_transactions;
create trigger trg_subscription_paid after update of status on payment_transactions for each row execute function on_subscription_paid();
