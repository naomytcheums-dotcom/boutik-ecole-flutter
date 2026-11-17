-- Lot F3b : écrans entreprise 88, 93, 93b, 94, 98, 99, 187, 189, 285 (besoins et propositions reçus).
--   * missions.deadline_date : échéance en vraie date, calculée depuis le texte libre (dd/MM/yyyy, yyyy-MM-dd, « 30 nov. 2026 ») par un déclencheur ;
--     le compteur « Échéances sous 7 jours » devient exact (E1-10, E2-11) sans toucher à save_mission (propriété du lot F1).
--   * company_missions(p_owner) / company_proposals(p_owner) : un membre actif de l'équipe lit les besoins du propriétaire (E3-9, company_effective_owner),
--     noms abrégés (E2-15), identifiants et statuts nécessaires aux écrans (fiche de proposition, comparaison, dossier de mission),
--     compteur de propositions ACTIVES (soumises ou retenues) distinct du total (E1-9), indicateur « besoin » (ni brouillon, ni annulé, ni mission sur mesure).
--   * decide_proposal(p_id, p_accept, p_reason) : refuse un compte suspendu (E2-16), motif de refus facultatif transmis au talent (E2-6).
-- Retour arrière :
--   drop function company_missions(uuid), company_proposals(uuid), decide_proposal(uuid, boolean, text);
--   puis réappliquer company_missions()/company_proposals() depuis 20261105000400 et decide_proposal(uuid, boolean) depuis 20261117045100 ;
--   drop trigger missions_deadline_sync on missions; drop function _missions_deadline_sync(), _parse_deadline(text);
--   alter table missions drop column deadline_date; alter table mission_proposals drop column decline_reason.

alter table missions add column if not exists deadline_date date;
alter table mission_proposals add column if not exists decline_reason text check (decline_reason is null or char_length(decline_reason) <= 300);

-- Date réelle d'une échéance saisie en texte ; null si le texte n'est pas une date valide.
create or replace function _parse_deadline(p text) returns date
language plpgsql immutable set search_path = public as $$
declare s text := translate(lower(btrim(coalesce(p, ''))), 'éèêûôàâ', 'eeeuoaa'); a text[]; w text; m int;
begin
  if s = '' then return null; end if;
  a := regexp_match(s, '^(\d{4})-(\d{1,2})-(\d{1,2})(?:$|[t ])');
  if a is not null then return make_date(a[1]::int, a[2]::int, a[3]::int); end if;
  a := regexp_match(s, '^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$');
  if a is not null then return make_date(a[3]::int, a[2]::int, a[1]::int); end if;
  a := regexp_match(s, '^(\d{1,2})(?:er)?\s+([a-z]+)\.?\s+(\d{4})$');
  if a is not null then
    w := a[2];
    m := case when w like 'janv%' or w = 'jan' then 1 when w like 'fev%' then 2 when w like 'mar%' then 3 when w like 'avr%' then 4 when w = 'mai' then 5
              when w like 'juin%' then 6 when w like 'juil%' then 7 when w like 'aou%' then 8 when w like 'sep%' then 9 when w like 'oct%' then 10
              when w like 'nov%' then 11 when w like 'dec%' then 12 else null end;
    if m is null then return null; end if;
    return make_date(a[3]::int, m, a[1]::int);
  end if;
  return null;
exception when others then
  return null;
end $$;
revoke all on function _parse_deadline(text) from public, anon;
grant execute on function _parse_deadline(text) to authenticated;

create or replace function _missions_deadline_sync() returns trigger
language plpgsql set search_path = public as $$
begin
  new.deadline_date := _parse_deadline(new.deadline);
  return new;
end $$;
revoke all on function _missions_deadline_sync() from public, anon;

drop trigger if exists missions_deadline_sync on missions;
create trigger missions_deadline_sync before insert or update of deadline on missions
  for each row execute function _missions_deadline_sync();

update missions set deadline_date = _parse_deadline(deadline) where deadline is not null and deadline_date is null;

-- Besoins de l'entreprise (ou de l'entreprise dont on est membre actif).
drop function if exists company_missions();
create or replace function company_missions(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'number', m.number, 'title', coalesce(m.title, m.number), 'kind', m.kind, 'status', m.status,
      'created_at', m.created_at, 'updated_at', m.updated_at, 'deadline', m.deadline, 'deadline_date', m.deadline_date,
      'budget_min', m.budget_min, 'budget_max', m.budget_max, 'team', coalesce(m.assigned_team, ''),
      'is_need', (m.kind = 'besoin' and m.status not in ('draft', 'cancelled')),
      'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id and p.status in ('submitted', 'accepted')),
      'proposals_total', (select count(*)::int from mission_proposals p where p.mission_id = m.id)
    ) order by m.created_at desc)
    from (select * from missions where client_id = v_owner order by created_at desc limit 300) m
  ), '[]'::jsonb);
end $$;

-- Propositions reçues : auteur abrégé, message, identifiants, certification et nombre de projets publics de l'auteur.
drop function if exists company_proposals();
create or replace function company_proposals(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'mission_id', m.id, 'mission', coalesce(m.title, m.number), 'mission_status', m.status, 'mission_kind', m.kind,
      'author_id', p.author_id, 'author', display_name(p.author_id), 'amount', p.amount, 'delay_days', p.delay_days,
      'status', p.status, 'message', p.message, 'attempts', p.attempts, 'created_at', p.created_at,
      'author_certified', coalesce(a.certification::text = 'approved', false),
      'author_projects', (select count(*)::int from projects x where x.owner_id = p.author_id and x.status = 'approved' and x.visibility = 'public')
    ) order by p.created_at desc)
    from mission_proposals p join missions m on m.id = p.mission_id left join profiles a on a.id = p.author_id
    where m.client_id = v_owner
  ), '[]'::jsonb);
end $$;

revoke all on function company_missions(uuid), company_proposals(uuid) from public, anon;
grant execute on function company_missions(uuid), company_proposals(uuid) to authenticated;

-- Décision sur une proposition : garde-fous de 20261117045100 conservés, plus compte suspendu refusé et motif de refus facultatif.
drop function if exists decide_proposal(uuid, boolean);
create or replace function decide_proposal(p_id uuid, p_accept boolean, p_reason text default null) returns text
language plpgsql security definer set search_path = public as $$
declare p mission_proposals%rowtype; m missions%rowtype; v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 300), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false)) then raise exception 'Votre compte est suspendu'; end if;
  select * into p from mission_proposals where id = p_id;
  if not found then raise exception 'Proposition introuvable'; end if;
  select * into m from missions where id = p.mission_id;
  if m.client_id <> auth.uid() then raise exception 'Proposition introuvable'; end if;
  if p.status <> 'submitted' then raise exception 'Cette proposition est déjà traitée'; end if;
  if not p_accept then
    update mission_proposals set status = 'declined', decided_at = now(), decline_reason = v_reason where id = p.id;
    perform notify_user(p.author_id, 'mission', 'Proposition non retenue',
      'Besoin « ' || coalesce(m.title, m.number) || ' »' || case when v_reason is null then '' else ' · Motif : ' || v_reason end, jsonb_build_object('mission_id', m.id));
    return 'declined';
  end if;
  if m.status <> 'published' then raise exception 'Ce besoin est déjà attribué'; end if;
  if exists (select 1 from profiles where id = p.author_id and coalesce(suspended, false)) then raise exception 'Ce talent n''est plus disponible'; end if;
  perform _mission_accept(p.id, null, false);
  return 'accepted';
end $$;

revoke all on function decide_proposal(uuid, boolean, text) from public, anon;
grant execute on function decide_proposal(uuid, boolean, text) to authenticated;
