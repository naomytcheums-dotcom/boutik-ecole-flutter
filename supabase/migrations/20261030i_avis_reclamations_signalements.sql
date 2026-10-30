-- Avis vérifiés, réclamations et signalements d'annonces. Aucune écriture directe : tout passe par des fonctions serveur qui contrôlent le droit d'agir.

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  reviewer_id uuid not null references profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) <= 1000),
  created_at timestamptz not null default now(),
  unique (order_id, listing_id)
);
create table if not exists claims (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  claimant_id uuid not null references profiles(id) on delete cascade,
  seller_id uuid references profiles(id) on delete set null,
  reason text not null check (reason in ('not_received', 'damaged', 'cancel_before_prep', 'refund')),
  details text not null check (char_length(details) between 10 and 2000),
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  answer text check (answer is null or char_length(answer) <= 2000),
  answered_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  answered_at timestamptz
);
create table if not exists listing_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (reason in ('fraud', 'copied', 'price', 'other')),
  details text check (details is null or char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  created_at timestamptz not null default now(),
  unique (listing_id, reporter_id)
);
alter table reviews enable row level security;
alter table claims enable row level security;
alter table listing_reports enable row level security;
revoke all on reviews, claims, listing_reports from anon, authenticated;
grant select on reviews to anon, authenticated;
grant select on claims, listing_reports to authenticated;

drop policy if exists "avis publics" on reviews;
create policy "avis publics" on reviews for select using (true);
drop policy if exists "reclamations : demandeur, vendeur, moderation" on claims;
create policy "reclamations : demandeur, vendeur, moderation" on claims for select
  using (claimant_id = auth.uid() or seller_id = auth.uid() or current_role_name() in ('dept', 'admin', 'support'));
drop policy if exists "signalements : auteur et moderation" on listing_reports;
create policy "signalements : auteur et moderation" on listing_reports for select
  using (reporter_id = auth.uid() or current_role_name() in ('dept', 'admin', 'support'));

-- Avis : seul l'acheteur d'une commande payée et non annulée, une fois l'article prêt/livré (ou vendu par la plateforme), un seul avis par article.
create or replace function submit_review(p_order text, p_title text, p_rating integer, p_comment text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; l listings%rowtype; ln order_lines%rowtype; rid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_rating < 1 or p_rating > 5 then raise exception 'La note doit être comprise entre 1 et 5'; end if;
  select * into o from orders where number = p_order and buyer_id = auth.uid();
  if not found then raise exception 'Commande introuvable'; end if;
  if not o.paid or o.cancelled or o.cancelled_at is not null then raise exception 'Seule une commande payée et non annulée peut être évaluée'; end if;
  select ol.* into ln from order_lines ol where ol.order_id = o.id and ol.title = p_title limit 1;
  if not found then raise exception 'Article introuvable dans cette commande'; end if;
  select * into l from listings where id = ln.listing_id;
  if l.seller_id is not null and ln.fulfillment < 3 then raise exception 'Vous pourrez évaluer cet article quand le vendeur l''aura préparé'; end if;
  if exists (select 1 from reviews where order_id = o.id and listing_id = l.id) then raise exception 'Vous avez déjà évalué cet article'; end if;
  insert into reviews (order_id, listing_id, reviewer_id, rating, comment) values (o.id, l.id, auth.uid(), p_rating, nullif(trim(p_comment), '')) returning id into rid;
  if l.seller_id is not null then
    insert into notifications (user_id, kind, title, body, data)
    values (l.seller_id, 'review', 'Nouvel avis', p_rating || '/5 sur « ' || l.title || ' »', jsonb_build_object('listing_id', l.id));
  end if;
  return rid;
end $$;

-- Réclamation : l'acheteur de la commande ; une seule réclamation ouverte par commande ; le vendeur concerné est notifié.
create or replace function submit_claim(p_order text, p_reason text, p_details text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; seller uuid; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_order and buyer_id = auth.uid();
  if not found then raise exception 'Commande introuvable'; end if;
  if p_reason not in ('not_received', 'damaged', 'cancel_before_prep', 'refund') then raise exception 'Motif invalide'; end if;
  if p_details is null or char_length(trim(p_details)) < 10 then raise exception 'Décrivez le problème en 10 caractères minimum'; end if;
  if exists (select 1 from claims where order_id = o.id and status = 'open') then raise exception 'Une réclamation est déjà ouverte pour cette commande'; end if;
  select l.seller_id into seller from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null order by ol.id limit 1;
  insert into claims (order_id, claimant_id, seller_id, reason, details) values (o.id, auth.uid(), seller, p_reason, left(trim(p_details), 2000)) returning id into cid;
  if seller is not null then
    insert into notifications (user_id, kind, title, body, data)
    values (seller, 'claim', 'Réclamation reçue', 'Commande ' || o.number || ' : une réclamation a été déposée.', jsonb_build_object('order_number', o.number, 'claim_id', cid));
  end if;
  return cid;
end $$;

-- Réponse : le vendeur concerné ou la modération (département, administrateur, support) ; le demandeur est notifié.
create or replace function answer_claim(p_claim uuid, p_message text) returns text
language plpgsql security definer set search_path = public as $$
declare c claims%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from claims where id = p_claim;
  if not found then raise exception 'Réclamation introuvable'; end if;
  if not (c.seller_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support')) then raise exception 'Réclamation introuvable'; end if;
  if p_message is null or char_length(trim(p_message)) = 0 then raise exception 'Réponse vide'; end if;
  update claims set answer = left(trim(p_message), 2000), answered_by = auth.uid(), answered_at = now(), status = 'answered' where id = c.id;
  insert into notifications (user_id, kind, title, body, data)
  values (c.claimant_id, 'claim', 'Réponse à votre réclamation', left(trim(p_message), 120), jsonb_build_object('claim_id', c.id));
  return 'answered';
end $$;

-- Signalement d'une annonce : tout compte connecté, une fois par annonce ; jamais sur sa propre annonce.
create or replace function report_listing(p_title text, p_reason text, p_details text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; rid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_reason not in ('fraud', 'copied', 'price', 'other') then raise exception 'Motif invalide'; end if;
  select * into l from listings where title = p_title and status = 'approved' order by (seller_id is null) limit 1;
  if not found then raise exception 'Annonce introuvable'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas signaler votre propre annonce'; end if;
  if exists (select 1 from listing_reports where listing_id = l.id and reporter_id = auth.uid()) then raise exception 'Vous avez déjà signalé cette annonce'; end if;
  insert into listing_reports (listing_id, reporter_id, reason, details) values (l.id, auth.uid(), p_reason, nullif(left(trim(coalesce(p_details, '')), 2000), '')) returning id into rid;
  return rid;
end $$;

-- Note moyenne publique d'une annonce.
create or replace function listing_rating(p_title text) returns table (average numeric, total integer)
language sql stable security definer set search_path = public as $$
  select round(avg(r.rating)::numeric, 1), count(*)::int from reviews r join listings l on l.id = r.listing_id where l.title = p_title
$$;

revoke all on function submit_review(text, text, integer, text), submit_claim(text, text, text), answer_claim(uuid, text), report_listing(text, text, text) from public, anon;
grant execute on function submit_review(text, text, integer, text), submit_claim(text, text, text), answer_claim(uuid, text), report_listing(text, text, text) to authenticated;
revoke all on function listing_rating(text) from public;
grant execute on function listing_rating(text) to anon, authenticated;
