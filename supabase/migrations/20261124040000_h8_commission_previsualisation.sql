-- Lot H8 (COM) : préparation des taux de commission, SANS activer aucune règle financière.
-- Rappel (docs/transformation/H7_DECISIONS_PROPRIETAIRE.md, décisions 1, 3 et 4) : les taux « commission.product / service / financing » sont enregistrés par l'écran 135 mais aucun
-- calcul réel ne les lit ; la répartition reste celle de money_split_rules (70/20/10 par défaut). Cette migration ne change AUCUN calcul réel : elle ajoute seulement
--   1. commission_rate_for(kind)            : taux enregistré (entier, %) pour product | service | financing, ou null s'il n'est pas enregistré. Lecture seule.
--   2. commission_preview(montant, kind, assiette, déduction) : ce que donneraient les taux enregistrés sous CHAQUE hypothèse documentée, à côté de la répartition actuelle :
--        replace_platform : le taux remplace la part « plateforme » (le fonds de l'institution reste à son %, le prestataire reçoit le reste ; décision 1, option A) ;
--        additional_levy  : le taux est un prélèvement en plus, retranché du montant avant la répartition de la règle en vigueur (option B) ;
--        replace_split    : le taux remplace toute la règle, sans fonds d'institution (option C).
--      Assiettes : gross (prix des articles après remise, comme aujourd'hui), net_vat (prix TTC ramené hors TVA : montant × 100 / (100 + d)), net_fees (montant moins d % de frais d'opérateur).
--      Les assiettes nettes exigent le pourcentage d (non fixé par le propriétaire : décisions 3, 10 et 11) ; sans lui, elles sont signalées « indisponibles ».
--      Aucune écriture, aucun appel par request_seller_payout, le séquestre, les commandes ou les forfaits. Tous les montants sont des entiers tronqués (comme money_split_amounts).
--   3. Interrupteur « commission.engine_enabled » (platform_settings), désactivé (false) par défaut :
--        - écriture réservée à l'administrateur global, journalisée (audit_log, niveau Critique), session 2FA aal2 exigée si la double authentification est active
--          (garde _require_staff_aal2) ; la valeur doit être un booléen. Passe par commission_engine_set(booléen) ou setting_set : le déclencheur applique les mêmes gardes ;
--        - AUCUN calcul réel ne le lit. Point d'insertion unique, documenté et testé : la première instruction de money_split_amounts(p_gross)
--          (migration 20261114002800), de la forme « if _commission_engine_enabled() then … end if; ». Procédure complète : docs/transformation/H8_DECISIONS_PROPRIETAIRE_SEPAREES.md.
--        - _commission_engine_enabled() : lecture interne (faux si la ligne est absente ou n'est pas le booléen true). commission_engine_get() : lecture personnel finance.
-- Retour arrière : drop trigger trg_h8_commission_engine on platform_settings ; drop function _h8_commission_engine_guard(), commission_engine_set(boolean), commission_engine_get(),
--   _commission_engine_enabled(), commission_preview(integer, text, text, numeric), commission_rate_for(text) ; delete from platform_settings where key = 'commission.engine_enabled'.

create or replace function commission_rate_for(p_kind text) returns integer
language plpgsql stable security definer set search_path = public as $$
declare v_key text; v numeric;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _staff_perm(array['finance.read']) then raise exception 'Action non autorisée'; end if;
  v_key := case p_kind when 'product' then 'commission.product' when 'service' then 'commission.service' when 'financing' then 'commission.financing' end;
  if v_key is null then raise exception 'Type inconnu : product, service ou financing'; end if;
  select (value #>> '{}')::numeric into v from platform_settings where key = v_key and jsonb_typeof(value) = 'number';
  return case when v is not null and v = trunc(v) and v between 0 and 30 then v::int end;
end $$;

create or replace function commission_preview(p_amount integer, p_kind text, p_basis text default 'gross', p_deduction_pct numeric default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  r money_split_rules%rowtype;
  v_rate integer; v_base bigint; v_basis_ok boolean := true;
  cb integer; ci integer; cp integer;
  c bigint; rest bigint; hb bigint; hi bigint; hp bigint;
  v_cur jsonb; v_a jsonb; v_b jsonb; v_c jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _staff_perm(array['finance.read']) then raise exception 'Action non autorisée'; end if;
  if p_amount is null or p_amount < 0 then raise exception 'Montant invalide'; end if;
  if p_kind is null or p_kind not in ('product', 'service', 'financing') then raise exception 'Type inconnu : product, service ou financing'; end if;
  if p_basis is null or p_basis not in ('gross', 'net_vat', 'net_fees') then raise exception 'Assiette inconnue : gross, net_vat ou net_fees'; end if;
  if p_deduction_pct is not null and (p_deduction_pct < 0 or p_deduction_pct >= 100) then raise exception 'Pourcentage de déduction invalide (0 à moins de 100)'; end if;

  select * into r from money_split_rules order by id desc limit 1;
  v_rate := commission_rate_for(p_kind);
  select b, i, p into cb, ci, cp from money_split_amounts(p_amount);
  v_cur := jsonb_build_object('rule', r.beneficiary_pct || '/' || r.institution_pct || '/' || r.platform_pct, 'beneficiary', cb, 'institution', ci, 'platform', cp, 'commission_amount', cp);

  if p_basis = 'gross' then
    v_base := p_amount;
  elsif p_deduction_pct is null then
    v_basis_ok := false;
  elsif p_basis = 'net_vat' then
    v_base := floor(p_amount::numeric * 100 / (100 + p_deduction_pct));
  else
    v_base := p_amount - floor(p_amount::numeric * p_deduction_pct / 100);
  end if;

  if v_rate is not null and v_basis_ok then
    c := floor(v_base::numeric * v_rate / 100);
    -- A : le taux remplace la part plateforme ; le fonds garde son pourcentage ; le prestataire reçoit le reste
    hi := floor(p_amount::numeric * r.institution_pct / 100);
    hb := p_amount - c - hi;
    v_a := jsonb_build_object('beneficiary', hb, 'institution', hi, 'platform', c, 'commission_amount', c, 'coherent', hb >= 0,
      'delta_beneficiary', hb - cb, 'delta_institution', hi - ci, 'delta_platform', c - cp);
    -- B : prélèvement supplémentaire avant la répartition en vigueur du reste
    rest := p_amount - c;
    hb := floor(rest::numeric * r.beneficiary_pct / 100);
    hi := floor(rest::numeric * r.institution_pct / 100);
    hp := rest - hb - hi + c;
    v_b := jsonb_build_object('beneficiary', hb, 'institution', hi, 'platform', hp, 'commission_amount', c, 'coherent', rest >= 0,
      'delta_beneficiary', hb - cb, 'delta_institution', hi - ci, 'delta_platform', hp - cp);
    -- C : le taux remplace toute la règle ; plus de part pour le fonds de l'institution
    hb := p_amount - c;
    v_c := jsonb_build_object('beneficiary', hb, 'institution', 0, 'platform', c, 'commission_amount', c, 'coherent', hb >= 0,
      'delta_beneficiary', hb - cb, 'delta_institution', -ci, 'delta_platform', c - cp);
  end if;

  return jsonb_build_object(
    'simulation', true, 'note', 'simulation : aucune règle appliquée',
    'amount', p_amount, 'kind', p_kind, 'basis', p_basis, 'deduction_pct', p_deduction_pct,
    'rate_pct', v_rate, 'rate_recorded', v_rate is not null,
    'basis_available', v_basis_ok, 'base_amount', case when v_basis_ok then v_base end,
    'current', v_cur,
    'hypotheses', jsonb_build_object('replace_platform', v_a, 'additional_levy', v_b, 'replace_split', v_c));
end $$;

-- Interrupteur : désactivé par défaut ; aucun calcul réel ne le lit (voir l'en-tête).
insert into platform_settings (key, value) values ('commission.engine_enabled', 'false'::jsonb) on conflict (key) do nothing;

create or replace function _commission_engine_enabled() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select value = 'true'::jsonb from platform_settings where key = 'commission.engine_enabled' and jsonb_typeof(value) = 'boolean'), false)
$$;
revoke all on function _commission_engine_enabled() from public, anon, authenticated;

create or replace function _h8_commission_engine_guard() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if new.key <> 'commission.engine_enabled' then return new; end if;
  if jsonb_typeof(new.value) <> 'boolean' then raise exception 'Interrupteur des commissions : true ou false'; end if;
  if auth.uid() is not null then
    if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
    perform _require_staff_aal2();
    -- une écriture « insert … on conflict do update » déclenche ce garde deux fois dans la même transaction : une seule ligne d'audit
    insert into audit_log (actor, action, target, category, level)
    select auth.uid()::text, 'Interrupteur des commissions : ' || case when new.value = 'true'::jsonb then 'activé' else 'désactivé' end, 'commission.engine_enabled', 'Réglages', 'Critique'
    where not exists (select 1 from audit_log a where a.target = 'commission.engine_enabled' and a.actor = auth.uid()::text and a.created_at = now()
      and a.action = 'Interrupteur des commissions : ' || case when new.value = 'true'::jsonb then 'activé' else 'désactivé' end);
  end if;
  return new;
end $$;
revoke all on function _h8_commission_engine_guard() from public, anon, authenticated;
drop trigger if exists trg_h8_commission_engine on platform_settings;
create trigger trg_h8_commission_engine before insert or update of value on platform_settings for each row execute function _h8_commission_engine_guard();

create or replace function commission_engine_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _staff_perm(array['finance.read']) then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object('enabled', _commission_engine_enabled(), 'read_by_calculations', false,
    'note', 'Aucun calcul réel ne lit cet interrupteur : les taux enregistrés ne s''appliquent pas.');
end $$;

create or replace function commission_engine_set(p_enabled boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
  if p_enabled is null then raise exception 'Valeur invalide'; end if;
  insert into platform_settings (key, value, updated_by) values ('commission.engine_enabled', to_jsonb(p_enabled), auth.uid())
  on conflict (key) do update set value = excluded.value, updated_by = auth.uid(), updated_at = now();
  return commission_engine_get();
end $$;

revoke all on function commission_rate_for(text), commission_preview(integer, text, text, numeric), commission_engine_get(), commission_engine_set(boolean) from public, anon;
grant execute on function commission_rate_for(text), commission_preview(integer, text, text, numeric), commission_engine_get(), commission_engine_set(boolean) to authenticated;
