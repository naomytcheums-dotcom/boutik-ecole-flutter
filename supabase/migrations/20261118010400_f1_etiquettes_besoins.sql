-- Lot F1 (5/6) — étiquettes honnêtes des besoins publiés, offres visibles des visiteurs (E5-7, E6-4, E5-12, décision 3).
--   · _need_poster(owner) : « entreprise » (raison sociale + badge « vérifiée ») SEULEMENT pour une fiche approuvée ; sinon nom abrégé + rôle réel
--     (« Claire C. · Client ») ; compte suspendu ou introuvable : le besoin n'est plus listé ;
--   · open_needs_list / open_calls : champs « company » (étiquette), « verified », « poster_role », « company_id » (identifiant de l'entreprise, seulement si vérifiée) ;
--   · opp_detail : le numéro WhatsApp de candidature n'est plus donné aux visiteurs non connectés.
-- Retour arrière : recréer open_needs_list et open_calls depuis 20261117040500, opp_detail depuis 20261117080000 ; drop function _need_poster(uuid).

create or replace function _need_poster(p_owner uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case
    when p.role::text in ('company', 'other') and (c.status = 'approved' or p.is_test) and nullif(btrim(coalesce(c.company_name, '')), '') is not null
      then jsonb_build_object('label', btrim(c.company_name), 'verified', true, 'role', p.role::text, 'id', p.id)
    else jsonb_build_object('label', _short_name(p.name) || ' · ' || case p.role::text
        when 'client' then 'Client' when 'student' then 'Étudiant' when 'company' then 'Entreprise non vérifiée' when 'other' then 'Organisation non vérifiée'
        when 'dept' then 'Département' when 'admin' then 'Administration' else 'Membre' end,
      'verified', false, 'role', p.role::text) end
  from profiles p left join company_profiles c on c.owner_id = p.id
  where p.id = p_owner and not coalesce(p.suspended, false)
$$;
revoke all on function _need_poster(uuid) from public, anon, authenticated;

create or replace function open_needs_list(p_q text default null, p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_q text := nullif(trim(coalesce(p_q, '')), ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', m.id, 'number', m.number, 'title', m.title, 'description', m.description, 'budget_min', m.budget_min, 'budget_max', m.budget_max,
      'deadline', m.deadline, 'created_at', m.created_at,
      'company', x.pj ->> 'label', 'verified', (x.pj ->> 'verified')::boolean, 'poster_role', x.pj ->> 'role', 'company_id', x.pj ->> 'id',
      'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id),
      'own', m.client_id = uid,
      'proposed', exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = uid and p.status = 'submitted')
    ) order by m.created_at desc)
    from missions m cross join lateral (select _need_poster(m.client_id) as pj) x
    where m.status = 'published' and m.title is not null and x.pj is not null
      and (m.kind is distinct from 'mission' or m.client_id = uid or v_staff)
      and (v_q is null or m.title ilike '%' || v_q || '%' or coalesce(m.description, '') ilike '%' || v_q || '%')
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ), '[]'::jsonb);
end $$;

create or replace function open_calls(p_q text default null, p_limit integer default 30, p_sort text default 'recent', p_department text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_q text := nullif(trim(coalesce(p_q, '')), ''); v_dept text := nullif(trim(coalesce(p_department, '')), ''); v_staff boolean := coalesce(current_role_name()::text, '') in ('dept', 'admin');
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if coalesce(p_sort, 'recent') not in ('recent', 'budget', 'fewest') then raise exception 'Tri inconnu'; end if;
  return coalesce((
    select jsonb_agg(y.j order by
        case when coalesce(p_sort, 'recent') = 'budget' then y.budget end desc nulls last,
        case when p_sort = 'fewest' then y.props end asc,
        y.created_at desc)
    from (
      select jsonb_build_object(
        'id', m.id, 'number', m.number, 'title', m.title, 'description', m.description, 'budget_min', m.budget_min, 'budget_max', m.budget_max,
        'deadline', m.deadline, 'created_at', m.created_at,
        'company', x.pj ->> 'label', 'verified', (x.pj ->> 'verified')::boolean, 'poster_role', x.pj ->> 'role', 'company_id', x.pj ->> 'id',
        'proposals', (select count(*)::int from mission_proposals p where p.mission_id = m.id),
        'own', m.client_id = uid,
        'proposed', exists (select 1 from mission_proposals p where p.mission_id = m.id and p.author_id = uid and p.status = 'submitted')) j,
        coalesce(m.budget_max, m.budget_min) budget,
        (select count(*)::int from mission_proposals p where p.mission_id = m.id) props,
        m.created_at
      from missions m cross join lateral (select _need_poster(m.client_id) as pj) x
      where m.status = 'published' and m.title is not null and x.pj is not null
        and (m.kind is distinct from 'mission' or m.client_id = uid or v_staff)
        and (v_q is null or m.title ilike '%' || v_q || '%' or coalesce(m.description, '') ilike '%' || v_q || '%')
        and (v_dept is null or m.title ilike '%' || v_dept || '%' or coalesce(m.description, '') ilike '%' || v_dept || '%')
      limit least(greatest(coalesce(p_limit, 30), 1), 100)
    ) y
  ), '[]'::jsonb);
end $$;

revoke all on function open_needs_list(text, integer), open_calls(text, integer, text, text) from public, anon;
grant execute on function open_needs_list(text, integer), open_calls(text, integer, text, text) to authenticated;

-- Fiche d'une offre (dernière définition : 20261117080000) : le numéro WhatsApp de l'annonceur est réservé aux comptes connectés.
create or replace function opp_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; uid uuid := auth.uid();
begin
  select * into o from opportunities where id = p_id;
  if not found or (o.status <> 'published' and o.poster_id is distinct from uid and coalesce(current_role_name()::text, '') not in ('admin', 'dept')) then raise exception 'Offre introuvable'; end if;
  return _opp_card(o, uid) || jsonb_build_object('description', o.description, 'missions', to_jsonb(o.missions), 'profile_wanted', o.profile_wanted, 'level', o.level, 'gains', to_jsonb(o.gains),
    'apply_whatsapp', case when uid is null then '' else o.apply_whatsapp end, 'apply_in_app', o.apply_in_app, 'about_org', o.about_org, 'mine', o.poster_id = uid, 'review_note', o.review_note,
    'iut_eligible', case when uid is null then false else _is_verified_iut_student(uid) end,
    'my_application', (select to_jsonb(a) - 'opportunity_id' - 'applicant_id' - 'message' from (select id, status, created_at from opportunity_applications where opportunity_id = p_id and applicant_id = uid) a),
    'reminder', exists (select 1 from opportunity_reminders r where r.opportunity_id = p_id and r.user_id = uid),
    'other_offers', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind)) from (select id, title, kind from opportunities where poster_id = o.poster_id and id <> p_id and status in ('published', 'closed') order by created_at desc limit 5) x), '[]'::jsonb));
end $$;
revoke all on function opp_detail(uuid) from public;
grant execute on function opp_detail(uuid) to anon, authenticated;
