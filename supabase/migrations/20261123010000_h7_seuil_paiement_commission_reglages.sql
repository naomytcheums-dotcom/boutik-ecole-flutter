-- Lot H7 (facturation) : les règles enregistrées par l'écran admin 135 (réglages « commission.* ») sont relues par la facturation là où leur sens est sans ambiguïté.
--   - « commission.payout_threshold » (Seuil de paiement vendeur, FCFA) = montant minimum d'une demande de retrait du vendeur. Quand l'administrateur l'a enregistré,
--     il remplace « payouts.min » (réglage plus ancien, sans écran, 1 000 FCFA par défaut) dans request_seller_payout, my_payouts (clé « min ») et le contrôle de suppression de compte.
--     Il ne dépasse jamais « payouts.max » (sinon plus aucun retrait ne serait possible). Aucun seuil enregistré : comportement inchangé (payouts.min, puis 1 000).
--     La finance (payout_create) reste libre de verser un solde inférieur : décision du propriétaire (docs/transformation/H7_DECISIONS_PROPRIETAIRE.md).
--   - « commission.product », « commission.service », « commission.financing » ne sont PAS branchés : ils ne disent ni sur quelle base (brut, net), ni comment ils se combinent avec la
--     répartition 70/20/10 de money_split_rules (part plateforme 10 %), qui reste inchangée. Ils sont seulement validés à l'écriture (entier de 0 à 30, comme l'écran).
--   - platform_settings : les réglages « commission.* » sont contrôlés côté serveur (une valeur non numérique ou hors bornes était acceptée par setting_set).
-- Retour arrière : drop trigger trg_h7_commission_settings on platform_settings ; drop function _h7_commission_settings_check() ;
--   recréer _payout_limit(text, integer) depuis 20261117040300.

create or replace function _payout_limit(p_key text, p_default integer) returns integer
language plpgsql stable security definer set search_path = public as $$
declare v_base integer; v_thr integer; v_max integer;
begin
  select (value #>> '{}')::numeric::int into v_base from platform_settings where key = p_key and jsonb_typeof(value) = 'number';
  v_base := coalesce(v_base, p_default);
  if p_key = 'payouts.min' then
    select least((value #>> '{}')::numeric, 100000000)::int into v_thr from platform_settings
      where key = 'commission.payout_threshold' and jsonb_typeof(value) = 'number' and (value #>> '{}')::numeric >= 0;
    if v_thr is not null then
      select (value #>> '{}')::numeric::int into v_max from platform_settings where key = 'payouts.max' and jsonb_typeof(value) = 'number';
      v_base := least(v_thr, coalesce(v_max, 500000));
    end if;
  end if;
  return v_base;
end $$;
revoke all on function _payout_limit(text, integer) from public, anon, authenticated;

create or replace function _h7_commission_settings_check() returns trigger
language plpgsql set search_path = public as $$
declare v numeric;
begin
  if new.key not in ('commission.product', 'commission.service', 'commission.financing', 'commission.payout_threshold') then return new; end if;
  if jsonb_typeof(new.value) <> 'number' then raise exception 'Valeur invalide pour % : un nombre entier est attendu', new.key; end if;
  v := (new.value #>> '{}')::numeric;
  if v <> trunc(v) then raise exception 'Valeur invalide pour % : un nombre entier est attendu', new.key; end if;
  if new.key = 'commission.payout_threshold' then
    if v < 0 or v > 100000000 then raise exception 'Seuil de paiement vendeur : de 0 à 100 000 000 FCFA'; end if;
  elsif v < 0 or v > 30 then
    raise exception 'Taux de commission : de 0 à 30 %%';
  end if;
  return new;
end $$;
revoke all on function _h7_commission_settings_check() from public, anon, authenticated;
drop trigger if exists trg_h7_commission_settings on platform_settings;
create trigger trg_h7_commission_settings before insert or update of value on platform_settings for each row execute function _h7_commission_settings_check();
