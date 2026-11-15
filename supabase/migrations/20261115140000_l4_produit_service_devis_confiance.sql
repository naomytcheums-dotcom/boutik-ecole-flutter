-- Lot L4 : produit, service, devis, confiance produit (écrans 05, 31 à 40, 95b, 170, 172, 211, 212 et fiche marketplace).
-- 1. report_listing : limite par compte et par heure, modération prévenue ; set_report_status : le signaleur est prévenu de la décision.
-- 2. verify_certificate : limite de tentatives infructueuses par appelant (compte ou adresse IP), même forme de réponse.
-- 3. Alerte « Me prévenir » (engagements stock_alert) : notification quand le stock repasse au-dessus de 0.
-- 4. product_extras (annonce d'exemple, matériaux recyclés, certificat lié au produit) et provider_card (prestataire abrégé et photo).
-- 5. Devis : limite par heure, budget borné, notification vendeur avec le contenu, confirmation du montant à l'acceptation,
--    commande au prix du devis de nouveau possible quand la commande précédente a été annulée.
-- 6. product_reviews : auteur abrégé, achat vérifié, total et moyenne de toutes les notes.
-- Retour arrière : recréer report_listing, set_report_status, verify_certificate (language sql stable), request_quote, request_quote_offer,
--   quote_checkout et product_reviews depuis leurs migrations d'origine (20261030000800, 20261101000000, 20261031000000, 20261030000900,
--   20261114000300, 20261114002000, 20261114004100) ; drop function decide_quote(uuid, boolean, integer) puis recréer decide_quote(uuid, boolean) depuis 20261030000900 ;
--   drop trigger trg_fire_stock_engagements on listings ; drop function fire_stock_engagements(), product_extras(uuid), provider_card(uuid, uuid) ;
--   drop table certificate_checks.

-- ============================================================ 1. signalements d'annonces
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
  if (select count(*) from listing_reports where reporter_id = auth.uid() and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Trop de signalements en peu de temps : réessayez dans une heure';
  end if;
  insert into listing_reports (listing_id, reporter_id, reason, details) values (l.id, auth.uid(), p_reason, nullif(left(trim(coalesce(p_details, '')), 2000), '')) returning id into rid;
  insert into notifications (user_id, kind, title, body, data)
  select a.id, 'report', 'Annonce signalée', 'Annonce « ' || l.title || ' » signalée (' || case p_reason when 'fraud' then 'fraude' when 'copied' then 'contenu copié' when 'price' then 'prix anormal' else 'autre motif' end || ').', jsonb_build_object('report_id', rid, 'listing', l.id)
  from profiles a where a.role::text in ('support', 'admin') and a.id <> auth.uid();
  return rid;
end $$;
revoke all on function report_listing(text, text, text) from public, anon;
grant execute on function report_listing(text, text, text) to authenticated;

create or replace function set_report_status(p_report uuid, p_status text) returns text
language plpgsql security definer set search_path = public as $$
declare v_old text; v_title text; v_reporter uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('support', 'dept', 'admin') then raise exception 'Réservé au support, au département ou à l''administration'; end if;
  if p_status not in ('open', 'reviewing', 'closed') then raise exception 'Statut invalide'; end if;
  select r.status, l.title, r.reporter_id into v_old, v_title, v_reporter from listing_reports r join listings l on l.id = r.listing_id where r.id = p_report for update of r;
  if not found then raise exception 'Signalement introuvable'; end if;
  if v_old = p_status then return p_status; end if;
  update listing_reports set status = p_status where id = p_report;
  insert into audit_log (actor, action, target, category, level) values (
    coalesce((select name from profiles where id = auth.uid()), 'Modération'), 'Signalement : ' || v_old || ' → ' || p_status,
    left(coalesce(v_title, ''), 200), 'Modération', 'Sensible');
  if p_status in ('reviewing', 'closed') then
    insert into notifications (user_id, kind, title, body, data)
    values (v_reporter, 'report', case p_status when 'closed' then 'Signalement traité' else 'Signalement en cours d''examen' end,
            'Annonce « ' || coalesce(v_title, '') || ' » : ' || case p_status when 'closed' then 'l''équipe de modération a traité votre signalement.' else 'l''équipe de modération l''examine.' end,
            jsonb_build_object('report_id', p_report));
  end if;
  return p_status;
end $$;
revoke all on function set_report_status(uuid, text) from public, anon;
grant execute on function set_report_status(uuid, text) to authenticated;

-- ============================================================ 2. vérification d'un certificat : limite de tentatives infructueuses
create table if not exists certificate_checks (
  caller text not null,
  at timestamptz not null default now()
);
create index if not exists certificate_checks_caller_idx on certificate_checks (caller, at desc);
create index if not exists certificate_checks_at_idx on certificate_checks (at);
alter table certificate_checks enable row level security;
revoke all on certificate_checks from public, anon, authenticated;

create or replace function verify_certificate(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_code text := upper(left(trim(coalesce(p_code, '')), 40)); v_headers jsonb; v_caller text; v_res jsonb;
begin
  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := null;
  end;
  v_caller := coalesce(auth.uid()::text, nullif(trim(split_part(coalesce(v_headers ->> 'x-forwarded-for', v_headers ->> 'cf-connecting-ip', ''), ',', 1)), ''), 'inconnu');
  if (select count(*) from certificate_checks where caller = v_caller and at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('code', v_code, 'valide', false, 'limite', true);
  end if;
  select jsonb_build_object('code', code, 'objet', subject_title, 'type', subject_kind, 'titulaire', holder_name, 'departement', department,
           'delivre_le', to_char(issued_at, 'DD/MM/YYYY'), 'valide', not revoked, 'motif_revocation', revoked_reason, 'empreinte', fingerprint)
    into v_res from certificates where code = v_code;
  if v_res is null then
    insert into certificate_checks (caller) values (v_caller);
    delete from certificate_checks where at < now() - interval '1 day';
    return jsonb_build_object('code', v_code, 'valide', false, 'introuvable', true);
  end if;
  return v_res;
end $$;
revoke all on function verify_certificate(text) from public;
grant execute on function verify_certificate(text) to anon, authenticated;

-- ============================================================ 3. alerte « Me prévenir » : retour en stock
create or replace function fire_stock_engagements() returns trigger
language plpgsql security definer set search_path = public as $$
declare a record;
begin
  if new.status <> 'approved' or coalesce(old.stock, 0) > 0 or coalesce(new.stock, 0) <= 0 then return null; end if;
  for a in select id, user_id from engagements where kind = 'stock_alert' and ref = 'product:' || new.title and status = 'active' loop
    insert into notifications (user_id, kind, title, body, data)
    values (a.user_id, 'alert', 'De retour en stock', new.title || ' est de nouveau disponible.', jsonb_build_object('listing', new.id));
    update engagements set status = 'done', updated_at = now() where id = a.id;
  end loop;
  return null;
end $$;
revoke all on function fire_stock_engagements() from public, anon, authenticated;
drop trigger if exists trg_fire_stock_engagements on listings;
create trigger trg_fire_stock_engagements after update of stock on listings for each row execute function fire_stock_engagements();

-- ============================================================ 4. informations complémentaires de la fiche produit et prestataire abrégé
create or replace function product_extras(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l listings%rowtype;
begin
  select * into l from listings where id = p_id and status = 'approved';
  if not found then return jsonb_build_object('found', false); end if;
  return jsonb_build_object('found', true, 'showcase', l.showcase, 'recycled', coalesce(l.recycled, false), 'recycled_kg', l.recycled_kg,
    'department', l.department, 'platform', l.seller_id is null,
    'certificate', (select jsonb_build_object('code', c.code, 'valide', not c.revoked, 'delivre_le', to_char(c.issued_at, 'DD/MM/YYYY'), 'departement', c.department)
                    from certificates c where c.listing_id = l.id order by c.revoked, c.issued_at desc limit 1));
end $$;
revoke all on function product_extras(uuid) from public;
grant execute on function product_extras(uuid) to anon, authenticated;

-- Prestataire d'une annonce (ou vendeur désigné) : nom abrégé, photo, filière, vérification, note. Seulement pour un vendeur ayant une annonce publiée.
create or replace function provider_card(p_listing uuid default null, p_seller uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_seller uuid := p_seller; v_p profiles%rowtype; l listings%rowtype; v_avg numeric; v_n integer;
begin
  if p_listing is not null then
    select * into l from listings where id = p_listing and status = 'approved';
    if not found then return jsonb_build_object('found', false); end if;
    v_seller := l.seller_id;
  end if;
  if v_seller is null or not exists (select 1 from listings x where x.seller_id = v_seller and x.status = 'approved') then return jsonb_build_object('found', false); end if;
  select * into v_p from profiles where id = v_seller;
  if not found or coalesce(v_p.suspended, false) then return jsonb_build_object('found', false); end if;
  if p_listing is not null then
    select round(avg(r.rating)::numeric, 1), count(*)::int into v_avg, v_n from reviews r where r.listing_id = p_listing;
  else
    select round(avg(r.rating)::numeric, 1), count(*)::int into v_avg, v_n from reviews r join listings x on x.id = r.listing_id where x.seller_id = v_seller;
  end if;
  return jsonb_build_object('found', true, 'id', v_p.id, 'name', display_name(v_p.id), 'avatar_url', v_p.avatar_url,
    'department', coalesce(v_p.department, ''), 'certified', v_p.certification::text = 'approved', 'rating_avg', v_avg, 'rating_count', v_n);
end $$;
revoke all on function provider_card(uuid, uuid) from public;
grant execute on function provider_card(uuid, uuid) to anon, authenticated;

-- ============================================================ 5. devis
create or replace function request_quote(p_service text, p_brief text, p_budget integer, p_deadline text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; qid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into l from listings where title = p_service and category = 'Services' and status = 'approved' order by (seller_id is null) limit 1;
  if not found then raise exception 'Service introuvable'; end if;
  if l.seller_id is null then raise exception 'Ce service ne reçoit pas de demande de devis'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas demander un devis pour votre propre service'; end if;
  if p_brief is null or char_length(trim(p_brief)) < 10 then raise exception 'Décrivez votre besoin en 10 caractères minimum'; end if;
  if p_budget is not null and (p_budget < 0 or p_budget > 100000000) then raise exception 'Budget invalide : indiquez un montant entre 0 et 100 000 000 FCFA'; end if;
  if exists (select 1 from quote_requests where listing_id = l.id and requester_id = auth.uid() and status in ('requested', 'quoted')) then
    raise exception 'Une demande est déjà en cours pour ce service';
  end if;
  if (select count(*) from quote_requests where requester_id = auth.uid() and created_at > now() - interval '1 hour') >= 8 then
    raise exception 'Trop de demandes de devis en peu de temps : réessayez dans une heure';
  end if;
  insert into quote_requests (listing_id, requester_id, provider_id, brief, budget, deadline)
  values (l.id, auth.uid(), l.seller_id, left(trim(p_brief), 2000), p_budget, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
  returning id into qid;
  insert into notifications (user_id, kind, title, body, data)
  values (l.seller_id, 'quote', 'Nouvelle demande de devis',
          'Service « ' || l.title || ' » : ' || left(regexp_replace(trim(p_brief), '\s+', ' ', 'g'), 120) || case when p_budget is not null then ' (budget ' || p_budget || ' FCFA)' else '' end,
          jsonb_build_object('quote_id', qid));
  return qid;
end $$;

create or replace function request_quote_offer(p_listing uuid, p_brief text, p_budget integer default null, p_deadline text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare l listings%rowtype; qid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into l from listings where id = p_listing and status = 'approved';
  if not found or exists (select 1 from shops s where s.id = l.shop_id and s.status <> 'active') then raise exception 'Cette offre n''est plus disponible'; end if;
  if offer_type_of(l.category) = 'product' then raise exception 'Ce produit s''achète directement : le devis concerne les services, solutions et projets'; end if;
  if l.seller_id is null then raise exception 'Cette offre ne reçoit pas de demande de devis'; end if;
  if l.seller_id = auth.uid() then raise exception 'Vous ne pouvez pas demander un devis pour votre propre offre'; end if;
  if p_brief is null or char_length(trim(p_brief)) < 10 then raise exception 'Décrivez votre besoin en 10 caractères minimum'; end if;
  if p_budget is not null and (p_budget < 0 or p_budget > 100000000) then raise exception 'Budget invalide : indiquez un montant entre 0 et 100 000 000 FCFA'; end if;
  if exists (select 1 from quote_requests where listing_id = l.id and requester_id = auth.uid() and status in ('requested', 'quoted')) then
    raise exception 'Une demande est déjà en cours pour cette offre';
  end if;
  if (select count(*) from quote_requests where requester_id = auth.uid() and created_at > now() - interval '1 hour') >= 8 then
    raise exception 'Trop de demandes de devis en peu de temps : réessayez dans une heure';
  end if;
  insert into quote_requests (listing_id, requester_id, provider_id, brief, budget, deadline)
  values (l.id, auth.uid(), l.seller_id, left(trim(p_brief), 2000), p_budget, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
  returning id into qid;
  insert into notifications (user_id, kind, title, body, data)
  values (l.seller_id, 'quote', 'Nouvelle demande de devis',
          'Offre « ' || l.title || ' » : ' || left(regexp_replace(trim(p_brief), '\s+', ' ', 'g'), 120) || case when p_budget is not null then ' (budget ' || p_budget || ' FCFA)' else '' end,
          jsonb_build_object('quote_id', qid));
  return qid;
end $$;
revoke all on function request_quote(text, text, integer, text), request_quote_offer(uuid, text, integer, text) from public, anon;
grant execute on function request_quote(text, text, integer, text), request_quote_offer(uuid, text, integer, text) to authenticated;

-- Acceptation : le montant que le demandeur a vu est rappelé ; s'il a changé entre-temps, l'acceptation est refusée.
drop function if exists decide_quote(uuid, boolean);
create or replace function decide_quote(p_id uuid, p_accept boolean, p_amount integer default null) returns text
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; t text; s text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_id and requester_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'quoted' then raise exception 'Aucun devis à valider pour cette demande'; end if;
  if p_accept and p_amount is not null and p_amount is distinct from q.quote_amount then
    raise exception 'Le prestataire a modifié son devis : relisez le nouveau montant avant d''accepter';
  end if;
  s := case when p_accept then 'accepted' else 'declined' end;
  update quote_requests set status = s, decided_at = now() where id = q.id;
  select title into t from listings where id = q.listing_id;
  insert into notifications (user_id, kind, title, body, data)
  values (q.provider_id, 'quote', case when p_accept then 'Devis accepté' else 'Devis refusé' end, 'Service « ' || t || ' »', jsonb_build_object('quote_id', q.id));
  return s;
end $$;
revoke all on function decide_quote(uuid, boolean, integer) from public, anon;
grant execute on function decide_quote(uuid, boolean, integer) to authenticated;

-- Commande au prix du devis : si la commande déjà créée a été annulée, une nouvelle commande est créée (le devis reste valable).
create or replace function quote_checkout(p_quote uuid, p_method text default 'Mobile Money') returns jsonb
language plpgsql security definer set search_path = public as $$
declare q quote_requests%rowtype; l listings%rowtype; num text; oid uuid; v_method text := coalesce(nullif(btrim(p_method), ''), 'Mobile Money');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from quote_requests where id = p_quote and requester_id = auth.uid() for update;
  if not found then raise exception 'Devis introuvable'; end if;
  if q.status <> 'accepted' then raise exception 'Acceptez d''abord le devis pour commander'; end if;
  if q.order_number is not null and exists (select 1 from orders where number = q.order_number and cancelled_at is null) then
    return jsonb_build_object('number', q.order_number, 'subtotal', q.quote_amount, 'fee', 0, 'existing', true);
  end if;
  if q.quote_amount is null or q.quote_amount <= 0 then raise exception 'Ce devis n''a pas de montant'; end if;
  select * into l from listings where id = q.listing_id;
  if not found then raise exception 'Offre introuvable'; end if;
  num := '#BE-' || extract(year from now())::int || '-' || lpad(nextval('order_seq')::text, 4, '0');
  perform set_config('app.internal', '1', true);
  perform set_config('app.order_number', num, true);
  insert into orders (number, buyer_id, subtotal, fee, method, status, paid, home_delivery)
    values (num, auth.uid(), q.quote_amount, 0, v_method, 0, false, false) returning id into oid;
  insert into order_lines (order_id, listing_id, title, unit_price, qty) values (oid, l.id, l.title, q.quote_amount, 1);
  perform set_config('app.internal', '', true);
  perform set_config('app.order_number', '', true);
  update quote_requests set order_number = num where id = q.id;
  insert into notifications (user_id, kind, title, body, data)
    values (q.provider_id, 'order', 'Commande au prix du devis', 'Commande ' || num || ' pour « ' || l.title || ' » : ' || q.quote_amount || ' FCFA, à préparer dès le paiement.', jsonb_build_object('order_number', num, 'quote_id', q.id));
  return jsonb_build_object('number', num, 'subtotal', q.quote_amount, 'fee', 0, 'existing', false);
end $$;
revoke all on function quote_checkout(uuid, text) from public, anon;
grant execute on function quote_checkout(uuid, text) to authenticated;

-- ============================================================ 6. avis d'un produit : auteur abrégé, achat vérifié, total et moyenne de toutes les notes
create or replace function product_reviews(p_title text, p_limit integer default 50) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'created_at', r.created_at, 'author', display_name(r.reviewer_id), 'verified', true, 'total', r.total, 'avg', r.avg) order by r.created_at desc), '[]'::jsonb)
  from (select rv.*,
               (select count(*)::int from reviews x where x.listing_id = rv.listing_id) as total,
               (select round(avg(x.rating)::numeric, 1) from reviews x where x.listing_id = rv.listing_id) as avg
        from reviews rv join listings l on l.id = rv.listing_id
        where l.title = p_title and l.status = 'approved'
        order by rv.created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 100)) r
$$;
revoke all on function product_reviews(text, integer) from public;
grant execute on function product_reviews(text, integer) to anon, authenticated;
