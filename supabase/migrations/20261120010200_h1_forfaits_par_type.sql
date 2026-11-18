-- Lot H1 (Organisation) 3/5 — forfaits et quotas adaptés au type d'organisation.
-- Constat : les forfaits de company_plans s'adressaient aux seules « entreprises » (Découverte / Entreprise / Partenaire). Une association, une ONG ou une
-- institution doit pouvoir publier des besoins, offres et concours aux mêmes conditions de vérification, avec un forfait payant adapté à une structure non commerciale.
--   · company_plans.audience_types : types d'organisation concernés (vide = tous) ; le forfait payant « Organisation solidaire » (types non commerciaux) est ajouté ;
--     « Découverte » et « Partenaire » restent ouverts à tous les types : aucune inégalité injustifiée sur les quotas ;
--   · le forfait historique « Entreprise » s'appelle désormais « Organisation » ;
--   · company_plans_list ne propose à une organisation que les forfaits de son type ; company_plan_checkout, company_subscription_request et le déclencheur
--     de company_subscriptions refusent un forfait étranger au type (aucun paiement pour un forfait qui ne s'activerait pas).
-- Retour arrière : recréer company_plans_list depuis 20261114002600, company_plan_checkout et company_subscription_request depuis 20261118020100 ;
--   drop trigger trg_company_subscription_audience on company_subscriptions; drop function _company_plan_check(uuid, text), company_subscription_audience();
--   delete from company_plans where code = 'solidaire'; alter table company_plans drop column audience_types.

alter table company_plans add column if not exists audience_types text[] not null default '{}';

update company_plans set name = 'Organisation', perks = 'Jusqu''à 10 besoins, 10 offres et 2 concours actifs en même temps.' where code = 'pro' and name = 'Entreprise';

insert into company_plans (code, name, price_fcfa, period_days, max_needs, max_offers, max_contests, perks, position, audience_types) values
  ('solidaire', 'Organisation solidaire', 10000, 30, 10, 10, 2, 'Pour associations, ONG, coopératives, fondations et institutions : jusqu''à 10 besoins, 10 offres et 2 concours actifs en même temps.', 2,
   '{association,ong,cooperative,fondation,institution,structure_partenaire,autre_reconnue}')
on conflict (code) do nothing;

-- Un forfait est-il ouvert au type de cette organisation ? (interne)
create or replace function _company_plan_check(p_owner uuid, p_plan text) returns void
language plpgsql stable security definer set search_path = public as $$
declare v_type text; v_aud text[]; v_name text;
begin
  select audience_types, name into v_aud, v_name from company_plans where code = p_plan;
  if not found then return; end if;
  if cardinality(v_aud) = 0 then return; end if;
  select org_type into v_type from company_profiles where owner_id = p_owner;
  if v_type is null or not (v_type = any (v_aud)) then
    raise exception 'Le forfait « % » ne concerne pas ce type d''organisation', v_name;
  end if;
end $$;
revoke all on function _company_plan_check(uuid, text) from public, anon, authenticated;

create or replace function company_subscription_audience() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _company_plan_check(new.owner_id, new.plan_code);
  return new;
end $$;
revoke all on function company_subscription_audience() from public, anon, authenticated;
drop trigger if exists trg_company_subscription_audience on company_subscriptions;
create trigger trg_company_subscription_audience before insert on company_subscriptions for each row execute function company_subscription_audience();

-- Les forfaits proposés : ceux du type de l'appelant (l'administrateur voit tout ; sans fiche, tout est proposé et le serveur filtre à la demande).
create or replace function company_plans_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(p) order by p.position, p.price_fcfa), '[]'::jsonb)
  from company_plans p
  where coalesce(current_role_name()::text, '') = 'admin'
     or (p.active and (cardinality(p.audience_types) = 0
                       or not exists (select 1 from company_profiles c where c.owner_id = auth.uid())
                       or (select c.org_type from company_profiles c where c.owner_id = auth.uid()) = any (p.audience_types)))
$$;

create or replace function company_plan_checkout(p_plan text, p_owner uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; v_id uuid; v_ref text; v_subject text;
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''organisation'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner and status = 'approved') then raise exception 'Faites d''abord vérifier votre organisation'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa <= 0 then raise exception 'Forfait introuvable'; end if;
  perform _company_plan_check(v_owner, pl.code);
  -- forfait supérieur déjà actif : refus avant le débit (pas de paiement qui n'activerait rien)
  if exists (select 1 from company_subscriptions s join company_plans cp on cp.code = s.plan_code
             where s.owner_id = v_owner and s.status = 'active' and s.ends_at > now() and s.plan_code <> pl.code and cp.price_fcfa > pl.price_fcfa) then
    raise exception 'Un forfait supérieur est déjà actif : attendez son échéance avant de passer à « % ».', pl.name;
  end if;
  v_subject := 'cplan:' || pl.code || case when v_owner <> auth.uid() then ':' || v_owner::text else '' end;
  -- une transaction déjà créée et non débitée est reprise (pas de nouvelle transaction à chaque pression)
  select id into v_id from payment_transactions
    where payer_id = auth.uid() and kind = 'subscription' and subject = v_subject and provider = 'tara' and status in ('created', 'failed') and amount = pl.price_fcfa
    order by created_at desc limit 1;
  if v_id is null then
    v_id := payment_start('subscription', v_subject, pl.price_fcfa, 'tara');
  end if;
  select reference into v_ref from payment_transactions where id = v_id;
  return jsonb_build_object('id', v_id, 'reference', v_ref, 'amount', pl.price_fcfa, 'plan', pl.name);
end $$;
revoke all on function company_plan_checkout(text, uuid) from public, anon;
grant execute on function company_plan_checkout(text, uuid) to authenticated;

create or replace function company_subscription_request(p_plan text, p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; c company_profiles%rowtype; rq company_subscriptions%rowtype; v_pay uuid; v_subject text;
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''organisation'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  if not found or c.status <> 'approved' then raise exception 'Faites d''abord vérifier votre organisation'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa = 0 then raise exception 'Forfait introuvable'; end if;
  perform _company_plan_check(v_owner, pl.code);
  if exists (select 1 from company_subscriptions s join company_plans cp on cp.code = s.plan_code
             where s.owner_id = v_owner and s.status = 'active' and s.ends_at > now() and s.plan_code <> pl.code and cp.price_fcfa > pl.price_fcfa) then
    raise exception 'Un forfait supérieur est déjà actif : attendez son échéance avant de passer à « % ».', pl.name;
  end if;
  v_subject := 'cplan:' || pl.code || case when v_owner <> auth.uid() then ':' || v_owner::text else '' end;
  select * into rq from company_subscriptions where owner_id = v_owner and status = 'requested';
  if found and rq.plan_code = pl.code and rq.payment_id is not null
     and exists (select 1 from payment_transactions where id = rq.payment_id and status in ('created', 'pending', 'failed')) then
    v_pay := rq.payment_id;
  else
    if found and rq.payment_id is not null then
      update payment_transactions set status = 'cancelled', decided_at = now(), note = 'Demande de forfait remplacée' where id = rq.payment_id and status in ('created', 'pending', 'failed');
    end if;
    v_pay := payment_start('subscription', v_subject, pl.price_fcfa, 'manual');
  end if;
  begin
    insert into company_subscriptions (owner_id, plan_code, payment_id) values (v_owner, pl.code, v_pay);
  exception when unique_violation then
    update company_subscriptions set plan_code = pl.code, requested_at = now(), payment_id = v_pay where owner_id = v_owner and status = 'requested';
  end;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'company_plan', 'Forfait demandé', c.company_name || ' demande le forfait « ' || pl.name || ' » (' || pl.price_fcfa || ' FCFA).', jsonb_build_object('owner', v_owner, 'plan', pl.code, 'payment_id', v_pay) from profiles a where a.role::text = 'admin';
  return 'requested';
end $$;
revoke all on function company_subscription_request(text, uuid) from public, anon;
grant execute on function company_subscription_request(text, uuid) to authenticated;

-- Édition d'un forfait par l'administrateur : types concernés (audience_types) en plus des quotas, avec trace dans le journal d'audit.
create or replace function company_plan_save(p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare v_code text := lower(btrim(coalesce(p->>'code', ''))); who text; v_aud text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if v_code !~ '^[a-z0-9_]{2,30}$' then raise exception 'Code du forfait : lettres minuscules, chiffres ou _ (2 à 30)'; end if;
  if exists (select 1 from plans where code = v_code) then raise exception 'Ce code est déjà utilisé par une offre premium : choisissez-en un autre'; end if;
  if p ? 'audience_types' then
    select coalesce(array_agg(x), '{}') into v_aud from jsonb_array_elements_text(coalesce(p->'audience_types', '[]'::jsonb)) x;
    if exists (select 1 from unnest(v_aud) t where not exists (select 1 from org_types where code = t)) then raise exception 'Type d''organisation inconnu'; end if;
  end if;
  insert into company_plans (code, name, price_fcfa, period_days, max_needs, max_offers, max_contests, perks, position, active, audience_types)
  values (v_code, btrim(coalesce(p->>'name', '')), coalesce((p->>'price_fcfa')::int, 0), coalesce((p->>'period_days')::int, 30), coalesce((p->>'max_needs')::int, 1), coalesce((p->>'max_offers')::int, 1),
          coalesce((p->>'max_contests')::int, 0), left(btrim(coalesce(p->>'perks', '')), 400), coalesce((p->>'position')::int, 0), coalesce((p->>'active')::boolean, true), coalesce(v_aud, '{}'))
  on conflict (code) do update set name = excluded.name, price_fcfa = excluded.price_fcfa, period_days = excluded.period_days, max_needs = excluded.max_needs, max_offers = excluded.max_offers,
    max_contests = excluded.max_contests, perks = excluded.perks, position = excluded.position, active = excluded.active,
    audience_types = case when p ? 'audience_types' then excluded.audience_types else company_plans.audience_types end;
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Administrateur'), 'Forfait d''organisation modifié', v_code || ' · ' || coalesce((p->>'price_fcfa'), '0') || ' FCFA', 'Finance', 'Sensible');
  return v_code;
end $$;
revoke all on function company_plan_save(jsonb) from public, anon;
grant execute on function company_plan_save(jsonb) to authenticated;

