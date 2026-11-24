-- H10 Talent (2/5) : Passeport Talent 360° avec partage PAR RUBRIQUE décidé par le propriétaire (CDC 7.1, B-701/702/708/713/717).
--  1. talent_passport_shares : pour chaque rubrique (identite, competences, realisations, certificats, missions, disponibilites), le propriétaire choisit qui voit :
--       'prive' (défaut ; aucune ligne = privé), 'organisations' (organisations approuvées, uniquement si « Me proposer aux recruteurs » est actif), 'connectes' (tout compte connecté).
--     Jamais de partage public anonyme : l'anonyme est refusé. L'administrateur n'a pas de droit particulier sur une rubrique privée.
--  2. talent_passport_profile : titre et résumé professionnels (rédigés par le propriétaire, vides par défaut).
--  3. talent_passport_360(user) : vue unique (identité professionnelle, compétences avec niveau/années/justificatif, réalisations, certificats vérifiables avec leur code,
--     missions menées à terme sans montant, disponibilités). Une rubrique non partagée n'est PAS révélée : { shared: false }. Retirer un partage prend effet immédiatement.
--  4. talent_passport_share_set / talent_passport_share_get / talent_passport_identity_set ; _passport_audience_ok(owner, rubrique) réutilisé par le moteur de matching.
-- L'ancienne RPC talent_passport(user) est conservée telle quelle (badges, points).
-- Additive et rejouable. Retour arrière : drop function talent_passport_360(uuid), talent_passport_share_set(text, text), talent_passport_share_get(), talent_passport_identity_set(text, text),
--   _passport_audience_ok(uuid, text, uuid) ; drop table talent_passport_shares, talent_passport_profile.

create table if not exists talent_passport_shares (
  owner_id uuid not null references profiles (id) on delete cascade,
  section text not null check (section in ('identite', 'competences', 'realisations', 'certificats', 'missions', 'disponibilites')),
  audience text not null default 'prive' check (audience in ('prive', 'organisations', 'connectes')),
  updated_at timestamptz not null default now(),
  primary key (owner_id, section)
);
create table if not exists talent_passport_profile (
  owner_id uuid primary key references profiles (id) on delete cascade,
  headline text not null default '' check (char_length(headline) <= 120),
  summary text not null default '' check (char_length(summary) <= 1000),
  updated_at timestamptz not null default now()
);
alter table talent_passport_shares enable row level security;
alter table talent_passport_profile enable row level security;
revoke all on talent_passport_shares, talent_passport_profile from public, anon, authenticated;

-- La personne connectée peut-elle voir cette rubrique du passeport de p_owner ?
-- p_org : organisation au nom de laquelle la personne consulte (membre d'équipe actif d'une entreprise approuvée) ; null = son propre compte.
create or replace function _passport_audience_ok(p_owner uuid, p_section text, p_org uuid default null) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare v_aud text; v_org_ok boolean;
begin
  if auth.uid() is null or p_owner is null then return false; end if;
  if p_owner = auth.uid() then return true; end if;
  v_aud := coalesce((select audience from talent_passport_shares where owner_id = p_owner and section = p_section), 'prive');
  if v_aud = 'connectes' then
    return coalesce(current_role_name()::text, '') <> '';
  elsif v_aud = 'organisations' then
    v_org_ok := case when p_org is not null and p_org <> auth.uid() then company_role_of(p_org) is not null and _org_approved(p_org) else _viewer_class() = 'org_ok' end;
    return v_org_ok and _talent_visible(p_owner)
      and (not exists (select 1 from profiles where id = p_owner and role::text = 'student') or _talent_listable(p_owner));
  end if;
  return false;
end $$;
revoke all on function _passport_audience_ok(uuid, text, uuid) from public, anon, authenticated;

create or replace function talent_passport_share_set(p_section text, p_audience text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_section not in ('identite', 'competences', 'realisations', 'certificats', 'missions', 'disponibilites') then raise exception 'Rubrique inconnue'; end if;
  if p_audience not in ('prive', 'organisations', 'connectes') then raise exception 'Choix de partage inconnu'; end if;
  insert into talent_passport_shares (owner_id, section, audience) values (auth.uid(), p_section, p_audience)
  on conflict (owner_id, section) do update set audience = excluded.audience, updated_at = now();
  return talent_passport_share_get();
end $$;

create or replace function talent_passport_share_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_object_agg(s.section, coalesce(h.audience, 'prive'))
                   from unnest(array['identite', 'competences', 'realisations', 'certificats', 'missions', 'disponibilites']) s(section)
                   left join talent_passport_shares h on h.owner_id = auth.uid() and h.section = s.section), '{}'::jsonb);
end $$;

create or replace function talent_passport_identity_set(p_headline text, p_summary text) returns void
language plpgsql security definer set search_path = public as $$
declare v_h text := left(_clean_text(p_headline), 120); v_s text := left(_clean_text(p_summary), 1000);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  insert into talent_passport_profile (owner_id, headline, summary) values (auth.uid(), v_h, v_s)
  on conflict (owner_id) do update set headline = excluded.headline, summary = excluded.summary, updated_at = now();
end $$;

create or replace function talent_passport_360(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := coalesce(p_user, auth.uid()); v_own boolean; p profiles%rowtype; v_class text; v_full boolean; v_sections jsonb := '{}'::jsonb; v_ok boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_user is null then return null; end if;
  v_own := v_user = auth.uid();
  v_class := _viewer_class();
  if v_class = 'suspended' then raise exception 'Compte suspendu'; end if;
  select * into p from profiles where id = v_user and not coalesce(suspended, false);
  if p.id is null or not profile_visible(v_user) then return null; end if;
  if not v_own and v_class = 'org_locked' and p.role::text = 'student' then return null; end if;
  v_full := v_own or v_class in ('staff', 'other') or (v_class = 'org_ok' and (p.role::text <> 'student' or _cv_published(v_user)));

  v_ok := _passport_audience_ok(v_user, 'identite');
  v_sections := v_sections || jsonb_build_object('identite', case when not v_ok then jsonb_build_object('shared', false) else jsonb_build_object('shared', true,
    'headline', coalesce((select headline from talent_passport_profile where owner_id = v_user), ''), 'summary', coalesce((select summary from talent_passport_profile where owner_id = v_user), ''),
    'department', coalesce(p.department, ''), 'institution', coalesce(p.institution, ''), 'city', coalesce(p.city, ''), 'avatar_url', p.avatar_url, 'certified', p.certification::text = 'approved') end);

  v_ok := _passport_audience_ok(v_user, 'competences');
  v_sections := v_sections || jsonb_build_object('competences', case when not v_ok then jsonb_build_object('shared', false) else jsonb_build_object('shared', true, 'items', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'domain', s.domain, 'job', s.job, 'skill', s.skill, 'level', s.level, 'years', s.years,
                                          'description', case when v_own then s.description else '' end,
                                          'has_proof', s.proof_document_id is not null, 'proof_verified', coalesce(d.status = 'verified', false))
                       order by _talent_level_rank(s.level) desc, s.created_at)
      from talent_skills s left join user_documents d on d.id = s.proof_document_id where s.owner_id = v_user), '[]'::jsonb)) end);

  v_ok := _passport_audience_ok(v_user, 'realisations');
  v_sections := v_sections || jsonb_build_object('realisations', case when not v_ok then jsonb_build_object('shared', false) else jsonb_build_object('shared', true, 'items', coalesce((
      select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'category', x.category, 'happened_on', x.happened_on, 'description', left(x.description, 400),
                                          'url', case when x.url ~* '^https://' then x.url else '' end) order by x.created_at desc)
      from (select * from portfolio_items where owner_id = v_user and kind = 'realisation' order by created_at desc limit 20) x), '[]'::jsonb)) end);

  v_ok := _passport_audience_ok(v_user, 'certificats');
  v_sections := v_sections || jsonb_build_object('certificats', case when not v_ok then jsonb_build_object('shared', false) else jsonb_build_object('shared', true, 'items', coalesce((
      select jsonb_agg(jsonb_build_object('code', c.code, 'subject_kind', c.subject_kind, 'title', c.subject_title, 'issued_at', c.issued_at) order by c.issued_at desc)
      from certificates c where c.holder_id = v_user and not c.revoked), '[]'::jsonb)) end);

  v_ok := _passport_audience_ok(v_user, 'missions');
  v_sections := v_sections || jsonb_build_object('missions', case when not v_ok then jsonb_build_object('shared', false) else jsonb_build_object('shared', true, 'items', coalesce((
      select jsonb_agg(jsonb_build_object('title', m.title, 'status', m.status, 'ended_on', m.updated_at::date) order by m.updated_at desc)
      from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = v_user and mp.status = 'accepted'
      where m.status in ('delivered', 'closed')), '[]'::jsonb)) end);

  v_ok := _passport_audience_ok(v_user, 'disponibilites');
  v_sections := v_sections || jsonb_build_object('disponibilites', case when not v_ok then jsonb_build_object('shared', false) else jsonb_build_object('shared', true,
    'availability', (select jsonb_build_object('kinds', to_jsonb(a.kinds), 'note', case when v_own then a.note else left(a.note, 300) end, 'available_from', a.available_from) from student_availability a where a.user_id = v_user),
    'languages', coalesce((select jsonb_agg(jsonb_build_object('language', l.language, 'level', l.level) order by l.language) from student_languages l where l.user_id = v_user), '[]'::jsonb)) end);

  return jsonb_build_object('user_id', v_user, 'own', v_own, 'name', case when v_full then p.name else _short_name(p.name) end,
    'shares', case when v_own then talent_passport_share_get() else null end, 'sections', v_sections);
end $$;

revoke all on function talent_passport_share_set(text, text), talent_passport_share_get(), talent_passport_identity_set(text, text), talent_passport_360(uuid) from public, anon;
grant execute on function talent_passport_share_set(text, text), talent_passport_share_get(), talent_passport_identity_set(text, text), talent_passport_360(uuid) to authenticated;
