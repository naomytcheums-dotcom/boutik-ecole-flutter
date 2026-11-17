-- Lot F1 (3/6) — publication : besoins, offres, concours, duels (E1-3, E1-4, E1-18, E1-22, E5-2, E5-7, E5-8, E5-14, E5-15, E5-19, E6-13).
--   · save_mission : la porte (_publish_check) s'applique à toute publication des rôles company ET other (vérification + forfait) ; les rôles client, étudiant,
--     département et administration gardent leurs besoins (décision 3) ; brouillons plafonnés à 10 ; « Brouillon » sur un besoin publié exige p_unpublish = true
--     (sinon refus explicite) et prévient les proposants ; 5 publications / 24 h comptées sur la date de publication, message exact avec l'heure de reprise ;
--     p_owner : un administrateur d'équipe publie au nom de l'entreprise (vérifications et quotas de l'ENTREPRISE) ; l'auteur réel est tracé (created_by) et le propriétaire prévenu ;
--   · opp_save : même porte ; le nom de l'organisation d'une entreprise ou ONG est celui de sa fiche approuvée (plus de texte libre) ; p_owner ;
--   · ann_save : même porte ; quota sans exclusion à tort (E5-14) ; organisateur et type imposés pour company/other ; p_owner ;
--   · duel_create : entreprise et organisation approuvées seulement ; le prix est une information NON financière (aucune somme), annoncée comme telle par duels_list.
-- Retour arrière : recréer save_mission (20261115210000), opp_save (20261114004100), ann_save (20261115200400), duel_create (20261115200100) et duels_list (20261117060300) ;
--   drop function save_mission(uuid, text, text, integer, integer, text, boolean, text, boolean, uuid), opp_save(... , uuid), ann_save(jsonb, uuid).

-- ============================================================ besoins
drop function if exists save_mission(uuid, text, text, integer, integer, text, boolean, text);
create or replace function save_mission(p_id uuid, p_title text, p_description text, p_budget_min integer, p_budget_max integer, p_deadline text, p_publish boolean,
  p_kind text default 'besoin', p_unpublish boolean default false, p_owner uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare m missions%rowtype; mid uuid; st text; v_actor uuid := auth.uid(); v_owner uuid; v_arg uuid; r record; v_new boolean := false; v_msg text; v_nprop integer;
begin
  if v_actor is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  v_arg := case when v_owner = v_actor then null else v_owner end;
  if p_id is not null then
    select * into m from missions where id = p_id and client_id = v_owner;
    if not found then raise exception 'Besoin introuvable'; end if;
  end if;
  v_msg := _publish_check(case when not coalesce(p_publish, false) then 'draft' when m.status = 'published' then 'need_edit' else 'need' end, p_id, v_arg);
  if v_msg is not null then raise exception '%', v_msg; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre : 3 à 120 caractères'; end if;
  if p_publish and (p_description is null or char_length(trim(p_description)) < 20) then raise exception 'Décrivez le besoin en 20 caractères minimum'; end if;
  if char_length(coalesce(p_description, '')) > 4000 then raise exception 'Description trop longue'; end if;
  if p_budget_min is not null and p_budget_min < 0 or p_budget_max is not null and p_budget_max < coalesce(p_budget_min, 0) then raise exception 'Budget invalide'; end if;
  if p_kind not in ('besoin', 'mission') then raise exception 'Type inconnu'; end if;
  st := case when p_publish then 'published' else 'draft' end;
  if p_id is null then
    insert into missions (number, client_id, kind, title, description, total, status, budget_min, budget_max, deadline, created_by, published_at)
    values ('#BR-' || to_char(now(), 'YYYY') || '-' || lpad((floor(random() * 1000000))::text, 6, '0'), v_owner, p_kind, trim(p_title),
            coalesce(trim(p_description), ''), coalesce(p_budget_max, p_budget_min, 0), st, p_budget_min, p_budget_max, nullif(left(trim(coalesce(p_deadline, '')), 60), ''),
            v_actor, case when p_publish then now() end)
    returning id into mid;
    v_new := p_publish;
  else
    if m.status not in ('draft', 'published') then raise exception 'Ce besoin est déjà attribué'; end if;
    if m.status = 'published' and not p_publish then
      select count(*) into v_nprop from mission_proposals where mission_id = m.id and status = 'submitted';
      if not coalesce(p_unpublish, false) then
        raise exception 'Ce besoin est publié : l''enregistrer comme brouillon le retire de la liste des besoins%. Utilisez « Publier » pour enregistrer vos modifications sans le retirer, ou confirmez le retrait.',
          case when v_nprop > 0 then ' (' || v_nprop || ' proposition(s) en attente seront suspendues)' else '' end;
      end if;
    end if;
    update missions set title = trim(p_title), description = coalesce(trim(p_description), ''), budget_min = p_budget_min, budget_max = p_budget_max,
      total = coalesce(p_budget_max, p_budget_min, 0), deadline = nullif(left(trim(coalesce(p_deadline, '')), 60), ''), status = st, updated_at = now(),
      published_at = case when p_publish and m.status = 'draft' then now() else published_at end
    where id = m.id;
    mid := m.id;
    v_new := p_publish and m.status = 'draft';
    if m.status = 'published' and not p_publish then
      for r in select author_id from mission_proposals where mission_id = m.id and status = 'submitted' loop
        perform notify_user(r.author_id, 'mission', 'Besoin retiré de la liste', 'Le besoin « ' || coalesce(m.title, m.number) || ' » a été retiré temporairement par son auteur. Votre proposition est conservée s''il est republié.',
          jsonb_build_object('mission_id', m.id));
      end loop;
    end if;
  end if;
  if v_new then
    for r in select id from profiles where role::text in ('dept', 'admin') and not suspended and id <> v_actor loop
      perform notify_user(r.id, 'mission', 'Nouveau besoin à qualifier', display_name(v_owner) || ' a publié « ' || trim(p_title) || ' ».', jsonb_build_object('mission_id', mid));
    end loop;
  end if;
  if v_new and v_owner <> v_actor then
    perform notify_user(v_owner, 'company_team', 'Besoin publié par votre équipe', display_name(v_actor) || ' a publié « ' || trim(p_title) || ' » au nom de votre entreprise.', jsonb_build_object('mission_id', mid, 'by', v_actor));
    insert into audit_log (actor, action, target, category, level) values (v_actor::text, 'Besoin publié au nom de l''entreprise', trim(p_title), 'Entreprise', 'Info');
  end if;
  return mid;
end $$;
revoke all on function save_mission(uuid, text, text, integer, integer, text, boolean, text, boolean, uuid) from public, anon;
grant execute on function save_mission(uuid, text, text, integer, integer, text, boolean, text, boolean, uuid) to authenticated;

-- ============================================================ offres
drop function if exists opp_save(text, text, text, text, text, text, text, text, integer, text, date, text[], text, text[], text, text, text, text[], text, boolean, text, boolean);
create or replace function opp_save(p_org text, p_kind text, p_contract text, p_title text, p_location text, p_mode text, p_duration text, p_pay_kind text, p_pay_amount integer, p_pay_note text,
  p_deadline date, p_skills text[], p_description text, p_missions text[], p_profile text, p_department text, p_level text, p_gains text[], p_whatsapp text, p_in_app boolean, p_about text,
  p_iut_only boolean, p_owner uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_actor uuid := auth.uid(); v_owner uuid; v_arg uuid; v_role text; v_staff boolean; v_skills text[]; v_missions text[]; v_gains text[]; r record; v_msg text; v_org text;
begin
  if v_actor is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  v_arg := case when v_owner = v_actor then null else v_owner end;
  v_msg := _publish_check('offer', null, v_arg);
  if v_msg is not null then raise exception '%', v_msg; end if;
  select role::text into v_role from profiles where id = v_owner;
  v_staff := v_role in ('admin', 'dept');
  v_org := btrim(coalesce(p_org, ''));
  -- Une entreprise ou une ONG publie sous le nom de sa fiche approuvée (jamais un nom libre).
  if v_role in ('company', 'other') then
    v_org := coalesce((select nullif(btrim(c.company_name), '') from company_profiles c where c.owner_id = v_owner), v_org);
  end if;
  if char_length(v_org) < 2 then raise exception 'Indiquez le nom de l''organisation'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Indiquez le poste ou la mission'; end if;
  if p_kind not in ('stage', 'emploi', 'mission', 'defi', 'benevolat', 'formation') then raise exception 'Type d''opportunité inconnu'; end if;
  if p_mode not in ('onsite', 'online', 'hybrid') then raise exception 'Mode inconnu'; end if;
  if p_pay_kind not in ('paid', 'unpaid', 'negotiable') then raise exception 'Rémunération inconnue'; end if;
  if p_deadline is not null and p_deadline < current_date then raise exception 'La date limite doit être dans le futur'; end if;
  if char_length(btrim(coalesce(p_description, ''))) < 20 then raise exception 'Décrivez l''offre en 20 caractères minimum'; end if;
  if coalesce(p_in_app, true) = false and btrim(coalesce(p_whatsapp, '')) = '' then raise exception 'Indiquez au moins un moyen de postuler (dans l''application ou par WhatsApp)'; end if;
  if (select count(*) from opportunities where poster_id = v_owner and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix offres par jour au plus'; end if;
  select array_agg(btrim(x)) into v_skills from unnest(coalesce(p_skills, '{}'::text[])) x where char_length(btrim(x)) between 1 and 40;
  select array_agg(btrim(x)) into v_missions from unnest(coalesce(p_missions, '{}'::text[])) x where char_length(btrim(x)) between 2 and 200;
  select array_agg(btrim(x)) into v_gains from unnest(coalesce(p_gains, '{}'::text[])) x where char_length(btrim(x)) between 2 and 60;
  insert into opportunities (poster_id, posted_by, org_name, kind, contract, title, location, mode, duration, pay_kind, pay_amount, pay_note, deadline, skills, description, missions, profile_wanted,
      department_target, level, gains, apply_whatsapp, apply_in_app, about_org, iut_only, verified, status)
    values (v_owner, v_actor, v_org, p_kind, left(btrim(coalesce(p_contract, '')), 40), btrim(p_title), left(btrim(coalesce(p_location, '')), 80), p_mode, left(btrim(coalesce(p_duration, '')), 40), p_pay_kind,
      p_pay_amount, left(btrim(coalesce(p_pay_note, '')), 120), p_deadline, coalesce(v_skills, '{}'), btrim(p_description), coalesce(v_missions, '{}'), left(btrim(coalesce(p_profile, '')), 1000),
      left(btrim(coalesce(p_department, '')), 120), left(btrim(coalesce(p_level, '')), 60), coalesce(v_gains, '{}'), btrim(coalesce(p_whatsapp, '')), coalesce(p_in_app, true), left(btrim(coalesce(p_about, '')), 1000),
      coalesce(p_iut_only, false), v_staff, case when v_staff then 'published' else 'pending' end)
    returning id into v_id;
  if v_staff then
    perform _opp_alert_matching(v_id);
  else
    for r in select id from profiles where role::text in ('admin', 'dept') loop
      perform notify_user(r.id, 'opportunity_review', 'Offre à valider', v_org || ' propose « ' || btrim(p_title) || ' ».', jsonb_build_object('opportunity', v_id));
    end loop;
  end if;
  if v_owner <> v_actor then
    perform notify_user(v_owner, 'company_team', 'Offre déposée par votre équipe', display_name(v_actor) || ' a déposé l''offre « ' || btrim(p_title) || ' » au nom de votre entreprise.', jsonb_build_object('opportunity', v_id, 'by', v_actor));
    insert into audit_log (actor, action, target, category, level) values (v_actor::text, 'Offre déposée au nom de l''entreprise', btrim(p_title), 'Entreprise', 'Info');
  end if;
  return v_id;
end $$;
revoke all on function opp_save(text, text, text, text, text, text, text, text, integer, text, date, text[], text, text[], text, text, text, text[], text, boolean, text, boolean, uuid) from public, anon;
grant execute on function opp_save(text, text, text, text, text, text, text, text, integer, text, date, text[], text, text[], text, text, text, text[], text, boolean, text, boolean, uuid) to authenticated;

-- ============================================================ concours
drop function if exists ann_save(jsonb);
create or replace function ann_save(p jsonb, p_owner uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_actor uuid := auth.uid(); v_owner uuid; v_arg uuid; v_role text; v_staff boolean; v_id uuid; r record; v_msg text; v_org text; v_kind text;
begin
  if v_actor is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  v_arg := case when v_owner = v_actor then null else v_owner end;
  -- Le quota est contrôlé sur les annonces EXISTANTES : cette fonction ne fait que créer, aucune n'est à exclure (E5-14).
  v_msg := _publish_check('contest', null, v_arg);
  if v_msg is not null then raise exception '%', v_msg; end if;
  select role::text into v_role from profiles where id = v_owner;
  v_staff := v_role in ('admin', 'dept');
  v_org := btrim(coalesce(p->>'organizer', ''));
  v_kind := coalesce(nullif(p->>'organizer_kind', ''), 'other');
  if v_role in ('company', 'other') then
    v_org := coalesce((select nullif(btrim(c.company_name), '') from company_profiles c where c.owner_id = v_owner), v_org);
    v_kind := case when v_role = 'company' then 'company' when v_kind in ('ngo', 'other') then v_kind else 'ngo' end;
  end if;
  if char_length(btrim(coalesce(p->>'title', ''))) < 3 then raise exception 'Indiquez le titre du concours'; end if;
  if char_length(v_org) < 2 then raise exception 'Indiquez l''organisateur'; end if;
  if coalesce(p->>'kind', '') not in ('contest', 'scholarship', 'hackathon', 'call', 'internship', 'job', 'training') then raise exception 'Type inconnu'; end if;
  if coalesce(p->>'official_url', '') !~* '^https?://[^ ]+\.[^ ]+' then raise exception 'Indiquez le lien officiel (commençant par http)'; end if;
  begin
    if nullif(p->>'deadline', '') is not null and (p->>'deadline')::date < current_date then raise exception 'La date limite doit être dans le futur'; end if;
    perform nullif(p->>'opens_on', '')::date, nullif(p->>'results_on', '')::date, nullif(p->>'program_start', '')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception 'Une des dates est invalide : utilisez le format AAAA-MM-JJ';
  end;
  if nullif(p->>'cost_amount', '') is not null and (p->>'cost_amount') !~ '^[0-9]{1,9}$' then raise exception 'Le coût doit être un nombre entier de 9 chiffres au plus'; end if;
  if (select count(*) from contest_announcements where poster_id = v_owner and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix annonces par jour au plus'; end if;
  insert into contest_announcements (poster_id, posted_by, title, organizer, organizer_kind, country, place_kind, place, domain, kind, description, why, conditions, documents, steps, criteria,
      opens_on, deadline, results_on, program_start, reward, eligible_level, eligible_age, eligible_department, eligible_country, iut_only, free, cost_amount, cost_currency, official_url, verified, status)
  values (v_owner, v_actor, btrim(p->>'title'), v_org, v_kind, left(coalesce(p->>'country', ''), 60), coalesce(nullif(p->>'place_kind', ''), 'online'), left(coalesce(p->>'place', ''), 100),
      coalesce(nullif(p->>'domain', ''), 'other'), p->>'kind', left(coalesce(p->>'description', ''), 4000), left(coalesce(p->>'why', ''), 1000),
      coalesce(array(select jsonb_array_elements_text(coalesce(p->'conditions', '[]'::jsonb))), '{}'), coalesce(array(select jsonb_array_elements_text(coalesce(p->'documents', '[]'::jsonb))), '{}'),
      coalesce(array(select jsonb_array_elements_text(coalesce(p->'steps', '[]'::jsonb))), '{}'), coalesce(array(select jsonb_array_elements_text(coalesce(p->'criteria', '[]'::jsonb))), '{}'),
      nullif(p->>'opens_on', '')::date, nullif(p->>'deadline', '')::date, nullif(p->>'results_on', '')::date, nullif(p->>'program_start', '')::date,
      left(coalesce(p->>'reward', ''), 200), left(coalesce(p->>'eligible_level', ''), 80), left(coalesce(p->>'eligible_age', ''), 40), left(coalesce(p->>'eligible_department', ''), 120), left(coalesce(p->>'eligible_country', ''), 80),
      coalesce((p->>'iut_only')::boolean, false), coalesce((p->>'free')::boolean, true), nullif(p->>'cost_amount', '')::integer, coalesce(nullif(p->>'cost_currency', ''), 'FCFA'), btrim(p->>'official_url'),
      v_staff, case when v_staff then 'published' else 'pending' end)
  returning id into v_id;
  if not v_staff then
    for r in select id from profiles where role::text = 'admin' loop
      perform notify_user(r.id, 'contest_review', 'Concours à valider', v_org || ' propose « ' || btrim(p->>'title') || ' ».', jsonb_build_object('announcement', v_id));
    end loop;
  end if;
  if v_owner <> v_actor then
    perform notify_user(v_owner, 'company_team', 'Concours déposé par votre équipe', display_name(v_actor) || ' a déposé « ' || btrim(p->>'title') || ' » au nom de votre entreprise.', jsonb_build_object('announcement', v_id, 'by', v_actor));
    insert into audit_log (actor, action, target, category, level) values (v_actor::text, 'Concours déposé au nom de l''entreprise', btrim(p->>'title'), 'Entreprise', 'Info');
  end if;
  return v_id;
end $$;
revoke all on function ann_save(jsonb, uuid) from public, anon;
grant execute on function ann_save(jsonb, uuid) to authenticated;

-- ============================================================ duels
create or replace function duel_create(p_need text, p_prize text, p_hours int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; v_role text := coalesce(current_role_name()::text, ''); v_prize text := trim(coalesce(p_prize, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('admin', 'direction', 'dept', 'company', 'other', 'client') then raise exception 'Action non autorisée'; end if;
  if v_role in ('company', 'other') and not _org_approved(auth.uid()) then
    raise exception '% doit être vérifiée par l''administrateur avant de lancer un duel : complétez votre fiche entreprise et envoyez vos pièces justificatives.', case when v_role = 'other' then 'Votre organisation' else 'Votre entreprise' end;
  end if;
  if char_length(trim(coalesce(p_need, ''))) not between 3 and 160 then raise exception 'Besoin : 3 à 160 caractères'; end if;
  if char_length(v_prize) > 120 then raise exception 'Prix : 120 caractères au plus'; end if;
  -- Aucun séquestre n'existe pour les duels : le prix ne peut pas être une somme d'argent promise.
  if v_prize ~* '[0-9][0-9 .,]*\s*(fcfa|f\s?cfa|cfa|xaf|xof|francs?|euros?|eur|usd|dollars?|€|\$)' or v_prize ~* '(fcfa|xaf|xof|eur|usd|€|\$)\s*[0-9]' then
    raise exception 'Le prix d''un duel ne peut pas être une somme d''argent : Boutik-École ne verse ni ne garantit aucune récompense de duel. Indiquez par exemple un lot, une visibilité ou une opportunité (stage, entretien).';
  end if;
  if p_hours is null or p_hours not between 1 and 336 then raise exception 'Durée invalide (1 à 336 heures)'; end if;
  if (select count(*) from duels where created_by = auth.uid() and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq duels par jour au plus'; end if;
  insert into duels (need_title, prize, ends_at, created_by) values (trim(p_need), v_prize, now() + make_interval(hours => p_hours), auth.uid()) returning id into v;
  return v;
end $$;
revoke all on function duel_create(text, text, int) from public, anon;
grant execute on function duel_create(text, text, int) to authenticated;

-- duels_list (dernière définition : 20261117060300) : le prix est étiqueté comme non financier.
create or replace function duels_list(p_scope text default 'all', p_limit integer default 50, p_offset integer default 0) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'need', d.need_title, 'prize', d.prize, 'ends_at', d.ends_at, 'open', d.ends_at > now(),
    'prize_note', case when btrim(coalesce(d.prize, '')) <> '' then 'Récompense non financière, convenue entre le créateur du duel et le gagnant : Boutik-École ne la verse ni ne la garantit.' end,
    'mine', d.created_by = auth.uid(),
    'my_entry', auth.uid() is not null and exists (select 1 from duel_entries x where x.duel_id = d.id and x.author_id = auth.uid()),
    'winner_entry', case when d.ends_at > now() then null else coalesce(d.winner_entry_id, (select w.entry_id from _duel_winner(d.id) w)) end,
    'winner_id', case when auth.uid() is null or d.ends_at > now() then null else coalesce(d.winner_id, (select w.author_id from _duel_winner(d.id) w)) end,
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'link', e.link, 'author', coalesce(nullif(display_name(e.author_id), ''), 'Étudiant'),
                  'author_id', case when auth.uid() is not null then e.author_id end,
                  'mine', auth.uid() is not null and e.author_id = auth.uid(),
                  'votes', case when d.ends_at > now() then null else (select count(*)::int from duel_votes v where v.entry_id = e.id) end,
                  'my_vote', auth.uid() is not null and exists (select 1 from duel_votes v where v.entry_id = e.id and v.voter_id = auth.uid())) order by e.created_at)
                from duel_entries e where e.duel_id = d.id), '[]'::jsonb)
  ) order by d.created_at desc), '[]'::jsonb)
  from (select * from duels x
        where case coalesce(nullif(btrim(p_scope), ''), 'all') when 'open' then x.ends_at > now() when 'done' then x.ends_at <= now() else true end
        order by x.created_at desc
        limit least(greatest(coalesce(p_limit, 50), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) d;
$$;
revoke all on function duels_list(text, integer, integer) from public;
grant execute on function duels_list(text, integer, integer) to anon, authenticated;
