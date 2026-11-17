-- Lot F2 (profil Entreprise) — forfaits et paiements.
-- DÉCISION E5-18 / E6-2 / E6-16 (deux systèmes de forfaits) : ils restent distincts mais ne partagent plus de sujet de paiement ambigu.
--   · forfaits d'entreprise (company_plans / company_subscriptions : quotas besoins/offres/concours) : sujet de paiement « cplan:<code>[:<propriétaire>] » ;
--     l'ancien sujet « plan:<code> » reste lu par le déclencheur tant qu'aucune souscription « Offres premium » n'est liée au paiement ;
--   · offres premium (plans / subscriptions : boost_campagnes, gestion_equipe…) : sujet « plan:<code> », activé par payment_set_status (inchangé) ;
--   · le déclencheur on_subscription_paid ne traite jamais un paiement lié à une souscription premium (subscriptions.payment_id), et chaque paiement n'active
--     qu'une seule fois (company_subscriptions.payment_id unique) : aucun double traitement ;
--   · un code de forfait d'entreprise ne peut pas reprendre celui d'une offre premium (company_plan_save) ;
--   · company_team_allowed (20261116120000) continue d'ouvrir l'équipe aux forfaits d'entreprise payants : « Voir les offres » n'est donc plus nécessaire.
--  E5-16  Paiement confirmé mais forfait non activé : le payeur est prévenu, la finance et l'administration sont avisées, le journal d'audit et la note du paiement le disent.
--  E5-17  Renouvellement : les jours restants sont reportés ; un forfait inférieur ne remplace pas un forfait supérieur actif sans confirmation explicite.
--  E5-23  Demande de forfait manuelle : un paiement manuel (référence PAY-…) est créé et lié à la demande ; l'activation par l'administrateur le confirme (audit + lien).
--  E5-24  company_plan_save et company_subscription_activate laissent une trace dans le journal d'audit.
--  Expiration automatique des abonnements d'entreprise (pg_cron : expire-company-subscriptions).
-- Retour arrière : recréer company_activate_internal(uuid, text, integer, text, uuid), company_plan_checkout(text, uuid), company_plan_status(uuid), company_plan_save(jsonb),
--   company_subscription_request(text, uuid), company_subscriptions_pending() et company_subscription_activate(uuid, text, integer, text) et on_subscription_paid() depuis 20261114002600 à 20261114004100 ;
--   select cron.unschedule('expire-company-subscriptions'); drop function expire_company_subscriptions(); alter table company_subscriptions drop column payment_id.

alter table company_subscriptions add column if not exists payment_id uuid references payment_transactions(id) on delete set null;
create unique index if not exists company_subscriptions_payment on company_subscriptions (payment_id) where payment_id is not null;

-- ============================================================ activation interne
drop function if exists company_activate_internal(uuid, text, integer, text, uuid);
create or replace function company_activate_internal(p_owner uuid, p_plan text, p_days integer, p_note text, p_by uuid, p_payment uuid default null, p_force boolean default false) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; cur company_subscriptions%rowtype; cp company_plans%rowtype; v_days integer; v_end timestamptz; v_found boolean; v_carry text := '';
begin
  select * into pl from company_plans where code = p_plan;
  if not found then raise exception 'Forfait introuvable'; end if;
  v_days := coalesce(p_days, nullif(pl.period_days, 0), 30);
  select * into cur from company_subscriptions where owner_id = p_owner and status = 'active' and ends_at > now() order by ends_at desc limit 1;
  v_found := found;
  v_end := now() + make_interval(days => v_days);
  if v_found then
    select * into cp from company_plans where code = cur.plan_code;
    if cur.plan_code <> pl.code and coalesce(cp.price_fcfa, 0) > pl.price_fcfa and not p_force then
      raise exception 'Le forfait « % » est actif jusqu''au % : le remplacer par « % » (inférieur) fait perdre ses avantages. Confirmez le remplacement ou attendez son échéance.', cp.name, to_char(cur.ends_at, 'DD/MM/YYYY'), pl.name;
    end if;
    -- les jours restants du forfait en cours sont reportés (renouvellement anticipé sans perte)
    v_end := cur.ends_at + make_interval(days => v_days);
    v_carry := ' (jours restants reportés)';
  end if;
  update company_subscriptions set status = 'expired' where owner_id = p_owner and status = 'active';
  delete from company_subscriptions where owner_id = p_owner and status = 'requested';
  insert into company_subscriptions (owner_id, plan_code, status, starts_at, ends_at, note, activated_by, payment_id)
  values (p_owner, pl.code, 'active', now(), v_end, nullif(left(btrim(coalesce(p_note, '')), 300), ''), p_by, p_payment);
  insert into notifications (user_id, kind, title, body, data)
    values (p_owner, 'company_plan', 'Forfait activé', 'Votre forfait « ' || pl.name || ' » est actif jusqu''au ' || to_char(v_end, 'DD/MM/YYYY') || v_carry || '.', jsonb_build_object('plan', pl.code));
  return v_end;
end $$;
revoke all on function company_activate_internal(uuid, text, integer, text, uuid, uuid, boolean) from public, anon, authenticated;

-- ============================================================ paiement confirmé -> forfait activé, ou signalement (jamais de perte silencieuse)
create or replace function on_subscription_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; v_code text; v_extra text; v_owner uuid; v_reason text; v_name text;
begin
  if not (new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'subscription') then return null; end if;
  if new.subject like 'cplan:%' then
    v_code := split_part(substr(new.subject, 7), ':', 1);
    v_extra := split_part(new.subject, ':', 3);
  elsif new.subject like 'plan:%' and not exists (select 1 from subscriptions where payment_id = new.id) then
    v_code := split_part(substr(new.subject, 6), ':', 1);
    v_extra := split_part(new.subject, ':', 3);
  else
    return null;
  end if;
  select * into pl from company_plans where code = v_code;
  if not found then return null; end if;
  if exists (select 1 from company_subscriptions where payment_id = new.id and status <> 'requested') then return null; end if;
  begin
    v_owner := coalesce(nullif(v_extra, '')::uuid, new.payer_id);
  exception when others then
    v_owner := null;
  end;
  if v_owner is null then
    v_reason := 'l''entreprise visée par le paiement est introuvable';
  elsif not (v_owner = new.payer_id or exists (select 1 from company_members m join profiles p on p.id = m.user_id
        where m.owner_id = v_owner and m.user_id = new.payer_id and m.status = 'active' and m.role in ('admin', 'finance') and not coalesce(p.suspended, false))) then
    v_reason := 'le payeur n''est ni le propriétaire, ni administrateur, ni finance de l''entreprise';
  elsif new.amount < pl.price_fcfa then
    v_reason := 'montant reçu (' || new.amount || ' FCFA) inférieur au prix du forfait (' || pl.price_fcfa || ' FCFA)';
  elsif not exists (select 1 from company_profiles where owner_id = v_owner and status = 'approved') then
    v_reason := 'l''entreprise n''est pas (ou plus) vérifiée';
  end if;
  if v_reason is null then
    begin
      perform company_activate_internal(v_owner, pl.code, null, 'Payé (' || new.reference || ')', null, new.id, false);
    exception when others then
      v_reason := sqlerrm;
    end;
  end if;
  if v_reason is null then
    insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
    values ('subscription', new.reference, new.payer_id, null, new.amount, new.amount, 'plateforme', 'released', now());
    return null;
  end if;
  -- paiement confirmé mais forfait non activé : payeur, finance et administration sont prévenus
  select company_name into v_name from company_profiles where owner_id = coalesce(v_owner, new.payer_id);
  update payment_transactions set note = left(coalesce(new.note || ' | ', '') || 'Forfait non activé : ' || v_reason, 300) where id = new.id;
  perform notify_user(new.payer_id, 'company_plan', 'Paiement reçu, forfait non activé',
    'Votre paiement ' || new.reference || ' (' || new.amount || ' FCFA) est bien enregistré mais le forfait « ' || pl.name || ' » n''a pas pu être activé : ' || v_reason || '. La finance a été prévenue : vous serez contacté pour l''activation ou le remboursement.',
    jsonb_build_object('payment', new.id, 'plan', pl.code, 'activated', false));
  perform notify_user(s.id, 'payment_review', 'Paiement de forfait non activé',
    new.reference || ' · ' || new.amount || ' FCFA · forfait « ' || pl.name || ' » · ' || coalesce(v_name, 'entreprise inconnue') || ' : ' || v_reason || '. À activer à la main ou à rembourser.',
    jsonb_build_object('payment_id', new.id, 'plan', pl.code, 'owner', v_owner))
    from profiles s where s.role::text in ('finance', 'admin') and not coalesce(s.suspended, false);
  insert into audit_log (actor, action, target, category, level)
  values ('Système', 'Forfait non activé après paiement', left(new.reference || ' : ' || v_reason, 200), 'Finance', 'Critique');
  return null;
end $$;
revoke all on function on_subscription_paid() from public, anon, authenticated;
drop trigger if exists trg_subscription_paid on payment_transactions;
create trigger trg_subscription_paid after update of status on payment_transactions for each row execute function on_subscription_paid();

-- ============================================================ paiement Mobile Money d'un forfait d'entreprise
create or replace function company_plan_checkout(p_plan text, p_owner uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; v_id uuid; v_ref text; v_subject text;
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  if not exists (select 1 from company_profiles where owner_id = v_owner and status = 'approved') then raise exception 'Faites d''abord vérifier votre entreprise'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa <= 0 then raise exception 'Forfait introuvable'; end if;
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

-- ============================================================ situation du forfait (avec la demande manuelle en cours)
create or replace function company_plan_status(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; s company_subscriptions%rowtype; rq company_subscriptions%rowtype; t payment_transactions%rowtype;
begin
  select * into pl from company_current_plan(v_owner);
  select * into s from company_subscriptions where owner_id = v_owner and status = 'active' and ends_at > now() order by ends_at desc limit 1;
  select * into rq from company_subscriptions where owner_id = v_owner and status = 'requested';
  if rq.payment_id is not null then select * into t from payment_transactions where id = rq.payment_id; end if;
  return jsonb_build_object('plan', to_jsonb(pl), 'ends_at', s.ends_at, 'my_role', company_role_of(v_owner),
    'requested', rq.plan_code,
    'requested_payment', case when t.id is null then null else jsonb_build_object('id', t.id, 'reference', t.reference, 'amount', t.amount, 'status', t.status) end,
    'used_needs', (select count(*)::int from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress')),
    'used_offers', (select count(*)::int from opportunities where poster_id = v_owner and status in ('pending', 'published')),
    'used_contests', (select count(*)::int from contest_announcements where poster_id = v_owner and status in ('pending', 'published')));
end $$;
revoke all on function company_plan_status(uuid) from public, anon;
grant execute on function company_plan_status(uuid) to authenticated;

-- ============================================================ demande de forfait avec paiement manuel lié
create or replace function company_subscription_request(p_plan text, p_owner uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := company_effective_owner(p_owner); pl company_plans%rowtype; c company_profiles%rowtype; rq company_subscriptions%rowtype; v_pay uuid; v_subject text;
begin
  if company_role_of(v_owner) not in ('owner', 'admin', 'finance') then raise exception 'Réservé au propriétaire, aux administrateurs et à la finance de l''entreprise'; end if;
  select * into c from company_profiles where owner_id = v_owner;
  if not found or c.status <> 'approved' then raise exception 'Faites d''abord vérifier votre entreprise'; end if;
  select * into pl from company_plans where code = p_plan and active;
  if not found or pl.price_fcfa = 0 then raise exception 'Forfait introuvable'; end if;
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

-- ============================================================ activation manuelle par l'administrateur (journal d'audit, lien avec le paiement)
drop function if exists company_subscription_activate(uuid, text, integer, text);
create or replace function company_subscription_activate(p_owner uuid, p_plan text, p_days integer default null, p_note text default '', p_confirm_replace boolean default false) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare pl company_plans%rowtype; v_days integer; v_end timestamptz; v_pay uuid; t payment_transactions%rowtype; who text; v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into pl from company_plans where code = p_plan;
  if not found then raise exception 'Forfait introuvable'; end if;
  select company_name into v_name from company_profiles where owner_id = p_owner and status = 'approved';
  if v_name is null then raise exception 'Entreprise non vérifiée'; end if;
  v_days := coalesce(p_days, nullif(pl.period_days, 0), 30);
  if v_days < 1 or v_days > 366 then raise exception 'Durée de 1 à 366 jours'; end if;
  select payment_id into v_pay from company_subscriptions where owner_id = p_owner and status = 'requested' and plan_code = pl.code;
  v_end := company_activate_internal(p_owner, pl.code, v_days, p_note, auth.uid(), v_pay, coalesce(p_confirm_replace, false));
  if v_pay is not null then
    select * into t from payment_transactions where id = v_pay;
    -- le paiement lié est confirmé par l'administrateur ; le déclencheur voit la souscription déjà liée et ne traite rien une seconde fois
    if t.status in ('created', 'pending', 'failed') then
      update payment_transactions set status = 'confirmed', decided_at = now(), decided_by = auth.uid(), note = left('Forfait activé par l''administrateur', 300) where id = v_pay;
      insert into payment_messages (transaction_id, sender, body) values (v_pay, 'finance', 'Paiement confirmé et forfait activé par l''administration. Merci !');
      insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, platform_amount, split, status, released_at)
      values ('subscription', t.reference, t.payer_id, null, t.amount, t.amount, 'plateforme', 'released', now());
    end if;
  end if;
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Administrateur'), 'Forfait entreprise activé : ' || pl.name || ' (' || v_days || ' j)', left(v_name || coalesce(' · paiement ' || t.reference, ' · sans paiement lié'), 200), 'Finance', 'Sensible');
  return v_end;
end $$;
revoke all on function company_subscription_activate(uuid, text, integer, text, boolean) from public, anon;
grant execute on function company_subscription_activate(uuid, text, integer, text, boolean) to authenticated;

-- ============================================================ édition des forfaits par l'administrateur (journal d'audit, pas de code partagé avec les offres premium)
create or replace function company_plan_save(p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare v_code text := lower(btrim(coalesce(p->>'code', ''))); who text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if v_code !~ '^[a-z0-9_]{2,30}$' then raise exception 'Code du forfait : lettres minuscules, chiffres ou _ (2 à 30)'; end if;
  if exists (select 1 from plans where code = v_code) then raise exception 'Ce code est déjà utilisé par une offre premium : choisissez-en un autre'; end if;
  insert into company_plans (code, name, price_fcfa, period_days, max_needs, max_offers, max_contests, perks, position, active)
  values (v_code, btrim(coalesce(p->>'name', '')), coalesce((p->>'price_fcfa')::int, 0), coalesce((p->>'period_days')::int, 30), coalesce((p->>'max_needs')::int, 1), coalesce((p->>'max_offers')::int, 1),
          coalesce((p->>'max_contests')::int, 0), left(btrim(coalesce(p->>'perks', '')), 400), coalesce((p->>'position')::int, 0), coalesce((p->>'active')::boolean, true))
  on conflict (code) do update set name = excluded.name, price_fcfa = excluded.price_fcfa, period_days = excluded.period_days, max_needs = excluded.max_needs, max_offers = excluded.max_offers,
    max_contests = excluded.max_contests, perks = excluded.perks, position = excluded.position, active = excluded.active;
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Administrateur'), 'Forfait entreprise modifié', v_code || ' · ' || coalesce((p->>'price_fcfa'), '0') || ' FCFA', 'Finance', 'Sensible');
  return v_code;
end $$;
revoke all on function company_plan_save(jsonb) from public, anon;
grant execute on function company_plan_save(jsonb) to authenticated;

-- ============================================================ file des demandes : référence et état du paiement lié
create or replace function company_subscriptions_pending() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('owner_id', s.owner_id, 'company_name', c.company_name, 'plan_code', s.plan_code, 'plan_name', p.name, 'price_fcfa', p.price_fcfa, 'period_days', p.period_days,
      'requested_at', s.requested_at, 'phone', c.phone, 'email', (select email from auth.users where id = s.owner_id),
      'payment_reference', t.reference, 'payment_status', t.status, 'provider_ref', t.provider_ref) order by s.requested_at)
    from company_subscriptions s join company_profiles c on c.owner_id = s.owner_id join company_plans p on p.code = s.plan_code
    left join payment_transactions t on t.id = s.payment_id where s.status = 'requested'), '[]'::jsonb);
end $$;
revoke all on function company_subscriptions_pending() from public, anon;
grant execute on function company_subscriptions_pending() to authenticated;

-- ============================================================ expiration automatique
-- À planifier chaque heure (pg_cron ci-dessous) : les forfaits échus passent à « expired », l'entreprise est prévenue et retombe sur « Découverte » ;
-- les demandes manuelles dont le paiement a échoué ou été annulé sont abandonnées.
create or replace function expire_company_subscriptions() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer := 0; r record;
begin
  for r in update company_subscriptions set status = 'expired' where status = 'active' and ends_at is not null and ends_at <= now() returning owner_id, plan_code loop
    n := n + 1;
    if not exists (select 1 from company_subscriptions where owner_id = r.owner_id and status = 'active' and ends_at > now()) then
      perform notify_user(r.owner_id, 'company_plan', 'Forfait terminé',
        'Votre forfait « ' || coalesce((select name from company_plans where code = r.plan_code), r.plan_code) || ' » est arrivé à échéance : l''entreprise repasse au forfait Découverte. Renouvelez-le depuis l''accueil entreprise.',
        jsonb_build_object('plan', r.plan_code, 'expired', true));
    end if;
  end loop;
  delete from company_subscriptions s where s.status = 'requested' and s.payment_id is not null
    and exists (select 1 from payment_transactions t where t.id = s.payment_id and t.status in ('failed', 'cancelled'));
  return n;
end $$;
revoke all on function expire_company_subscriptions() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('expire-company-subscriptions') where exists (select 1 from cron.job where jobname = 'expire-company-subscriptions');
  perform cron.schedule('expire-company-subscriptions', '10 * * * *', 'select public.expire_company_subscriptions()');
exception when others then
  raise notice 'pg_cron indisponible : expire_company_subscriptions() doit être planifiée autrement (%).', sqlerrm;
end $$;
