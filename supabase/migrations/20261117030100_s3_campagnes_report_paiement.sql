-- Lot S3 : campagne refusée après paiement (S3-88). Le budget confirmé est conservé sur la campagne : la renvoyer en validation ne crée
-- aucun second paiement, et une campagne dont le budget est déjà payé ne peut plus être supprimée (le paiement serait perdu).
-- Fichier additif et rejouable. Repart de la dernière définition (20261115210000_l11_missions_offres_campagnes.sql).

create or replace function ad_campaign_save(p_id uuid, p_title text, p_body text, p_post uuid, p_listing uuid, p_budget int, p_daily int, p_starts date, p_ends date) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; c ad_campaigns%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not user_has_feature('boost_campagnes') and not exists (select 1 from profiles where id = auth.uid() and is_test) then
    raise exception 'Les campagnes sponsorisées font partie des offres Vendeur professionnel et Entreprise';
  end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 80 then raise exception 'Titre : 3 à 80 caractères'; end if;
  if char_length(coalesce(trim(p_body), '')) > 300 then raise exception 'Texte : 300 caractères au plus'; end if;
  if p_budget is null or p_budget < 1000 then raise exception 'Budget : 1 000 FCFA au minimum'; end if;
  if p_budget > 100000000 then raise exception 'Budget : 100 000 000 FCFA au plus'; end if;
  if p_daily is not null and p_daily <= 0 then raise exception 'Le budget par jour doit être supérieur à 0'; end if;
  if p_post is not null and not exists (select 1 from posts where id = p_post and author_id = auth.uid() and status = 'published') then raise exception 'Publication introuvable ou non publiée'; end if;
  if p_listing is not null and not exists (select 1 from listings where id = p_listing and seller_id = auth.uid() and status = 'approved') then raise exception 'Annonce introuvable ou non publiée'; end if;
  if p_post is null and p_listing is null then raise exception 'Choisissez une publication ou une annonce à promouvoir'; end if;
  if p_ends is not null and p_starts is not null and p_ends < p_starts then raise exception 'Dates invalides'; end if;
  if p_id is null then
    insert into ad_campaigns (owner_id, title, body, post_id, listing_id, budget_xaf, daily_budget_xaf, starts_on, ends_on)
    values (auth.uid(), trim(p_title), coalesce(trim(p_body), ''), p_post, p_listing, p_budget, p_daily, p_starts, p_ends) returning id into v;
  else
    select * into c from ad_campaigns where id = p_id and owner_id = auth.uid() and status in ('draft', 'rejected') for update;
    if not found then raise exception 'Campagne non modifiable'; end if;
    if c.payment_id is not null and exists (select 1 from payment_transactions t where t.id = c.payment_id and t.status = 'confirmed') and p_budget <> c.budget_xaf then
      raise exception 'Le budget de cette campagne est déjà payé (% FCFA) : il ne peut plus être modifié', c.budget_xaf;
    end if;
    update ad_campaigns set title = trim(p_title), body = coalesce(trim(p_body), ''), post_id = p_post, listing_id = p_listing, budget_xaf = p_budget, daily_budget_xaf = p_daily, starts_on = p_starts, ends_on = p_ends
    where id = c.id returning id into v;
  end if;
  return v;
end $$;

create or replace function ad_campaign_submit(p_id uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype; pay uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not user_has_feature('boost_campagnes') and not exists (select 1 from profiles where id = auth.uid() and is_test) then
    raise exception 'Les campagnes sponsorisées font partie des offres Vendeur professionnel et Entreprise';
  end if;
  select * into c from ad_campaigns where id = p_id and owner_id = auth.uid() and status in ('draft', 'rejected') for update;
  if not found then raise exception 'Campagne non soumissible'; end if;
  -- budget déjà payé (campagne refusée puis corrigée) : report du paiement, retour direct en validation, aucun nouveau paiement
  if c.payment_id is not null and exists (select 1 from payment_transactions t where t.id = c.payment_id and t.status = 'confirmed' and t.amount >= c.budget_xaf) then
    update ad_campaigns set status = 'pending_review', review_note = null where id = c.id;
    return c.payment_id;
  end if;
  pay := payment_start('campaign', 'campagne:' || c.id::text, c.budget_xaf, 'manual');
  update ad_campaigns set status = 'awaiting_payment', payment_id = pay where id = c.id;
  return pay;
end $$;

create or replace function ad_campaign_cancel(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c ad_campaigns%rowtype; t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from ad_campaigns where id = p_id and owner_id = auth.uid() for update;
  if not found then raise exception 'Campagne introuvable'; end if;
  if c.status not in ('draft', 'rejected', 'awaiting_payment') then raise exception 'Cette campagne ne peut plus être annulée'; end if;
  if c.payment_id is not null then
    select * into t from payment_transactions where id = c.payment_id for update;
    if found then
      if t.status = 'confirmed' then raise exception 'Le budget est déjà payé : corrigez la campagne puis renvoyez-la en validation (le paiement est reporté, sans nouveau règlement)'; end if;
      if c.status = 'awaiting_payment' then
        if t.status = 'pending' then raise exception 'Le paiement est déclaré : attendez la décision de la finance'; end if;
        if t.status in ('created', 'failed') then
          update payment_transactions set status = 'cancelled', decided_at = now(), note = 'Campagne annulée par son auteur' where id = t.id;
          insert into payment_messages (transaction_id, sender, body) values (t.id, 'system', 'Campagne annulée : paiement annulé.');
        end if;
      end if;
    end if;
  end if;
  delete from ad_campaigns where id = c.id;
end $$;

create or replace function my_ad_campaigns() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'title', c.title, 'status', c.status, 'budget', c.budget_xaf, 'spent', c.spent_xaf, 'review_note', c.review_note, 'payment_id', c.payment_id,
      'paid', exists (select 1 from payment_transactions t where t.id = c.payment_id and t.status = 'confirmed'),
      'impressions', (select count(*)::int from ad_events e where e.campaign_id = c.id and e.kind = 'impression'),
      'clicks', (select count(*)::int from ad_events e where e.campaign_id = c.id and e.kind = 'click'),
      'ctr', case when (select count(*) from ad_events e where e.campaign_id = c.id and e.kind = 'impression') = 0 then null
                  else round(100.0 * (select count(*) from ad_events e where e.campaign_id = c.id and e.kind = 'click') / (select count(*) from ad_events e where e.campaign_id = c.id and e.kind = 'impression'), 1) end)
      order by c.created_at desc) from ad_campaigns c where c.owner_id = auth.uid()), '[]'::jsonb);
end $$;

revoke all on function ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date), ad_campaign_submit(uuid), ad_campaign_cancel(uuid), my_ad_campaigns() from public, anon;
grant execute on function ad_campaign_save(uuid, text, text, uuid, uuid, int, int, date, date), ad_campaign_submit(uuid), ad_campaign_cancel(uuid), my_ad_campaigns() to authenticated;

-- Retour arrière : recréer ad_campaign_save, ad_campaign_submit et ad_campaign_cancel depuis 20261115210000_l11_missions_offres_campagnes.sql et my_ad_campaigns depuis 20261106000000_premium_publicites.sql.
