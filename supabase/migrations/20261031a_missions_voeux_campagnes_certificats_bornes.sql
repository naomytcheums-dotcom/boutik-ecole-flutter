-- 20261031a — Missions et besoins, propositions, jalons, vœux, campagnes, certificats, supervision des bornes.
-- Principes (identiques aux migrations précédentes) : RLS partout, aucune écriture directe, tout passe par des fonctions
-- serveur qui vérifient l'identité, le rôle, l'état et les données ; chaque transition notifie la personne concernée.
-- Réversibilité : voir le bloc « RETOUR ARRIÈRE » en fin de fichier.

-- ============================================================ missions (table existante, étendue)
-- La table « missions » existait (schema.sql) sans être utilisée par l'application. Elle porte désormais les besoins
-- publiés par les clients et entreprises (écran 90) et les missions sur mesure.
alter table missions add column if not exists title text;
alter table missions add column if not exists status text not null default 'draft';
alter table missions add column if not exists budget_min integer;
alter table missions add column if not exists budget_max integer;
alter table missions add column if not exists deadline text;
alter table missions add column if not exists assigned_team text;
alter table missions add column if not exists assigned_by uuid references profiles(id);
alter table missions add column if not exists updated_at timestamptz not null default now();
do $$ begin
  alter table missions add constraint missions_status_chk check (status in ('draft', 'published', 'assigned', 'in_progress', 'delivered', 'closed', 'cancelled'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table missions add constraint missions_budget_chk check ((budget_min is null or budget_min >= 0) and (budget_max is null or budget_max >= coalesce(budget_min, 0)));
exception when duplicate_object then null; end $$;
create index if not exists missions_client_idx on missions (client_id);
create index if not exists missions_status_idx on missions (status);

-- L'ancienne règle « mise à jour des missions » laissait tout étudiant modifier toute mission : remplacée par les fonctions.
drop policy if exists "mise à jour des missions" on missions;
drop policy if exists "un client crée sa mission" on missions;
drop policy if exists "missions du client ou de l'administration" on missions;
revoke insert, update, delete on missions from anon, authenticated;
grant select on missions to authenticated;
drop policy if exists "missions : propriétaire, publiées, département" on missions;
create policy "missions : propriétaire, publiées, département" on missions for select
  using (client_id = auth.uid() or (status <> 'draft' and auth.uid() is not null) or current_role_name() in ('dept', 'admin'));

create table if not exists mission_proposals (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references missions(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  amount integer not null check (amount > 0 and amount <= 100000000),
  delay_days integer not null check (delay_days between 1 and 365),
  message text check (message is null or char_length(message) <= 2000),
  status text not null default 'submitted' check (status in ('submitted', 'accepted', 'declined', 'withdrawn')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (mission_id, author_id)
);
create index if not exists mission_proposals_mission_idx on mission_proposals (mission_id);
alter table mission_proposals enable row level security;
revoke all on mission_proposals from anon, authenticated;
grant select on mission_proposals to authenticated;
drop policy if exists "propositions : auteur, client, département" on mission_proposals;
create policy "propositions : auteur, client, département" on mission_proposals for select
  using (author_id = auth.uid() or exists (select 1 from missions m where m.id = mission_id and m.client_id = auth.uid())
         or current_role_name() in ('dept', 'admin'));

create table if not exists mission_milestones (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references missions(id) on delete cascade,
  position smallint not null check (position between 1 and 20),
  title text not null check (char_length(title) between 2 and 120),
  amount integer not null default 0 check (amount >= 0),
  status text not null default 'pending' check (status in ('pending', 'submitted', 'validated', 'correction')),
  note text check (note is null or char_length(note) <= 1000),
  updated_at timestamptz not null default now(),
  unique (mission_id, position)
);
alter table mission_milestones enable row level security;
revoke all on mission_milestones from anon, authenticated;
grant select on mission_milestones to authenticated;
drop policy if exists "jalons : client, prestataire retenu, département" on mission_milestones;
create policy "jalons : client, prestataire retenu, département" on mission_milestones for select
  using (exists (select 1 from missions m where m.id = mission_id and (m.client_id = auth.uid()
           or exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')))
         or current_role_name() in ('dept', 'admin'));

-- Enregistre un besoin (brouillon ou publication). Seul le propriétaire modifie, et seulement avant attribution.
create or replace function save_mission(p_id uuid, p_title text, p_description text, p_budget_min integer, p_budget_max integer,
                                        p_deadline text, p_publish boolean, p_kind text default 'besoin') returns uuid
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid uuid; st text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('client', 'company', 'other', 'student', 'dept', 'admin') then raise exception 'Action non autorisée'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if p_publish and (p_description is null or char_length(trim(p_description)) < 20) then raise exception 'Décrivez le besoin en 20 caractères minimum'; end if;
  if char_length(coalesce(p_description, '')) > 4000 then raise exception 'Description trop longue'; end if;
  if p_budget_min is not null and p_budget_min < 0 or p_budget_max is not null and p_budget_max < coalesce(p_budget_min, 0) then raise exception 'Budget invalide'; end if;
  if p_kind not in ('besoin', 'mission') then raise exception 'Type inconnu'; end if;
  st := case when p_publish then 'published' else 'draft' end;
  if p_id is null then
    insert into missions (number, client_id, kind, title, description, total, status, budget_min, budget_max, deadline)
    values ('#BR-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 1000000))::text, 6, '0'), auth.uid(), p_kind, trim(p_title),
            coalesce(trim(p_description), ''), coalesce(p_budget_max, p_budget_min, 0), st, p_budget_min, p_budget_max, nullif(left(trim(coalesce(p_deadline, '')), 60), ''))
    returning id into mid;
    return mid;
  end if;
  select * into m from missions where id = p_id and client_id = auth.uid();
  if not found then raise exception 'Besoin introuvable'; end if;
  if m.status not in ('draft', 'published') then raise exception 'Ce besoin est déjà attribué'; end if;
  update missions set title = trim(p_title), description = coalesce(trim(p_description), ''), budget_min = p_budget_min, budget_max = p_budget_max,
    total = coalesce(p_budget_max, p_budget_min, 0), deadline = nullif(left(trim(coalesce(p_deadline, '')), 60), ''), status = st, updated_at = now()
  where id = m.id;
  return m.id;
end $$;

-- Proposition d'un talent (étudiant) sur un besoin publié ; jamais sur son propre besoin ; une seule par talent.
create or replace function propose_on_mission(p_mission uuid, p_amount integer, p_delay_days integer, p_message text) returns uuid
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; pid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Seuls les talents peuvent proposer'; end if;
  select * into m from missions where id = p_mission;
  if not found or m.status <> 'published' then raise exception 'Ce besoin ne reçoit plus de propositions'; end if;
  if m.client_id = auth.uid() then raise exception 'Vous ne pouvez pas répondre à votre propre besoin'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Indiquez un montant supérieur à 0'; end if;
  if p_delay_days is null or p_delay_days not between 1 and 365 then raise exception 'Indiquez un délai de 1 à 365 jours'; end if;
  if exists (select 1 from mission_proposals where mission_id = m.id and author_id = auth.uid() and status = 'submitted') then raise exception 'Vous avez déjà proposé'; end if;
  insert into mission_proposals (mission_id, author_id, amount, delay_days, message)
  values (m.id, auth.uid(), p_amount, p_delay_days, nullif(left(trim(coalesce(p_message, '')), 2000), ''))
  on conflict (mission_id, author_id) do update set amount = excluded.amount, delay_days = excluded.delay_days, message = excluded.message, status = 'submitted', created_at = now(), decided_at = null
  returning id into pid;
  insert into notifications (user_id, kind, title, body, data)
  values (m.client_id, 'mission', 'Nouvelle proposition', 'Besoin « ' || coalesce(m.title, m.number) || ' » : ' || p_amount || ' FCFA en ' || p_delay_days || ' jour(s).', jsonb_build_object('mission_id', m.id, 'proposal_id', pid));
  return pid;
end $$;

-- Le client accepte (le besoin est attribué, les autres propositions sont déclinées, trois jalons sont créés) ou refuse.
create or replace function decide_proposal(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare p mission_proposals%rowtype; m missions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from mission_proposals where id = p_id;
  if not found then raise exception 'Proposition introuvable'; end if;
  select * into m from missions where id = p.mission_id;
  if m.client_id <> auth.uid() then raise exception 'Proposition introuvable'; end if;
  if p.status <> 'submitted' then raise exception 'Cette proposition est déjà traitée'; end if;
  if not p_accept then
    update mission_proposals set status = 'declined', decided_at = now() where id = p.id;
    insert into notifications (user_id, kind, title, body, data) values (p.author_id, 'mission', 'Proposition non retenue', 'Besoin « ' || coalesce(m.title, m.number) || ' »', jsonb_build_object('mission_id', m.id));
    return 'declined';
  end if;
  if m.status <> 'published' then raise exception 'Ce besoin est déjà attribué'; end if;
  update mission_proposals set status = 'accepted', decided_at = now() where id = p.id;
  update mission_proposals set status = 'declined', decided_at = now() where mission_id = m.id and id <> p.id and status = 'submitted';
  update missions set status = 'assigned', accepted = true, total = p.amount, updated_at = now() where id = m.id;
  insert into mission_milestones (mission_id, position, title, amount) values
    (m.id, 1, 'Brief validé', round(p.amount * 0.3)), (m.id, 2, 'Propositions', round(p.amount * 0.4)), (m.id, 3, 'Livraison finale', p.amount - round(p.amount * 0.3) - round(p.amount * 0.4))
  on conflict (mission_id, position) do nothing;
  insert into notifications (user_id, kind, title, body, data) values (p.author_id, 'mission', 'Proposition acceptée', 'Besoin « ' || coalesce(m.title, m.number) || ' » : la mission vous est attribuée.', jsonb_build_object('mission_id', m.id));
  return 'accepted';
end $$;

-- Attribution par le département (écran 199) d'un besoin publié à une équipe qualifiée.
create or replace function assign_mission(p_mission uuid, p_team text) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_team is null or char_length(trim(p_team)) not between 2 and 120 then raise exception 'Équipe invalide'; end if;
  select * into m from missions where id = p_mission;
  if not found or m.status <> 'published' then raise exception 'Ce besoin n''est pas attribuable'; end if;
  update missions set status = 'assigned', assigned_team = trim(p_team), assigned_by = auth.uid(), updated_at = now() where id = m.id;
  insert into notifications (user_id, kind, title, body, data) values (m.client_id, 'mission', 'Besoin attribué', 'Équipe : ' || trim(p_team), jsonb_build_object('mission_id', m.id));
  return 'assigned';
end $$;

-- Le prestataire retenu déclare un jalon livré ; le client le valide ou demande une correction (motif obligatoire).
create or replace function submit_milestone(p_mission uuid, p_position smallint) returns text
language plpgsql security definer set search_path = public as $$
declare j mission_milestones%rowtype; m missions%rowtype;
begin
  select * into m from missions where id = p_mission;
  if not found or not exists (select 1 from mission_proposals where mission_id = m.id and author_id = auth.uid() and status = 'accepted') then raise exception 'Mission introuvable'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status not in ('pending', 'correction') then raise exception 'Ce jalon est déjà livré'; end if;
  update mission_milestones set status = 'submitted', updated_at = now() where id = j.id;
  update missions set status = 'in_progress', updated_at = now() where id = m.id and status = 'assigned';
  insert into notifications (user_id, kind, title, body, data) values (m.client_id, 'mission', 'Jalon livré', j.title || ' : à valider', jsonb_build_object('mission_id', m.id, 'position', p_position));
  return 'submitted';
end $$;

create or replace function decide_milestone(p_mission uuid, p_position smallint, p_validate boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare j mission_milestones%rowtype; m missions%rowtype; who uuid;
begin
  select * into m from missions where id = p_mission and client_id = auth.uid();
  if not found then raise exception 'Mission introuvable'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status <> 'submitted' then raise exception 'Ce jalon n''a pas été livré'; end if;
  if not p_validate and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Précisez la correction demandée'; end if;
  update mission_milestones set status = case when p_validate then 'validated' else 'correction' end, note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), updated_at = now() where id = j.id;
  if p_validate and not exists (select 1 from mission_milestones where mission_id = m.id and status <> 'validated') then
    update missions set status = 'delivered', updated_at = now() where id = m.id;
  end if;
  select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  if who is not null then
    insert into notifications (user_id, kind, title, body, data) values (who, 'mission', case when p_validate then 'Jalon validé' else 'Correction demandée' end, j.title, jsonb_build_object('mission_id', m.id, 'position', p_position));
  end if;
  return case when p_validate then 'validated' else 'correction' end;
end $$;

-- ============================================================ vœux (marché des vœux, écrans 216–218, validation 224)
create table if not exists wishes (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  description text check (description is null or char_length(description) <= 2000),
  price integer check (price is null or price between 0 and 100000000),
  threshold integer check (threshold is null or threshold between 1 and 100000),
  duration_days integer check (duration_days is null or duration_days between 1 and 180),
  status text not null default 'draft' check (status in ('draft', 'submitted', 'approved', 'rejected', 'scheduled', 'closed')),
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_by uuid references profiles(id),
  scheduled_for text check (scheduled_for is null or char_length(scheduled_for) <= 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists wishes_status_idx on wishes (status);
alter table wishes enable row level security;
revoke all on wishes from anon, authenticated;
grant select on wishes to anon, authenticated;
drop policy if exists "vœux : publics une fois validés, auteur, département" on wishes;
create policy "vœux : publics une fois validés, auteur, département" on wishes for select
  using (status in ('approved', 'scheduled') or author_id = auth.uid() or current_role_name() in ('dept', 'admin'));

create or replace function save_wish(p_id uuid, p_title text, p_description text, p_price integer, p_threshold integer, p_duration_days integer, p_submit boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare w wishes%rowtype; wid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if p_submit and (p_price is null or p_price <= 0 or p_threshold is null or p_threshold < 1) then raise exception 'Indiquez le prix et le seuil de précommandes'; end if;
  if p_price is not null and p_price < 0 or p_threshold is not null and p_threshold < 1 or p_duration_days is not null and p_duration_days not between 1 and 180 then raise exception 'Valeurs invalides'; end if;
  if p_id is null then
    insert into wishes (author_id, title, description, price, threshold, duration_days, status)
    values (auth.uid(), trim(p_title), nullif(left(trim(coalesce(p_description, '')), 2000), ''), p_price, p_threshold, p_duration_days, case when p_submit then 'submitted' else 'draft' end)
    returning id into wid;
  else
    select * into w from wishes where id = p_id and author_id = auth.uid();
    if not found then raise exception 'Vœu introuvable'; end if;
    if w.status not in ('draft', 'rejected') then raise exception 'Ce vœu est déjà en validation ou publié'; end if;
    update wishes set title = trim(p_title), description = nullif(left(trim(coalesce(p_description, '')), 2000), ''), price = p_price, threshold = p_threshold,
      duration_days = p_duration_days, status = case when p_submit then 'submitted' else 'draft' end, updated_at = now() where id = w.id returning id into wid;
  end if;
  if p_submit then
    insert into notifications (user_id, kind, title, body, data)
    select id, 'wish', 'Vœu à valider', trim(p_title), jsonb_build_object('wish_id', wid) from profiles where role = 'dept';
  end if;
  return wid;
end $$;

create or replace function delete_wish(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
begin
  delete from wishes where id = p_id and author_id = auth.uid() and status in ('draft', 'rejected');
  if not found then raise exception 'Seul un brouillon ou un vœu refusé peut être supprimé'; end if;
  return 'deleted';
end $$;

-- Validation par le département : approuver, refuser (motif obligatoire) ou planifier la mise en ligne.
create or replace function review_wish(p_id uuid, p_decision text, p_note text, p_scheduled_for text default null) returns text
language plpgsql security definer set search_path = public as $$
declare w wishes%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into w from wishes where id = p_id;
  if not found or w.status <> 'submitted' then raise exception 'Aucun vœu à valider'; end if;
  if p_decision not in ('approved', 'rejected', 'scheduled') then raise exception 'Décision inconnue'; end if;
  if p_decision = 'rejected' and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  if p_decision = 'scheduled' and char_length(trim(coalesce(p_scheduled_for, ''))) < 3 then raise exception 'Date de mise en ligne obligatoire'; end if;
  update wishes set status = p_decision, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), reviewed_by = auth.uid(),
    scheduled_for = nullif(left(trim(coalesce(p_scheduled_for, '')), 60), ''), updated_at = now() where id = w.id;
  insert into notifications (user_id, kind, title, body, data)
  values (w.author_id, 'wish', case p_decision when 'rejected' then 'Vœu refusé' when 'scheduled' then 'Vœu planifié' else 'Vœu validé' end, w.title, jsonb_build_object('wish_id', w.id));
  return p_decision;
end $$;

-- ============================================================ campagnes de financement (écrans 84, 84b, 86)
create table if not exists campaigns (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  kind text not null default 'project' check (kind in ('project', 'preorder', 'sponsoring')),
  project text not null check (char_length(project) between 3 and 120),
  goal integer check (goal is null or goal between 1000 and 1000000000),
  duration_days integer check (duration_days is null or duration_days between 7 and 90),
  presentation text check (presentation is null or char_length(presentation) <= 4000),
  rewards text check (rewards is null or char_length(rewards) <= 2000),
  status text not null default 'draft' check (status in ('draft', 'submitted', 'approved', 'rejected', 'closed')),
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  reviewed_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table campaigns enable row level security;
revoke all on campaigns from anon, authenticated;
grant select on campaigns to anon, authenticated;
drop policy if exists "campagnes : publiques une fois validées, porteur, département" on campaigns;
create policy "campagnes : publiques une fois validées, porteur, département" on campaigns for select
  using (status = 'approved' or owner_id = auth.uid() or current_role_name() in ('dept', 'admin'));

create or replace function save_campaign(p_id uuid, p_kind text, p_project text, p_goal integer, p_duration_days integer, p_presentation text, p_rewards text, p_submit boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype; cid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux porteurs de projet étudiants'; end if;
  if p_kind not in ('project', 'preorder', 'sponsoring') then raise exception 'Type de campagne inconnu'; end if;
  if p_project is null or char_length(trim(p_project)) not between 3 and 120 then raise exception 'Projet : 3 à 120 caractères'; end if;
  if p_submit and (p_goal is null or p_goal < 1000 or p_duration_days is null or char_length(trim(coalesce(p_presentation, ''))) < 30) then
    raise exception 'Objectif (1 000 FCFA minimum), durée et présentation (30 caractères) sont nécessaires pour envoyer la campagne';
  end if;
  if p_goal is not null and p_goal not between 1000 and 1000000000 or p_duration_days is not null and p_duration_days not between 7 and 90 then raise exception 'Valeurs invalides'; end if;
  if p_id is null then
    insert into campaigns (owner_id, kind, project, goal, duration_days, presentation, rewards, status)
    values (auth.uid(), p_kind, trim(p_project), p_goal, p_duration_days, nullif(left(trim(coalesce(p_presentation, '')), 4000), ''), nullif(left(trim(coalesce(p_rewards, '')), 2000), ''),
            case when p_submit then 'submitted' else 'draft' end) returning id into cid;
  else
    select * into c from campaigns where id = p_id and owner_id = auth.uid();
    if not found then raise exception 'Campagne introuvable'; end if;
    if c.status not in ('draft', 'rejected') then raise exception 'Cette campagne est déjà en validation ou publiée'; end if;
    update campaigns set kind = p_kind, project = trim(p_project), goal = p_goal, duration_days = p_duration_days, presentation = nullif(left(trim(coalesce(p_presentation, '')), 4000), ''),
      rewards = nullif(left(trim(coalesce(p_rewards, '')), 2000), ''), status = case when p_submit then 'submitted' else 'draft' end, updated_at = now() where id = c.id returning id into cid;
  end if;
  return cid;
end $$;

create or replace function review_campaign(p_id uuid, p_approve boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare c campaigns%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into c from campaigns where id = p_id;
  if not found or c.status <> 'submitted' then raise exception 'Aucune campagne à valider'; end if;
  if not p_approve and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  update campaigns set status = case when p_approve then 'approved' else 'rejected' end, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), reviewed_by = auth.uid(), updated_at = now() where id = c.id;
  insert into notifications (user_id, kind, title, body, data) values (c.owner_id, 'campaign', case when p_approve then 'Campagne validée' else 'Campagne refusée' end, c.project, jsonb_build_object('campaign_id', c.id));
  return case when p_approve then 'approved' else 'rejected' end;
end $$;

-- ============================================================ certificats (écrans 166, 211, 213, 283)
create table if not exists certificates (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^BE-CERT-[0-9A-F]{8}$'),
  subject_kind text not null check (subject_kind in ('product', 'project', 'talent')),
  subject_title text not null check (char_length(subject_title) between 3 and 160),
  holder_id uuid references profiles(id) on delete set null,
  holder_name text not null check (char_length(holder_name) between 2 and 120),
  department text check (department is null or char_length(department) <= 120),
  listing_id uuid references listings(id) on delete set null,
  issued_by uuid not null references profiles(id),
  issued_at timestamptz not null default now(),
  fingerprint text not null,
  revoked boolean not null default false,
  revoked_reason text check (revoked_reason is null or char_length(revoked_reason) <= 500),
  revoked_at timestamptz
);
alter table certificates enable row level security;
revoke all on certificates from anon, authenticated;
grant select on certificates to authenticated;
drop policy if exists "certificats : titulaire, émetteurs" on certificates;
create policy "certificats : titulaire, émetteurs" on certificates for select
  using (holder_id = auth.uid() or current_role_name() in ('dept', 'admin', 'direction'));

-- Émission : département ou administration ; un produit doit être une annonce approuvée ; empreinte SHA-256 du contenu.
create or replace function issue_certificate(p_kind text, p_subject text, p_holder_email text, p_holder_name text, p_department text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare l listings%rowtype; h profiles%rowtype; c text; fp text;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Émission réservée au département ou à l''administrateur'; end if;
  if p_kind not in ('product', 'project', 'talent') then raise exception 'Type de certificat inconnu'; end if;
  if p_subject is null or char_length(trim(p_subject)) not between 3 and 160 then raise exception 'Objet du certificat : 3 à 160 caractères'; end if;
  if p_kind = 'product' then
    select * into l from listings where title = trim(p_subject) and status = 'approved' order by created_at desc limit 1;
    if not found then raise exception 'Seul un produit validé peut être certifié'; end if;
  end if;
  if nullif(trim(coalesce(p_holder_email, '')), '') is not null then
    select * into h from profiles where lower(email) = lower(trim(p_holder_email));
    if not found then raise exception 'Titulaire introuvable'; end if;
  end if;
  if coalesce(h.name, trim(coalesce(p_holder_name, ''))) = '' then raise exception 'Nom du titulaire obligatoire'; end if;
  if exists (select 1 from certificates where subject_kind = p_kind and lower(subject_title) = lower(trim(p_subject)) and coalesce(holder_id::text, holder_name) = coalesce(h.id::text, trim(p_holder_name)) and not revoked) then
    raise exception 'Un certificat valide existe déjà pour ce titulaire et cet objet';
  end if;
  c := 'BE-CERT-' || upper(encode(gen_random_bytes(4), 'hex'));
  fp := encode(digest(c || '|' || p_kind || '|' || trim(p_subject) || '|' || coalesce(h.id::text, trim(p_holder_name)) || '|' || now()::text, 'sha256'), 'hex');
  insert into certificates (code, subject_kind, subject_title, holder_id, holder_name, department, listing_id, issued_by, fingerprint)
  values (c, p_kind, trim(p_subject), h.id, coalesce(h.name, trim(p_holder_name)), nullif(left(trim(coalesce(p_department, '')), 120), ''), l.id, auth.uid(), fp);
  if h.id is not null then
    insert into notifications (user_id, kind, title, body, data) values (h.id, 'certificate', 'Certificat délivré', trim(p_subject) || ' · ' || c, jsonb_build_object('code', c));
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Certificat émis', c, 'Certificats', 'Sensible');
  return c;
end $$;

create or replace function revoke_certificate(p_code text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 5 then raise exception 'Motif de révocation obligatoire'; end if;
  update certificates set revoked = true, revoked_reason = left(trim(p_reason), 500), revoked_at = now() where code = upper(trim(p_code)) and not revoked;
  if not found then raise exception 'Certificat introuvable ou déjà révoqué'; end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Certificat révoqué', upper(trim(p_code)), 'Certificats', 'Sensible');
  return 'revoked';
end $$;

-- Vérification publique (scan du QR, écrans 166 et 211) : ne révèle que ce qui figure sur le certificat lui-même.
create or replace function verify_certificate(p_code text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce((select jsonb_build_object('code', code, 'objet', subject_title, 'type', subject_kind, 'titulaire', holder_name, 'departement', department,
                     'delivre_le', to_char(issued_at, 'DD/MM/YYYY'), 'valide', not revoked, 'motif_revocation', revoked_reason, 'empreinte', fingerprint)
                   from certificates where code = upper(trim(p_code))), jsonb_build_object('code', upper(trim(p_code)), 'valide', false, 'introuvable', true));
$$;

-- ============================================================ bornes (supervision 277, événements 282)
create table if not exists kiosks (
  id text primary key check (id ~ '^borne-[0-9]{1,3}$'),
  name text not null,
  location text not null,
  status text not null default 'online' check (status in ('online', 'offline', 'fallback', 'maintenance')),
  updated_at timestamptz not null default now()
);
create table if not exists kiosk_incidents (
  id bigint generated always as identity primary key,
  kiosk_id text not null references kiosks(id) on delete cascade,
  kind text not null check (kind in ('offline', 'restart', 'fallback', 'hardware', 'payment', 'other')),
  message text not null check (char_length(message) between 3 and 500),
  reported_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create table if not exists kiosk_events (
  id uuid primary key default gen_random_uuid(),
  kiosk_id text not null references kiosks(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
alter table kiosks enable row level security;
alter table kiosk_incidents enable row level security;
alter table kiosk_events enable row level security;
revoke all on kiosks, kiosk_incidents, kiosk_events from anon, authenticated;
grant select on kiosks, kiosk_events to anon, authenticated;
grant select on kiosk_incidents to authenticated;
drop policy if exists "bornes : visibles" on kiosks;
create policy "bornes : visibles" on kiosks for select using (true);
drop policy if exists "événements de borne : visibles" on kiosk_events;
create policy "événements de borne : visibles" on kiosk_events for select using (true);
drop policy if exists "incidents : support et administration" on kiosk_incidents;
create policy "incidents : support et administration" on kiosk_incidents for select using (current_role_name() in ('support', 'admin'));
insert into kiosks (id, name, location) values
  ('borne-1', 'Borne 1', 'Hall principal'), ('borne-2', 'Borne 2', 'Bibliothèque'), ('borne-3', 'Borne 3', 'Département MMI'), ('borne-4', 'Borne 4', 'Cafétéria')
on conflict (id) do nothing;

create or replace function report_kiosk_incident(p_kiosk text, p_kind text, p_message text, p_status text default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare iid bigint;
begin
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au support ou à l''administrateur'; end if;
  if not exists (select 1 from kiosks where id = p_kiosk) then raise exception 'Borne inconnue'; end if;
  if p_status is not null and p_status not in ('online', 'offline', 'fallback', 'maintenance') then raise exception 'État inconnu'; end if;
  insert into kiosk_incidents (kiosk_id, kind, message, reported_by) values (p_kiosk, p_kind, trim(p_message), auth.uid()) returning id into iid;
  if p_status is not null then update kiosks set status = p_status, updated_at = now() where id = p_kiosk; end if;
  return iid;
end $$;

create or replace function schedule_kiosk_event(p_kiosk text, p_title text, p_starts timestamptz, p_ends timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare eid uuid;
begin
  if coalesce(current_role_name()::text, '') not in ('support', 'admin') then raise exception 'Réservé au support ou à l''administrateur'; end if;
  if not exists (select 1 from kiosks where id = p_kiosk) then raise exception 'Borne inconnue'; end if;
  if p_ends <= p_starts then raise exception 'La fin doit suivre le début'; end if;
  if p_starts < now() - interval '1 hour' then raise exception 'L''événement ne peut pas commencer dans le passé'; end if;
  if exists (select 1 from kiosk_events where kiosk_id = p_kiosk and tstzrange(starts_at, ends_at) && tstzrange(p_starts, p_ends)) then raise exception 'Un événement occupe déjà ce créneau'; end if;
  insert into kiosk_events (kiosk_id, title, starts_at, ends_at, created_by) values (p_kiosk, trim(p_title), p_starts, p_ends, auth.uid()) returning id into eid;
  return eid;
end $$;

-- ============================================================ projets étudiants (205 dépôt, 82 journal, 278 liens et PI)
create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  summary text check (summary is null or char_length(summary) <= 4000),
  department text check (department is null or char_length(department) <= 120),
  links jsonb not null default '{}'::jsonb check (jsonb_typeof(links) = 'object' and pg_column_size(links) <= 4000),
  status text not null default 'draft' check (status in ('draft', 'submitted', 'approved', 'rejected')),
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists project_steps (
  id bigint generated always as identity primary key,
  project_id uuid not null references projects(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 160),
  happened_on date not null default current_date,
  created_at timestamptz not null default now()
);
alter table projects enable row level security;
alter table project_steps enable row level security;
revoke all on projects, project_steps from anon, authenticated;
grant select on projects, project_steps to authenticated;
drop policy if exists "projets : porteur, approuvés, département" on projects;
create policy "projets : porteur, approuvés, département" on projects for select
  using (owner_id = auth.uid() or status = 'approved' or current_role_name() in ('dept', 'admin'));
drop policy if exists "étapes : avec le projet" on project_steps;
create policy "étapes : avec le projet" on project_steps for select
  using (exists (select 1 from projects p where p.id = project_id and (p.owner_id = auth.uid() or p.status = 'approved' or current_role_name() in ('dept', 'admin'))));

create or replace function save_project(p_id uuid, p_title text, p_summary text, p_department text, p_links jsonb, p_submit boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype; pid uuid; l jsonb := coalesce(p_links, '{}'::jsonb);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux étudiants'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if jsonb_typeof(l) <> 'object' or pg_column_size(l) > 4000 then raise exception 'Liens invalides'; end if;
  if p_id is null then
    if p_submit and char_length(trim(coalesce(p_summary, ''))) < 30 then raise exception 'Présentez le projet en 30 caractères minimum avant de l''envoyer'; end if;
    insert into projects (owner_id, title, summary, department, links, status)
    values (auth.uid(), trim(p_title), nullif(left(trim(coalesce(p_summary, '')), 4000), ''), nullif(left(trim(coalesce(p_department, '')), 120), ''), l, case when p_submit then 'submitted' else 'draft' end)
    returning id into pid;
    return pid;
  end if;
  select * into p from projects where id = p_id and owner_id = auth.uid();
  if not found then raise exception 'Projet introuvable'; end if;
  if p_submit and p.status not in ('draft', 'rejected') then raise exception 'Ce projet est déjà envoyé'; end if;
  -- la présentation déjà enregistrée compte : on peut envoyer un projet sans la ressaisir
  if p_submit and char_length(trim(coalesce(nullif(trim(coalesce(p_summary, '')), ''), p.summary, ''))) < 30 then
    raise exception 'Présentez le projet en 30 caractères minimum avant de l''envoyer';
  end if;
  update projects set title = trim(p_title), summary = coalesce(nullif(left(trim(coalesce(p_summary, '')), 4000), ''), summary),
    department = coalesce(nullif(left(trim(coalesce(p_department, '')), 120), ''), department), links = links || l,
    status = case when p_submit then 'submitted' else status end, updated_at = now() where id = p.id;
  return p.id;
end $$;

create or replace function add_project_step(p_project uuid, p_title text, p_on date default current_date) returns bigint
language plpgsql security definer set search_path = public as $$
declare sid bigint;
begin
  if not exists (select 1 from projects where id = p_project and owner_id = auth.uid()) then raise exception 'Projet introuvable'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 160 then raise exception 'Étape : 3 à 160 caractères'; end if;
  if p_on > current_date + 1 then raise exception 'Une étape ne peut pas être datée dans le futur'; end if;
  insert into project_steps (project_id, title, happened_on) values (p_project, trim(p_title), coalesce(p_on, current_date)) returning id into sid;
  return sid;
end $$;

create or replace function review_project(p_id uuid, p_approve boolean, p_note text) returns text
language plpgsql security definer set search_path = public as $$
declare p projects%rowtype;
begin
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into p from projects where id = p_id;
  if not found or p.status <> 'submitted' then raise exception 'Aucun projet à examiner'; end if;
  if not p_approve and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Motif du refus obligatoire'; end if;
  update projects set status = case when p_approve then 'approved' else 'rejected' end, review_note = nullif(left(trim(coalesce(p_note, '')), 1000), ''), updated_at = now() where id = p.id;
  insert into notifications (user_id, kind, title, body, data) values (p.owner_id, 'project', case when p_approve then 'Projet accepté' else 'Projet refusé' end, p.title, jsonb_build_object('project_id', p.id));
  return case when p_approve then 'approved' else 'rejected' end;
end $$;

-- ============================================================ lives programmés (224)
create table if not exists scheduled_lives (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  starts_at text check (starts_at is null or char_length(starts_at) <= 60),
  product_title text check (product_title is null or char_length(product_title) <= 120),
  status text not null default 'draft' check (status in ('draft', 'scheduled', 'cancelled')),
  created_at timestamptz not null default now()
);
alter table scheduled_lives enable row level security;
revoke all on scheduled_lives from anon, authenticated;
grant select on scheduled_lives to anon, authenticated;
drop policy if exists "lives : programmés publics, brouillons à l'hôte" on scheduled_lives;
create policy "lives : programmés publics, brouillons à l'hôte" on scheduled_lives for select using (status = 'scheduled' or host_id = auth.uid());

create or replace function save_live(p_title text, p_starts_at text, p_product text, p_schedule boolean) returns uuid
language plpgsql security definer set search_path = public as $$
declare lid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux créateurs étudiants'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre du live : 3 à 120 caractères'; end if;
  if p_schedule and char_length(trim(coalesce(p_starts_at, ''))) < 3 then raise exception 'Indiquez la date et l''heure du live'; end if;
  insert into scheduled_lives (host_id, title, starts_at, product_title, status)
  values (auth.uid(), trim(p_title), nullif(left(trim(coalesce(p_starts_at, '')), 60), ''), nullif(left(trim(coalesce(p_product, '')), 120), ''), case when p_schedule then 'scheduled' else 'draft' end)
  returning id into lid;
  return lid;
end $$;

-- ============================================================ liens et outils du profil (271, P5)
alter table profiles add column if not exists links jsonb not null default '[]'::jsonb;
do $$ begin
  alter table profiles add constraint profiles_links_chk check (jsonb_typeof(links) = 'array' and jsonb_array_length(links) <= 12 and pg_column_size(links) <= 4000);
exception when duplicate_object then null; end $$;

create or replace function save_profile_links(p_links jsonb) returns integer
language plpgsql security definer set search_path = public as $$
declare x jsonb; n integer := 0;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if jsonb_typeof(p_links) <> 'array' or jsonb_array_length(p_links) > 12 then raise exception '12 liens au maximum'; end if;
  for x in select * from jsonb_array_elements(p_links) loop
    if jsonb_typeof(x) <> 'object' or coalesce(x->>'url', '') !~* '^https://[^\s<>"]+$' or char_length(coalesce(x->>'url', '')) not between 12 and 300
       or char_length(coalesce(x->>'label', '')) > 60 then
      raise exception 'Lien invalide : adresse https:// obligatoire';
    end if;
    n := n + 1;
  end loop;
  update profiles set links = p_links where id = auth.uid();
  return n;
end $$;

revoke all on function save_project(uuid, text, text, text, jsonb, boolean), add_project_step(uuid, text, date), review_project(uuid, boolean, text),
  save_live(text, text, text, boolean), save_profile_links(jsonb) from public, anon;
grant execute on function save_project(uuid, text, text, text, jsonb, boolean), add_project_step(uuid, text, date), review_project(uuid, boolean, text),
  save_live(text, text, text, boolean), save_profile_links(jsonb) to authenticated;

-- ============================================================ motif d'annulation d'une commande (écran 47)
-- Correctif : cancel_order (20261030c) renseignait cancelled_at sans le booléen « cancelled » lu par l'application ;
-- une commande annulée réapparaissait comme active. Le booléen est désormais tenu à jour (et rattrapé).
update orders set cancelled = true where cancelled_at is not null and not cancelled;
create or replace function sync_order_cancelled() returns trigger language plpgsql as $$
begin
  if new.cancelled_at is not null then new.cancelled := true; end if;
  return new;
end $$;
drop trigger if exists trg_sync_order_cancelled on orders;
create trigger trg_sync_order_cancelled before update of cancelled_at on orders for each row execute function sync_order_cancelled();
create table if not exists order_cancellations (
  order_id uuid primary key references orders(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  reason text not null check (reason in ('wrong_product', 'too_slow', 'better_offer', 'other')),
  created_at timestamptz not null default now()
);
alter table order_cancellations enable row level security;
revoke all on order_cancellations from anon, authenticated;
grant select on order_cancellations to authenticated;
drop policy if exists "motifs d'annulation : acheteur, support, finance" on order_cancellations;
create policy "motifs d'annulation : acheteur, support, finance" on order_cancellations for select
  using (user_id = auth.uid() or current_role_name() in ('admin', 'support', 'finance'));

-- Réutilise cancel_order (propriété, commande non payée, restitution du stock) puis enregistre le motif.
create or replace function cancel_order_with_reason(p_number text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare r text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_reason not in ('wrong_product', 'too_slow', 'better_offer', 'other') then raise exception 'Motif inconnu'; end if;
  r := cancel_order(p_number);
  insert into order_cancellations (order_id, user_id, reason)
  select id, auth.uid(), p_reason from orders where number = p_number and buyer_id = auth.uid()
  on conflict (order_id) do nothing;
  return r;
end $$;
revoke all on function cancel_order_with_reason(text, text) from public, anon;
grant execute on function cancel_order_with_reason(text, text) to authenticated;

-- ============================================================ droits d'exécution
revoke all on function save_mission(uuid, text, text, integer, integer, text, boolean, text), propose_on_mission(uuid, integer, integer, text),
  decide_proposal(uuid, boolean), assign_mission(uuid, text), submit_milestone(uuid, smallint), decide_milestone(uuid, smallint, boolean, text),
  save_wish(uuid, text, text, integer, integer, integer, boolean), delete_wish(uuid), review_wish(uuid, text, text, text),
  save_campaign(uuid, text, text, integer, integer, text, text, boolean), review_campaign(uuid, boolean, text),
  issue_certificate(text, text, text, text, text), revoke_certificate(text, text),
  report_kiosk_incident(text, text, text, text), schedule_kiosk_event(text, text, timestamptz, timestamptz) from public, anon;
grant execute on function save_mission(uuid, text, text, integer, integer, text, boolean, text), propose_on_mission(uuid, integer, integer, text),
  decide_proposal(uuid, boolean), assign_mission(uuid, text), submit_milestone(uuid, smallint), decide_milestone(uuid, smallint, boolean, text),
  save_wish(uuid, text, text, integer, integer, integer, boolean), delete_wish(uuid), review_wish(uuid, text, text, text),
  save_campaign(uuid, text, text, integer, integer, text, text, boolean), review_campaign(uuid, boolean, text),
  issue_certificate(text, text, text, text, text), revoke_certificate(text, text),
  report_kiosk_incident(text, text, text, text), schedule_kiosk_event(text, text, timestamptz, timestamptz) to authenticated;
revoke all on function verify_certificate(text) from public;
grant execute on function verify_certificate(text) to anon, authenticated;

-- ============================================================ RETOUR ARRIÈRE (à exécuter manuellement si nécessaire)
-- drop function if exists save_mission(uuid,text,text,integer,integer,text,boolean,text), propose_on_mission(uuid,integer,integer,text), decide_proposal(uuid,boolean),
--   assign_mission(uuid,text), submit_milestone(uuid,smallint), decide_milestone(uuid,smallint,boolean,text), save_wish(uuid,text,text,integer,integer,integer,boolean),
--   delete_wish(uuid), review_wish(uuid,text,text,text), save_campaign(uuid,text,text,integer,integer,text,text,boolean), review_campaign(uuid,boolean,text),
--   issue_certificate(text,text,text,text,text), revoke_certificate(text,text), verify_certificate(text), report_kiosk_incident(text,text,text,text),
--   schedule_kiosk_event(text,text,timestamptz,timestamptz);
-- drop trigger if exists trg_sync_order_cancelled on orders; drop function if exists sync_order_cancelled();
-- drop function if exists cancel_order_with_reason(text, text); drop table if exists order_cancellations;
-- drop function if exists save_project(uuid,text,text,text,jsonb,boolean), add_project_step(uuid,text,date), review_project(uuid,boolean,text),
--   save_live(text,text,text,boolean), save_profile_links(jsonb);
-- drop table if exists project_steps, projects, scheduled_lives;
-- alter table profiles drop constraint if exists profiles_links_chk, drop column if exists links;
-- drop table if exists kiosk_events, kiosk_incidents, kiosks, certificates, campaigns, wishes, mission_milestones, mission_proposals;
-- alter table missions drop constraint if exists missions_status_chk, drop constraint if exists missions_budget_chk,
--   drop column if exists title, drop column if exists status, drop column if exists budget_min, drop column if exists budget_max,
--   drop column if exists deadline, drop column if exists assigned_team, drop column if exists assigned_by, drop column if exists updated_at;
-- (les anciennes règles de « missions » ne sont pas restaurées : elles laissaient tout étudiant modifier toute mission.)
