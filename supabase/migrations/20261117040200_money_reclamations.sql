-- Lot MONEY (3/6) : réclamations. S4-51/52/53/54.
-- S4-51 : une réclamation ouverte OU répondue-non-tranchée bloque le séquestre jusqu'à décision (le vendeur ne neutralise plus le gel en répondant « ok »).
-- S4-52 : une réclamation close n'est plus modifiable ; les échanges sont conservés (claim_messages), horodatés.
-- S4-53 : la clôture / la décision relance le déblocage (« release ») ou le remboursement (« refund », voir 20261117040100).
-- S4-54 : réclamation multi-vendeurs : chaque vendeur de la commande est rattaché (claim_sellers), lit, répond et est notifié.
-- Retour arrière : drop function claim_decide(uuid, text, text), claim_withdraw(uuid, text), claim_thread(uuid), my_claims() ; drop table claim_messages, claim_sellers ; alter table claims drop column decision, decided_by, decided_at ;
--   recréer submit_claim (20261115150000), answer_claim (20261030000800), dispute_close (20261107000000) ; drop policy "reclamations : vendeurs rattaches" on claims.

alter table claims add column if not exists decision text;
alter table claims add column if not exists decided_by uuid references profiles(id) on delete set null;
alter table claims add column if not exists decided_at timestamptz;
alter table claims drop constraint if exists claims_decision_check;
alter table claims add constraint claims_decision_check check (decision is null or decision in ('release', 'refund'));

create table if not exists claim_sellers (
  claim_id uuid not null references claims(id) on delete cascade,
  seller_id uuid not null references profiles(id) on delete cascade,
  primary key (claim_id, seller_id)
);
create index if not exists claim_sellers_seller on claim_sellers (seller_id);
create table if not exists claim_messages (
  id bigint generated always as identity primary key,
  claim_id uuid not null references claims(id) on delete cascade,
  author_id uuid references profiles(id) on delete set null,
  author_role text not null check (author_role in ('buyer', 'seller', 'staff')),
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists claim_messages_claim on claim_messages (claim_id, created_at);
alter table claim_sellers enable row level security;
alter table claim_messages enable row level security;
revoke all on claim_sellers, claim_messages from anon, authenticated;
grant select on claim_sellers, claim_messages to authenticated;
drop policy if exists "reclamations : vendeurs rattaches" on claims;
create policy "reclamations : vendeurs rattaches" on claims for select
  using (exists (select 1 from claim_sellers cs where cs.claim_id = claims.id and cs.seller_id = auth.uid()));
drop policy if exists "rattachements : le vendeur et la moderation" on claim_sellers;
create policy "rattachements : le vendeur et la moderation" on claim_sellers for select
  using (seller_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support'));
drop policy if exists "echanges : parties de la reclamation" on claim_messages;
create policy "echanges : parties de la reclamation" on claim_messages for select
  using (exists (select 1 from claims c where c.id = claim_id));

-- Reprise de l'existant : vendeurs de chaque commande, premier message (détails) et réponse éventuelle.
insert into claim_sellers (claim_id, seller_id)
  select c.id, l.seller_id from claims c join order_lines ol on ol.order_id = c.order_id join listings l on l.id = ol.listing_id where l.seller_id is not null
  union select id, seller_id from claims where seller_id is not null
on conflict do nothing;
insert into claim_messages (claim_id, author_id, author_role, body, created_at)
  select c.id, c.claimant_id, 'buyer', c.details, c.created_at from claims c where not exists (select 1 from claim_messages m where m.claim_id = c.id);
insert into claim_messages (claim_id, author_id, author_role, body, created_at)
  select c.id, c.answered_by, case when c.answered_by = c.claimant_id then 'buyer' when c.answered_by = c.seller_id then 'seller' else 'staff' end, c.answer, coalesce(c.answered_at, c.created_at)
  from claims c where c.answer is not null and not exists (select 1 from claim_messages m where m.claim_id = c.id and m.author_role <> 'buyer');

-- ============================================================ dépôt : tous les vendeurs de la commande sont rattachés
create or replace function submit_claim(p_order text, p_reason text, p_details text) returns uuid
language plpgsql security definer set search_path = public as $$
declare o orders%rowtype; seller uuid; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from orders where number = p_order and buyer_id = auth.uid();
  if not found then raise exception 'Commande introuvable'; end if;
  if o.cancelled_at is not null or o.cancelled then raise exception 'Cette commande est annulée : aucune réclamation n''est possible'; end if;
  if not o.paid and not o.cod then raise exception 'Cette commande n''est pas encore payée : annulez-la depuis « Annuler la commande » si vous n''en voulez plus'; end if;
  if p_reason not in ('not_received', 'damaged', 'cancel_before_prep', 'refund') then raise exception 'Motif invalide'; end if;
  if p_details is null or char_length(trim(p_details)) < 10 then raise exception 'Décrivez le problème en 10 caractères minimum'; end if;
  if exists (select 1 from claims where order_id = o.id and status in ('open', 'answered')) then raise exception 'Une réclamation est déjà ouverte pour cette commande'; end if;
  select l.seller_id into seller from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null order by ol.id limit 1;
  insert into claims (order_id, claimant_id, seller_id, reason, details) values (o.id, auth.uid(), seller, p_reason, left(trim(p_details), 2000)) returning id into cid;
  insert into claim_sellers (claim_id, seller_id)
    select distinct cid, l.seller_id from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null
  on conflict do nothing;
  insert into claim_messages (claim_id, author_id, author_role, body) values (cid, auth.uid(), 'buyer', left(trim(p_details), 2000));
  insert into notifications (user_id, kind, title, body, data)
    select distinct l.seller_id, 'claim', 'Réclamation reçue', 'Commande ' || o.number || ' : une réclamation a été déposée. Votre argent reste en séquestre jusqu''à la décision.', jsonb_build_object('order_number', o.number, 'claim_id', cid)
    from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and l.seller_id is not null;
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'claim', 'Réclamation à suivre', 'Commande ' || o.number || ' : une réclamation vient d''être déposée.', jsonb_build_object('order_number', o.number, 'claim_id', cid)
    from profiles p
    where not coalesce(p.suspended, false) and (p.role::text in ('admin', 'support')
      or (p.role::text = 'dept' and p.department is not null and p.department in (select sp.department from order_lines ol join listings l on l.id = ol.listing_id join profiles sp on sp.id = l.seller_id where ol.order_id = o.id and sp.department is not null)));
  return cid;
end $$;

-- ============================================================ échanges
-- Acheteur, vendeur rattaché ou modération écrivent tant que la réclamation n'est pas close. Répondre ne libère JAMAIS l'argent : seule la décision le fait.
create or replace function answer_claim(p_claim uuid, p_message text) returns text
language plpgsql security definer set search_path = public as $$
declare c claims%rowtype; v_role text; v_msg text := left(trim(coalesce(p_message, '')), 2000); v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from claims where id = p_claim for update;
  if not found then raise exception 'Réclamation introuvable'; end if;
  if c.claimant_id = auth.uid() then v_role := 'buyer';
  elsif c.seller_id = auth.uid() or exists (select 1 from claim_sellers where claim_id = c.id and seller_id = auth.uid()) then v_role := 'seller';
  elsif coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then v_role := 'staff';
  else raise exception 'Réclamation introuvable'; end if;
  if c.status = 'closed' then raise exception 'Cette réclamation est clôturée : elle ne peut plus être modifiée'; end if;
  if char_length(v_msg) = 0 then raise exception 'Réponse vide'; end if;
  if char_length(v_msg) < 5 then raise exception 'Réponse trop courte : 5 caractères minimum'; end if;
  select number into v_num from orders where id = c.order_id;
  insert into claim_messages (claim_id, author_id, author_role, body) values (c.id, auth.uid(), v_role, v_msg);
  if v_role = 'buyer' then
    update claims set status = 'open' where id = c.id;
    insert into notifications (user_id, kind, title, body, data)
      select s.seller_id, 'claim', 'Nouveau message de l''acheteur', left(v_msg, 120), jsonb_build_object('claim_id', c.id, 'order_number', v_num) from claim_sellers s where s.claim_id = c.id;
    return 'open';
  end if;
  update claims set answer = v_msg, answered_by = auth.uid(), answered_at = now(), status = 'answered' where id = c.id;
  insert into notifications (user_id, kind, title, body, data)
    values (c.claimant_id, 'claim', 'Réponse à votre réclamation', left(v_msg, 120), jsonb_build_object('claim_id', c.id, 'order_number', v_num));
  if v_role = 'staff' then
    insert into notifications (user_id, kind, title, body, data)
      select s.seller_id, 'claim', 'Message de la modération', left(v_msg, 120), jsonb_build_object('claim_id', c.id, 'order_number', v_num) from claim_sellers s where s.claim_id = c.id;
  end if;
  return 'answered';
end $$;

-- L'acheteur retire sa réclamation (satisfait de la réponse) : elle est close en faveur du vendeur et le déblocage est relancé.
create or replace function claim_withdraw(p_claim uuid, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c claims%rowtype; v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from claims where id = p_claim and claimant_id = auth.uid() for update;
  if not found then raise exception 'Réclamation introuvable'; end if;
  if c.status = 'closed' then raise exception 'Cette réclamation est clôturée : elle ne peut plus être modifiée'; end if;
  select number into v_num from orders where id = c.order_id;
  update claims set status = 'closed', decision = 'release', decided_by = auth.uid(), decided_at = now() where id = c.id;
  insert into claim_messages (claim_id, author_id, author_role, body)
    values (c.id, auth.uid(), 'buyer', 'Réclamation retirée par l''acheteur.' || case when char_length(btrim(coalesce(p_note, ''))) > 0 then ' ' || left(btrim(p_note), 500) else '' end);
  insert into notifications (user_id, kind, title, body, data)
    select s.seller_id, 'claim', 'Réclamation retirée', 'Commande ' || v_num || ' : l''acheteur a retiré sa réclamation. Votre argent sera débloqué selon les règles de livraison.', jsonb_build_object('claim_id', c.id, 'order_number', v_num) from claim_sellers s where s.claim_id = c.id;
  perform money_try_release(c.order_id);
  return 'closed';
end $$;

-- Décision de la médiation : « release » (réclamation non fondée : l'argent suit son cours) ou « refund » (acheteur remboursé, commande annulée).
create or replace function claim_decide(p_id uuid, p_decision text, p_note text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c claims%rowtype; o orders%rowtype; v_note text := left(btrim(coalesce(p_note, '')), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à l''équipe de médiation'; end if;
  if p_decision not in ('release', 'refund') then raise exception 'Décision inconnue'; end if;
  select * into c from claims where id = p_id for update;
  if not found then raise exception 'Litige introuvable'; end if;
  if c.status = 'closed' then raise exception 'Cette réclamation est déjà clôturée'; end if;
  select * into o from orders where id = c.order_id for update;
  if p_decision = 'refund' then
    if char_length(v_note) < 5 then raise exception 'Indiquez le motif de la décision'; end if;
    if not o.paid or o.cod then raise exception 'Remboursement impossible : la commande a été payée en espèces à la livraison ou n''est pas payée'; end if;
  end if;
  update claims set status = 'closed', decision = p_decision, decided_by = auth.uid(), decided_at = now(), answer = coalesce(nullif(v_note, ''), answer) where id = c.id;
  insert into claim_messages (claim_id, author_id, author_role, body)
    values (c.id, auth.uid(), 'staff', 'Décision : ' || case p_decision when 'refund' then 'acheteur remboursé' else 'réclamation non retenue' end || case when v_note <> '' then ' — ' || v_note else '' end);
  if p_decision = 'refund' then
    if o.cancelled_at is null then
      perform _order_refund_open(o.id, c.id, 'Décision de la réclamation : ' || coalesce(nullif(v_note, ''), 'acheteur remboursé') || ' (réclamation ' || left(c.id::text, 8) || ')', auth.uid(), v_note);
      perform _order_refund_apply(o.id);
    end if;
  else
    perform money_try_release(o.id);
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Litige clos', c.id::text, 'Marketplace', 'Normal');
  insert into notifications (user_id, kind, title, body, data)
    select u, 'claim', 'Réclamation tranchée', 'Commande ' || o.number || case p_decision when 'refund' then ' : vous êtes remboursé (annulation de la commande).' else ' : la réclamation n''est pas retenue.' end || case when v_note <> '' then ' ' || v_note else '' end,
           jsonb_build_object('claim_id', c.id, 'order_number', o.number)
    from (select c.claimant_id as u union select seller_id from claim_sellers where claim_id = c.id) x;
  return p_decision;
end $$;

-- Ancienne fonction de la modération (écran Litiges) : clore = rejeter la réclamation, l'argent suit son cours.
create or replace function dispute_close(p_id uuid, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') not in ('admin', 'support') then raise exception 'Réservé à l''équipe de médiation'; end if;
  perform claim_decide(p_id, 'release', coalesce(p_note, ''));
end $$;

-- Fil complet d'une réclamation pour l'acheteur, les vendeurs rattachés et la modération.
create or replace function claim_thread(p_claim uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c claims%rowtype; v_role text; v_num text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from claims where id = p_claim;
  if not found then raise exception 'Réclamation introuvable'; end if;
  if c.claimant_id = auth.uid() then v_role := 'buyer';
  elsif c.seller_id = auth.uid() or exists (select 1 from claim_sellers where claim_id = c.id and seller_id = auth.uid()) then v_role := 'seller';
  elsif coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then v_role := 'staff';
  else raise exception 'Réclamation introuvable'; end if;
  select number into v_num from orders where id = c.order_id;
  return jsonb_build_object('id', c.id, 'order_number', v_num, 'reason', c.reason, 'status', c.status, 'decision', c.decision, 'created_at', c.created_at, 'as', v_role,
    'can_reply', c.status <> 'closed',
    'messages', coalesce((select jsonb_agg(jsonb_build_object('role', m.author_role, 'author', case m.author_role when 'staff' then 'Boutik-École' else display_name(m.author_id) end, 'body', m.body, 'at', m.created_at) order by m.created_at, m.id)
                          from claim_messages m where m.claim_id = c.id), '[]'::jsonb));
end $$;

-- Mes réclamations : celles de l'acheteur, ou celles qui concernent les ventes du vendeur (tous les vendeurs d'une commande multi-vendeurs).
create or replace function my_claims() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'order_number', o.number, 'reason', c.reason, 'details', c.details, 'status', c.status, 'decision', c.decision, 'answer', c.answer,
      'created_at', c.created_at, 'as', case when c.claimant_id = auth.uid() then 'buyer' else 'seller' end) order by c.created_at desc)
    from (select * from claims order by created_at desc limit 100) c join orders o on o.id = c.order_id
    where c.claimant_id = auth.uid() or c.seller_id = auth.uid() or exists (select 1 from claim_sellers s where s.claim_id = c.id and s.seller_id = auth.uid())), '[]'::jsonb);
end $$;

revoke all on function submit_claim(text, text, text), answer_claim(uuid, text), claim_withdraw(uuid, text), claim_decide(uuid, text, text), dispute_close(uuid, text), claim_thread(uuid), my_claims() from public, anon;
grant execute on function submit_claim(text, text, text), answer_claim(uuid, text), claim_withdraw(uuid, text), claim_decide(uuid, text, text), dispute_close(uuid, text), claim_thread(uuid), my_claims() to authenticated;
