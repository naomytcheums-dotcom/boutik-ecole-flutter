-- Parrainage : les récompenses sont définies dans UNE table de configuration (referral_rules), modifiable par l'administrateur.
-- AUCUN montant n'est inventé : la table est livrée VIDE. Tant qu'aucun palier n'est défini, aucune prime n'est créée,
-- l'application affiche « Récompense non définie » et les administrateurs reçoivent une notification (une par jour au plus).
-- Les gains déjà enregistrés ne sont pas modifiés. Additive : aucune donnée supprimée.

create table if not exists referral_rules (
  tier text primary key check (char_length(tier) between 2 and 30),
  min_active integer not null unique check (min_active >= 1),   -- nombre de filleuls actifs à partir duquel le palier s'applique
  bonus_fcfa integer not null check (bonus_fcfa >= 0),            -- prime au parrain par filleul qui devient actif
  share_pct numeric(5,4) not null default 0 check (share_pct >= 0 and share_pct <= 0.5), -- part des ventes du filleul (12 mois)
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles(id) on delete set null
);
alter table referral_rules enable row level security;
revoke all on referral_rules from anon, authenticated;
grant select on referral_rules to authenticated;
drop policy if exists "barème : lecture" on referral_rules;
create policy "barème : lecture" on referral_rules for select to authenticated using (true);

create or replace function set_referral_rule(p_tier text, p_min_active integer, p_bonus integer, p_share_pct numeric default 0) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  insert into referral_rules (tier, min_active, bonus_fcfa, share_pct, updated_by)
    values (trim(p_tier), p_min_active, p_bonus, coalesce(p_share_pct, 0), auth.uid())
  on conflict (tier) do update set min_active = excluded.min_active, bonus_fcfa = excluded.bonus_fcfa,
    share_pct = excluded.share_pct, updated_at = now(), updated_by = auth.uid();
end $$;

create or replace function delete_referral_rule(p_tier text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  delete from referral_rules where tier = p_tier;
end $$;
revoke all on function set_referral_rule(text, integer, integer, numeric), delete_referral_rule(text) from public, anon;
grant execute on function set_referral_rule(text, integer, integer, numeric), delete_referral_rule(text) to authenticated;

-- Palier du parrain, d'après le barème en base (plus aucune valeur écrite dans le code)
drop function if exists referral_tier(uuid);
create function referral_tier(p_referrer uuid)
returns table (tier text, active integer, bonus integer, share_pct numeric, defined boolean)
language sql stable security definer set search_path = public as $$
  with n as (select count(*)::int as c from referrals where referrer_id = p_referrer and status = 'active'),
       r as (select ru.* from referral_rules ru, n where ru.min_active <= n.c order by ru.min_active desc limit 1)
  select coalesce((select r.tier from r), 'Aucun'), n.c, (select r.bonus_fcfa from r), coalesce((select r.share_pct from r), 0),
         exists (select 1 from referral_rules)
  from n
$$;
revoke all on function referral_tier(uuid) from public, anon, authenticated;

-- Paiement confirmé : activation du filleul ; prime et part des ventes UNIQUEMENT si un palier est défini
create or replace function on_order_paid_referral() returns trigger
language plpgsql security definer set search_path = public as $$
declare rf referrals%rowtype; t record; month_count int; share int;
begin
  if not (new.paid and not coalesce(old.paid, false)) or new.cancelled or new.cancelled_at is not null then return null; end if;
  select * into rf from referrals where referee_id = new.buyer_id;
  if not found or rf.status = 'expired' then return null; end if;
  if rf.status = 'pending' then
    if now() > rf.created_at + interval '90 days' then
      update referrals set status = 'expired' where referee_id = rf.referee_id;
      return null;
    end if;
    if new.subtotal < 10000 then return null; end if;
    select count(*) into month_count from referrals where referrer_id = rf.referrer_id and status = 'active' and activated_at >= date_trunc('month', now());
    update referrals set status = 'active', activated_at = now() where referee_id = rf.referee_id;
    select * into t from referral_tier(rf.referrer_id);
    if t.bonus is null then
      -- règle non définie : on le signale aux administrateurs (au plus une fois par jour et par administrateur)
      insert into notifications (user_id, kind, title, body, data)
        select a.id, 'referral', 'Parrainage : récompense non définie',
               'Un filleul est devenu actif mais aucun palier de récompense n''est défini (table referral_rules). Aucune prime n''a été créée.', jsonb_build_object('referral_rules', true)
        from profiles a
        where a.role::text = 'admin'
          and not exists (select 1 from notifications n where n.user_id = a.id and n.title = 'Parrainage : récompense non définie' and n.created_at > now() - interval '1 day');
    elsif t.bonus > 0 and month_count < 50 then
      insert into earnings (user_id, source, referee_id, order_id, amount) values (rf.referrer_id, 'referral_bonus', rf.referee_id, new.id, t.bonus)
      on conflict do nothing;
      insert into notifications (user_id, kind, title, body, data)
        values (rf.referrer_id, 'referral', 'Prime de parrainage', t.bonus || ' FCFA en attente (disponibles sous 14 jours).', jsonb_build_object('order', new.number));
    end if;
    rf.status := 'active'; rf.activated_at := now();
  end if;
  if rf.status = 'active' and now() <= rf.activated_at + interval '12 months' then
    select * into t from referral_tier(rf.referrer_id);
    share := floor(new.subtotal * t.share_pct);
    if share > 0 then
      insert into earnings (user_id, source, referee_id, order_id, amount) values (rf.referrer_id, 'referral_share', rf.referee_id, new.id, share)
      on conflict do nothing;
    end if;
  end if;
  return null;
end $$;

-- Déclaration du parrain : mêmes garde-fous qu'avant, plus un plafond de 20 déclarations par code et par 24 h (prévention des abus)
create or replace function claim_referral(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; r referral_codes%rowtype; rp profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.role::text in ('dept', 'direction', 'finance', 'support', 'admin') then raise exception 'Les comptes du personnel ne participent pas au parrainage'; end if;
  if exists (select 1 from referrals where referee_id = auth.uid()) then raise exception 'Un parrain est déjà enregistré pour votre compte'; end if;
  if (select created_at from auth.users where id = auth.uid()) < now() - interval '30 days' then raise exception 'Le code de parrainage se saisit dans les 30 jours suivant l''inscription'; end if;
  select * into r from referral_codes where code = upper(trim(coalesce(p_code, '')));
  if not found then raise exception 'Code de parrainage inconnu'; end if;
  if r.user_id = auth.uid() then raise exception 'Vous ne pouvez pas vous parrainer vous-même'; end if;
  select * into rp from profiles where id = r.user_id;
  if rp.suspended or rp.role::text in ('dept', 'direction', 'finance', 'support', 'admin') then raise exception 'Code de parrainage inutilisable'; end if;
  if me.phone is not null and me.phone = rp.phone then raise exception 'Parrainage refusé : même numéro de téléphone'; end if;
  if (select count(*) from referrals where referrer_id = r.user_id and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'Ce code a atteint sa limite quotidienne de parrainages. Réessayez demain.';
  end if;
  insert into referrals (referee_id, referrer_id) values (auth.uid(), r.user_id);
  insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'referral', 'Nouveau filleul', 'Un nouvel inscrit a utilisé votre code. La prime sera due à sa première commande payée.', jsonb_build_object('referral', true));
  return 'pending';
end $$;
revoke all on function claim_referral(text) from public, anon;
grant execute on function claim_referral(text) to authenticated;

-- Synthèse de l'écran 243 / 240 : barème réel, état « défini ou non », filleuls et historique des gains
create or replace function my_referral_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from referral_tier(auth.uid());
  return jsonb_build_object(
    'tier', t.tier, 'active', t.active, 'bonus', t.bonus, 'share_pct', t.share_pct, 'rewards_defined', t.defined,
    'rules', coalesce((select jsonb_agg(jsonb_build_object('tier', ru.tier, 'min_active', ru.min_active, 'bonus', ru.bonus_fcfa, 'share_pct', ru.share_pct) order by ru.min_active) from referral_rules ru), '[]'::jsonb),
    'pending_referrals', (select count(*) from referrals where referrer_id = auth.uid() and status = 'pending'),
    'available', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and available_at <= now()), 0),
    'waiting', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and available_at > now()), 0),
    'this_month', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and created_at >= date_trunc('month', now())), 0),
    'referees', coalesce((select jsonb_agg(jsonb_build_object(
        'name', coalesce(nullif(trim(split_part(p.name, ' ', 1) || ' ' || case when split_part(p.name, ' ', 2) <> '' then left(split_part(p.name, ' ', 2), 1) || '.' else '' end), ''), 'Filleul'),
        'status', r.status, 'since', r.created_at,
        'earned', coalesce((select sum(e.amount) from earnings e where e.user_id = auth.uid() and e.referee_id = r.referee_id and e.status = 'pending'), 0))
        order by r.created_at desc)
      from referrals r join profiles p on p.id = r.referee_id where r.referrer_id = auth.uid()), '[]'::jsonb),
    'history', coalesce((select jsonb_agg(jsonb_build_object('at', e.created_at, 'source', e.source, 'amount', e.amount, 'status', e.status, 'available_at', e.available_at) order by e.created_at desc)
      from (select * from earnings where user_id = auth.uid() order by created_at desc limit 30) e), '[]'::jsonb)
  );
end $$;
revoke all on function my_referral_summary() from public, anon;
grant execute on function my_referral_summary() to authenticated;
