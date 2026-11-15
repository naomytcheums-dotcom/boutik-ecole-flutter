-- Lot L7 (profil Client) : parrainage, retraits de gains, publications en attente, signalements, boutique d'une publication,
-- défis réels, droits et garde-fous des lives.
--
-- BARÈME DE PARRAINAGE PAR DÉFAUT (poser seulement si referral_rules est VIDE ; jamais écrasé si l'administrateur a déjà défini ses paliers) :
--   Bronze  1 à 4 filleuls actifs  : prime de 500 FCFA par filleul qui devient actif
--   Argent  5 à 19 filleuls actifs : 750 FCFA + 2 % des ventes du filleul (12 mois)
--   Or      20 filleuls actifs et + : 1 000 FCFA + 3 % des ventes du filleul (12 mois)
-- Un filleul devient actif à sa 1re commande payée d'au moins 10 000 FCFA dans les 90 jours. Garde-fous : 50 primes par mois et par parrain,
-- part des ventes plafonnée à 5 000 FCFA par commande, les primes et parts sont prélevées sur la commission de la plateforme (10 %).
-- Désactivation : set_referral_rule('Bronze', 1, 0, 0) (idem Argent et Or) arrête toute prime sans supprimer l'historique ; ou
-- delete_referral_rule pour revenir à « barème non défini » (les administrateurs sont alors prévenus une fois par jour).
--
-- Retour arrière : drop trigger trg_pending_post on posts ; drop function trg_notify_pending_post(), my_posts_status(integer), post_shop_target(uuid),
--   author_shop_slug(uuid), report_comment(uuid, text), comment_reports_list(integer), comment_report_close(uuid), live_reports_list(integer),
--   live_report_close(uuid), request_referral_payout(integer, text, text), referral_payouts_list(text), referral_payout_decide(uuid, boolean, text),
--   _referral_available(uuid), _referral_norm_phone(text), _referral_norm_email(text), _streak(uuid), _assert_active(), _can_broadcast(uuid), _clean_live_title(text) ;
--   drop table referral_payouts, comment_reports ; alter table live_reports drop column status ;
--   delete from referral_rules where updated_by is null (barème par défaut) ; puis rejouer les définitions précédentes de claim_referral,
--   on_order_paid_referral, my_referral_summary (20261110000100), my_challenges, claim_challenge, claim_streak_boost, report_post (20261101000600),
--   circle_feed, post_comment_list_v2, create_live, start_live, end_live, join_live, post_live_message, react_live, send_gift, report_live (20261110000000),
--   request_cohost (20261113000100), save_live et create_live (20261114002400).

-- ============================================================ 1. Parrainage
insert into referral_rules (tier, min_active, bonus_fcfa, share_pct)
select v.tier, v.min_active, v.bonus, v.share
from (values ('Bronze', 1, 500, 0::numeric), ('Argent', 5, 750, 0.02), ('Or', 20, 1000, 0.03)) as v(tier, min_active, bonus, share)
where not exists (select 1 from referral_rules);

create or replace function _referral_norm_phone(p text) returns text
language sql immutable as $$
  select nullif(right(regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g'), 9), '')
$$;

-- Adresse comparable : minuscules, sans « +alias », sans points pour gmail.
create or replace function _referral_norm_email(p text) returns text
language plpgsql immutable as $$
declare loc text; dom text;
begin
  if p is null or position('@' in p) = 0 then return null; end if;
  loc := regexp_replace(lower(split_part(p, '@', 1)), '\+.*$', '');
  dom := lower(split_part(p, '@', 2));
  if dom in ('gmail.com', 'googlemail.com') then loc := replace(loc, '.', ''); dom := 'gmail.com'; end if;
  return loc || '@' || dom;
end $$;

create or replace function claim_referral(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; r referral_codes%rowtype; rp profiles%rowtype; my_mail text; ref_mail text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.role::text in ('dept', 'direction', 'finance', 'support', 'admin') then raise exception 'Les comptes du personnel ne participent pas au parrainage'; end if;
  if exists (select 1 from referrals where referee_id = auth.uid()) then raise exception 'Un parrain est déjà enregistré pour votre compte'; end if;
  if (select created_at from auth.users where id = auth.uid()) < now() - interval '30 days' then raise exception 'Le code de parrainage se saisit dans les 30 jours suivant l''inscription'; end if;
  if exists (select 1 from orders where buyer_id = auth.uid() and paid) then raise exception 'Le code de parrainage se saisit avant votre première commande payée'; end if;
  select * into r from referral_codes where code = upper(trim(coalesce(p_code, '')));
  if not found then raise exception 'Code de parrainage inconnu'; end if;
  if r.user_id = auth.uid() then raise exception 'Vous ne pouvez pas vous parrainer vous-même'; end if;
  select * into rp from profiles where id = r.user_id;
  if rp.suspended or rp.role::text in ('dept', 'direction', 'finance', 'support', 'admin') then raise exception 'Code de parrainage inutilisable'; end if;
  if _referral_norm_phone(me.phone) is not null and _referral_norm_phone(me.phone) = _referral_norm_phone(rp.phone) then raise exception 'Parrainage refusé : même numéro de téléphone'; end if;
  select _referral_norm_email(email) into my_mail from auth.users where id = auth.uid();
  select _referral_norm_email(email) into ref_mail from auth.users where id = r.user_id;
  if my_mail is not null and my_mail = ref_mail then raise exception 'Parrainage refusé : même adresse e-mail'; end if;
  if exists (select 1 from referrals where referee_id = r.user_id and referrer_id = auth.uid()) then raise exception 'Parrainage refusé : ce membre est déjà votre filleul'; end if;
  if (select count(*) from referrals where referrer_id = r.user_id and created_at > now() - interval '24 hours') >= 20 then
    raise exception 'Ce code a atteint sa limite quotidienne de parrainages. Réessayez demain.';
  end if;
  insert into referrals (referee_id, referrer_id) values (auth.uid(), r.user_id);
  insert into notifications (user_id, kind, title, body, data)
    values (r.user_id, 'referral', 'Nouveau filleul', 'Un nouvel inscrit a utilisé votre code. La prime sera due à sa première commande payée d’au moins 10 000 FCFA.', jsonb_build_object('referral', true));
  return 'pending';
end $$;
revoke all on function claim_referral(text) from public, anon;
grant execute on function claim_referral(text) to authenticated;

-- Même logique qu'avant ; la part des ventes est plafonnée à 5 000 FCFA par commande.
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
    share := least(floor(new.subtotal * t.share_pct), 5000);
    if share > 0 then
      insert into earnings (user_id, source, referee_id, order_id, amount) values (rf.referrer_id, 'referral_share', rf.referee_id, new.id, share)
      on conflict do nothing;
    end if;
  end if;
  return null;
end $$;

-- Demandes de retrait : le versement est fait par l'équipe finance (Mobile Money), sur demande.
create table if not exists referral_payouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  amount integer not null check (amount >= 1000),
  provider text not null check (provider in ('orange_money', 'mtn_momo')),
  phone text not null check (phone ~ '^6[0-9]{8}$'),
  status text not null default 'requested' check (status in ('requested', 'paid', 'rejected')),
  note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references profiles(id) on delete set null
);
create index if not exists referral_payouts_statut on referral_payouts (status, created_at);
create unique index if not exists referral_payouts_une_ouverte on referral_payouts (user_id) where status = 'requested';
alter table referral_payouts enable row level security;
revoke all on referral_payouts from anon, authenticated;
grant select on referral_payouts to authenticated;
drop policy if exists "retraits : titulaire et finance" on referral_payouts;
create policy "retraits : titulaire et finance" on referral_payouts for select
  using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('finance', 'admin'));

-- Solde disponible : gains échus moins les retraits demandés ou payés.
create or replace function _referral_available(p_user uuid) returns integer
language sql stable security definer set search_path = public as $$
  select greatest(
    coalesce((select sum(amount) from earnings where user_id = p_user and status = 'pending' and available_at <= now()), 0)
    - coalesce((select sum(amount) from referral_payouts where user_id = p_user and status in ('requested', 'paid')), 0), 0)::int
$$;
revoke all on function _referral_available(uuid) from public, anon, authenticated;

create or replace function request_referral_payout(p_amount integer, p_phone text, p_provider text default 'orange_money') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_phone text := _referral_norm_phone(p_phone); v_avail int; v_id uuid; f record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if coalesce(p_provider, '') not in ('orange_money', 'mtn_momo') then raise exception 'Choisissez Orange Money ou MTN MoMo'; end if;
  if v_phone is null or v_phone !~ '^6[0-9]{8}$' then raise exception 'Numéro Mobile Money invalide : 9 chiffres commençant par 6'; end if;
  if exists (select 1 from referral_payouts where user_id = auth.uid() and status = 'requested') then raise exception 'Une demande de retrait est déjà en cours de traitement'; end if;
  if p_amount is null or p_amount < 1000 then raise exception 'Le retrait minimum est de 1 000 FCFA'; end if;
  v_avail := _referral_available(auth.uid());
  if p_amount > v_avail then raise exception 'Montant supérieur à votre solde disponible (% FCFA)', v_avail; end if;
  insert into referral_payouts (user_id, amount, provider, phone) values (auth.uid(), p_amount, p_provider, v_phone) returning id into v_id;
  for f in select id from profiles where role::text in ('finance', 'admin') and not suspended loop
    perform notify_user(f.id, 'money', 'Demande de retrait de gains', display_name(auth.uid()) || ' demande ' || p_amount || ' FCFA (' || case p_provider when 'mtn_momo' then 'MTN MoMo' else 'Orange Money' end || ').', jsonb_build_object('payout', v_id));
  end loop;
  return v_id;
end $$;

create or replace function referral_payouts_list(p_status text default 'requested') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Réservé à la finance'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'user', display_name(x.user_id), 'amount', x.amount, 'provider', x.provider, 'phone', x.phone,
                                                        'status', x.status, 'created_at', x.created_at, 'note', x.note) order by x.created_at)
                   from (select * from referral_payouts where p_status is null or status = p_status order by created_at limit 200) x), '[]'::jsonb);
end $$;

create or replace function referral_payout_decide(p_id uuid, p_paid boolean, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare p referral_payouts%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Réservé à la finance'; end if;
  select * into p from referral_payouts where id = p_id for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if p.status <> 'requested' then raise exception 'Cette demande est déjà traitée'; end if;
  if not p_paid and char_length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'Motif obligatoire pour refuser'; end if;
  update referral_payouts set status = case when p_paid then 'paid' else 'rejected' end, note = nullif(btrim(coalesce(p_note, '')), ''), decided_at = now(), decided_by = auth.uid() where id = p.id;
  perform notify_user(p.user_id, 'money', case when p_paid then 'Retrait de gains effectué' else 'Retrait de gains refusé' end,
                      case when p_paid then p.amount || ' FCFA ont été envoyés sur votre compte Mobile Money.' else coalesce(nullif(btrim(p_note), ''), 'Demande refusée') || ' Votre solde est inchangé.' end,
                      jsonb_build_object('payout', p.id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case when p_paid then 'Retrait de gains payé' else 'Retrait de gains refusé' end, p.id::text, 'Parrainage', 'Sensible');
  return case when p_paid then 'paid' else 'rejected' end;
end $$;

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
    'available', _referral_available(auth.uid()),
    'waiting', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and available_at > now()), 0),
    'this_month', coalesce((select sum(amount) from earnings where user_id = auth.uid() and status = 'pending' and created_at >= date_trunc('month', now())), 0),
    'payout_requested', coalesce((select sum(amount) from referral_payouts where user_id = auth.uid() and status = 'requested'), 0),
    'payout_paid', coalesce((select sum(amount) from referral_payouts where user_id = auth.uid() and status = 'paid'), 0),
    'min_payout', 1000,
    'payouts', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'amount', x.amount, 'status', x.status, 'provider', x.provider, 'at', x.created_at, 'note', x.note) order by x.created_at desc)
                         from (select * from referral_payouts where user_id = auth.uid() order by created_at desc limit 5) x), '[]'::jsonb),
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

revoke all on function request_referral_payout(integer, text, text), referral_payouts_list(text), referral_payout_decide(uuid, boolean, text) from public, anon;
grant execute on function request_referral_payout(integer, text, text), referral_payouts_list(text), referral_payout_decide(uuid, boolean, text) to authenticated;

-- ============================================================ 2. Publications : file de modération, suivi par l'auteur, boutique, signalements
create or replace function trg_notify_pending_post() returns trigger
language plpgsql security definer set search_path = public as $$
declare m record; n int;
begin
  select count(*) into n from posts where status = 'pending';
  for m in
    select p.id from profiles p
    where p.role::text in ('dept', 'admin') and not p.suspended
      and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'post_review' and x.read_at is null and x.created_at > now() - interval '15 minutes')
  loop
    insert into notifications (user_id, kind, title, body, data)
      values (m.id, 'post_review', 'Publications à valider', n || ' publication' || case when n > 1 then 's attendent' else ' attend' end || ' la validation du département.', jsonb_build_object('post', new.id));
  end loop;
  return null;
end $$;
drop trigger if exists trg_pending_post on posts;
create trigger trg_pending_post after insert on posts for each row when (new.status = 'pending') execute function trg_notify_pending_post();

-- Les publications de l'auteur qui attendent la validation (ou qui ont été masquées, avec le motif).
create or replace function my_posts_status(p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'status', x.status, 'text', left(coalesce(nullif(x.body, ''), x.caption, ''), 120),
                                               'media_kind', x.media_kind, 'created_at', x.created_at, 'note', x.review_note) order by x.created_at desc), '[]'::jsonb)
  from (select * from posts where author_id = auth.uid() and status in ('pending', 'hidden') and community_id is null
        order by created_at desc limit least(greatest(coalesce(p_limit, 20), 1), 50)) x
$$;

-- Boutique liée à une publication (annonce approuvée) ou, à défaut, boutique active de l'auteur.
create or replace function post_shop_target(p_post uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('listing_id', l.id, 'shop_slug', coalesce(s.slug, (select o.slug from shops o where o.owner_id = p.author_id and o.status = 'active' limit 1)), 'seller_id', p.author_id)
  from posts p
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  left join shops s on s.id = l.shop_id and s.status = 'active'
  where p.id = p_post and p.status = 'published'
$$;
create or replace function author_shop_slug(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select s.slug from shops s where s.owner_id = p_user and s.status = 'active' order by s.created_at limit 1
$$;
grant execute on function post_shop_target(uuid), author_shop_slug(uuid) to anon, authenticated;
revoke all on function my_posts_status(integer) from public, anon;
grant execute on function my_posts_status(integer) to authenticated;

-- Signalement d'une publication : la modération est prévenue (une notification non lue toutes les 15 minutes au plus).
create or replace function report_post(p_post uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare m record; ins int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from posts where id = p_post and status = 'published') then raise exception 'Publication introuvable'; end if;
  insert into post_reports (post_id, reporter_id, reason) values (p_post, auth.uid(), trim(p_reason))
  on conflict (post_id, reporter_id) do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select p.id from profiles p where p.role::text in ('dept', 'admin', 'support') and not p.suspended
             and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'report' and x.read_at is null and x.created_at > now() - interval '15 minutes') loop
      perform notify_user(m.id, 'report', 'Publication signalée', 'Une publication a été signalée et attend un examen.', jsonb_build_object('post', p_post));
    end loop;
  end if;
  return 'reported';
end $$;

create table if not exists comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references post_comments(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 3 and 300),
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  unique (comment_id, reporter_id)
);
alter table comment_reports enable row level security;
revoke all on comment_reports from anon, authenticated;

create or replace function report_comment(p_comment uuid, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare c post_comments%rowtype; m record; ins int; v_reason text := btrim(coalesce(p_reason, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
  if char_length(v_reason) not between 3 and 300 then raise exception 'Indiquez un motif de 3 à 300 caractères'; end if;
  select * into c from post_comments where id = p_comment and status = 'visible';
  if not found then raise exception 'Commentaire introuvable'; end if;
  if c.author_id = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre commentaire'; end if;
  insert into comment_reports (comment_id, reporter_id, reason) values (p_comment, auth.uid(), v_reason) on conflict (comment_id, reporter_id) do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select p.id from profiles p where p.role::text in ('dept', 'admin', 'support') and not p.suspended
             and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'report' and x.read_at is null and x.created_at > now() - interval '15 minutes') loop
      perform notify_user(m.id, 'report', 'Commentaire signalé', 'Un commentaire a été signalé et attend un examen.', jsonb_build_object('post', c.post_id, 'comment', c.id));
    end loop;
  end if;
  return 'reported';
end $$;

create or replace function comment_reports_list(p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'comment_id', x.comment_id, 'post_id', c.post_id, 'body', left(c.body, 300), 'author', display_name(c.author_id),
                                                        'reason', x.reason, 'reporter', display_name(x.reporter_id), 'status', x.status, 'created_at', x.created_at) order by x.created_at desc)
                   from (select * from comment_reports order by created_at desc limit least(greatest(coalesce(p_limit, 100), 1), 300)) x
                   join post_comments c on c.id = x.comment_id), '[]'::jsonb);
end $$;

create or replace function comment_report_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'support') then raise exception 'Réservé à la modération'; end if;
  update comment_reports set status = 'closed' where id = p_id;
end $$;
revoke all on function report_post(uuid, text), report_comment(uuid, text), comment_reports_list(integer), comment_report_close(uuid) from public, anon;
grant execute on function report_post(uuid, text), report_comment(uuid, text), comment_reports_list(integer), comment_report_close(uuid) to authenticated;

-- Auteur sans nom : « Étudiant » seulement pour un étudiant, « Membre » sinon.
create or replace function circle_feed(p_limit integer default 30)
returns table (id uuid, kind text, author text, author_id uuid, author_avatar text, author_verified boolean,
               media_path text, media_kind text, caption text, tags text[], listing_title text, link_url text,
               likes integer, liked boolean, boosted boolean, published_at timestamptz,
               comments integer, saves integer, shares integer, saved boolean, reposts integer,
               media jsonb, repost_id uuid, repost_author text, repost_author_id uuid, repost_caption text, repost_media_path text, repost_media_kind text)
language sql stable security definer set search_path = public as $$
  select p.id, p.kind,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), case when a.role::text = 'student' then 'Étudiant' else 'Membre' end),
         p.author_id, a.avatar_url, a.certification::text = 'approved',
         p.media_path, p.media_kind, case when p.kind = 'text' then coalesce(p.body, '') else p.caption end, p.tags, l.title, p.link_url,
         (select count(*)::int from post_likes k where k.post_id = p.id),
         exists (select 1 from post_likes k where k.post_id = p.id and k.user_id = auth.uid()),
         exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at),
         p.published_at,
         (select count(*)::int from post_comments c where c.post_id = p.id and c.status = 'visible'),
         (select count(*)::int from post_saves s where s.post_id = p.id),
         (select count(*)::int from post_shares h where h.post_id = p.id),
         exists (select 1 from post_saves s where s.post_id = p.id and s.user_id = auth.uid()),
         (select count(*)::int from posts r where r.repost_of = p.id and r.status = 'published'),
         coalesce((select jsonb_agg(jsonb_build_object('path', pm.path, 'kind', pm.kind, 'w', pm.width, 'h', pm.height) order by pm.pos) from post_media pm where pm.post_id = p.id), '[]'::jsonb),
         rp.id,
         case when rp.id is not null then coalesce(nullif(trim(split_part(ra.name, ' ', 1) || ' ' || case when split_part(ra.name, ' ', 2) <> '' then left(split_part(ra.name, ' ', 2), 1) || '.' else '' end), ''), case when ra.role::text = 'student' then 'Étudiant' else 'Membre' end) end,
         rp.author_id,
         case when rp.id is not null then case when rp.kind = 'text' then coalesce(rp.body, '') else rp.caption end end,
         rp.media_path, rp.media_kind
  from posts p
  join profiles a on a.id = p.author_id and not a.suspended
  left join listings l on l.id = p.listing_id and l.status = 'approved'
  left join posts rp on rp.id = p.repost_of and rp.status = 'published'
  left join profiles ra on ra.id = rp.author_id
  where p.status = 'published' and p.community_id is null
  order by exists (select 1 from post_boosts b where b.post_id = p.id and now() between b.starts_at and b.ends_at) desc, p.published_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
grant execute on function circle_feed(integer) to anon, authenticated;

create or replace function post_comment_list_v2(p_post uuid, p_limit integer default 100)
returns table (id uuid, parent_id uuid, author text, author_id uuid, author_avatar text, author_verified boolean, mine boolean, body text, created_at timestamptz,
               likes integer, liked boolean, attachment_path text, attachment_kind text)
language sql stable security definer set search_path = public as $$
  select c.id, c.parent_id,
         coalesce(nullif(trim(split_part(a.name, ' ', 1) || ' ' || case when split_part(a.name, ' ', 2) <> '' then left(split_part(a.name, ' ', 2), 1) || '.' else '' end), ''), case when a.role::text = 'student' then 'Étudiant' else 'Membre' end),
         c.author_id, a.avatar_url, a.certification::text = 'approved', c.author_id = auth.uid(), c.body, c.created_at,
         (select count(*)::int from comment_likes k where k.comment_id = c.id),
         exists (select 1 from comment_likes k where k.comment_id = c.id and k.user_id = auth.uid()),
         c.attachment_path, c.attachment_kind
  from post_comments c join profiles a on a.id = c.author_id join posts p on p.id = c.post_id
  where c.post_id = p_post and c.status = 'visible' and p.status = 'published'
  order by c.created_at
  limit least(greatest(coalesce(p_limit, 100), 1), 300)
$$;
grant execute on function post_comment_list_v2(uuid, integer) to anon, authenticated;

-- ============================================================ 3. Défis réels
-- Série : on compte à partir d'aujourd'hui si la présence est pointée, sinon à partir d'hier (la série n'est pas perdue avant la fin du jour).
create or replace function _streak(p_user uuid) returns integer
language plpgsql stable security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; n int := 0;
begin
  if not exists (select 1 from daily_checkins where user_id = p_user and day = d) then d := d - 1; end if;
  while exists (select 1 from daily_checkins where user_id = p_user and day = d - n) loop n := n + 1; end loop;
  return n;
end $$;
revoke all on function _streak(uuid) from public, anon, authenticated;

create or replace function my_challenges() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; streak int; wk date := date_trunc('week', d)::date; posts_week int; pts int; rank int;
        ledger int; followers int; best_peak int; sales int; v_marks jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  streak := _streak(auth.uid());
  select count(*) into posts_week from posts
    where author_id = auth.uid() and status = 'published' and repost_of is null and remix_of is null and community_id is null and published_at >= (wk::timestamp at time zone 'Africa/Douala');
  select coalesce(sum(points), 0) into ledger from points_ledger where user_id = auth.uid();
  begin
    pts := points_total(auth.uid());
  exception when undefined_function then
    pts := ledger;
  end;
  select count(*) + 1 into rank from (select user_id, sum(points) s from points_ledger group by user_id) x where x.s > ledger;
  select count(*) into followers from engagements where kind = 'follow' and ref = auth.uid()::text and status = 'active';
  select coalesce(max(peak_viewers), 0) into best_peak from lives where host_id = auth.uid() and status = 'ended';
  select count(*) into sales from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id where l.seller_id = auth.uid() and o.paid and o.cancelled_at is null;
  select jsonb_agg(exists (select 1 from daily_checkins c where c.user_id = auth.uid() and c.day = wk + g) order by g) into v_marks from generate_series(0, 6) g;
  return jsonb_build_object(
    'streak', streak, 'next_reward_in', greatest(6 - streak, 0),
    'checked_today', exists (select 1 from daily_checkins where user_id = auth.uid() and day = d),
    'streak_reward_claimable', streak >= 6 and not exists (select 1 from points_ledger where user_id = auth.uid() and source = 'streak6' and ref = d::text),
    'streak_claimed_today', exists (select 1 from points_ledger where user_id = auth.uid() and source = 'streak6' and ref = d::text),
    'week_marks', v_marks, 'today_index', extract(isodow from d)::int - 1,
    'week_end_days', 7 - extract(isodow from d)::int,
    'posts_week', posts_week, 'posts_goal', 3,
    'posts_claimable', posts_week >= 3 and not exists (select 1 from points_ledger where user_id = auth.uid() and source = 'challenge:posts3' and ref = wk::text),
    'posts_claimed', exists (select 1 from points_ledger where user_id = auth.uid() and source = 'challenge:posts3' and ref = wk::text),
    'points', pts,
    'badges', jsonb_build_object('first_sale', sales > 0, 'followers_100', followers >= 100, 'live_star', best_peak >= 10, 'top10', ledger > 0 and rank <= 10),
    'badge_info', jsonb_build_object('sales', sales, 'followers', followers, 'best_peak', best_peak, 'rank', case when ledger > 0 then rank end)
  );
end $$;

create or replace function claim_challenge(p_code text) returns integer
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; wk date := date_trunc('week', d)::date; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_code <> 'posts3' then raise exception 'Défi indisponible'; end if;
  select count(*) into n from posts
    where author_id = auth.uid() and status = 'published' and repost_of is null and remix_of is null and community_id is null and published_at >= (wk::timestamp at time zone 'Africa/Douala');
  if n < 3 then raise exception 'Défi non atteint : % publication(s) sur 3 cette semaine (les republications ne comptent pas)', n; end if;
  insert into points_ledger (user_id, source, ref, points) values (auth.uid(), 'challenge:posts3', wk::text, 200);
  return 200;
exception when unique_violation then raise exception 'Récompense déjà récupérée cette semaine';
end $$;

create or replace function claim_streak_boost() returns text
language plpgsql security definer set search_path = public as $$
declare d date := (now() at time zone 'Africa/Douala')::date; streak int; p uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  streak := _streak(auth.uid());
  if streak < 6 then raise exception 'Série de % jour(s) : la récompense arrive à 6 jours', streak; end if;
  select id into p from posts where author_id = auth.uid() and status = 'published' order by published_at desc limit 1;
  if p is null then raise exception 'Publiez d''abord un post pour recevoir le boost'; end if;
  if exists (select 1 from post_boosts where user_id = auth.uid() and now() between starts_at and ends_at) then raise exception 'Un boost est déjà actif'; end if;
  insert into points_ledger (user_id, source, ref, points) values (auth.uid(), 'streak6', d::text, 1);
  insert into post_boosts (post_id, user_id) values (p, auth.uid());
  return 'boosted';
exception when unique_violation then raise exception 'Récompense du jour déjà récupérée';
end $$;
revoke all on function my_challenges(), claim_challenge(text), claim_streak_boost() from public, anon;
grant execute on function my_challenges(), claim_challenge(text), claim_streak_boost() to authenticated;

-- ============================================================ 4. Lives : droits, suspension, garde-fous
-- Règle : tout compte connecté et non suspendu peut regarder, discuter et réagir. DIFFUSER (créer, programmer, démarrer, inviter) exige un rôle
-- étudiant, département ou administration, ou une certification approuvée.
create or replace function _assert_active() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and suspended) then raise exception 'Votre compte est suspendu : action impossible. Contactez l’administration.'; end if;
end $$;
revoke all on function _assert_active() from public, anon, authenticated;

create or replace function _can_broadcast(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select not suspended and (role::text in ('student', 'dept', 'admin') or certification::text = 'approved') from profiles where id = p_user), false)
$$;
revoke all on function _can_broadcast(uuid) from public, anon, authenticated;

-- Titre sans lien, sans balise ni caractère de contrôle (il part dans les notifications des abonnés).
create or replace function _clean_live_title(p text) returns text
language sql immutable as $$
  select btrim(regexp_replace(regexp_replace(regexp_replace(coalesce(p, ''), '(https?://|www\.)[^[:space:]]+', '', 'gi'), '[<>]', '', 'g'), '[[:cntrl:][:space:]]+', ' ', 'g'))
$$;

alter table live_reports add column if not exists status text not null default 'open';
alter table live_reports drop constraint if exists live_reports_status_check;
alter table live_reports add constraint live_reports_status_check check (status in ('open', 'closed'));

create or replace function create_live(p_title text, p_description text default '', p_cover_path text default null, p_scheduled_at timestamptz default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare lid uuid; v_title text := _clean_live_title(p_title);
begin
  perform _assert_active();
  if not _can_broadcast(auth.uid()) then raise exception 'La diffusion en direct est réservée aux étudiants, au département et aux comptes certifiés. Vous pouvez regarder tous les lives.'; end if;
  if char_length(v_title) not between 3 and 100 then raise exception 'Le titre doit contenir entre 3 et 100 caractères (sans lien)'; end if;
  if p_cover_path is not null and split_part(p_cover_path, '/', 1) <> auth.uid()::text then raise exception 'Couverture invalide : déposez-la d''abord dans votre dossier'; end if;
  if p_scheduled_at is not null and (p_scheduled_at < now() + interval '1 minute' or p_scheduled_at > now() + interval '90 days') then
    raise exception 'Choisissez une date et une heure à venir (90 jours au plus)';
  end if;
  if (select count(*) from lives where host_id = auth.uid() and status = 'scheduled') >= 10 then raise exception '10 lives programmés au plus'; end if;
  insert into lives (host_id, title, description, cover_path, scheduled_at)
    values (auth.uid(), v_title, left(_clean_live_title(p_description), 500), p_cover_path, p_scheduled_at) returning id into lid;
  return lid;
end $$;

-- Démarrage : 15 minutes au moins entre deux démarrages, 3 diffusions notifiées par jour au plus, abonnés prévenus (500 au plus, les plus anciens d'abord).
create or replace function start_live(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; f record; v_today int;
begin
  perform _assert_active();
  select * into l from lives where id = p_live for update;
  if not found or l.host_id <> auth.uid() then raise exception 'Live introuvable'; end if;
  if l.status = 'live' then return l.room_name; end if;
  if not _can_broadcast(auth.uid()) then raise exception 'La diffusion en direct est réservée aux étudiants, au département et aux comptes certifiés.'; end if;
  if l.status <> 'scheduled' then raise exception 'Ce live est terminé'; end if;
  update lives set status = 'ended', ended_at = now(), viewer_count = 0 where host_id = auth.uid() and status = 'live' and started_at < now() - interval '12 hours';
  if exists (select 1 from lives where host_id = auth.uid() and status = 'live') then raise exception 'Vous avez déjà un live en cours'; end if;
  if exists (select 1 from lives where host_id = auth.uid() and id <> p_live and started_at > now() - interval '15 minutes') then
    raise exception 'Patientez avant de relancer un direct : 15 minutes au moins entre deux démarrages';
  end if;
  update lives set status = 'live', started_at = now() where id = p_live;
  insert into live_messages (live_id, kind, body) values (p_live, 'system', 'Le live a commencé.');
  select count(*) into v_today from lives where host_id = auth.uid() and started_at > now() - interval '24 hours';
  if v_today <= 3 then
    for f in select e.user_id from engagements e join profiles u on u.id = e.user_id and not u.suspended
             where e.kind = 'follow' and e.ref = auth.uid()::text and e.status = 'active' order by e.created_at, e.user_id limit 500 loop
      perform notify_user(f.user_id, 'live', 'Live en direct', _live_author(auth.uid()) || ' est en direct : ' || _clean_live_title(l.title), jsonb_build_object('live', p_live, 'host', auth.uid()));
    end loop;
  end if;
  return l.room_name;
end $$;

create or replace function end_live(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into l from lives where id = p_live for update;
  if not found then raise exception 'Live introuvable'; end if;
  if l.host_id <> auth.uid() and coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Action non autorisée'; end if;
  if l.status in ('ended', 'cancelled') then return l.status; end if;
  update lives set status = case when l.status = 'scheduled' then 'cancelled' else 'ended' end, ended_at = now(), viewer_count = 0 where id = p_live;
  update live_viewers set left_at = now() where live_id = p_live and left_at is null;
  update live_cohosts set status = 'removed', decided_at = now() where live_id = p_live and status in ('requested', 'approved');
  if l.status = 'live' then insert into live_messages (live_id, kind, body) values (p_live, 'system', 'Le live est terminé.'); end if;
  return case when l.status = 'scheduled' then 'cancelled' else 'ended' end;
end $$;

create or replace function join_live(p_live uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype; n int;
begin
  perform _assert_active();
  select * into l from lives where id = p_live;
  if not found or l.status = 'cancelled' then raise exception 'Live introuvable'; end if;
  if l.status <> 'live' then raise exception 'Ce live n''est pas en direct'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Vous ne pouvez pas rejoindre ce live'; end if;
  insert into live_viewers (live_id, user_id) values (p_live, auth.uid())
    on conflict (live_id, user_id) do update set last_seen_at = now(), left_at = null;
  n := _live_recount(p_live);
  return jsonb_build_object('viewers', n, 'room', l.room_name, 'host', l.host_id);
end $$;

create or replace function post_live_message(p_live uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare mid bigint; b text := btrim(coalesce(p_body, ''));
begin
  perform _assert_active();
  if char_length(b) not between 1 and 300 then raise exception 'Message de 1 à 300 caractères'; end if;
  if not exists (select 1 from lives where id = p_live and status = 'live') then raise exception 'Ce live n''est pas en direct'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Vous ne pouvez plus écrire dans ce live'; end if;
  if (select count(*) from live_messages where live_id = p_live and user_id = auth.uid() and kind = 'chat' and created_at > now() - interval '10 seconds') >= 5 then
    raise exception 'Trop de messages en peu de temps. Ralentissez un instant.';
  end if;
  insert into live_messages (live_id, user_id, author, kind, body) values (p_live, auth.uid(), _live_author(auth.uid()), 'chat', b) returning id into mid;
  return mid;
end $$;

create or replace function react_live(p_live uuid, p_emoji text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _assert_active();
  if coalesce(p_emoji, '') not in ('heart', 'fire', 'clap', 'laugh', 'wow') then raise exception 'Réaction inconnue'; end if;
  if not exists (select 1 from lives where id = p_live and status = 'live') then raise exception 'Ce live n''est pas en direct'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Action impossible'; end if;
  if (select count(*) from live_messages where live_id = p_live and user_id = auth.uid() and kind = 'reaction' and created_at > now() - interval '10 seconds') >= 20 then return; end if;
  insert into live_messages (live_id, user_id, author, kind, body) values (p_live, auth.uid(), _live_author(auth.uid()), 'reaction', p_emoji);
end $$;

create or replace function send_gift(p_live uuid, p_gift text, p_qty integer, p_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); l lives%rowtype; g gift_catalog%rowtype; s gift_settings%rowtype; w credit_wallets%rowtype; prev gift_sends%rowtype;
        total bigint; creator bigint; sid uuid;
begin
  perform _assert_active();
  if char_length(coalesce(p_key, '')) not between 8 and 64 then raise exception 'Clé de transaction invalide'; end if;
  insert into credit_wallets (user_id) values (me) on conflict do nothing;
  select * into w from credit_wallets where user_id = me for update;
  select * into prev from gift_sends where sender_id = me and idempotency_key = p_key;
  if found then
    return jsonb_build_object('ok', true, 'duplicate', true, 'id', prev.id, 'credits', prev.credits_total, 'balance', w.balance);
  end if;
  select * into s from gift_settings;
  select * into g from gift_catalog where code = p_gift and active;
  if not found then raise exception 'Cadeau indisponible'; end if;
  if coalesce(p_qty, 0) not between 1 and s.max_quantity then raise exception 'Quantité invalide (1 à % )', s.max_quantity; end if;
  select * into l from lives where id = p_live;
  if not found or l.status <> 'live' then raise exception 'Ce live n''est pas en direct'; end if;
  if l.host_id = me then raise exception 'Vous ne pouvez pas vous offrir un cadeau'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = me) then raise exception 'Action impossible'; end if;
  total := g.credits::bigint * p_qty;
  if w.balance < total then raise exception 'Crédits insuffisants : % requis, % disponibles', total, w.balance; end if;
  creator := (total * s.creator_share_pct) / 100;
  update credit_wallets set balance = balance - total, updated_at = now() where user_id = me;
  insert into creator_earnings (user_id, credits) values (l.host_id, creator)
    on conflict (user_id) do update set credits = creator_earnings.credits + excluded.credits, updated_at = now();
  insert into gift_sends (live_id, sender_id, receiver_id, gift_code, quantity, credits_total, creator_credits, platform_credits, idempotency_key)
    values (p_live, me, l.host_id, g.code, p_qty, total, creator, total - creator, p_key) returning id into sid;
  insert into credit_ledger (user_id, account, delta, kind, ref) values (me, 'wallet', -total, 'gift_sent', sid::text);
  if creator > 0 then insert into credit_ledger (user_id, account, delta, kind, ref) values (l.host_id, 'earnings', creator, 'gift_received', sid::text); end if;
  insert into live_messages (live_id, user_id, author, kind, body, payload)
    values (p_live, me, _live_author(me), 'gift', g.code, jsonb_build_object('gift', g.code, 'name', g.name, 'emoji', g.emoji, 'qty', p_qty, 'credits', total));
  return jsonb_build_object('ok', true, 'duplicate', false, 'id', sid, 'credits', total, 'balance', w.balance - total);
end $$;

create or replace function request_cohost(p_live uuid) returns text
language plpgsql security definer set search_path = public as $$
declare l lives%rowtype;
begin
  perform _assert_active();
  if not _can_broadcast(auth.uid()) then raise exception 'Participer à la diffusion est réservé aux étudiants, au département et aux comptes certifiés'; end if;
  select * into l from lives where id = p_live and status = 'live';
  if not found then raise exception 'Ce live n''est pas en direct'; end if;
  if l.host_id = auth.uid() then raise exception 'Vous êtes déjà l''hôte de ce live'; end if;
  if exists (select 1 from live_bans where live_id = p_live and user_id = auth.uid()) then raise exception 'Vous ne pouvez pas participer à ce live'; end if;
  insert into live_cohosts (live_id, user_id, status) values (p_live, auth.uid(), 'requested')
  on conflict (live_id, user_id) do update set status = case when live_cohosts.status = 'approved' then 'approved' else 'requested' end, decided_at = null;
  return 'demandée';
end $$;

-- Programmation d'un live (agenda) : mêmes droits que create_live, 10 lives programmés au plus.
create or replace function save_live(p_title text, p_starts_at text, p_product text, p_schedule boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare lid uuid; v_title text := _clean_live_title(p_title);
begin
  perform _assert_active();
  if not _can_broadcast(auth.uid()) then raise exception 'La diffusion en direct est réservée aux étudiants, au département et aux comptes certifiés. Vous pouvez regarder tous les lives.'; end if;
  if char_length(v_title) not between 3 and 120 then raise exception 'Titre du live : 3 à 120 caractères (sans lien)'; end if;
  if p_schedule and char_length(trim(coalesce(p_starts_at, ''))) < 3 then raise exception 'Indiquez la date et l''heure du live'; end if;
  if (select count(*) from scheduled_lives where host_id = auth.uid() and status in ('scheduled', 'draft')) >= 10 then raise exception '10 lives programmés au plus'; end if;
  insert into scheduled_lives (host_id, title, starts_at, product_title, status)
  values (auth.uid(), v_title, nullif(left(trim(coalesce(p_starts_at, '')), 60), ''), nullif(left(trim(coalesce(p_product, '')), 120), ''), case when p_schedule then 'scheduled' else 'draft' end)
  returning id into lid;
  return lid;
end $$;

-- Signalement d'un live : la modération (admin, support) est prévenue et peut lire les signalements.
create or replace function report_live(p_live uuid, p_message bigint, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare m record; ins int;
begin
  perform _assert_active();
  if not exists (select 1 from lives where id = p_live) then raise exception 'Live introuvable'; end if;
  insert into live_reports (live_id, reporter_id, message_id, reason) values (p_live, auth.uid(), p_message, btrim(p_reason))
    on conflict do nothing;
  get diagnostics ins = row_count;
  if ins > 0 then
    for m in select p.id from profiles p where p.role::text in ('admin', 'support') and not p.suspended
             and not exists (select 1 from notifications x where x.user_id = p.id and x.kind = 'report' and x.read_at is null and x.created_at > now() - interval '15 minutes') loop
      perform notify_user(m.id, 'report', 'Live signalé', 'Un live a été signalé et attend un examen.', jsonb_build_object('live', p_live));
    end loop;
  end if;
  return 'reported';
end $$;

create or replace function live_reports_list(p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à la modération'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'live_id', x.live_id, 'title', l.title, 'host', _live_author(l.host_id), 'status_live', l.status,
                                                        'reason', x.reason, 'message', m.body, 'reporter', display_name(x.reporter_id), 'status', x.status, 'created_at', x.created_at) order by x.created_at desc)
                   from (select * from live_reports order by created_at desc limit least(greatest(coalesce(p_limit, 100), 1), 300)) x
                   join lives l on l.id = x.live_id
                   left join live_messages m on m.id = x.message_id), '[]'::jsonb);
end $$;

create or replace function live_report_close(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à la modération'; end if;
  update live_reports set status = 'closed' where id = p_id;
end $$;

revoke all on function create_live(text, text, text, timestamptz), start_live(uuid), end_live(uuid), join_live(uuid), post_live_message(uuid, text), react_live(uuid, text),
  send_gift(uuid, text, integer, text), request_cohost(uuid), save_live(text, text, text, boolean), report_live(uuid, bigint, text),
  live_reports_list(integer), live_report_close(uuid) from public, anon;
grant execute on function create_live(text, text, text, timestamptz), start_live(uuid), end_live(uuid), join_live(uuid), post_live_message(uuid, text), react_live(uuid, text),
  send_gift(uuid, text, integer, text), request_cohost(uuid), save_live(text, text, text, boolean), report_live(uuid, bigint, text),
  live_reports_list(integer), live_report_close(uuid) to authenticated;
