-- Lot S5 — campagnes de financement : clôture automatique, reversement au porteur (par le solde existant money_entries / payout_create), remboursement des
-- contributeurs si l'objectif n'est pas atteint, notification des contributions, liste des contributeurs pour le porteur, contributions « fantômes » nettoyées,
-- jalons déclarés avec preuve puis validés par le département, une seule campagne active par projet, relecture cloisonnée par département.
-- Corrige S5-3 (MAJ), S5-4, S5-28, S5-31, S5-32, S5-33, S5-35, S5-36 (partiel), S5-6 (campagnes).
-- RÈGLE (décision produit à confirmer) : « tout ou rien » — si l'objectif n'est pas atteint à l'échéance, les contributions confirmées sont à rembourser par la finance ;
-- s'il est atteint, la part du porteur (règle de répartition en vigueur, money_split_rules : 70/20/10 par défaut) est débloquée sur son solde et versée par payout_create.
-- Les contributions restent chez Boutik-École jusqu'à la clôture (séquestre). Aucune clé de paiement n'est lue ni modifiée ; payment_set_status n'est pas redéfini (un déclencheur réagit à la confirmation).
-- NON APPLIQUÉE en production au moment de l'écriture : testée sur PGlite (etu_s5.mjs).
-- Retour arrière :
--   select cron.unschedule('close-campaigns');
--   drop trigger if exists trg_campaign_paid on payment_transactions;
--   drop function if exists on_campaign_paid(), campaign_close_due(), campaign_refund_done(uuid), campaign_backers(uuid), campaign_contribution_cancel(uuid), campaign_milestone_review(uuid, boolean, text), campaign_milestones_to_review();
--   drop function if exists campaign_milestone_done(uuid, boolean, text);  puis recréer campaign_milestone_done(uuid, boolean), campaigns_overview, save_campaign, review_campaign, notification_category depuis 20261115190000 / 20261115160000 ;
--   alter table campaigns drop column if exists outcome, drop column if exists closed_at;
--   alter table campaign_contributions drop column if exists refund_status, drop column if exists refunded_at;
--   alter table campaign_milestones drop column if exists proof, drop column if exists proof_url, drop column if exists declared_at, drop column if exists validated_at, drop column if exists validated_by, drop column if exists review_note;
--   alter table money_entries drop column if exists campaign_id; drop index if exists money_entries_campaign_ref;

-- ============================================================ 1. Colonnes
alter table campaigns add column if not exists outcome text check (outcome is null or outcome in ('funded', 'unfunded'));
alter table campaigns add column if not exists closed_at timestamptz;
alter table campaign_contributions add column if not exists refund_status text check (refund_status is null or refund_status in ('to_refund', 'refunded'));
alter table campaign_contributions add column if not exists refunded_at timestamptz;
alter table campaign_milestones add column if not exists proof text check (proof is null or char_length(proof) <= 1000);
alter table campaign_milestones add column if not exists proof_url text check (proof_url is null or char_length(proof_url) <= 300);
alter table campaign_milestones add column if not exists declared_at timestamptz;
alter table campaign_milestones add column if not exists validated_at timestamptz;
alter table campaign_milestones add column if not exists validated_by uuid references profiles(id) on delete set null;
alter table campaign_milestones add column if not exists review_note text check (review_note is null or char_length(review_note) <= 500);
-- Les jalons déjà cochés par le porteur seul repassent « en attente de validation » : plus rien n'est affiché comme atteint sans relecture.
update campaign_milestones set declared_at = done_at, done_at = null where done_at is not null and declared_at is null and validated_at is null;
alter table money_entries add column if not exists campaign_id uuid references campaigns(id) on delete set null;
create unique index if not exists money_entries_campaign_ref on money_entries (ref) where kind = 'campaign';

-- ============================================================ 2. Notifications « campagne » : plus rangées dans les promotions (une décision ne doit jamais être filtrée)
create or replace function notification_category(p_kind text) returns text
language sql immutable set search_path = public as $$
  select case
    when p_kind in ('order', 'payment', 'claim', 'dispute', 'money', 'quote') then 'orders'
    when p_kind in ('message', 'teammate_message') then 'messages'
    when p_kind in ('review', 'company_review', 'question') then 'reviews'
    when p_kind in ('alert', 'ads', 'opportunity_alert') then 'promotions'
    else 'other' end
$$;

-- ============================================================ 3. Campagne : une seule active par projet, relecture cloisonnée
drop function if exists save_campaign(uuid, text, text, integer, integer, text, text, boolean, uuid);
create or replace function save_campaign(p_id uuid, p_kind text, p_project text, p_goal integer, p_duration_days integer, p_presentation text, p_rewards text, p_submit boolean, p_project_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype; cid uuid; v_title text := trim(coalesce(p_project, '')); v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux porteurs de projet étudiants'; end if;
  if p_kind not in ('project', 'preorder', 'sponsoring') then raise exception 'Type de campagne inconnu'; end if;
  if p_project_id is not null then
    select title, department into v_title, v_dept from projects where id = p_project_id and owner_id = auth.uid() and status = 'approved';
    if not found then raise exception 'Choisissez l''un de vos projets validés'; end if;
  elsif p_submit then
    raise exception 'Choisissez l''un de vos projets validés pour envoyer la campagne';
  end if;
  if v_title is null or char_length(v_title) not between 3 and 120 then raise exception 'Projet : 3 à 120 caractères'; end if;
  if p_submit and (p_goal is null or p_goal < 1000 or p_duration_days is null or char_length(trim(coalesce(p_presentation, ''))) < 30) then
    raise exception 'Objectif (1 000 FCFA minimum), durée et présentation (30 caractères) sont nécessaires pour envoyer la campagne';
  end if;
  if p_goal is not null and p_goal not between 1000 and 1000000000 or p_duration_days is not null and p_duration_days not between 7 and 90 then raise exception 'Valeurs invalides'; end if;
  if p_submit and p_project_id is not null and exists (
       select 1 from campaigns where project_id = p_project_id and id is distinct from p_id
         and (status = 'submitted' or (status = 'approved' and (ends_at is null or ends_at > now())))) then
    raise exception 'Ce projet a déjà une campagne en validation ou ouverte : une seule campagne active par projet';
  end if;
  if p_id is null then
    insert into campaigns (owner_id, kind, project, project_id, goal, duration_days, presentation, rewards, status)
    values (auth.uid(), p_kind, v_title, p_project_id, p_goal, p_duration_days, nullif(left(trim(coalesce(p_presentation, '')), 4000), ''), nullif(left(trim(coalesce(p_rewards, '')), 2000), ''),
            case when p_submit then 'submitted' else 'draft' end) returning id into cid;
  else
    select * into c from campaigns where id = p_id and owner_id = auth.uid();
    if not found then raise exception 'Campagne introuvable'; end if;
    if c.status not in ('draft', 'rejected') then raise exception 'Cette campagne est déjà en validation ou publiée'; end if;
    update campaigns set kind = p_kind, project = v_title, project_id = p_project_id, goal = p_goal, duration_days = p_duration_days, presentation = nullif(left(trim(coalesce(p_presentation, '')), 4000), ''),
      rewards = nullif(left(trim(coalesce(p_rewards, '')), 2000), ''), status = case when p_submit then 'submitted' else 'draft' end, updated_at = now() where id = c.id returning id into cid;
  end if;
  if p_submit then
    insert into notifications (user_id, kind, title, body, data)
    select r, 'campaign', 'Campagne à examiner', v_title, jsonb_build_object('campaign_id', cid) from _project_reviewers(v_dept) r where r <> auth.uid();
  end if;
  return cid;
end $$;
revoke all on function save_campaign(uuid, text, text, integer, integer, text, text, boolean, uuid) from public, anon;
grant execute on function save_campaign(uuid, text, text, integer, integer, text, text, boolean, uuid) to authenticated;

create or replace function review_campaign(p_id uuid, p_approve boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype; v_dept text;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into c from campaigns where id = p_id;
  if not found or c.status <> 'submitted' then raise exception 'Aucune campagne à valider'; end if;
  select department into v_dept from projects where id = c.project_id;
  if not _can_review_dept(v_dept) then raise exception 'Cette campagne relève d''un autre département'; end if;
  if not p_approve and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  update campaigns set status = case when p_approve then 'approved' else 'rejected' end, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), reviewed_by = auth.uid(), updated_at = now(),
    ends_at = case when p_approve then now() + make_interval(days => coalesce(c.duration_days, 30)) else null end where id = c.id;
  insert into notifications (user_id, kind, title, body, data) values (c.owner_id, 'campaign', case when p_approve then 'Campagne validée' else 'Campagne refusée' end, c.project, jsonb_build_object('campaign_id', c.id));
  return case when p_approve then 'approved' else 'rejected' end;
end $$;

-- ============================================================ 4. Contribution confirmée : porteur prévenu, argent mis en séquestre sur son nom (ou remboursement si la campagne est close sans objectif)
create or replace function on_campaign_paid() returns trigger
language plpgsql security definer set search_path = public as $$
declare k campaign_contributions%rowtype; c campaigns%rowtype; v_b integer; v_i integer; v_p integer;
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' and new.kind = 'campaign' then
    select * into k from campaign_contributions where payment_id = new.id;
    if not found then return null; end if;
    select * into c from campaigns where id = k.campaign_id for update;
    if not found then return null; end if;
    if c.status = 'closed' and c.outcome = 'unfunded' then
      update campaign_contributions set refund_status = 'to_refund' where id = k.id;
      perform notify_user(k.user_id, 'campaign', 'Campagne terminée : remboursement',
        left('« ' || c.project || ' » n''a pas atteint son objectif : votre paiement de ' || k.amount || ' FCFA (' || new.reference || ') sera remboursé par la finance.', 500), jsonb_build_object('campaign_id', c.id));
      insert into notifications (user_id, kind, title, body, data)
        select f.id, 'payment', 'Remboursement à traiter', new.reference || ' · ' || k.amount || ' FCFA · campagne « ' || left(c.project, 80) || ' » non financée', jsonb_build_object('payment_id', new.id)
        from profiles f where f.role::text in ('finance', 'admin');
      return null;
    end if;
    select b, i, p into v_b, v_i, v_p from money_split_amounts(k.amount);
    insert into money_entries (kind, ref, payer_id, beneficiary_id, gross, beneficiary_amount, institution_amount, platform_amount, split, status, released_at, campaign_id)
    values ('campaign', new.reference, k.user_id, c.owner_id, k.amount, v_b, v_i, v_p, money_split_label(),
            case when c.status = 'closed' then 'released' else 'held' end, case when c.status = 'closed' then now() end, c.id)
    on conflict (ref) where kind = 'campaign' do nothing;
    perform notify_user(c.owner_id, 'campaign', 'Nouvelle contribution',
      left(display_name(k.user_id) || ' a contribué ' || k.amount || ' FCFA à « ' || c.project || ' ».', 500), jsonb_build_object('campaign_id', c.id));
  end if;
  return null;
end $$;
revoke all on function on_campaign_paid() from public, anon, authenticated;
drop trigger if exists trg_campaign_paid on payment_transactions;
create trigger trg_campaign_paid after update of status on payment_transactions for each row execute function on_campaign_paid();

-- Contribution jamais payée : le contributeur l'annule (la demande de paiement non aboutie est annulée avec elle).
create or replace function campaign_contribution_cancel(p_payment uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t payment_transactions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from payment_transactions where id = p_payment and payer_id = auth.uid() and kind = 'campaign' for update;
  if not found or not exists (select 1 from campaign_contributions where payment_id = p_payment) then raise exception 'Contribution introuvable'; end if;
  if t.status not in ('created', 'failed') then raise exception 'Ce paiement est déjà déclaré ou confirmé : il ne peut plus être annulé ici'; end if;
  update payment_transactions set status = 'cancelled', decided_at = now(), note = 'Contribution annulée par le contributeur' where id = p_payment;
  delete from campaign_contributions where payment_id = p_payment;
end $$;
revoke all on function campaign_contribution_cancel(uuid) from public, anon;
grant execute on function campaign_contribution_cancel(uuid) to authenticated;

-- ============================================================ 5. Clôture à l'échéance (pg_cron toutes les 15 minutes)
create or replace function campaign_close_due() returns integer
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype; v_raised bigint; v_mine bigint; n integer := 0; v_refunds integer; k record;
begin
  -- contributions fantômes : demandes de paiement jamais déclarées depuis 24 h
  for k in select cc.payment_id from campaign_contributions cc join payment_transactions t on t.id = cc.payment_id
           where t.status in ('created', 'failed', 'cancelled') and cc.created_at < now() - interval '24 hours' loop
    update payment_transactions set status = 'cancelled', decided_at = now(), note = 'Contribution non payée : demande expirée' where id = k.payment_id and status in ('created', 'failed');
    delete from campaign_contributions where payment_id = k.payment_id;
  end loop;
  for c in select * from campaigns where status = 'approved' and ends_at is not null and ends_at <= now() order by ends_at limit 100 for update skip locked loop
    -- un paiement déclaré en cours de vérification depuis moins de 48 h retarde la clôture
    if exists (select 1 from campaign_contributions cc join payment_transactions t on t.id = cc.payment_id
               where cc.campaign_id = c.id and t.status = 'pending' and coalesce(t.declared_at, t.created_at) > now() - interval '48 hours') then continue; end if;
    select coalesce(sum(cc.amount), 0) into v_raised from campaign_contributions cc join payment_transactions t on t.id = cc.payment_id where cc.campaign_id = c.id and t.status = 'confirmed';
    if v_raised >= coalesce(c.goal, 0) and v_raised > 0 then
      update campaigns set status = 'closed', outcome = 'funded', closed_at = now(), updated_at = now() where id = c.id;
      update money_entries set status = 'released', released_at = now() where campaign_id = c.id and status = 'held';
      select coalesce(sum(beneficiary_amount), 0) into v_mine from money_entries where campaign_id = c.id and status = 'released';
      perform notify_user(c.owner_id, 'campaign', 'Campagne réussie',
        left('« ' || c.project || ' » a atteint son objectif (' || v_raised || ' FCFA). ' || v_mine || ' FCFA sont disponibles sur votre solde, après répartition ' || money_split_label() || '.', 500), jsonb_build_object('campaign_id', c.id));
      for k in select distinct user_id from campaign_contributions where campaign_id = c.id loop
        perform notify_user(k.user_id, 'campaign', 'Campagne financée', left('Merci : « ' || c.project || ' » a atteint son objectif.', 500), jsonb_build_object('campaign_id', c.id));
      end loop;
    else
      update campaigns set status = 'closed', outcome = 'unfunded', closed_at = now(), updated_at = now() where id = c.id;
      update money_entries set status = 'refunded' where campaign_id = c.id and status = 'held';
      update campaign_contributions cc set refund_status = 'to_refund' from payment_transactions t where t.id = cc.payment_id and cc.campaign_id = c.id and t.status = 'confirmed';
      get diagnostics v_refunds = row_count;
      perform notify_user(c.owner_id, 'campaign', 'Campagne terminée sans objectif atteint',
        left('« ' || c.project || ' » a collecté ' || v_raised || ' FCFA sur ' || coalesce(c.goal, 0) || ' : les contributeurs sont remboursés.', 500), jsonb_build_object('campaign_id', c.id));
      for k in select cc.user_id, cc.amount, t.reference from campaign_contributions cc join payment_transactions t on t.id = cc.payment_id where cc.campaign_id = c.id and cc.refund_status = 'to_refund' loop
        perform notify_user(k.user_id, 'campaign', 'Campagne terminée : remboursement',
          left('« ' || c.project || ' » n''a pas atteint son objectif : votre paiement de ' || k.amount || ' FCFA (' || k.reference || ') sera remboursé par la finance.', 500), jsonb_build_object('campaign_id', c.id));
      end loop;
      if v_refunds > 0 then
        insert into notifications (user_id, kind, title, body, data)
          select f.id, 'payment', 'Remboursements à traiter', left(v_refunds || ' contribution(s) à rembourser : campagne « ' || c.project || ' » non financée.', 500), jsonb_build_object('campaign_id', c.id)
          from profiles f where f.role::text in ('finance', 'admin');
      end if;
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function campaign_close_due() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('close-campaigns') where exists (select 1 from cron.job where jobname = 'close-campaigns');
  perform cron.schedule('close-campaigns', '*/15 * * * *', 'select public.campaign_close_due()');
exception when others then
  raise notice 'pg_cron indisponible : les campagnes échues ne sont pas clôturées tant que campaign_close_due() n''est pas planifiée (%).', sqlerrm;
end $$;

-- Remboursement effectué par la finance : le contributeur est prévenu.
create or replace function campaign_refund_done(p_contribution uuid) returns void
language plpgsql security definer set search_path = public as $$
declare k campaign_contributions%rowtype; c campaigns%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin') then raise exception 'Action non autorisée'; end if;
  select * into k from campaign_contributions where id = p_contribution and refund_status = 'to_refund' for update;
  if not found then raise exception 'Aucun remboursement en attente pour cette contribution'; end if;
  update campaign_contributions set refund_status = 'refunded', refunded_at = now() where id = k.id;
  select * into c from campaigns where id = k.campaign_id;
  perform notify_user(k.user_id, 'campaign', 'Remboursement effectué', left('Votre contribution de ' || k.amount || ' FCFA à « ' || coalesce(c.project, 'la campagne') || ' » a été remboursée.', 500), jsonb_build_object('campaign_id', k.campaign_id));
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Remboursement campagne', coalesce(c.project, k.campaign_id::text), 'Finance', 'Info');
end $$;
revoke all on function campaign_refund_done(uuid) from public, anon;
grant execute on function campaign_refund_done(uuid) to authenticated;

-- ============================================================ 6. Contributeurs d'une campagne (porteur, département, finance)
create or replace function campaign_backers(p_campaign uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from campaigns c where c.id = p_campaign and (c.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'finance'))) then raise exception 'Campagne introuvable'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', k.id, 'name', display_name(k.user_id), 'amount', k.amount, 'status', t.status, 'refund_status', k.refund_status, 'created_at', k.created_at) order by k.created_at desc)
    from campaign_contributions k join payment_transactions t on t.id = k.payment_id where k.campaign_id = p_campaign and t.status in ('pending', 'confirmed')
  ), '[]'::jsonb);
end $$;
revoke all on function campaign_backers(uuid) from public, anon;
grant execute on function campaign_backers(uuid) to authenticated;

-- ============================================================ 7. Jalons : déclarés avec preuve par le porteur, validés par le département
drop function if exists campaign_milestone_done(uuid, boolean);
create or replace function campaign_milestone_done(p_id uuid, p_done boolean default true, p_proof text default null, p_proof_url text default null) returns void
language plpgsql security definer set search_path = public as $$
declare m campaign_milestones%rowtype; c campaigns%rowtype; v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select m2.* into m from campaign_milestones m2 join campaigns c2 on c2.id = m2.campaign_id where m2.id = p_id and c2.owner_id = auth.uid() for update of m2;
  if not found then raise exception 'Jalon introuvable'; end if;
  select * into c from campaigns where id = m.campaign_id;
  if not coalesce(p_done, true) then
    update campaign_milestones set declared_at = null, validated_at = null, validated_by = null, done_at = null, proof = null, proof_url = null, review_note = null where id = m.id;
    return;
  end if;
  if char_length(btrim(coalesce(p_proof, ''))) < 10 then raise exception 'Décrivez la preuve de réalisation du jalon (10 caractères au moins)'; end if;
  if coalesce(btrim(p_proof_url), '') <> '' and (btrim(p_proof_url) !~* '^https?://\S{3,}$' or char_length(btrim(p_proof_url)) > 300) then raise exception 'Lien de preuve invalide : une adresse http:// ou https:// est attendue'; end if;
  if c.status <> 'approved' then raise exception 'Un jalon se déclare atteint une fois la campagne ouverte'; end if;
  update campaign_milestones set declared_at = now(), validated_at = null, validated_by = null, done_at = null, proof = left(btrim(p_proof), 1000), proof_url = nullif(btrim(coalesce(p_proof_url, '')), ''), review_note = null where id = m.id;
  select department into v_dept from projects where id = c.project_id;
  insert into notifications (user_id, kind, title, body, data)
    select r, 'campaign', 'Jalon à valider', left(c.project || ' · ' || m.title, 200), jsonb_build_object('campaign_id', c.id, 'milestone_id', m.id) from _project_reviewers(v_dept) r where r <> auth.uid();
end $$;
revoke all on function campaign_milestone_done(uuid, boolean, text, text) from public, anon;
grant execute on function campaign_milestone_done(uuid, boolean, text, text) to authenticated;

create or replace function campaign_milestone_review(p_id uuid, p_approve boolean, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare m campaign_milestones%rowtype; c campaigns%rowtype; v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into m from campaign_milestones where id = p_id and declared_at is not null and validated_at is null for update;
  if not found then raise exception 'Aucun jalon à valider'; end if;
  select * into c from campaigns where id = m.campaign_id;
  select department into v_dept from projects where id = c.project_id;
  if not _can_review_dept(v_dept) then raise exception 'Cette campagne relève d''un autre département'; end if;
  if not coalesce(p_approve, false) and char_length(btrim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  if coalesce(p_approve, false) then
    update campaign_milestones set validated_at = now(), validated_by = auth.uid(), done_at = now(), review_note = nullif(left(btrim(coalesce(p_note, '')), 500), '') where id = m.id;
  else
    update campaign_milestones set declared_at = null, review_note = left(btrim(p_note), 500) where id = m.id;
  end if;
  perform notify_user(c.owner_id, 'campaign', case when coalesce(p_approve, false) then 'Jalon validé' else 'Jalon non validé' end, left(c.project || ' · ' || m.title, 200), jsonb_build_object('campaign_id', c.id));
end $$;
revoke all on function campaign_milestone_review(uuid, boolean, text) from public, anon;
grant execute on function campaign_milestone_review(uuid, boolean, text) to authenticated;

create or replace function campaign_milestones_to_review() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title, 'campaign', c.project, 'proof', m.proof, 'proof_url', m.proof_url, 'declared_at', m.declared_at, 'owner', display_name(c.owner_id)) order by m.declared_at)
    from campaign_milestones m join campaigns c on c.id = m.campaign_id left join projects p on p.id = c.project_id
    where m.declared_at is not null and m.validated_at is null and _can_review_dept(p.department)
  ), '[]'::jsonb);
end $$;
revoke all on function campaign_milestones_to_review() from public, anon;
grant execute on function campaign_milestones_to_review() to authenticated;

-- Un jalon modifié perd sa validation (le contenu public ne change pas après approbation sans relecture).
create or replace function campaign_milestone_save(p_campaign uuid, p_id uuid, p_title text, p_target integer default null, p_due date default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from campaigns where id = p_campaign and owner_id = auth.uid() and status <> 'closed') then raise exception 'Campagne introuvable'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 120 then raise exception 'Jalon : 3 à 120 caractères'; end if;
  if p_target is not null and p_target not between 1 and 1000000000 then raise exception 'Montant du jalon invalide'; end if;
  if p_id is null then
    if (select count(*) from campaign_milestones where campaign_id = p_campaign) >= 12 then raise exception 'Douze jalons au plus par campagne'; end if;
    insert into campaign_milestones (campaign_id, title, target_xaf, due_on) values (p_campaign, btrim(p_title), p_target, p_due) returning id into mid;
  else
    update campaign_milestones set title = btrim(p_title), target_xaf = p_target, due_on = p_due,
      done_at = case when title is distinct from btrim(p_title) then null else done_at end,
      validated_at = case when title is distinct from btrim(p_title) then null else validated_at end,
      validated_by = case when title is distinct from btrim(p_title) then null else validated_by end,
      declared_at = case when title is distinct from btrim(p_title) then null else declared_at end
    where id = p_id and campaign_id = p_campaign returning id into mid;
    if mid is null then raise exception 'Jalon introuvable'; end if;
  end if;
  return mid;
end $$;
revoke all on function campaign_milestone_save(uuid, uuid, text, integer, date) from public, anon;
grant execute on function campaign_milestone_save(uuid, uuid, text, integer, date) to authenticated;

-- ============================================================ 8. Vue d'ensemble : clôturées visibles, jalons validés seulement pour le public, preuves pour le porteur
create or replace function campaigns_overview(p_mine boolean default false, p_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(p_mine, false) and auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'kind', c.kind, 'project', c.project, 'project_id', c.project_id, 'goal', c.goal, 'duration_days', c.duration_days,
      'presentation', c.presentation, 'rewards', c.rewards, 'status', c.status, 'review_note', case when c.owner_id = auth.uid() then c.review_note end,
      'created_at', c.created_at, 'ends_at', c.ends_at, 'mine', c.owner_id = auth.uid(), 'outcome', c.outcome, 'closed_at', c.closed_at,
      'open', c.status = 'approved' and (c.ends_at is null or c.ends_at > now()),
      'raised', coalesce(x.raised, 0), 'backers', coalesce(x.backers, 0),
      'to_refund', case when c.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'finance') then
                        (select count(*)::int from campaign_contributions k where k.campaign_id = c.id and k.refund_status = 'to_refund') end,
      'milestones', coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title, 'target_xaf', m.target_xaf, 'due_on', m.due_on, 'done', m.validated_at is not null,
                                                                  'declared', coalesce(m.declared_at is not null and m.validated_at is null and c.owner_id = auth.uid(), false),
                                                                  'proof', case when c.owner_id = auth.uid() or m.validated_at is not null then m.proof end,
                                                                  'proof_url', case when c.owner_id = auth.uid() or m.validated_at is not null then m.proof_url end,
                                                                  'review_note', case when c.owner_id = auth.uid() then m.review_note end)
                                               order by m.due_on nulls last, m.created_at) from campaign_milestones m where m.campaign_id = c.id), '[]'::jsonb)
    ) order by (c.status = 'approved' and (c.ends_at is null or c.ends_at > now())) desc, c.created_at desc)
    from (select * from campaigns where (case when coalesce(p_mine, false) then owner_id = auth.uid() else status in ('approved', 'closed') end) and (p_id is null or id = p_id)
          order by created_at desc limit 100) c
    left join lateral (select sum(k.amount)::bigint raised, count(distinct k.user_id)::int backers from campaign_contributions k
                       join payment_transactions t on t.id = k.payment_id where k.campaign_id = c.id and t.status = 'confirmed') x on true
  ), '[]'::jsonb);
end $$;
revoke all on function campaigns_overview(boolean, uuid) from public;
grant execute on function campaigns_overview(boolean, uuid) to anon, authenticated;
