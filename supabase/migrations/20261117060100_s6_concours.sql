-- Lot S6 (2/4) : concours et hackathons (S6-64, S6-65, S6-11).
--  1. save_contest : règlement, thématique, frais d'inscription (entry_fee) et dates de début/fin désormais enregistrables (messages clairs sur chaque borne) ;
--     après publication les frais ne peuvent plus augmenter (comme la dotation) ;
--  2. jurés : my_juror_contests() et my_judging_projects() permettent à TOUT compte désigné juré de noter (l'écran 167 n'est plus limité au département) ;
--  3. contest_team_leave : un membre ajouté à une équipe (invitation acceptée) peut la quitter tant que le dépôt n'est pas clos.
-- Retour arrière : voir le bas du fichier.

drop function if exists save_contest(uuid, text, text, text, text, text, timestamptz, timestamptz, date, date, integer, integer, boolean);

create or replace function save_contest(p_id uuid, p_title text, p_description text, p_theme text, p_rules text, p_city text,
  p_reg_close timestamptz, p_submit_close timestamptz, p_starts date, p_ends date, p_prize integer, p_places integer, p_publish boolean, p_entry_fee integer default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare c contests%rowtype; cid uuid; v_fee integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not is_contest_staff() then raise exception 'Publication réservée au département ou à l''administrateur'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if char_length(trim(coalesce(p_theme, ''))) > 200 then raise exception 'Thématique : 200 caractères au plus'; end if;
  if char_length(trim(coalesce(p_rules, ''))) > 8000 then raise exception 'Règlement : 8 000 caractères au plus'; end if;
  if p_reg_close is null or p_submit_close is null then raise exception 'Dates de clôture obligatoires'; end if;
  if p_submit_close < p_reg_close then raise exception 'La clôture des dépôts ne peut pas précéder celle des inscriptions'; end if;
  if p_starts is not null and p_ends is not null and p_ends < p_starts then raise exception 'La date de fin ne peut pas précéder la date de début'; end if;
  if coalesce(p_places, 0) not between 1 and 1000 then raise exception 'Places : de 1 à 1 000 équipes'; end if;
  if coalesce(p_prize, 0) not between 0 and 1000000000 then raise exception 'Dotation invalide'; end if;
  if p_entry_fee is not null and p_entry_fee not between 0 and 100000000 then raise exception 'Frais d''inscription invalides'; end if;
  if p_publish and (p_reg_close <= now()) then raise exception 'La clôture des inscriptions doit être future'; end if;
  if p_publish and char_length(coalesce(trim(p_description), '')) < 30 then raise exception 'Décrivez le concours (30 caractères minimum)'; end if;
  if p_id is null then
    insert into contests (title, description, theme, rules, city, reg_close_at, submit_close_at, starts_on, ends_on, prize, places, status, created_by, entry_fee)
    values (trim(p_title), coalesce(trim(p_description), ''), coalesce(trim(p_theme), ''), coalesce(trim(p_rules), ''), coalesce(nullif(trim(p_city), ''), 'En ligne'),
            p_reg_close, p_submit_close, p_starts, p_ends, coalesce(p_prize, 0), p_places, case when p_publish then 'published' else 'draft' end, auth.uid(), coalesce(p_entry_fee, 0))
    returning id into cid;
  else
    select * into c from contests where id = p_id for update;
    if not found then raise exception 'Concours introuvable'; end if;
    if c.status in ('results', 'cancelled') then raise exception 'Concours terminé : modification impossible'; end if;
    v_fee := coalesce(p_entry_fee, c.entry_fee);
    if c.status <> 'draft' then
      -- après publication : dates seulement prolongées, dotation et places seulement augmentées, frais seulement réduits
      if p_reg_close < c.reg_close_at or p_submit_close < c.submit_close_at then raise exception 'Après publication, les dates ne peuvent qu''être prolongées'; end if;
      if coalesce(p_prize, 0) < c.prize then raise exception 'Après publication, la dotation ne peut qu''augmenter'; end if;
      if p_places < c.places then raise exception 'Après publication, le nombre de places ne peut qu''augmenter'; end if;
      if v_fee > c.entry_fee then raise exception 'Après publication, les frais d''inscription ne peuvent qu''être réduits'; end if;
    end if;
    update contests set title = trim(p_title), description = coalesce(trim(p_description), ''), theme = coalesce(trim(p_theme), ''), rules = coalesce(trim(p_rules), ''),
      city = coalesce(nullif(trim(p_city), ''), 'En ligne'), reg_close_at = p_reg_close, submit_close_at = p_submit_close, starts_on = p_starts, ends_on = p_ends,
      prize = coalesce(p_prize, 0), places = p_places, entry_fee = v_fee, status = case when c.status = 'draft' and p_publish then 'published' else c.status end, updated_at = now()
    where id = c.id;
    cid := c.id;
  end if;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, case when p_id is null then 'Concours créé' else 'Concours modifié' end, trim(p_title), 'Concours', 'Sensible');
  return cid;
end $$;

-- Concours dont je suis juré (tout compte désigné, quel que soit son rôle) : projets déposés hors de mon équipe et nombre de projets que j'ai déjà notés.
create or replace function my_juror_contests() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'status', c.status, 'submit_close_at', c.submit_close_at,
      'projects', (select count(*)::int from contest_submissions s join contest_teams t on t.id = s.team_id
                   where t.contest_id = c.id and s.submitted and not t.hidden
                     and not exists (select 1 from contest_members m where m.team_id = t.id and m.user_id = auth.uid())),
      'scored', (select count(*)::int from contest_scores x join contest_submissions s on s.id = x.submission_id join contest_teams t on t.id = s.team_id
                 where t.contest_id = c.id and x.juror_id = auth.uid())) order by c.created_at desc)
    from contests c join contest_jurors j on j.contest_id = c.id and j.user_id = auth.uid()
    where c.status in ('published', 'judging', 'results')), '[]'::jsonb);
end $$;

-- Projets que je peux noter maintenant (concours en délibération dont je suis juré, hors de ma propre équipe), avec ma note éventuelle.
create or replace function my_judging_projects() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'submission_id', s.id, 'title', s.title, 'team', t.name, 'contest_id', c.id, 'contest', c.title,
      'my_total', (select x.innovation + x.feasibility + x.impact + x.pitch from contest_scores x where x.submission_id = s.id and x.juror_id = auth.uid())) order by c.title, s.updated_at)
    from contest_submissions s join contest_teams t on t.id = s.team_id join contests c on c.id = t.contest_id
    where s.submitted and not t.hidden and c.status = 'judging' and is_contest_juror(c.id)
      and not exists (select 1 from contest_members m where m.team_id = t.id and m.user_id = auth.uid())), '[]'::jsonb);
end $$;

-- Quitter une équipe de concours (membre ajouté d'office par une invitation acceptée) : avant la clôture des dépôts, sans projet déjà soumis. Le capitaine ne peut pas partir.
create or replace function contest_team_leave(p_team uuid) returns text
language plpgsql security definer set search_path = public as $$
declare t contest_teams%rowtype; c contests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into t from contest_teams where id = p_team;
  if not found or not exists (select 1 from contest_members where team_id = p_team and user_id = auth.uid() and status in ('captain', 'member')) then raise exception 'Vous n''êtes pas membre de cette équipe'; end if;
  if t.captain_id = auth.uid() then raise exception 'Le capitaine ne peut pas quitter son équipe'; end if;
  select * into c from contests where id = t.contest_id;
  if c.status <> 'published' or now() > c.submit_close_at then raise exception 'Le concours est clos : vous ne pouvez plus quitter l''équipe'; end if;
  if exists (select 1 from contest_submissions where team_id = t.id and submitted) then raise exception 'Le projet est déjà déposé : vous ne pouvez plus quitter l''équipe'; end if;
  delete from contest_members where team_id = p_team and user_id = auth.uid();
  update contest_tasks set assignee_id = null where team_id = p_team and assignee_id = auth.uid();
  perform notify_user(t.captain_id, 'contest', 'Un membre a quitté l''équipe', left(display_name(auth.uid()) || ' a quitté l''équipe « ' || t.name || ' ».', 500), jsonb_build_object('team_id', t.id));
  return 'left';
end $$;

revoke all on function save_contest(uuid, text, text, text, text, text, timestamptz, timestamptz, date, date, integer, integer, boolean, integer) from public, anon;
grant execute on function save_contest(uuid, text, text, text, text, text, timestamptz, timestamptz, date, date, integer, integer, boolean, integer) to authenticated;
revoke all on function my_juror_contests(), my_judging_projects(), contest_team_leave(uuid) from public, anon;
grant execute on function my_juror_contests(), my_judging_projects(), contest_team_leave(uuid) to authenticated;

-- Retour arrière : drop function save_contest(...14 paramètres), my_juror_contests(), my_judging_projects(), contest_team_leave(uuid) ;
--   recréer save_contest depuis 20261101000200_concours.sql (13 paramètres) avec ses GRANT.
