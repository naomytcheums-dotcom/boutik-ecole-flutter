-- Parrainage et gains (écrans 240, 243), selon REGLES_METIER_PROPOSEES.md § 3.
-- Un filleul devient ACTIF à sa première commande PAYÉE d'au moins 10 000 FCFA dans les 90 jours suivant le parrainage.
-- Prime au parrain selon son palier (Bronze 1-4 : 500 F ; Argent 5-19 : 750 F + 2 % ; Or 20+ : 1 000 F + 3 %) ; la part des
-- ventes (12 mois) est prise sur la commission de 10 % de la plateforme. Gains « en attente » 14 jours, annulés si la
-- commande est annulée. AUCUN versement : le retrait vers Mobile Money n'existe pas tant que les paiements ne sont pas activés.
-- Aucune donnée existante n'est modifiée.

create table if not exists referral_codes (
  user_id uuid primary key references profiles(id) on delete cascade,
  code text not null unique check (code ~ '^[A-Z0-9]{8}$'),
  created_at timestamptz not null default now()
);

create table if not exists referrals (
  referee_id uuid primary key references profiles(id) on delete cascade,
  referrer_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'active', 'expired')),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  constraint referrals_pas_soi check (referee_id <> referrer_id)
);
create index if not exists referrals_parrain on referrals (referrer_id);

create table if not exists earnings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  source text not null check (source in ('referral_bonus', 'referral_share')),
  referee_id uuid references profiles(id) on delete set null,
  order_id uuid references orders(id) on delete set null,
  amount integer not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending', 'void')),
  available_at timestamptz not null default now() + interval '14 days',
  created_at timestamptz not null default now()
);
create unique index if not exists earnings_prime_unique on earnings (referee_id) where source = 'referral_bonus';
create unique index if not exists earnings_part_unique on earnings (order_id, user_id) where source = 'referral_share';

alter table referral_codes enable row level security;
alter table referrals enable row level security;
alter table earnings enable row level security;
revoke all on referral_codes, referrals, earnings from anon, authenticated;
grant select on referral_codes, referrals, earnings to authenticated;
drop policy if exists "code : titulaire" on referral_codes;
create policy "code : titulaire" on referral_codes for select using (user_id = auth.uid());
drop policy if exists "parrainage : parrain ou filleul" on referrals;
create policy "parrainage : parrain ou filleul" on referrals for select using (referrer_id = auth.uid() or referee_id = auth.uid());
drop policy if exists "gains : titulaire et finance" on earnings;
create policy "gains : titulaire et finance" on earnings for select using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('finance', 'admin'));

-- Code personnel (créé à la première demande ; 8 caractères sans ambiguïté, aléa cryptographique)
create or replace function my_referral_code() returns text
language plpgsql security definer set search_path = public, extensions as $$
declare c text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; i int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select code into c from referral_codes where user_id = auth.uid();
  if found then return c; end if;
  loop
    b := gen_random_bytes(8); c := '';
    for i in 0..7 loop c := c || substr(alphabet, 1 + (get_byte(b, i) % 32), 1); end loop;
    begin
      insert into referral_codes (user_id, code) values (auth.uid(), c);
      return c;
    exception when unique_violation then
      if exists (select 1 from referral_codes where user_id = auth.uid()) then return (select code from referral_codes where user_id = auth.uid()); end if;
    end;
  end loop;
end $$;

-- Le filleul déclare son parrain : dans les 30 jours suivant son inscription, une seule fois, jamais soi-même ni le personnel.
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
  insert into referrals (referee_id, referrer_id) values (auth.uid(), r.user_id);
  insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'referral', 'Nouveau filleul', 'Un nouvel inscrit a utilisé votre code. La prime sera due à sa première commande payée.', jsonb_build_object('referral', true));
  return 'pending';
end $$;

-- Palier et barème du parrain (nombre de filleuls actifs)
create or replace function referral_tier(p_referrer uuid)
returns table (tier text, active integer, bonus integer, share_pct numeric)
language sql stable security definer set search_path = public as $$
  with n as (select count(*)::int as c from referrals where referrer_id = p_referrer and status = 'active')
  select case when c >= 20 then 'Or' when c >= 5 then 'Argent' when c >= 1 then 'Bronze' else 'Aucun' end, c,
         case when c >= 20 then 1000 when c >= 5 then 750 else 500 end,
         case when c >= 20 then 0.03 when c >= 5 then 0.02 else 0 end
  from n
$$;

-- Paiement confirmé d'une commande : activation du filleul et gains du parrain (jamais sur une commande annulée)
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
    if month_count < 50 then
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
drop trigger if exists trg_order_paid_referral on orders;
create trigger trg_order_paid_referral after update of paid on orders for each row execute function on_order_paid_referral();

-- Commande annulée ou remboursée : les gains en attente qui en dépendent sont annulés
create or replace function on_order_cancelled_referral() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.cancelled or new.cancelled_at is not null) and not (coalesce(old.cancelled, false) or old.cancelled_at is not null) then
    update earnings set status = 'void' where order_id = new.id and status = 'pending';
  end if;
  return null;
end $$;
drop trigger if exists trg_order_cancelled_referral on orders;
create trigger trg_order_cancelled_referral after update of cancelled, cancelled_at on orders for each row execute function on_order_cancelled_referral();

-- Synthèse pour l'écran 243 : soldes, filleuls (« Prénom I. »), palier ; aucun montant n'est « versé »
create or replace function my_referral_summary() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from referral_tier(auth.uid());
  return jsonb_build_object(
    'tier', t.tier, 'active', t.active, 'bonus', t.bonus, 'share_pct', t.share_pct,
    'pending_referrals', (select count(*) from referrals where referrer_id = auth.uid() and status = 'pending'),
    'available', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and available_at <= now()), 0),
    'waiting', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and available_at > now()), 0),
    'this_month', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and created_at >= date_trunc('month', now())), 0),
    'referees', coalesce((select jsonb_agg(jsonb_build_object(
        'name', coalesce(nullif(trim(split_part(p.name, ' ', 1) || ' ' || case when split_part(p.name, ' ', 2) <> '' then left(split_part(p.name, ' ', 2), 1) || '.' else '' end), ''), 'Filleul'),
        'status', r.status,
        'earned', coalesce((select sum(e.amount) from earnings e where e.user_id = auth.uid() and e.referee_id = r.referee_id and e.status = 'pending'), 0))
        order by r.created_at desc)
      from referrals r join profiles p on p.id = r.referee_id where r.referrer_id = auth.uid()), '[]'::jsonb)
  );
end $$;

revoke all on function my_referral_code(), claim_referral(text), referral_tier(uuid), my_referral_summary() from public, anon;
grant execute on function my_referral_code(), claim_referral(text), my_referral_summary() to authenticated;
revoke execute on function on_order_paid_referral(), on_order_cancelled_referral() from public, anon, authenticated;

-- Retour arrière (manuel) : drop trigger trg_order_paid_referral on orders; drop trigger trg_order_cancelled_referral on orders;
-- drop function on_order_paid_referral(), on_order_cancelled_referral(), my_referral_summary(), referral_tier(uuid), claim_referral(text), my_referral_code();
-- drop table earnings, referrals, referral_codes;
