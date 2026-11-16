-- Missions côté prestataire (profil étudiant-vendeur, lot S4 « devis-missions »).
--   S4-95   assign_mission : l'attribution par le département retient une proposition (ou crée celle du talent choisi), passe par la même logique que decide_proposal
--           (jalons, accord), et prévient le talent retenu ; decide_proposal prévient aussi les talents non retenus (S4-115)
--   S4-98/S4-100  submit_milestone(p_mission, p_position, p_note, p_files) : preuve obligatoire (texte d'au moins 10 caractères et/ou fichiers déposés dans project-files),
--           jalons livrés dans l'ordre, mission attribuée ou en cours
--   S4-92   mission_agreements (montant convenu, numéro de facture de mission), paiement de chaque jalon tracé entre les parties
--           (milestone_pay_declare par le client, milestone_pay_confirm par le prestataire), mission_invoice : aucun séquestre n'est prétendu
--   S4-89/S4-99/S4-109  my_missions (missions du client et du prestataire, avec jalons et preuves), my_proposals, withdraw_proposal
--   S4-114/S4-117  open_needs : besoins publiés avec leur description, sans l'identifiant du client (le chef peut alors restreindre la lecture de missions)
--   S4-103  send_mission_message : blocages (chat_guard), suspension et plafond de messages
--   S4-106/S4-120  mission_close, remind_milestones (rappel au client après 7 jours)
--   S4-73   seller_statement : relevé de ventes et de missions réglées d'un vendeur
-- Retour arrière : drop function _mission_accept(uuid, text, boolean), mission_close(uuid), milestone_pay_declare(uuid, smallint, text, text), milestone_pay_confirm(uuid, smallint, boolean),
--   mission_invoice(uuid), my_missions(), my_proposals(), withdraw_proposal(uuid), open_needs(), remind_milestones(), seller_statement(date, date) ;
--   select cron.unschedule('remind-milestones') ; drop table mission_agreements ; recréer assign_mission(uuid, text) et submit_milestone(uuid, smallint) (20261031000200),
--   decide_proposal (20261031000000), send_mission_message (20261031000200), my_needs (20261115210000) ;
--   alter table mission_milestones drop column proof_note, drop column proof_files, drop column submitted_at, drop column pay_status, drop column pay_method,
--   drop column pay_reference, drop column pay_declared_at, drop column pay_confirmed_at, drop column reminded_at.

-- ============================================================ 1. colonnes et accord
alter table mission_milestones add column if not exists proof_note text check (proof_note is null or char_length(proof_note) <= 2000);
alter table mission_milestones add column if not exists proof_files uuid[] not null default '{}';
alter table mission_milestones add column if not exists submitted_at timestamptz;
alter table mission_milestones add column if not exists pay_status text not null default 'unpaid' check (pay_status in ('unpaid', 'declared', 'confirmed'));
alter table mission_milestones add column if not exists pay_method text check (pay_method is null or char_length(pay_method) <= 40);
alter table mission_milestones add column if not exists pay_reference text check (pay_reference is null or char_length(pay_reference) <= 80);
alter table mission_milestones add column if not exists pay_declared_at timestamptz;
alter table mission_milestones add column if not exists pay_confirmed_at timestamptz;
alter table mission_milestones add column if not exists reminded_at timestamptz;

create sequence if not exists mission_invoice_seq;
create table if not exists mission_agreements (
  mission_id uuid primary key references missions(id) on delete cascade,
  client_id uuid not null references profiles(id) on delete cascade,
  provider_id uuid not null references profiles(id) on delete cascade,
  proposal_id uuid references mission_proposals(id) on delete set null,
  amount integer not null check (amount > 0),
  delay_days integer,
  invoice_number text not null unique,
  agreed_at timestamptz not null default now()
);
alter table mission_agreements enable row level security;
revoke all on mission_agreements from anon, authenticated;
grant select on mission_agreements to authenticated;
drop policy if exists "accords de mission : parties et département" on mission_agreements;
create policy "accords de mission : parties et département" on mission_agreements for select
  using (client_id = auth.uid() or provider_id = auth.uid() or current_role_name() in ('dept', 'admin'));

-- Missions déjà attribuées avant cette migration : l'accord est reconstitué depuis la proposition acceptée.
insert into mission_agreements (mission_id, client_id, provider_id, proposal_id, amount, delay_days, invoice_number, agreed_at)
select m.id, m.client_id, p.author_id, p.id, p.amount, p.delay_days,
       'MI-' || to_char(coalesce(p.decided_at, now()), 'YYYY') || '-' || lpad(nextval('mission_invoice_seq')::text, 5, '0'), coalesce(p.decided_at, now())
  from missions m join mission_proposals p on p.mission_id = m.id and p.status = 'accepted'
 where not exists (select 1 from mission_agreements a where a.mission_id = m.id)
on conflict (mission_id) do nothing;

-- ============================================================ 2. attribution (S4-95) et acceptation (S4-115)
-- Logique commune : proposition retenue, autres propositions déclinées et prévenues, mission attribuée, trois jalons 30/40/30, accord de mission.
create or replace function _mission_accept(p_proposal uuid, p_team text default null, p_by_staff boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare p mission_proposals%rowtype; m missions%rowtype; r record; v_team text;
begin
  select * into p from mission_proposals where id = p_proposal for update;
  select * into m from missions where id = p.mission_id for update;
  v_team := coalesce(nullif(trim(coalesce(p_team, '')), ''), display_name(p.author_id));
  update mission_proposals set status = 'accepted', decided_at = now() where id = p.id;
  for r in update mission_proposals set status = 'declined', decided_at = now() where mission_id = m.id and id <> p.id and status = 'submitted' returning author_id loop
    perform notify_user(r.author_id, 'mission', 'Proposition non retenue', 'Besoin « ' || coalesce(m.title, m.number) || ' » : une autre proposition a été retenue.', jsonb_build_object('mission_id', m.id));
  end loop;
  update missions set status = 'assigned', accepted = true, total = p.amount, assigned_team = v_team,
    assigned_by = case when p_by_staff then auth.uid() else assigned_by end, updated_at = now() where id = m.id;
  insert into mission_milestones (mission_id, position, title, amount) values
    (m.id, 1, 'Brief validé', round(p.amount * 0.3)), (m.id, 2, 'Propositions', round(p.amount * 0.4)), (m.id, 3, 'Livraison finale', p.amount - round(p.amount * 0.3) - round(p.amount * 0.4))
  on conflict (mission_id, position) do nothing;
  insert into mission_agreements (mission_id, client_id, provider_id, proposal_id, amount, delay_days, invoice_number)
  values (m.id, m.client_id, p.author_id, p.id, p.amount, p.delay_days, 'MI-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('mission_invoice_seq')::text, 5, '0'))
  on conflict (mission_id) do update set provider_id = excluded.provider_id, proposal_id = excluded.proposal_id, amount = excluded.amount, delay_days = excluded.delay_days, agreed_at = now();
  perform notify_user(p.author_id, 'mission', case when p_by_staff then 'Mission attribuée' else 'Proposition acceptée' end,
    'Besoin « ' || coalesce(m.title, m.number) || ' » : la mission vous est attribuée (' || p.amount || ' FCFA). Livrez chaque jalon avec une preuve.', jsonb_build_object('mission_id', m.id));
  if p_by_staff then
    perform notify_user(m.client_id, 'mission', 'Besoin attribué', 'Équipe : ' || v_team, jsonb_build_object('mission_id', m.id));
  end if;
end $$;
revoke all on function _mission_accept(uuid, text, boolean) from public, anon, authenticated;

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
    perform notify_user(p.author_id, 'mission', 'Proposition non retenue', 'Besoin « ' || coalesce(m.title, m.number) || ' »', jsonb_build_object('mission_id', m.id));
    return 'declined';
  end if;
  if m.status <> 'published' then raise exception 'Ce besoin est déjà attribué'; end if;
  if exists (select 1 from profiles where id = p.author_id and coalesce(suspended, false)) then raise exception 'Ce talent n''est plus disponible'; end if;
  perform _mission_accept(p.id, null, false);
  return 'accepted';
end $$;

drop function if exists assign_mission(uuid, text);
create or replace function assign_mission(p_mission uuid, p_team text default null, p_proposal uuid default null, p_author uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; p mission_proposals%rowtype; v_amount integer; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  select * into m from missions where id = p_mission for update;
  if not found or m.status <> 'published' then raise exception 'Ce besoin n''est pas attribuable'; end if;
  if p_proposal is null and p_author is null then
    select count(*) into v_n from mission_proposals where mission_id = m.id and status = 'submitted';
    if v_n <> 1 then raise exception 'Choisissez la proposition à retenir ou le talent à qui attribuer ce besoin'; end if;
    select id into p_proposal from mission_proposals where mission_id = m.id and status = 'submitted';
  end if;
  if p_proposal is not null then
    select * into p from mission_proposals where id = p_proposal and mission_id = m.id and status = 'submitted';
    if not found then raise exception 'Proposition introuvable ou déjà traitée'; end if;
  else
    if p_author = m.client_id then raise exception 'Le demandeur ne peut pas réaliser son propre besoin'; end if;
    if not exists (select 1 from profiles where id = p_author and role::text = 'student' and not coalesce(suspended, false)) then raise exception 'Talent introuvable ou indisponible'; end if;
    v_amount := coalesce(m.budget_max, m.budget_min, nullif(m.total, 0));
    if v_amount is null or v_amount <= 0 then raise exception 'Ce besoin n''a pas de budget : demandez une proposition chiffrée au talent'; end if;
    insert into mission_proposals (mission_id, author_id, amount, delay_days, message)
    values (m.id, p_author, v_amount, 30, 'Attribué par le département')
    on conflict (mission_id, author_id) do update set amount = excluded.amount, delay_days = excluded.delay_days, message = excluded.message, status = 'submitted', decided_at = null
    returning * into p;
  end if;
  perform _mission_accept(p.id, p_team, true);
  return 'assigned';
end $$;

-- ============================================================ 3. preuve de livraison (S4-98, S4-100)
drop function if exists submit_milestone(uuid, smallint);
create or replace function submit_milestone(p_mission uuid, p_position smallint, p_note text default null, p_files uuid[] default '{}') returns text
language plpgsql security definer set search_path = public as $$
declare j mission_milestones%rowtype; m missions%rowtype; v_note text := nullif(left(trim(coalesce(p_note, '')), 2000), ''); v_files uuid[] := coalesce(p_files, '{}');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into m from missions where id = p_mission;
  if not found or not exists (select 1 from mission_proposals where mission_id = m.id and author_id = auth.uid() and status = 'accepted') then raise exception 'Mission introuvable'; end if;
  if m.status not in ('assigned', 'in_progress') then raise exception 'Cette mission n''accepte plus de livraison'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position for update;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status not in ('pending', 'correction') then raise exception 'Ce jalon est déjà livré'; end if;
  if exists (select 1 from mission_milestones where mission_id = m.id and position < p_position and status <> 'validated') then
    raise exception 'Le jalon précédent doit d''abord être validé par le client';
  end if;
  if coalesce(array_length(v_files, 1), 0) > 5 then raise exception 'Cinq pièces au plus par livraison'; end if;
  if coalesce(array_length(v_files, 1), 0) > 0 and (select count(*) from files where id = any(v_files) and owner_id = auth.uid() and scope = 'mission' and ref = m.id) <> (select count(distinct x) from unnest(v_files) x) then
    raise exception 'Fichier introuvable dans ce dossier';
  end if;
  if v_note is null or char_length(v_note) < 10 then
    if coalesce(array_length(v_files, 1), 0) = 0 then raise exception 'Joignez une preuve : décrivez ce qui a été réalisé (10 caractères minimum) ou ajoutez une photo ou un fichier'; end if;
  end if;
  update mission_milestones set status = 'submitted', proof_note = v_note, proof_files = (select coalesce(array_agg(distinct x), '{}') from unnest(v_files) x), submitted_at = now(), reminded_at = null, updated_at = now() where id = j.id;
  update missions set status = 'in_progress', updated_at = now() where id = m.id and status = 'assigned';
  insert into notifications (user_id, kind, title, body, data)
  values (m.client_id, 'mission', 'Jalon livré', j.title || ' : à valider' || case when v_note is null then '' else ' — ' || left(regexp_replace(v_note, '\s+', ' ', 'g'), 100) end,
          jsonb_build_object('mission_id', m.id, 'position', p_position));
  return 'submitted';
end $$;

-- ============================================================ 4. accord de paiement tracé (S4-92) : sans séquestre
create or replace function milestone_pay_declare(p_mission uuid, p_position smallint, p_method text, p_reference text default null) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; j mission_milestones%rowtype; who uuid; v_method text := nullif(left(trim(coalesce(p_method, '')), 40), ''); v_ref text := nullif(left(trim(coalesce(p_reference, '')), 80), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission and client_id = auth.uid();
  if not found then raise exception 'Mission introuvable'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position for update;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.status <> 'validated' then raise exception 'Le paiement se déclare une fois le jalon validé'; end if;
  if j.pay_status = 'confirmed' then raise exception 'Ce paiement est déjà confirmé par le prestataire'; end if;
  if v_method is null then raise exception 'Indiquez le moyen de paiement utilisé'; end if;
  update mission_milestones set pay_status = 'declared', pay_method = v_method, pay_reference = v_ref, pay_declared_at = now(), pay_confirmed_at = null, updated_at = now() where id = j.id;
  select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  if who is not null then
    perform notify_user(who, 'mission', 'Paiement déclaré', j.title || ' : ' || j.amount || ' FCFA réglés par ' || v_method || '. Confirmez la réception dans « Mes missions ».', jsonb_build_object('mission_id', m.id, 'position', p_position));
  end if;
  return 'declared';
end $$;

create or replace function milestone_pay_confirm(p_mission uuid, p_position smallint, p_received boolean default true) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; j mission_milestones%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or not exists (select 1 from mission_proposals where mission_id = m.id and author_id = auth.uid() and status = 'accepted') then raise exception 'Mission introuvable'; end if;
  select * into j from mission_milestones where mission_id = m.id and position = p_position for update;
  if not found then raise exception 'Jalon introuvable'; end if;
  if j.pay_status <> 'declared' then raise exception 'Aucun paiement déclaré par le client pour ce jalon'; end if;
  if p_received then
    update mission_milestones set pay_status = 'confirmed', pay_confirmed_at = now(), updated_at = now() where id = j.id;
  else
    update mission_milestones set pay_status = 'unpaid', pay_declared_at = null, updated_at = now() where id = j.id;
  end if;
  perform notify_user(m.client_id, 'mission', case when p_received then 'Paiement confirmé' else 'Paiement non reçu' end,
    j.title || ' : ' || case when p_received then 'le prestataire confirme avoir reçu ' || j.amount || ' FCFA.' else 'le prestataire indique ne pas avoir reçu le paiement. Vérifiez et déclarez-le de nouveau.' end,
    jsonb_build_object('mission_id', m.id, 'position', p_position));
  return case when p_received then 'confirmed' else 'unpaid' end;
end $$;

-- Clôture par le client une fois tous les jalons validés.
create or replace function mission_close(p_mission uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; who uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission and client_id = auth.uid() for update;
  if not found then raise exception 'Mission introuvable'; end if;
  if m.status = 'closed' then return 'closed'; end if;
  if m.status <> 'delivered' then raise exception 'La mission se clôture une fois tous les jalons validés'; end if;
  update missions set status = 'closed', updated_at = now() where id = m.id;
  select author_id into who from mission_proposals where mission_id = m.id and status = 'accepted';
  if who is not null then
    perform notify_user(who, 'mission', 'Mission clôturée', coalesce(m.title, m.number) || ' : le client a clôturé la mission.', jsonb_build_object('mission_id', m.id));
  end if;
  return 'closed';
end $$;

-- Rappel au client après 7 jours sans décision sur un jalon livré ; le prestataire en est informé (aucune validation tacite).
create or replace function remind_milestones() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select j.id, j.title, j.mission_id, j.position, m.client_id, m.title as mtitle, m.number,
           (select author_id from mission_proposals p where p.mission_id = m.id and p.status = 'accepted') as provider_id
      from mission_milestones j join missions m on m.id = j.mission_id
     where j.status = 'submitted' and j.submitted_at is not null and j.submitted_at < now() - interval '7 days' and j.reminded_at is null
  loop
    n := n + 1;
    update mission_milestones set reminded_at = now() where id = r.id;
    perform notify_user(r.client_id, 'mission', 'Jalon en attente de votre décision', r.title || ' (' || coalesce(r.mtitle, r.number) || ') est livré depuis plus de 7 jours : validez-le ou demandez une correction.', jsonb_build_object('mission_id', r.mission_id, 'position', r.position));
    if r.provider_id is not null then
      perform notify_user(r.provider_id, 'mission', 'Relance envoyée au client', r.title || ' : le client a été relancé après 7 jours sans réponse.', jsonb_build_object('mission_id', r.mission_id, 'position', r.position));
    end if;
  end loop;
  return n;
end $$;
revoke all on function remind_milestones() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('remind-milestones') where exists (select 1 from cron.job where jobname = 'remind-milestones');
  perform cron.schedule('remind-milestones', '40 7 * * *', 'select public.remind_milestones()');
exception when others then
  raise notice 'pg_cron indisponible : remind_milestones() doit être planifiée autrement (%).', sqlerrm;
end $$;

-- ============================================================ 5. lectures : missions, propositions, besoins ouverts
create or replace function _mission_json(p_mission uuid, p_role text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'kind', m.kind, 'description', m.description, 'status', m.status, 'role', p_role,
      'total', m.total, 'team', coalesce(m.assigned_team, ''), 'deadline', m.deadline, 'created_at', m.created_at, 'updated_at', m.updated_at,
      'counterpart', case when p_role = 'client' then (select display_name(a.provider_id) from mission_agreements a where a.mission_id = m.id) else null end,
      'agreement', (select jsonb_build_object('invoice_number', a.invoice_number, 'amount', a.amount, 'delay_days', a.delay_days, 'agreed_at', a.agreed_at) from mission_agreements a where a.mission_id = m.id),
      'milestones', coalesce((select jsonb_agg(jsonb_build_object('position', j.position, 'title', j.title, 'amount', j.amount, 'status', j.status, 'note', j.note,
          'proof_note', j.proof_note, 'submitted_at', j.submitted_at, 'pay_status', j.pay_status, 'pay_method', j.pay_method, 'pay_reference', j.pay_reference,
          'pay_declared_at', j.pay_declared_at, 'pay_confirmed_at', j.pay_confirmed_at,
          'proof_files', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'path', f.path, 'mime', f.mime)) from files f where f.id = any(j.proof_files)), '[]'::jsonb)) order by j.position)
        from mission_milestones j where j.mission_id = m.id), '[]'::jsonb))
  from missions m where m.id = p_mission
$$;
revoke all on function _mission_json(uuid, text) from public, anon, authenticated;

-- Missions où le compte est client (hors brouillons et annulées) ou prestataire retenu ; le prestataire ne voit pas l'identité du client.
create or replace function my_missions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(_mission_json(x.id, x.role) order by x.updated_at desc)
    from (
      select m.id, 'client' as role, m.updated_at from missions m where m.client_id = auth.uid() and m.status not in ('draft', 'cancelled')
      union all
      select m.id, 'provider', m.updated_at from missions m
       where m.client_id <> auth.uid() and m.status <> 'cancelled'
         and exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')
      order by updated_at desc limit 100
    ) x
  ), '[]'::jsonb);
end $$;

create or replace function my_proposals() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'mission_id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'mission_status', m.status,
        'amount', p.amount, 'delay_days', p.delay_days, 'message', p.message, 'status', p.status, 'attempts', p.attempts, 'created_at', p.created_at, 'decided_at', p.decided_at)
      order by p.created_at desc)
    from (select * from mission_proposals where author_id = auth.uid() order by created_at desc limit 100) p join missions m on m.id = p.mission_id
  ), '[]'::jsonb);
end $$;

create or replace function withdraw_proposal(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare p mission_proposals%rowtype; m missions%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from mission_proposals where id = p_id and author_id = auth.uid() for update;
  if not found then raise exception 'Proposition introuvable'; end if;
  if p.status <> 'submitted' then raise exception 'Cette proposition est déjà traitée'; end if;
  select * into m from missions where id = p.mission_id;
  update mission_proposals set status = 'withdrawn', decided_at = now() where id = p.id;
  perform notify_user(m.client_id, 'mission', 'Proposition retirée', 'Besoin « ' || coalesce(m.title, m.number) || ' » : un talent a retiré sa proposition.', jsonb_build_object('mission_id', m.id));
  return 'withdrawn';
end $$;

create or replace function open_needs() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Réservé aux talents'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'kind', m.kind, 'description', m.description,
        'budget_min', m.budget_min, 'budget_max', m.budget_max, 'deadline', m.deadline, 'created_at', m.created_at,
        'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id and p.status in ('submitted', 'accepted')),
        'my_status', (select p.status from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid())) order by m.created_at desc)
    from (select * from missions where status = 'published' and client_id <> auth.uid() order by created_at desc limit 100) m
  ), '[]'::jsonb);
end $$;

-- Besoins du client : jalons avec preuve et paiement (le client doit voir la preuve avant de valider).
create or replace function my_needs() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'kind', m.kind, 'status', m.status,
      'budget_min', m.budget_min, 'budget_max', m.budget_max, 'deadline', m.deadline, 'created_at', m.created_at,
      'proposals', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'amount', p.amount, 'delay_days', p.delay_days, 'message', p.message, 'status', p.status,
          'author_id', p.author_id, 'author_name', display_name(p.author_id), 'attempts', p.attempts, 'created_at', p.created_at) order by p.created_at desc)
        from mission_proposals p where p.mission_id = m.id), '[]'::jsonb),
      'milestones', coalesce((select jsonb_agg(jsonb_build_object('position', j.position, 'title', j.title, 'amount', j.amount, 'status', j.status, 'note', j.note,
          'proof_note', j.proof_note, 'pay_status', j.pay_status, 'pay_method', j.pay_method, 'pay_reference', j.pay_reference,
          'proof_files', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'path', f.path)) from files f where f.id = any(j.proof_files)), '[]'::jsonb)) order by j.position)
        from mission_milestones j where j.mission_id = m.id), '[]'::jsonb)) order by m.updated_at desc)
    from (select * from missions where client_id = auth.uid() order by updated_at desc limit 50) m), '[]'::jsonb);
end $$;

-- ============================================================ 6. facture de mission (S4-92) : document de l'accord entre les parties
create or replace function mission_invoice(p_mission uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m missions%rowtype; a mission_agreements%rowtype; v_role text; v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into m from missions where id = p_mission;
  if not found or not is_mission_participant(p_mission) then raise exception 'Mission introuvable'; end if;
  select * into a from mission_agreements where mission_id = m.id;
  if not found then raise exception 'Aucun accord enregistré pour cette mission'; end if;
  v_role := case when auth.uid() = m.client_id then 'client' when auth.uid() = a.provider_id then 'provider' else 'staff' end;
  return jsonb_build_object(
    'number', a.invoice_number, 'issued_at', a.agreed_at, 'mission_number', m.number, 'title', coalesce(m.title, m.number), 'status', m.status,
    'role', v_role, 'agreed_amount', a.amount, 'delay_days', a.delay_days,
    'client_name', case when v_role in ('client', 'staff') or v_staff then display_name(m.client_id) else 'Client Boutik-École (identité non communiquée)' end,
    'provider_name', display_name(a.provider_id),
    'milestones', coalesce((select jsonb_agg(jsonb_build_object('position', j.position, 'title', j.title, 'amount', j.amount, 'status', j.status, 'pay_status', j.pay_status,
        'pay_method', j.pay_method, 'pay_reference', j.pay_reference, 'pay_confirmed_at', j.pay_confirmed_at) order by j.position)
      from mission_milestones j where j.mission_id = m.id), '[]'::jsonb),
    'validated_amount', (select coalesce(sum(amount), 0) from mission_milestones where mission_id = m.id and status = 'validated'),
    'declared_amount', (select coalesce(sum(amount), 0) from mission_milestones where mission_id = m.id and pay_status = 'declared'),
    'confirmed_amount', (select coalesce(sum(amount), 0) from mission_milestones where mission_id = m.id and pay_status = 'confirmed'),
    'notice', 'Accord conclu entre le client et le prestataire. Boutik-École ne bloque ni ne verse les fonds de la mission : chaque jalon se règle directement entre les parties ; la déclaration du paiement et la confirmation de réception sont tracées dans l''application.');
end $$;

-- ============================================================ 7. dossier de mission : blocages, suspension, plafond (S4-103)
create or replace function send_mission_message(p_mission uuid, p_body text, p_file uuid default null) returns bigint
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid bigint; who uuid; other uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into m from missions where id = p_mission;
  if not found or not is_mission_party(p_mission) then raise exception 'Dossier introuvable'; end if;
  if m.status not in ('assigned', 'in_progress', 'delivered') then raise exception 'Le dossier s''ouvre une fois la mission attribuée'; end if;
  if p_body is null or char_length(trim(p_body)) = 0 then raise exception 'Message vide'; end if;
  if p_file is not null and not exists (select 1 from files where id = p_file and owner_id = auth.uid() and scope = 'mission' and ref = m.id) then
    raise exception 'Fichier introuvable dans ce dossier';
  end if;
  if m.client_id = auth.uid() then
    select author_id into other from mission_proposals where mission_id = m.id and status = 'accepted';
  else
    other := m.client_id;
  end if;
  if other is not null then perform chat_guard(other); end if;
  if (select count(*) from mission_messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then
    raise exception 'Trop de messages : patientez un instant';
  end if;
  insert into mission_messages (mission_id, sender_id, body, file_id) values (m.id, auth.uid(), left(trim(p_body), 2000), p_file) returning id into mid;
  who := other;
  if who is not null and who <> auth.uid() then
    insert into notifications (user_id, kind, title, body, data) values (who, 'mission', 'Nouveau message du dossier', coalesce(m.title, m.number), jsonb_build_object('mission_id', m.id));
  end if;
  return mid;
end $$;

-- ============================================================ 8. relevé de ventes et de missions réglées (S4-73)
-- Montants bruts (prix × quantité de ses lignes) des commandes payées ou à payer à la livraison, non annulées ; la répartition du séquestre n'y figure pas.
create or replace function seller_statement(p_from date default null, p_to date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_to date := coalesce(p_to, current_date); v_from date := coalesce(p_from, coalesce(p_to, current_date) - 365);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_from > v_to then raise exception 'Période invalide'; end if;
  if v_to - v_from > 400 then raise exception 'Période trop longue (400 jours au plus)'; end if;
  return jsonb_build_object(
    'from', v_from, 'to', v_to, 'seller', (select name from profiles where id = auth.uid()), 'generated_at', now(),
    'sales', coalesce((
      select jsonb_agg(s order by s.created_at desc) from (
        select o.number, o.created_at::date as created_at, min(ol.title) as title, sum(ol.qty)::int as qty, sum(ol.qty * ol.unit_price)::int as total,
               case when o.paid then 'paid' else 'cod' end as payment, min(ol.fulfillment)::int as fulfillment
          from order_lines ol join listings l on l.id = ol.listing_id join orders o on o.id = ol.order_id
         where l.seller_id = auth.uid() and (o.paid or o.cod) and o.cancelled_at is null and not coalesce(o.cancelled, false)
           and o.created_at::date between v_from and v_to
         group by o.number, o.created_at, o.paid
      ) s), '[]'::jsonb),
    'missions', coalesce((
      select jsonb_agg(x order by x.confirmed_at desc) from (
        select m.number, coalesce(m.title, m.number) as title, j.position, j.title as milestone, j.amount, j.pay_method, j.pay_confirmed_at::date as confirmed_at
          from mission_milestones j join missions m on m.id = j.mission_id
         where j.pay_status = 'confirmed' and j.pay_confirmed_at::date between v_from and v_to
           and exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = auth.uid() and p.status = 'accepted')
      ) x), '[]'::jsonb));
end $$;

revoke all on function decide_proposal(uuid, boolean), assign_mission(uuid, text, uuid, uuid), submit_milestone(uuid, smallint, text, uuid[]),
  milestone_pay_declare(uuid, smallint, text, text), milestone_pay_confirm(uuid, smallint, boolean), mission_close(uuid),
  my_missions(), my_proposals(), withdraw_proposal(uuid), open_needs(), my_needs(), mission_invoice(uuid),
  send_mission_message(uuid, text, uuid), seller_statement(date, date) from public, anon;
grant execute on function decide_proposal(uuid, boolean), assign_mission(uuid, text, uuid, uuid), submit_milestone(uuid, smallint, text, uuid[]),
  milestone_pay_declare(uuid, smallint, text, text), milestone_pay_confirm(uuid, smallint, boolean), mission_close(uuid),
  my_missions(), my_proposals(), withdraw_proposal(uuid), open_needs(), my_needs(), mission_invoice(uuid),
  send_mission_message(uuid, text, uuid), seller_statement(date, date) to authenticated;
