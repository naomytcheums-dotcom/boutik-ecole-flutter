-- Lot H12 / TOP100-B (4/5) : Talent Discovery pour les entreprises (CDC Top 100, section 2).
--  1. Un talent n'est « découvrable » que s'il a consenti au classement public (talent_visibility_settings), reste vérifié et visible des recruteurs (_talent_listable, H10) et, pour la recherche,
--     figure dans le dernier classement publié (entrée non retirée). Seules les rubriques partagées par le talent servent de critère et sont affichées (compétences, score, évolution, projets, badges,
--     disponibilité publiée) : un filtre sur une rubrique non partagée n'écarte que ce talent, jamais il ne révèle l'information.
--  2. discovery_search : filière, établissement, département, promotion vérifiée, compétence (et niveau), domaine, classement (rang maximal dans une portée), score minimal, progression minimale,
--     disponibilité, projets, badges ; tri par rang (défaut), score ou progression. Chaque résultat porte « pourquoi ce talent vous est proposé » : la liste des critères de recherche réellement
--     satisfaits, avec leur valeur — aucun score opaque, aucune décision automatique (automatic_decision = false).
--  3. discovery_compare : de 2 à 4 profils côte à côte (profil public selon consentement + données privées de l'organisation : étape, étiquettes, notes) et matrice des critères.
--  4. Favoris et vivier : discovery_favorite_set / discovery_favorites / discovery_pool_add réutilisent talent_lists et talent_list_members (H10, pool_*) ; l'isolation entre organisations est celle de _pool_org
--     (propriétaire, administrateurs et lecteurs de l'organisation approuvée ; « finance » exclu ; une autre organisation reçoit « Accès refusé »).
--  5. discovery_contact_request : demande de contact, d'entretien ou proposition de stage / d'emploi / de mission, enregistrée dans talent_contacts (la contrainte de type est ÉLARGIE : rien n'est retiré),
--     visible dans l'historique de contact du vivier (pool_contacts_get), notifiée au talent ; mêmes limites que talent_contact_request (10 par jour, une demande par type et par talent et par jour,
--     blocages respectés). my_talent_contact_requests : l'étudiant retrouve ses demandes reçues.
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière : drop function discovery_search(...), discovery_compare(uuid[], uuid), discovery_favorite_set(uuid, boolean, uuid), discovery_favorites(uuid),
--   discovery_pool_add(uuid, uuid, text, uuid), discovery_contact_request(uuid, text, text, uuid), my_talent_contact_requests(integer), _discovery_ok(uuid) ;
--   remettre la contrainte talent_contacts_kind_check (kind in ('internship_offer', 'contact')) après suppression des lignes de nouveaux types.

-- ============================================================ 1. Types de demande élargis
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'talent_contacts'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%internship_offer%' and conname not like '%v2' loop
    execute format('alter table talent_contacts drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'talent_contacts_kind_check_v2') then
    alter table talent_contacts add constraint talent_contacts_kind_check_v2 check (kind in ('internship_offer', 'contact', 'interview', 'job_offer', 'mission_offer'));
  end if;
end $$;

-- ============================================================ 2. Aides
-- Consentement au classement public + vérifié, visible des recruteurs, hors blocage avec la personne connectée.
create or replace function _discovery_ok(p_student uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_student is not null and exists (select 1 from talent_visibility_settings v where v.user_id = p_student and v.public_ranking)
    and _talent_listable(p_student)
    and not exists (select 1 from user_blocks b where (b.blocker_id = p_student and b.blocked_id = auth.uid()) or (b.blocker_id = auth.uid() and b.blocked_id = p_student))
$$;
revoke all on function _discovery_ok(uuid) from public, anon, authenticated;

-- ============================================================ 3. Recherche
create or replace function discovery_search(p_org uuid default null, p_period text default null, p_institution uuid default null, p_program uuid default null, p_department uuid default null,
    p_skill text default null, p_domain text default null, p_min_level text default null, p_scope text default 'national', p_max_rank integer default null, p_min_score integer default null,
    p_min_progression integer default null, p_available boolean default null, p_availability_kind text default null, p_promotion text default null, p_min_projects integer default null,
    p_badge text default null, p_sort text default 'rank', p_limit integer default 20, p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); pr ranking_periods; v_lim integer := least(greatest(coalesce(p_limit, 20), 1), 50); v_off integer := greatest(coalesce(p_offset, 0), 0);
        v_skill text := _skill_norm(p_skill); v_items jsonb; v_total integer; v_fav uuid;
begin
  if p_scope is null or p_scope not in ('national', 'program', 'institution', 'department', 'domain') then raise exception 'Portée de classement inconnue'; end if;
  if p_sort is null or p_sort not in ('rank', 'score', 'progression') then raise exception 'Tri inconnu (rank, score, progression)'; end if;
  if p_min_level is not null and _talent_level_rank(p_min_level) is null then raise exception 'Niveau inconnu'; end if;
  if p_min_level is not null and v_skill = '' then raise exception 'Le niveau minimal exige une compétence'; end if;
  select * into pr from ranking_periods where (p_period is not null and period = p_period) or (p_period is null and status = 'published') order by period desc limit 1;
  if pr.id is null then
    return jsonb_build_object('published', false, 'period', p_period, 'items', '[]'::jsonb, 'total', 0, 'automatic_decision', false, 'note', 'Aucun classement n''est publié pour le moment : aucun talent à découvrir.');
  end if;
  select l.id into v_fav from talent_lists l where l.org_id = v_org and l.name = 'Favoris';
  select coalesce(jsonb_agg(x.j order by x.o1, x.rank, x.nm), '[]'::jsonb), coalesce(max(x.total), 0) into v_items, v_total from (
    select _ranking_item_json(e, v, pf)
           || jsonb_build_object('availability', case when v.availability_public then (select jsonb_build_object('kinds', to_jsonb(av.kinds), 'available_from', av.available_from) from student_availability av where av.user_id = e.user_id) end,
                'in_pool', _pool_in_pool(v_org, e.user_id),
                'favorite', v_fav is not null and exists (select 1 from talent_list_members m where m.list_id = v_fav and m.student_id = e.user_id),
                'stage', (select pp.stage from talent_pool_profiles pp where pp.org_id = v_org and pp.student_id = e.user_id),
                'why', jsonb_build_array(jsonb_build_object('criterion', 'published_ranking', 'label', 'Figure au classement publié de ' || pr.period, 'satisfied', true))
                       || to_jsonb(array_remove(array[
                  case when p_institution is not null then jsonb_build_object('criterion', 'institution', 'label', 'Établissement : ' || (e.details ->> 'institution'), 'satisfied', true) end,
                  case when p_program is not null then jsonb_build_object('criterion', 'program', 'label', 'Filière : ' || (e.details ->> 'program'), 'satisfied', true) end,
                  case when p_department is not null then jsonb_build_object('criterion', 'department', 'label', 'Département : ' || coalesce(e.details ->> 'department', ''), 'satisfied', true) end,
                  case when nullif(btrim(p_promotion), '') is not null then jsonb_build_object('criterion', 'promotion', 'label', 'Promotion vérifiée : ' || (e.details ->> 'promotion'), 'satisfied', true) end,
                  case when v_skill <> '' then jsonb_build_object('criterion', 'skill', 'label', 'Compétence démontrée : ' || btrim(p_skill) || case when p_min_level is not null then ' (niveau ' || p_min_level || ' ou plus)' else '' end, 'satisfied', true) end,
                  case when nullif(btrim(p_domain), '') is not null then jsonb_build_object('criterion', 'domain', 'label', 'Domaine de compétence : ' || btrim(p_domain), 'satisfied', true) end,
                  case when p_max_rank is not null then jsonb_build_object('criterion', 'rank', 'label', 'Rang ' || e.rank || ' (' || p_scope || ' ; demandé : ' || p_max_rank || ' ou mieux)', 'satisfied', true) end,
                  case when p_min_score is not null then jsonb_build_object('criterion', 'score', 'label', 'Score ' || e.score || ' (minimum demandé : ' || p_min_score || ')', 'satisfied', true) end,
                  case when p_min_progression is not null then jsonb_build_object('criterion', 'progression', 'label', 'Progression de ' || coalesce(e.delta_rank, 0) || ' rang(s) (minimum demandé : ' || p_min_progression || ')', 'satisfied', true) end,
                  case when p_available is true or p_availability_kind is not null then jsonb_build_object('criterion', 'availability', 'label', 'Disponibilité publiée par le talent', 'satisfied', true) end,
                  case when p_min_projects is not null then jsonb_build_object('criterion', 'projects', 'label', 'Projets approuvés : ' || (e.details ->> 'projects') || ' (minimum demandé : ' || p_min_projects || ')', 'satisfied', true) end,
                  case when nullif(btrim(p_badge), '') is not null then jsonb_build_object('criterion', 'badge', 'label', 'Badge vérifiable : ' || btrim(p_badge), 'satisfied', true) end
                ], null))) j,
           case p_sort when 'score' then case when 'score' = any (v.shared_sections) then -e.score else 1000000 end
                       when 'progression' then case when 'evolution' = any (v.shared_sections) then -coalesce(e.delta_rank, -1000000) else 1000000 end else 0 end o1,
           e.rank, pf.name nm, count(*) over ()::int total
    from ranking_entries e
    join talent_visibility_settings v on v.user_id = e.user_id and v.public_ranking
    join profiles pf on pf.id = e.user_id
    where e.id in (select distinct on (e2.user_id) e2.id from ranking_entries e2 where e2.period_id = pr.id and e2.scope_kind = p_scope and e2.voided_at is null order by e2.user_id, e2.rank)
      and _discovery_ok(e.user_id)
      and (p_institution is null or e.details ->> 'institution_id' = p_institution::text)
      and (p_program is null or e.details ->> 'program_id' = p_program::text)
      and (p_department is null or e.details ->> 'department_id' = p_department::text)
      and (nullif(btrim(p_promotion), '') is null or lower(e.details ->> 'promotion') = lower(btrim(p_promotion)))
      and (p_max_rank is null or e.rank <= p_max_rank)
      and (p_min_score is null or ('score' = any (v.shared_sections) and e.score >= p_min_score))
      and (p_min_progression is null or ('evolution' = any (v.shared_sections) and coalesce(e.delta_rank, -1000000) >= p_min_progression))
      and (v_skill = '' or ('skills' = any (v.shared_sections) and exists (select 1 from talent_skills t where t.owner_id = e.user_id and position(v_skill in _skill_norm(t.skill)) > 0
                                 and (p_min_level is null or _talent_level_rank(t.level) >= _talent_level_rank(p_min_level)))))
      and (nullif(btrim(p_domain), '') is null or ('skills' = any (v.shared_sections) and exists (select 1 from talent_skills t where t.owner_id = e.user_id and lower(t.domain) = lower(btrim(p_domain)))))
      and (not (coalesce(p_available, false) or p_availability_kind is not null)
           or (v.availability_public and exists (select 1 from student_availability av where av.user_id = e.user_id and cardinality(av.kinds) > 0
                                                 and (p_availability_kind is null or p_availability_kind = any (av.kinds)))))
      and (p_min_projects is null or ('projects' = any (v.shared_sections) and (e.details ->> 'projects')::int >= p_min_projects))
      and (nullif(btrim(p_badge), '') is null or ('badges' = any (v.shared_sections) and exists (select 1 from jsonb_array_elements(e.details -> 'badges') b where b ->> 'code' = btrim(p_badge))))
    order by 2, 3, 4 limit v_lim offset v_off) x;
  return jsonb_build_object('published', true, 'period', pr.period, 'scope', p_scope, 'items', v_items, 'total', v_total, 'automatic_decision', false,
    'notice', 'Les résultats viennent de critères que vous choisissez et de données partagées par les talents. Aucun score opaque et aucune décision automatique : la décision reste humaine.');
end $$;

-- ============================================================ 4. Comparaison (2 à 4 profils)
create or replace function discovery_compare(p_students uuid[], p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); s uuid; v_seen uuid[] := '{}'; v_talents jsonb := '[]'::jsonb; pj jsonb; v_matrix jsonb := '[]'::jsonb; k text; v_vals jsonb;
begin
  if p_students is null or cardinality(p_students) < 2 or cardinality(p_students) > 4 then raise exception 'Choisissez de 2 à 4 talents à comparer'; end if;
  foreach s in array p_students loop
    if s = any (v_seen) then raise exception 'Un talent est en double'; end if;
    v_seen := v_seen || s;
    if not _discovery_ok(s) then raise exception 'Talent introuvable'; end if;
    pj := talent_public_profile(s);
    if coalesce((pj ->> 'found')::boolean, false) is not true then raise exception 'Talent introuvable'; end if;
    v_talents := v_talents || jsonb_build_array(pj || jsonb_build_object('in_pool', _pool_in_pool(v_org, s),
      'stage', (select pp.stage from talent_pool_profiles pp where pp.org_id = v_org and pp.student_id = s),
      'tags', to_jsonb(coalesce((select pp.tags from talent_pool_profiles pp where pp.org_id = v_org and pp.student_id = s), '{}'::text[])),
      'notes_count', (select count(*)::int from talent_pool_notes n where n.org_id = v_org and n.student_id = s)));
  end loop;
  foreach k in array array['national_rank', 'score', 'progression', 'skills', 'badges', 'projects', 'availability'] loop
    select jsonb_agg(jsonb_build_object('user_id', t ->> 'user_id', 'value', case k
        when 'national_rank' then (select r ->> 'rank' from jsonb_array_elements(case when jsonb_typeof(t -> 'ranking') = 'array' then t -> 'ranking' else '[]'::jsonb end) r where r ->> 'scope' = 'national' limit 1)
        when 'score' then t ->> 'score'
        when 'progression' then (select h ->> 'delta_rank' from jsonb_array_elements(case when jsonb_typeof(t -> 'evolution') = 'array' then t -> 'evolution' else '[]'::jsonb end) h limit 1)
        when 'skills' then case when jsonb_typeof(t -> 'skills') = 'array' then jsonb_array_length(t -> 'skills')::text end
        when 'badges' then case when jsonb_typeof(t -> 'badges') = 'array' then jsonb_array_length(t -> 'badges')::text end
        when 'projects' then case when jsonb_typeof(t -> 'projects') = 'array' then jsonb_array_length(t -> 'projects')::text end
        else (t -> 'availability' -> 'kinds')::text end))
      into v_vals from jsonb_array_elements(v_talents) t;
    v_matrix := v_matrix || jsonb_build_array(jsonb_build_object('criterion', k, 'values', v_vals));
  end loop;
  return jsonb_build_object('talents', v_talents, 'matrix', v_matrix, 'automatic_decision', false,
    'notice', 'La comparaison aide à choisir ; elle ne décide de rien. Seules les rubriques partagées par chaque talent apparaissent (une valeur vide = non partagée ou absente).');
end $$;

-- ============================================================ 5. Favoris et vivier (listes H10)
create or replace function discovery_favorite_set(p_student uuid, p_on boolean, p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_list uuid;
begin
  if p_on is null then raise exception 'Choix incomplet'; end if;
  insert into talent_lists (owner_id, org_id, name) values (auth.uid(), v_org, 'Favoris') on conflict do nothing;
  select id into v_list from talent_lists where org_id = v_org and name = 'Favoris';
  if p_on then
    if not _discovery_ok(p_student) then raise exception 'Talent introuvable'; end if;
    perform pool_list_add(v_list, p_student, '', p_org);
  else
    perform pool_list_remove(v_list, p_student, p_org);
  end if;
  return jsonb_build_object('student', p_student, 'favorite', p_on);
end $$;

create or replace function discovery_favorites(p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); v_list uuid;
begin
  select id into v_list from talent_lists where org_id = v_org and name = 'Favoris';
  if v_list is null then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', m.student_id, 'name', case when v.show_full_name then pf.name else _short_name(pf.name) end, 'photo', case when v.show_photo then pf.avatar_url end,
      'added_at', m.added_at, 'note', m.note, 'stage', (select pp.stage from talent_pool_profiles pp where pp.org_id = v_org and pp.student_id = m.student_id)) order by m.added_at desc)
    from talent_list_members m join talent_visibility_settings v on v.user_id = m.student_id and v.public_ranking join profiles pf on pf.id = m.student_id
    where m.list_id = v_list and _discovery_ok(m.student_id)), '[]'::jsonb);
end $$;

create or replace function discovery_pool_add(p_student uuid, p_list uuid, p_note text default '', p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  if not _discovery_ok(p_student) then raise exception 'Talent introuvable'; end if;
  perform pool_list_add(p_list, p_student, p_note, p_org);
  return jsonb_build_object('student', p_student, 'list', p_list, 'added', true, 'org', v_org);
end $$;

-- ============================================================ 6. Demandes de contact, d'entretien, propositions
create or replace function discovery_contact_request(p_student uuid, p_kind text, p_message text default '', p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_msg text := left(_clean_text(p_message), 500); v_id uuid;
begin
  if p_kind is null or p_kind not in ('contact', 'interview', 'internship_offer', 'job_offer', 'mission_offer') then raise exception 'Type de demande inconnu'; end if;
  if p_student is null or p_student = auth.uid() or p_student = v_org then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not _discovery_ok(p_student) then raise exception 'Talent introuvable'; end if;
  if p_kind <> 'contact' and char_length(v_msg) < 10 then raise exception 'Précisez votre demande (10 caractères minimum).'; end if;
  if (select count(*) from talent_contacts where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix demandes par jour au plus'; end if;
  if v_msg <> '' and (select count(*) from talent_contacts where sender_id = auth.uid() and message = v_msg and created_at > now() - interval '1 day') >= 3 then
    raise exception 'Ce même message a déjà été envoyé à trois talents aujourd''hui : personnalisez-le.';
  end if;
  begin
    insert into talent_contacts (sender_id, target_id, kind, message) values (auth.uid(), p_student, p_kind, v_msg) returning id into v_id;
  exception when unique_violation then
    raise exception 'Vous avez déjà adressé cette demande à ce talent aujourd''hui';
  end;
  perform notify_user(p_student, 'talent_contact',
    case p_kind when 'internship_offer' then 'Proposition de stage' when 'job_offer' then 'Proposition d''emploi' when 'mission_offer' then 'Proposition de mission' when 'interview' then 'Invitation à un entretien' else 'Demande de contact' end,
    left(_talent_sender_label(v_org) || case p_kind when 'internship_offer' then ' vous propose un stage' when 'job_offer' then ' vous propose un emploi' when 'mission_offer' then ' vous propose une mission'
                                                    when 'interview' then ' vous invite à un entretien' else ' souhaite vous contacter' end || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('from', auth.uid(), 'kind', p_kind));
  return jsonb_build_object('ok', true, 'id', v_id, 'kind', p_kind, 'student', p_student);
end $$;

create or replace function my_talent_contact_requests(p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'kind', c.kind, 'message', c.message, 'sender', coalesce((select _talent_sender_label(m.owner_id) from company_members m where m.user_id = c.sender_id and m.status = 'active' and _org_approved(m.owner_id) limit 1), _talent_sender_label(c.sender_id)), 'created_at', c.created_at) order by c.created_at desc)
    from (select * from talent_contacts where target_id = auth.uid() order by created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) c), '[]'::jsonb);
end $$;

revoke all on function discovery_search(uuid, text, uuid, uuid, uuid, text, text, text, text, integer, integer, integer, boolean, text, text, integer, text, text, integer, integer), discovery_compare(uuid[], uuid),
  discovery_favorite_set(uuid, boolean, uuid), discovery_favorites(uuid), discovery_pool_add(uuid, uuid, text, uuid), discovery_contact_request(uuid, text, text, uuid), my_talent_contact_requests(integer) from public, anon;
grant execute on function discovery_search(uuid, text, uuid, uuid, uuid, text, text, text, text, integer, integer, integer, boolean, text, text, integer, text, text, integer, integer), discovery_compare(uuid[], uuid),
  discovery_favorite_set(uuid, boolean, uuid), discovery_favorites(uuid), discovery_pool_add(uuid, uuid, text, uuid), discovery_contact_request(uuid, text, text, uuid), my_talent_contact_requests(integer) to authenticated;
