-- H10 Talent (1/5) : graphe de compétences minimal (CDC 7.2) et critères structurés des offres (CDC 7.5-2).
--  1. skill_graph_edges : relations « proche_de » (symétrique) et « prerequis_de » entre compétences du catalogue (skill_catalog).
--     Le graphe est VIDE à la livraison : aucune relation n'est inventée. Seul l'administrateur global (2FA, journal d'audit) l'alimente par RPC.
--     Un prérequis ne peut pas former de cycle ; une relation « proche_de » n'existe qu'une fois pour une paire (sens indifférent).
--  2. skill_graph_neighbors(skill) : compétences proches, prérequis et suites d'une compétence (lecture, comptes connectés).
--  3. my_close_skills() : compétences proches de celles de la personne connectée et qu'elle n'a pas encore (pistes de progression, jamais une décision).
--  4. opportunity_criteria : critères d'une offre (obligatoire / souhaité, niveau minimal, années minimales), 12 au plus ; opp_criteria_set (propriétaire ou
--     administrateur d'équipe) / opp_criteria_get (équipe ; tout compte connecté pour une offre publiée : les critères sont transparents). Sans critère structuré,
--     les compétences de l'offre (opportunities.skills) servent de critères « souhaités » : les offres existantes ne changent pas.
-- Additive et rejouable. Retour arrière : drop function opp_criteria_get(uuid), opp_criteria_set(uuid, jsonb), my_close_skills(), skill_graph_neighbors(uuid), skill_graph_admin_list(),
--   skill_graph_unlink(uuid), skill_graph_link(uuid, uuid, text, numeric, text), _skill_norm(text), _talent_admin_only(), _talent_level_rank(text) ; drop table opportunity_criteria, skill_graph_edges.

create or replace function _skill_norm(p_text text) returns text
language sql immutable set search_path = public as $$
  select btrim(regexp_replace(translate(lower(coalesce(p_text, '')), 'àâäáéèêëíîïóôöúùûüçñ', 'aaaaeeeeiiiooouuuucn'), '\s+', ' ', 'g'))
$$;
revoke all on function _skill_norm(text) from public, anon;
grant execute on function _skill_norm(text) to authenticated;

create or replace function _talent_level_rank(p_level text) returns integer
language sql immutable set search_path = public as $$
  select case p_level when 'debutant' then 1 when 'intermediaire' then 2 when 'avance' then 3 when 'expert' then 4 else null end
$$;
revoke all on function _talent_level_rank(text) from public, anon;
grant execute on function _talent_level_rank(text) to authenticated;

create or replace function _talent_admin_only() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
  perform _require_staff_aal2();
end $$;
revoke all on function _talent_admin_only() from public, anon, authenticated;

-- ============================================================ 1. graphe
create table if not exists skill_graph_edges (
  id uuid primary key default gen_random_uuid(),
  from_skill uuid not null references skill_catalog (id) on delete cascade,
  to_skill uuid not null references skill_catalog (id) on delete cascade,
  kind text not null check (kind in ('proche_de', 'prerequis_de')),
  weight numeric(3, 2) not null default 0.5 check (weight > 0 and weight <= 1),
  note text check (note is null or char_length(note) <= 300),
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  check (from_skill <> to_skill)
);
-- « proche_de » est symétrique : une seule ligne par paire ; « prerequis_de » : from_skill est un prérequis de to_skill.
create unique index if not exists skill_graph_edges_pair on skill_graph_edges (kind, least(from_skill, to_skill), greatest(from_skill, to_skill)) where kind = 'proche_de';
create unique index if not exists skill_graph_edges_dir on skill_graph_edges (kind, from_skill, to_skill) where kind = 'prerequis_de';
create index if not exists skill_graph_edges_to on skill_graph_edges (to_skill);
create index if not exists skill_graph_edges_from on skill_graph_edges (from_skill);
alter table skill_graph_edges enable row level security;
revoke all on skill_graph_edges from public, anon, authenticated;

create or replace function skill_graph_link(p_from uuid, p_to uuid, p_kind text, p_weight numeric default 0.5, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; a skill_catalog%rowtype; b skill_catalog%rowtype;
begin
  perform _talent_admin_only();
  if p_kind not in ('proche_de', 'prerequis_de') then raise exception 'Relation inconnue'; end if;
  if p_from is null or p_to is null or p_from = p_to then raise exception 'Deux compétences différentes sont nécessaires'; end if;
  select * into a from skill_catalog where id = p_from and skill <> '' and status = 'approved';
  select * into b from skill_catalog where id = p_to and skill <> '' and status = 'approved';
  if a.id is null or b.id is null then raise exception 'Compétence introuvable dans le catalogue validé'; end if;
  if p_weight is null or p_weight <= 0 or p_weight > 1 then raise exception 'Le poids doit être compris entre 0 (exclu) et 1'; end if;
  if p_kind = 'prerequis_de' and exists (
       with recursive up(id) as (select p_to union select e.to_skill from skill_graph_edges e join up on e.from_skill = up.id where e.kind = 'prerequis_de')
       select 1 from up where id = p_from) then
    raise exception 'Ce prérequis créerait un cycle';
  end if;
  insert into skill_graph_edges (from_skill, to_skill, kind, weight, note, created_by)
  values (p_from, p_to, p_kind, p_weight, nullif(left(btrim(coalesce(p_note, '')), 300), ''), auth.uid()) returning id into v;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Relation de compétences ajoutée (' || p_kind || ')', left(a.skill || ' / ' || b.skill, 200), 'Talents', 'Info');
  return v;
exception when unique_violation then raise exception 'Cette relation existe déjà';
end $$;

create or replace function skill_graph_unlink(p_edge uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e skill_graph_edges%rowtype;
begin
  perform _talent_admin_only();
  delete from skill_graph_edges where id = p_edge returning * into e;
  if e.id is null then raise exception 'Relation introuvable'; end if;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Relation de compétences retirée (' || e.kind || ')', e.id::text, 'Talents', 'Info');
end $$;

create or replace function skill_graph_admin_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _talent_admin_only();
  return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'kind', e.kind, 'weight', e.weight, 'note', e.note, 'from', a.skill, 'from_id', a.id, 'to', b.skill, 'to_id', b.id, 'created_at', e.created_at)
                   order by e.created_at desc)
                   from skill_graph_edges e join skill_catalog a on a.id = e.from_skill join skill_catalog b on b.id = e.to_skill), '[]'::jsonb);
end $$;

-- Voisinage d'une compétence. Lecture : tout compte connecté (le graphe est un référentiel, pas une donnée personnelle).
create or replace function skill_graph_neighbors(p_skill uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s skill_catalog%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from skill_catalog where id = p_skill and skill <> '' and status = 'approved';
  if s.id is null then raise exception 'Compétence introuvable'; end if;
  return jsonb_build_object(
    'skill', jsonb_build_object('id', s.id, 'domain', s.domain, 'job', s.job, 'skill', s.skill),
    'close', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'skill', c.skill, 'domain', c.domain, 'weight', e.weight) order by e.weight desc, c.skill)
                       from skill_graph_edges e join skill_catalog c on c.id = case when e.from_skill = s.id then e.to_skill else e.from_skill end
                       where e.kind = 'proche_de' and s.id in (e.from_skill, e.to_skill) and c.status = 'approved'), '[]'::jsonb),
    'prerequisites', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'skill', c.skill, 'domain', c.domain) order by c.skill)
                               from skill_graph_edges e join skill_catalog c on c.id = e.from_skill
                               where e.kind = 'prerequis_de' and e.to_skill = s.id and c.status = 'approved'), '[]'::jsonb),
    'leads_to', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'skill', c.skill, 'domain', c.domain) order by c.skill)
                          from skill_graph_edges e join skill_catalog c on c.id = e.to_skill
                          where e.kind = 'prerequis_de' and e.from_skill = s.id and c.status = 'approved'), '[]'::jsonb));
end $$;

-- Pistes de progression de la personne connectée : compétences proches de celles qu'elle déclare, qu'elle n'a pas encore ; vide tant que le graphe l'est.
create or replace function my_close_skills() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(x.j order by x.w desc, x.n) from (
      select distinct on (c.id) jsonb_build_object('id', c.id, 'skill', c.skill, 'domain', c.domain, 'because', m.skill, 'weight', e.weight) j, e.weight w, c.skill n
      from talent_skills m
      join skill_catalog mc on _skill_norm(mc.skill) = _skill_norm(m.skill) and mc.skill <> '' and mc.status = 'approved'
      join skill_graph_edges e on e.kind = 'proche_de' and mc.id in (e.from_skill, e.to_skill)
      join skill_catalog c on c.id = case when e.from_skill = mc.id then e.to_skill else e.from_skill end and c.status = 'approved'
      where m.owner_id = auth.uid()
        and not exists (select 1 from talent_skills t where t.owner_id = auth.uid() and _skill_norm(t.skill) = _skill_norm(c.skill))
      order by c.id, e.weight desc) x), '[]'::jsonb);
end $$;

-- ============================================================ 2. critères structurés des offres
create table if not exists opportunity_criteria (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references opportunities (id) on delete cascade,
  skill text not null check (char_length(btrim(skill)) between 2 and 80),
  importance text not null default 'souhaite' check (importance in ('obligatoire', 'souhaite')),
  min_level text check (min_level is null or min_level in ('debutant', 'intermediaire', 'avance', 'expert')),
  min_years numeric(4, 1) check (min_years is null or min_years between 0 and 60),
  created_at timestamptz not null default now()
);
create unique index if not exists opportunity_criteria_skill on opportunity_criteria (opportunity_id, _skill_norm(skill));
alter table opportunity_criteria enable row level security;
revoke all on opportunity_criteria from public, anon, authenticated;

create or replace function opp_criteria_set(p_opp uuid, p_criteria jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; c jsonb; v_skill text; v_imp text; v_lvl text; v_years numeric; v_n integer := 0; v_seen text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and _opp_can(poster_id, true);
  if o.id is null then raise exception 'Offre introuvable'; end if;
  if jsonb_typeof(coalesce(p_criteria, '[]'::jsonb)) <> 'array' then raise exception 'Critères invalides'; end if;
  if jsonb_array_length(coalesce(p_criteria, '[]'::jsonb)) > 12 then raise exception '12 critères au plus'; end if;
  for c in select value from jsonb_array_elements(coalesce(p_criteria, '[]'::jsonb)) loop
    v_skill := btrim(coalesce(c ->> 'skill', ''));
    v_imp := coalesce(nullif(c ->> 'importance', ''), 'souhaite');
    v_lvl := nullif(c ->> 'min_level', '');
    v_years := nullif(c ->> 'min_years', '')::numeric;
    if char_length(v_skill) < 2 or char_length(v_skill) > 80 then raise exception 'Chaque critère doit nommer une compétence (2 à 80 caractères)'; end if;
    if v_imp not in ('obligatoire', 'souhaite') then raise exception 'Importance inconnue'; end if;
    if v_lvl is not null and _talent_level_rank(v_lvl) is null then raise exception 'Niveau minimal inconnu'; end if;
    if v_years is not null and (v_years < 0 or v_years > 60) then raise exception 'Années minimales invalides'; end if;
    if _skill_norm(v_skill) = any (v_seen) then raise exception 'Compétence en double : %', v_skill; end if;
    v_seen := v_seen || _skill_norm(v_skill);
  end loop;
  delete from opportunity_criteria where opportunity_id = p_opp;
  for c in select value from jsonb_array_elements(coalesce(p_criteria, '[]'::jsonb)) loop
    insert into opportunity_criteria (opportunity_id, skill, importance, min_level, min_years)
    values (p_opp, btrim(c ->> 'skill'), coalesce(nullif(c ->> 'importance', ''), 'souhaite'), nullif(c ->> 'min_level', ''), nullif(c ->> 'min_years', '')::numeric);
    v_n := v_n + 1;
  end loop;
  -- les compétences de l'offre restent alignées sur les critères (le score historique les lit encore)
  update opportunities set skills = coalesce((select array_agg(skill order by created_at, skill) from opportunity_criteria where opportunity_id = p_opp), '{}'::text[]) where id = p_opp;
  return opp_criteria_get(p_opp);
end $$;

create or replace function opp_criteria_get(p_opp uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and (status = 'published' or _opp_can(poster_id, false) or coalesce(current_role_name()::text, '') in ('admin', 'dept'));
  if o.id is null then raise exception 'Offre introuvable'; end if;
  return jsonb_build_object('opportunity_id', o.id, 'structured', exists (select 1 from opportunity_criteria where opportunity_id = o.id),
    'criteria', case when exists (select 1 from opportunity_criteria where opportunity_id = o.id) then
        (select jsonb_agg(jsonb_build_object('skill', k.skill, 'importance', k.importance, 'min_level', k.min_level, 'min_years', k.min_years) order by (k.importance = 'obligatoire') desc, k.created_at, k.skill)
         from opportunity_criteria k where k.opportunity_id = o.id)
      else coalesce((select jsonb_agg(jsonb_build_object('skill', btrim(s), 'importance', 'souhaite', 'min_level', null, 'min_years', null)) from unnest(o.skills) s where btrim(s) <> ''), '[]'::jsonb) end);
end $$;

revoke all on function skill_graph_link(uuid, uuid, text, numeric, text), skill_graph_unlink(uuid), skill_graph_admin_list(), skill_graph_neighbors(uuid), my_close_skills(),
  opp_criteria_set(uuid, jsonb), opp_criteria_get(uuid) from public, anon;
grant execute on function skill_graph_link(uuid, uuid, text, numeric, text), skill_graph_unlink(uuid), skill_graph_admin_list(), skill_graph_neighbors(uuid), my_close_skills(),
  opp_criteria_set(uuid, jsonb), opp_criteria_get(uuid) to authenticated;
