-- Lot H9 / EVAL : socle FOURNISSEUR-AGNOSTIQUE du module « Talent Assessment » (CDC 8, 21.5, 30).
-- AUCUN fournisseur d'évaluation n'est développé ni appelé : le registre est VIDE (aucune ligne insérée). Tant qu'aucun fournisseur n'est ACTIF,
-- toute demande d'évaluation est refusée proprement, sans consommer le quota gratuit. Aucun résultat, score, prix ni fournisseur n'est inventé.
--  1. assessment_families : taxonomie évolutive des 33 familles de métiers (CDC 8.1) ; ajout / désactivation réservés à l'administrateur (RPC) ;
--  2. assessment_providers (registre, vide) + assessment_provider_tests (tests d'intégration enregistrés) : activation réservée à l'administrateur global
--     (2FA, journal d'audit) et REFUSÉE sans test d'intégration réussi ;
--  3. assessment_requests, assessment_results (normalisés : compétences, critères, preuves, résultats, limites, recommandations, contestation, validation humaine),
--     assessment_disputes, assessment_campaigns + assessment_campaign_invites (financement par une organisation : lecture seule pour l'organisation, RLS) ;
--  4. quota : 1 évaluation gratuite par étudiant et par mois civil (fuseau Africa/Douala), CALCULÉ (aucun compteur) et consommé seulement quand un fournisseur actif a
--     ACCEPTÉ la demande (statuts acceptee / en_cours / terminee) ; refusée, échouée, annulée ou en attente : rien n'est consommé ;
--  5. évaluation supplémentaire : prix = décision du propriétaire (CDC 30) lue dans platform_settings 'assessment.extra_price' (absent = non décidé = indisponible) ;
--     s'il existe, le prix annoncé doit être transmis et identique ; le paiement n'étant pas en service, la demande reste « paiement_requis » (jamais envoyée à un fournisseur) ;
-- 6. aucune dépendance entre une candidature et une évaluation (aucune clé étrangère, aucun contrôle) ;
-- 7. les 11 modes d'évaluation du CDC 8.2 (liste unique _assessment_modes()) ;
-- 8. « une IA ne certifie jamais un geste non observé » appliqué côté serveur : un résultat ne peut porter le statut « validee_humainement » ou « non_verifiable_a_distance »
--    que par la RPC de validation humaine (20261125096000) ; jamais par l'enregistrement d'un fournisseur automatique ;
-- 9. non-discrimination (CDC 8.5) : les critères suivent une liste blanche de clés, et aucune clé évoquant l'accent, l'apparence, le sexe, l'origine, le handicap, l'âge,
--    la religion, la nationalité ou l'ethnie n'est acceptée dans les compétences, critères, preuves, détails ou recommandations ;
-- 10. équipe d'organisation : propriétaire et administrateurs (company_members) gèrent les campagnes et lisent les résultats partagés ; finance et lecteur lisent les campagnes seulement.
-- RLS stricte : le candidat ne voit que ses données ; une organisation ne voit que les demandes de SES campagnes (avec accord du candidat) ; l'administrateur selon ses permissions ; aucun accès anonyme.
-- Additive et rejouable. Retour arrière :
--   drop function _assessment_modes(), _assessment_bias_key(jsonb), _assessment_org_can(uuid, boolean), _assessment_result_shared_with_org(uuid), _assessment_check_criteria(jsonb);
--   drop function assessment_families(), assessment_quota(), assessment_request(text, text, boolean, text, numeric, uuid), assessment_my_list(), assessment_result(uuid), assessment_dispute(uuid, text),
--     assessment_providers_admin_list(), assessment_provider_register(text, text, text[], text[]), assessment_provider_record_test(text, boolean, text), assessment_provider_set_status(text, text),
--     assessment_family_set(text, text, boolean, integer), assessment_request_ack(uuid, text, text, text), assessment_result_record(uuid, jsonb), _assessment_extra_price(), _assessment_month_start(timestamptz), _assessment_staff();
--   (puis les retours arrière des migrations 20261125096000 à 20261125096200 si elles ont été appliquées)
--   drop table assessment_disputes, assessment_results, assessment_requests, assessment_campaign_invites, assessment_campaigns, assessment_provider_tests, assessment_providers, assessment_families;

-- ============================================================ 1. Familles de métiers
create table if not exists assessment_families (
  code text primary key check (code ~ '^[a-z0-9_]{2,40}$'),
  label text not null check (char_length(btrim(label)) between 2 and 120),
  active boolean not null default true,
  position integer not null default 0,
  created_at timestamptz not null default now()
);

insert into assessment_families (code, label, position) values
  ('btp_genie_civil', 'BTP et génie civil', 1),
  ('architecture_construction', 'Architecture et construction', 2),
  ('mecanique', 'Mécanique', 3),
  ('automobile', 'Automobile', 4),
  ('maintenance_industrielle', 'Maintenance industrielle', 5),
  ('electricite', 'Électricité', 6),
  ('electronique', 'Électronique', 7),
  ('electrotechnique', 'Électrotechnique', 8),
  ('energies_renouvelables_solaire', 'Énergies renouvelables et solaire', 9),
  ('informatique_developpement', 'Informatique et développement', 10),
  ('data_ia', 'Data et intelligence artificielle', 11),
  ('finance_comptabilite', 'Finance et comptabilité', 12),
  ('gestion_management', 'Gestion et management', 13),
  ('commerce_vente', 'Commerce et vente', 14),
  ('marketing', 'Marketing', 15),
  ('communication_medias', 'Communication et médias', 16),
  ('logistique_transport', 'Logistique et transport', 17),
  ('approvisionnement', 'Approvisionnement', 18),
  ('artisanat', 'Artisanat', 19),
  ('soudure', 'Soudure', 20),
  ('plomberie', 'Plomberie', 21),
  ('menuiserie', 'Menuiserie', 22),
  ('froid_climatisation', 'Froid et climatisation', 23),
  ('agriculture', 'Agriculture', 24),
  ('agro_industrie', 'Agro-industrie', 25),
  ('hotellerie_tourisme', 'Hôtellerie et tourisme', 26),
  ('ressources_humaines', 'Ressources humaines', 27),
  ('droit_conformite', 'Droit et conformité', 28),
  ('environnement', 'Environnement', 29),
  ('sciences_recherche', 'Sciences et recherche', 30),
  ('entrepreneuriat', 'Entrepreneuriat', 31),
  ('education_formation', 'Éducation et formation', 32),
  ('autres_metiers', 'Autres métiers et spécialités', 33)
on conflict (code) do nothing;

-- Les 11 modes d'évaluation du CDC 8.2 (liste unique, utilisée par les contraintes et les RPC).
create or replace function _assessment_modes() returns text[]
language sql immutable set search_path = public as $$
  select array['ecrit', 'etude_cas', 'entretien_oral_ia', 'analyse_documents', 'exercice_pratique', 'simulation', 'analyse_fichiers', 'presentation_video',
               'evaluation_projets', 'analyse_images_videos', 'validation_humaine']::text[]
$$;
revoke all on function _assessment_modes() from public, anon;
grant execute on function _assessment_modes() to authenticated;

-- ============================================================ 2. Registre des fournisseurs (VIDE : aucun fournisseur n'est actif)
create table if not exists assessment_providers (
  code text primary key check (code ~ '^[a-z0-9_]{2,40}$'),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  status text not null default 'candidat' check (status in ('candidat', 'en_test', 'actif', 'suspendu')),
  family_codes text[] not null default '{}',
  modes text[] not null default '{}' check (modes <@ _assessment_modes()),
  activated_at timestamptz,
  created_by uuid references profiles (id) on delete set null,
  updated_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Test d'intégration enregistré : un appel réel (sandbox ou production) réussi ou échoué, avec sa note. Sans test réussi, un fournisseur ne peut pas devenir actif.
create table if not exists assessment_provider_tests (
  id bigint generated always as identity primary key,
  provider_code text not null references assessment_providers (code) on delete cascade,
  ok boolean not null,
  note text not null default '',
  tested_by uuid references profiles (id) on delete set null,
  tested_at timestamptz not null default now()
);
create index if not exists assessment_provider_tests_provider on assessment_provider_tests (provider_code, tested_at desc);

-- ============================================================ 3. Campagnes financées par une organisation, demandes, résultats, contestations
create table if not exists assessment_campaigns (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references profiles (id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  family_code text not null references assessment_families (code),
  mode text not null check (mode = any (_assessment_modes())),
  -- Le financement réel est une décision du propriétaire : tant qu'aucun mécanisme de paiement n'existe, une campagne reste « en_attente_financement » et personne ne peut passer une évaluation dessus.
  status text not null default 'en_attente_financement' check (status in ('en_attente_financement', 'ouverte', 'close')),
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists assessment_campaigns_org on assessment_campaigns (org_id);

create table if not exists assessment_campaign_invites (
  campaign_id uuid not null references assessment_campaigns (id) on delete cascade,
  candidate_id uuid not null references profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (campaign_id, candidate_id)
);

create table if not exists assessment_requests (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references profiles (id) on delete cascade,
  family_code text not null references assessment_families (code),
  mode text not null check (mode = any (_assessment_modes())),
  provider_code text references assessment_providers (code),
  status text not null default 'envoyee' check (status in ('envoyee', 'paiement_requis', 'acceptee', 'en_cours', 'terminee', 'refusee', 'echouee', 'annulee')),
  funding text not null check (funding in ('gratuite_mensuelle', 'payee_candidat', 'financee_organisation')),
  campaign_id uuid references assessment_campaigns (id) on delete set null,
  consent boolean not null check (consent),
  share_with_org boolean not null default false,
  reuse_of uuid references assessment_requests (id) on delete set null,
  reuse_consent boolean not null default false,
  announced_price_xaf numeric,
  status_note text,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists assessment_requests_candidate on assessment_requests (candidate_id, created_at desc);
create index if not exists assessment_requests_campaign on assessment_requests (campaign_id) where campaign_id is not null;

create table if not exists assessment_results (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references assessment_requests (id) on delete cascade,
  candidate_id uuid not null references profiles (id) on delete cascade,
  provider_code text references assessment_providers (code),
  competences jsonb not null default '[]' check (jsonb_typeof(competences) = 'array'),
  criteria jsonb not null default '[]' check (jsonb_typeof(criteria) = 'array'),
  evidence jsonb not null default '[]' check (jsonb_typeof(evidence) = 'array'),
  details jsonb not null default '{}' check (jsonb_typeof(details) = 'object'),
  limits text not null check (char_length(btrim(limits)) > 0),
  recommendations jsonb not null default '[]' check (jsonb_typeof(recommendations) = 'array'),
  validation_status text not null default 'automatique' check (validation_status in ('automatique', 'validation_humaine_requise', 'validee_humainement', 'non_verifiable_a_distance')),
  reviewed_by uuid references profiles (id) on delete set null,
  reviewed_at timestamptz,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  dispute_possible boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists assessment_results_candidate on assessment_results (candidate_id, created_at desc);

create table if not exists assessment_disputes (
  id uuid primary key default gen_random_uuid(),
  result_id uuid not null references assessment_results (id) on delete cascade,
  candidate_id uuid not null references profiles (id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 10 and 2000),
  status text not null default 'ouverte' check (status in ('ouverte', 'en_examen', 'close')),
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists assessment_disputes_result on assessment_disputes (result_id);

-- Non-discrimination (CDC 8.5) : cherche, à toute profondeur, une clé évoquant une caractéristique sans rapport avec les compétences professionnelles.
-- La clé est normalisée (minuscules, sans accents, séparateurs unifiés) et comparée par mot entier : « accent_orateur » est refusée, « accentuation » non.
create or replace function _assessment_bias_key(p jsonb) returns text
language plpgsql immutable set search_path = public as $$
declare k text; v jsonb; r text; n text;
begin
  if jsonb_typeof(p) = 'object' then
    for k, v in select key, value from jsonb_each(p) loop
      n := btrim(regexp_replace(translate(lower(k), 'àâäáéèêëíîïóôöúùûüçñ', 'aaaaeeeeiiiooouuuucn'), '[^a-z0-9]+', '_', 'g'), '_');
      if n ~ '(^|_)(accent|apparence|appearance|sexe|sex|gender|genre|origine|origin|ethnie|ethnicite|ethnicity|race|nationalite|nationality|handicap|disability|age|religion)(_|$)' then return k; end if;
      r := _assessment_bias_key(v);
      if r is not null then return r; end if;
    end loop;
  elsif jsonb_typeof(p) = 'array' then
    for v in select value from jsonb_array_elements(p) loop
      r := _assessment_bias_key(v);
      if r is not null then return r; end if;
    end loop;
  end if;
  return null;
end $$;
revoke all on function _assessment_bias_key(jsonb) from public, anon;
grant execute on function _assessment_bias_key(jsonb) to authenticated;

-- Critères : liste blanche de clés (un critère est un objet), et aucun libellé qui désigne lui-même une caractéristique interdite.
create or replace function _assessment_check_criteria(p jsonb) returns void
language plpgsql immutable set search_path = public as $$
declare c jsonb; k text; n text;
  v_allowed text[] := array['name', 'label', 'description', 'score', 'max_score', 'level', 'weight', 'comment', 'observed', 'evidence_refs', 'verifiable_remotely', 'competence'];
begin
  if jsonb_typeof(p) is distinct from 'array' then return; end if;
  for c in select value from jsonb_array_elements(p) loop
    if jsonb_typeof(c) <> 'object' then raise exception 'Critère refusé : chaque critère doit être un objet'; end if;
    for k in select key from jsonb_object_keys(c) key loop
      if not (k = any (v_allowed)) then
        raise exception 'Critère refusé : la clé « % » n''est pas autorisée (clés acceptées : %). Aucun champ ne peut porter l''accent, l''apparence, le sexe, l''origine ou le handicap.', k, array_to_string(v_allowed, ', ');
      end if;
    end loop;
    foreach k in array array['name', 'label'] loop
      if jsonb_typeof(c -> k) = 'string' then
        n := btrim(regexp_replace(translate(lower(c ->> k), 'àâäáéèêëíîïóôöúùûüçñ', 'aaaaeeeeiiiooouuuucn'), '[^a-z0-9]+', '_', 'g'), '_');
        if n ~ '^(accent|apparence|sexe|sex|gender|handicap|disability|ethnicite|ethnicity|nationalite|nationality|religion|age)(_|$)' then
          raise exception 'Critère refusé : « % » est sans rapport avec les compétences professionnelles', c ->> k;
        end if;
      end if;
    end loop;
  end loop;
end $$;
revoke all on function _assessment_check_criteria(jsonb) from public, anon;
grant execute on function _assessment_check_criteria(jsonb) to authenticated;

-- Une IA ne certifie jamais un geste qu'elle n'a pas observé : une compétence non vérifiable à distance impose la validation humaine, quelle que soit la source.
-- Les statuts « validee_humainement » et « non_verifiable_a_distance » n'existent que par la RPC de validation humaine (20261125096000), qui signe la décision et pose
-- le réglage de transaction app.assessment_human_review ; aucun enregistrement de fournisseur ne peut les porter.
create or replace function _assessment_result_guard() returns trigger
language plpgsql set search_path = public as $$
declare v_bad text; x jsonb; v_human text[] := array['validee_humainement', 'non_verifiable_a_distance'];
begin
  foreach x in array array[new.competences, new.criteria, new.evidence, new.details, new.recommendations] loop
    v_bad := _assessment_bias_key(x);
    if v_bad is not null then
      raise exception 'Champ refusé : « % » pourrait porter l''accent, l''apparence, le sexe, l''origine, le handicap ou une caractéristique sans rapport avec les compétences professionnelles', v_bad;
    end if;
  end loop;
  perform _assessment_check_criteria(new.criteria);

  if tg_op = 'UPDATE' and old.validation_status = any (v_human) then
    if new.validation_status is distinct from old.validation_status or new.competences is distinct from old.competences or new.criteria is distinct from old.criteria
       or new.evidence is distinct from old.evidence or new.details is distinct from old.details or new.limits is distinct from old.limits then
      raise exception 'Décision humaine déjà enregistrée : ce résultat n''est plus modifiable';
    end if;
    return new;
  end if;

  if new.validation_status = any (v_human) then
    if new.reviewed_by is null or new.reviewed_at is null or coalesce(current_setting('app.assessment_human_review', true), '') <> new.reviewed_by::text then
      raise exception 'Une IA ne certifie jamais un geste non observé : seul un évaluateur habilité peut enregistrer une validation humaine';
    end if;
  elsif new.validation_status = 'automatique'
        and exists (select 1 from jsonb_array_elements(new.competences) c where jsonb_typeof(c) = 'object' and coalesce(c ->> 'verifiable_remotely', 'true') = 'false') then
    new.validation_status := 'validation_humaine_requise';
  end if;
  return new;
end $$;
drop trigger if exists trg_assessment_result_guard on assessment_results;
create trigger trg_assessment_result_guard before insert or update on assessment_results for each row execute function _assessment_result_guard();

-- ============================================================ 4. RLS : lecture seule côté client, toute écriture passe par les RPC
create or replace function _assessment_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_role_name()::text, '') = 'admin'
$$;
revoke all on function _assessment_staff() from public, anon;
grant execute on function _assessment_staff() to authenticated;

-- Équipe d'organisation (company_members) : le propriétaire et les administrateurs gèrent et lisent les résultats (p_write) ; finance et lecteur lisent les campagnes seulement.
-- company_role_of ignore les membres suspendus.
create or replace function _assessment_org_can(p_org uuid, p_write boolean) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.uid() is not null and p_org is not null and (
    company_role_of(p_org) in ('owner', 'admin') or (not coalesce(p_write, true) and company_role_of(p_org) in ('finance', 'viewer'))), false)
$$;
revoke all on function _assessment_org_can(uuid, boolean) from public, anon;
grant execute on function _assessment_org_can(uuid, boolean) to authenticated;

-- Appartenance à une campagne : fonctions SECURITY DEFINER (les politiques des campagnes et des invitations se référencent mutuellement : sans elles, récursion).
create or replace function _assessment_owns_campaign(p_campaign uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from assessment_campaigns c where c.id = p_campaign and _assessment_org_can(c.org_id, true))
$$;
create or replace function _assessment_invited(p_campaign uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from assessment_campaign_invites where campaign_id = p_campaign and candidate_id = auth.uid())
$$;
revoke all on function _assessment_owns_campaign(uuid), _assessment_invited(uuid) from public, anon;
grant execute on function _assessment_owns_campaign(uuid), _assessment_invited(uuid) to authenticated;

-- Un résultat n'est visible d'une organisation que si le candidat a accepté de le partager avec une campagne de cette organisation :
-- demande financée par la campagne (share_with_org), ou réutilisation d'un résultat récent avec accord explicite (reuse_of + reuse_consent).
create or replace function _assessment_result_shared_with_org(p_result uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from assessment_results r join assessment_requests q on (q.id = r.request_id or (q.reuse_of = r.request_id and q.reuse_consent))
    where r.id = p_result and q.share_with_org and q.campaign_id is not null and q.status <> 'annulee' and _assessment_owns_campaign(q.campaign_id))
$$;
revoke all on function _assessment_result_shared_with_org(uuid) from public, anon;
grant execute on function _assessment_result_shared_with_org(uuid) to authenticated;
alter table assessment_families enable row level security;
alter table assessment_providers enable row level security;
alter table assessment_provider_tests enable row level security;
alter table assessment_campaigns enable row level security;
alter table assessment_campaign_invites enable row level security;
alter table assessment_requests enable row level security;
alter table assessment_results enable row level security;
alter table assessment_disputes enable row level security;
revoke all on assessment_families, assessment_providers, assessment_provider_tests, assessment_campaigns, assessment_campaign_invites, assessment_requests, assessment_results, assessment_disputes from public, anon, authenticated;
grant select on assessment_families, assessment_providers, assessment_provider_tests, assessment_campaigns, assessment_campaign_invites, assessment_requests, assessment_results, assessment_disputes to authenticated;

drop policy if exists "familles d'évaluation : connectés" on assessment_families;
create policy "familles d'évaluation : connectés" on assessment_families for select to authenticated using (auth.uid() is not null and (active or _assessment_staff()));
drop policy if exists "fournisseurs d'évaluation : permission technique" on assessment_providers;
create policy "fournisseurs d'évaluation : permission technique" on assessment_providers for select to authenticated using (has_admin_permission('tech.integrations'));
drop policy if exists "tests de fournisseur : permission technique" on assessment_provider_tests;
create policy "tests de fournisseur : permission technique" on assessment_provider_tests for select to authenticated using (has_admin_permission('tech.integrations'));
drop policy if exists "campagnes d'évaluation : organisation propriétaire, invités, administrateur" on assessment_campaigns;
create policy "campagnes d'évaluation : organisation propriétaire, invités, administrateur" on assessment_campaigns for select to authenticated
  using (_assessment_org_can(org_id, false) or _assessment_staff() or _assessment_invited(id));
drop policy if exists "invitations d'évaluation : organisation propriétaire, invité, administrateur" on assessment_campaign_invites;
create policy "invitations d'évaluation : organisation propriétaire, invité, administrateur" on assessment_campaign_invites for select to authenticated
  using (candidate_id = auth.uid() or _assessment_staff() or _assessment_owns_campaign(campaign_id));
drop policy if exists "demandes d'évaluation : candidat, organisation financeuse, administrateur" on assessment_requests;
create policy "demandes d'évaluation : candidat, organisation financeuse, administrateur" on assessment_requests for select to authenticated
  using (candidate_id = auth.uid() or _assessment_staff()
         or (share_with_org and _assessment_owns_campaign(campaign_id)));
drop policy if exists "résultats d'évaluation : candidat, organisation financeuse, administrateur" on assessment_results;
create policy "résultats d'évaluation : candidat, organisation financeuse, administrateur" on assessment_results for select to authenticated
  using (candidate_id = auth.uid() or _assessment_staff() or _assessment_result_shared_with_org(id));
drop policy if exists "contestations d'évaluation : candidat, support" on assessment_disputes;
create policy "contestations d'évaluation : candidat, support" on assessment_disputes for select to authenticated
  using (candidate_id = auth.uid() or has_admin_permission('support.disputes'));

-- ============================================================ 5. Outils internes
-- Début du mois civil (fuseau de Douala) qui contient p_at.
create or replace function _assessment_month_start(p_at timestamptz) returns timestamptz
language sql immutable set search_path = public as $$
  select date_trunc('month', p_at at time zone 'Africa/Douala') at time zone 'Africa/Douala'
$$;
revoke all on function _assessment_month_start(timestamptz) from public, anon, authenticated;

-- Prix d'une évaluation supplémentaire : null tant que le propriétaire ne l'a pas décidé (réglage absent ou invalide). Aucune valeur par défaut.
create or replace function _assessment_extra_price() returns numeric
language plpgsql stable security definer set search_path = public as $$
declare v jsonb; n numeric;
begin
  select value into v from platform_settings where key = 'assessment.extra_price';
  if v is null then return null; end if;
  begin
    n := case jsonb_typeof(v) when 'number' then (v #>> '{}')::numeric when 'object' then (v ->> 'amount_xaf')::numeric else null end;
  exception when others then
    return null;
  end;
  return case when n is not null and n > 0 then n else null end;
end $$;
revoke all on function _assessment_extra_price() from public, anon, authenticated;

create or replace function _assessment_audit(p_action text, p_target text, p_level text default 'Sensible') returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), left(p_action, 120), left(p_target, 200), 'Évaluations', p_level);
end $$;
revoke all on function _assessment_audit(text, text, text) from public, anon, authenticated;

-- Garde commune des opérations d'administration : administrateur global, 2FA (session aal2 si un facteur est vérifié).
create or replace function _assessment_admin_only() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur global'; end if;
  perform _require_staff_aal2();
end $$;
revoke all on function _assessment_admin_only() from public, anon, authenticated;

-- Lien d'une demande avec un fournisseur actif (aucune requête vers l'extérieur) : le fournisseur actif qui couvre la famille ET le mode.
create or replace function _assessment_pick_provider(p_family text, p_mode text) returns text
language sql stable security definer set search_path = public as $$
  select code from assessment_providers where status = 'actif' and p_family = any (family_codes) and p_mode = any (modes) order by code limit 1
$$;
revoke all on function _assessment_pick_provider(text, text) from public, anon, authenticated;

create or replace function _assessment_used(p_uid uuid, p_at timestamptz) returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::int from assessment_requests
  where candidate_id = p_uid and funding = 'gratuite_mensuelle' and status in ('acceptee', 'en_cours', 'terminee')
    and accepted_at >= _assessment_month_start(p_at) and accepted_at < _assessment_month_start(p_at) + interval '1 month'
$$;
revoke all on function _assessment_used(uuid, timestamptz) from public, anon, authenticated;

-- ============================================================ 6. RPC candidat
create or replace function assessment_families() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'code', f.code, 'label', f.label, 'position', f.position,
      'covered', exists (select 1 from assessment_providers p where p.status = 'actif' and f.code = any (p.family_codes))) order by f.position, f.code)
    from assessment_families f where f.active), '[]'::jsonb);
end $$;

create or replace function assessment_quota() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_role text := coalesce(current_role_name()::text, ''); v_now timestamptz := now(); v_used int; v_price numeric;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  v_price := _assessment_extra_price();
  if v_role <> 'student' then
    return jsonb_build_object('eligible', false, 'monthly_free', 1, 'message', 'L''évaluation gratuite du mois est réservée aux comptes étudiants.',
      'active_providers', (select count(*)::int from assessment_providers where status = 'actif'));
  end if;
  v_used := _assessment_used(v_uid, v_now);
  return jsonb_build_object(
    'eligible', true, 'monthly_free', 1, 'used', v_used, 'remaining', greatest(1 - v_used, 0),
    'next_reset', _assessment_month_start(v_now) + interval '1 month',
    'pending', exists (select 1 from assessment_requests where candidate_id = v_uid and funding = 'gratuite_mensuelle' and status = 'envoyee'),
    'active_providers', (select count(*)::int from assessment_providers where status = 'actif'),
    'extra', jsonb_build_object(
      'available', v_price is not null,
      'price_xaf', v_price,
      'payment_ready', false,
      'message', case when v_price is null then 'Évaluation supplémentaire indisponible : son tarif n''a pas encore été décidé.'
                      else 'Évaluation supplémentaire : ' || v_price::text || ' FCFA, annoncés avant toute confirmation. Le paiement des évaluations supplémentaires n''est pas encore en service.' end));
end $$;

create or replace function assessment_request(p_family text, p_mode text, p_consent boolean, p_funding text, p_announced_price numeric default null, p_campaign uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_role text := coalesce(current_role_name()::text, ''); v_fam assessment_families; v_provider text; v_price numeric; v_camp assessment_campaigns;
        v_id uuid; v_status text; v_now timestamptz := now();
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('student', 'client') then raise exception 'Accès refusé : les évaluations sont réservées aux candidats (étudiants et clients).'; end if;
  if p_mode is null or not (p_mode = any (_assessment_modes())) then
    raise exception 'Mode d''évaluation inconnu';
  end if;
  if p_funding is null or p_funding not in ('gratuite_mensuelle', 'payee_candidat', 'financee_organisation') then raise exception 'Source de financement inconnue'; end if;
  if p_funding = 'gratuite_mensuelle' and v_role <> 'student' then raise exception 'Accès refusé : l''évaluation gratuite du mois est réservée aux étudiants.'; end if;
  if coalesce(p_consent, false) is not true then
    return jsonb_build_object('ok', false, 'code', 'consent_required', 'message', 'Votre consentement est nécessaire pour lancer une évaluation.');
  end if;
  select * into v_fam from assessment_families where code = p_family and active;
  if v_fam.code is null then return jsonb_build_object('ok', false, 'code', 'unknown_family', 'message', 'Famille de métiers inconnue ou désactivée.'); end if;

  -- Aucun fournisseur actif : refus propre, rien n'est enregistré ni consommé.
  v_provider := _assessment_pick_provider(p_family, p_mode);
  if v_provider is null then
    return jsonb_build_object('ok', false, 'code', 'no_provider', 'message', 'Aucun fournisseur actif pour cette famille et ce mode : votre demande n''est pas enregistrée et votre évaluation gratuite n''est pas consommée.');
  end if;

  if p_funding = 'gratuite_mensuelle' then
    if _assessment_used(v_uid, v_now) >= 1 then
      return jsonb_build_object('ok', false, 'code', 'quota_exhausted', 'message', 'Votre évaluation gratuite de ce mois est déjà utilisée.', 'next_reset', _assessment_month_start(v_now) + interval '1 month');
    end if;
    if exists (select 1 from assessment_requests where candidate_id = v_uid and funding = 'gratuite_mensuelle' and status = 'envoyee') then
      return jsonb_build_object('ok', false, 'code', 'already_pending', 'message', 'Une demande gratuite est déjà en attente de réponse du fournisseur.');
    end if;
    v_status := 'envoyee';
  elsif p_funding = 'payee_candidat' then
    v_price := _assessment_extra_price();
    if v_price is null then
      return jsonb_build_object('ok', false, 'code', 'extra_unavailable', 'message', 'Évaluation supplémentaire indisponible : son tarif n''a pas encore été décidé.');
    end if;
    if p_announced_price is null or p_announced_price <> v_price then
      return jsonb_build_object('ok', false, 'code', 'price_mismatch', 'message', 'Le prix annoncé ne correspond pas au tarif en vigueur : relisez le tarif avant de confirmer.', 'price_xaf', v_price);
    end if;
    v_status := 'paiement_requis';
  else
    select * into v_camp from assessment_campaigns where id = p_campaign and status = 'ouverte';
    if v_camp.id is null or v_camp.family_code <> p_family or v_camp.mode <> p_mode
       or not exists (select 1 from assessment_campaign_invites where campaign_id = v_camp.id and candidate_id = v_uid) then
      return jsonb_build_object('ok', false, 'code', 'campaign_invalid', 'message', 'Aucune campagne ouverte ne vous invite pour cette famille et ce mode.');
    end if;
    v_status := 'envoyee';
  end if;

  insert into assessment_requests (candidate_id, family_code, mode, provider_code, status, funding, campaign_id, consent, share_with_org, announced_price_xaf)
  values (v_uid, p_family, p_mode, case when v_status = 'envoyee' then v_provider end, v_status, p_funding, v_camp.id, true, p_funding = 'financee_organisation', v_price)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', v_status,
    'message', case when v_status = 'paiement_requis' then 'Demande enregistrée : le paiement des évaluations supplémentaires n''est pas encore en service, elle n''est pas envoyée au fournisseur.'
                    else 'Demande envoyée au fournisseur. Votre évaluation gratuite n''est consommée que lorsque le fournisseur accepte la demande.' end);
end $$;

create or replace function assessment_my_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'family_code', r.family_code, 'family_label', f.label, 'mode', r.mode, 'status', r.status, 'funding', r.funding, 'status_note', r.status_note,
      'created_at', r.created_at, 'accepted_at', r.accepted_at, 'reuse_of', r.reuse_of, 'campaign_id', r.campaign_id, 'shared_with_org', r.share_with_org,
      'result_id', res.id, 'validation_status', res.validation_status,
      'dispute_status', (select d.status from assessment_disputes d where d.result_id = res.id order by d.created_at desc limit 1)) order by r.created_at desc)
    from assessment_requests r join assessment_families f on f.code = r.family_code left join assessment_results res on res.request_id = coalesce(r.reuse_of, r.id)
    where r.candidate_id = auth.uid()), '[]'::jsonb);
end $$;

create or replace function assessment_result(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r assessment_results; q assessment_requests;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into r from assessment_results where id = p_id and candidate_id = auth.uid();
  if r.id is null then raise exception 'Résultat introuvable'; end if;
  select * into q from assessment_requests where id = r.request_id;
  return jsonb_build_object(
    'id', r.id, 'request_id', r.request_id, 'family_code', q.family_code, 'mode', q.mode, 'competences', r.competences, 'criteria', r.criteria, 'evidence', r.evidence,
    'details', r.details, 'limits', r.limits, 'recommendations', r.recommendations, 'validation_status', r.validation_status, 'review_note', r.review_note, 'reviewed_at', r.reviewed_at,
    'human_validation_required', r.validation_status = 'validation_humaine_requise', 'dispute_possible', r.dispute_possible, 'created_at', r.created_at,
    'disputes', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'status', d.status, 'reason', d.reason, 'resolution', d.resolution, 'created_at', d.created_at) order by d.created_at desc)
                          from assessment_disputes d where d.result_id = r.id), '[]'::jsonb));
end $$;

create or replace function assessment_dispute(p_id uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_results; v_reason text := btrim(coalesce(p_reason, '')); v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu'; end if;
  select * into r from assessment_results where id = p_id and candidate_id = auth.uid();
  if r.id is null then raise exception 'Résultat introuvable'; end if;
  if not r.dispute_possible then raise exception 'Ce résultat ne peut pas être contesté'; end if;
  if char_length(v_reason) < 10 or char_length(v_reason) > 2000 then raise exception 'Expliquez votre contestation en 10 à 2000 caractères'; end if;
  if exists (select 1 from assessment_disputes where result_id = r.id and status in ('ouverte', 'en_examen')) then raise exception 'Une contestation est déjà en cours pour ce résultat'; end if;
  insert into assessment_disputes (result_id, candidate_id, reason) values (r.id, auth.uid(), v_reason) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- ============================================================ 7. RPC d'administration et d'adaptateur de fournisseur
create or replace function assessment_providers_admin_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('tech.integrations') then raise exception 'Réservé : exige la permission d''intégrations'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'code', p.code, 'name', p.name, 'status', p.status, 'family_codes', to_jsonb(p.family_codes), 'modes', to_jsonb(p.modes), 'activated_at', p.activated_at,
      'last_test', (select jsonb_build_object('ok', t.ok, 'note', t.note, 'tested_at', t.tested_at) from assessment_provider_tests t where t.provider_code = p.code order by t.tested_at desc, t.id desc limit 1))
    order by p.code) from assessment_providers p), '[]'::jsonb);
end $$;

create or replace function assessment_provider_register(p_code text, p_name text, p_families text[], p_modes text[]) returns void
language plpgsql security definer set search_path = public as $$
declare v_code text := lower(btrim(coalesce(p_code, '')));
begin
  perform _assessment_admin_only();
  if v_code !~ '^[a-z0-9_]{2,40}$' then raise exception 'Code fournisseur invalide (2 à 40 caractères : a-z, 0-9, _)'; end if;
  if exists (select 1 from unnest(coalesce(p_families, '{}')) f where not exists (select 1 from assessment_families a where a.code = f)) then raise exception 'Famille inconnue dans la liste couverte'; end if;
  insert into assessment_providers (code, name, status, family_codes, modes, created_by, updated_by)
  values (v_code, btrim(coalesce(p_name, '')), 'candidat', coalesce(p_families, '{}'), coalesce(p_modes, '{}'), auth.uid(), auth.uid())
  on conflict (code) do update set name = excluded.name, family_codes = excluded.family_codes, modes = excluded.modes, updated_by = auth.uid(), updated_at = now();
  perform _assessment_audit('Fournisseur d''évaluation enregistré', v_code);
end $$;

create or replace function assessment_provider_record_test(p_code text, p_ok boolean, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
declare p assessment_providers;
begin
  perform _assessment_admin_only();
  select * into p from assessment_providers where code = p_code for update;
  if p.code is null then raise exception 'Fournisseur introuvable'; end if;
  insert into assessment_provider_tests (provider_code, ok, note, tested_by) values (p.code, coalesce(p_ok, false), left(btrim(coalesce(p_note, '')), 500), auth.uid());
  -- un test échoué retire un fournisseur actif du service
  if not coalesce(p_ok, false) and p.status = 'actif' then update assessment_providers set status = 'suspendu', updated_by = auth.uid(), updated_at = now() where code = p.code;
  elsif p.status = 'candidat' then update assessment_providers set status = 'en_test', updated_by = auth.uid(), updated_at = now() where code = p.code; end if;
  perform _assessment_audit('Test d''intégration de fournisseur enregistré', p.code || ' : ' || case when coalesce(p_ok, false) then 'réussi' else 'échoué' end);
end $$;

create or replace function assessment_provider_set_status(p_code text, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare p assessment_providers; v_last boolean;
begin
  perform _assessment_admin_only();
  if p_status is null or p_status not in ('candidat', 'en_test', 'actif', 'suspendu') then raise exception 'Statut de fournisseur inconnu'; end if;
  select * into p from assessment_providers where code = p_code for update;
  if p.code is null then raise exception 'Fournisseur introuvable'; end if;
  if p_status = 'actif' then
    select t.ok into v_last from assessment_provider_tests t where t.provider_code = p.code order by t.tested_at desc, t.id desc limit 1;
    if v_last is distinct from true then raise exception 'Activation refusée : aucun test d''intégration réussi enregistré pour ce fournisseur'; end if;
    if cardinality(p.family_codes) = 0 or cardinality(p.modes) = 0 then raise exception 'Activation refusée : familles et modes couverts à renseigner'; end if;
  end if;
  update assessment_providers set status = p_status, activated_at = case when p_status = 'actif' then now() else activated_at end, updated_by = auth.uid(), updated_at = now() where code = p.code;
  perform _assessment_audit('Statut de fournisseur d''évaluation : ' || p_status, p.code || ' (avant : ' || p.status || ')', case when p_status = 'actif' then 'Critique' else 'Sensible' end);
end $$;

create or replace function assessment_family_set(p_code text, p_label text, p_active boolean default true, p_position integer default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_code text := lower(btrim(coalesce(p_code, '')));
begin
  perform _assessment_admin_only();
  if v_code !~ '^[a-z0-9_]{2,40}$' then raise exception 'Code de famille invalide (2 à 40 caractères : a-z, 0-9, _)'; end if;
  insert into assessment_families (code, label, active, position)
  values (v_code, btrim(coalesce(p_label, '')), coalesce(p_active, true), coalesce(p_position, (select coalesce(max(position), 0) + 1 from assessment_families)))
  on conflict (code) do update set label = excluded.label, active = excluded.active, position = coalesce(p_position, assessment_families.position);
  perform _assessment_audit('Famille d''évaluation modifiée', v_code || case when coalesce(p_active, true) then '' else ' (désactivée)' end);
end $$;

-- Réponse du fournisseur à une demande envoyée : le quota gratuit n'est consommé qu'à l'acceptation. Appelée par l'administrateur ou, plus tard, par l'adaptateur serveur (service_role).
create or replace function assessment_request_ack(p_id uuid, p_outcome text, p_note text default null, p_provider_ref text default null) returns void
language plpgsql security definer set search_path = public as $$
declare q assessment_requests; v_service boolean := coalesce(auth.role(), '') = 'service_role';
begin
  if not v_service then perform _assessment_admin_only(); end if;
  if p_outcome is null or p_outcome not in ('acceptee', 'en_cours', 'terminee', 'refusee', 'echouee', 'annulee') then raise exception 'Issue inconnue'; end if;
  select * into q from assessment_requests where id = p_id for update;
  if q.id is null then raise exception 'Demande introuvable'; end if;
  if q.status in ('paiement_requis', 'refusee', 'echouee', 'annulee', 'terminee') then raise exception 'Cette demande n''est plus modifiable (statut : %)', q.status; end if;
  if p_outcome in ('acceptee', 'en_cours', 'terminee') and not exists (select 1 from assessment_providers where code = q.provider_code and status = 'actif') then
    raise exception 'Le fournisseur de cette demande n''est plus actif : acceptation impossible';
  end if;
  update assessment_requests set status = p_outcome, status_note = left(nullif(btrim(coalesce(p_note, '')), ''), 500),
    accepted_at = case when p_outcome in ('acceptee', 'en_cours', 'terminee') then coalesce(accepted_at, now()) else accepted_at end, updated_at = now()
  where id = q.id;
  perform _assessment_audit('Réponse du fournisseur à une demande d''évaluation : ' || p_outcome, q.id::text, 'Info');
end $$;

-- Enregistrement d'un résultat normalisé (adaptateur serveur ou administrateur) ; limites obligatoires ; compétences non vérifiables à distance : validation humaine requise.
create or replace function assessment_result_record(p_request uuid, p_payload jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare q assessment_requests; v_service boolean := coalesce(auth.role(), '') = 'service_role'; v_id uuid;
begin
  if not v_service then perform _assessment_admin_only(); end if;
  select * into q from assessment_requests where id = p_request for update;
  if q.id is null then raise exception 'Demande introuvable'; end if;
  if q.status not in ('acceptee', 'en_cours', 'terminee') then raise exception 'Aucun résultat avant l''acceptation de la demande par le fournisseur'; end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'Résultat invalide'; end if;
  insert into assessment_results (request_id, candidate_id, provider_code, competences, criteria, evidence, details, limits, recommendations, validation_status)
  values (q.id, q.candidate_id, q.provider_code, coalesce(p_payload -> 'competences', '[]'), coalesce(p_payload -> 'criteria', '[]'), coalesce(p_payload -> 'evidence', '[]'),
          coalesce(p_payload -> 'details', '{}'), coalesce(p_payload ->> 'limits', ''), coalesce(p_payload -> 'recommendations', '[]'),
          case when q.mode = 'validation_humaine' then 'validation_humaine_requise'
               when p_payload ->> 'validation_status' in ('automatique', 'validation_humaine_requise') then p_payload ->> 'validation_status' else 'automatique' end)
  returning id into v_id;
  update assessment_requests set status = 'terminee', updated_at = now() where id = q.id;
  return v_id;
end $$;

revoke all on function assessment_families(), assessment_quota(), assessment_my_list(), assessment_providers_admin_list() from public, anon;
revoke all on function assessment_request(text, text, boolean, text, numeric, uuid), assessment_result(uuid), assessment_dispute(uuid, text) from public, anon;
revoke all on function assessment_provider_register(text, text, text[], text[]), assessment_provider_record_test(text, boolean, text), assessment_provider_set_status(text, text),
  assessment_family_set(text, text, boolean, integer), assessment_request_ack(uuid, text, text, text), assessment_result_record(uuid, jsonb) from public, anon;
grant execute on function assessment_families(), assessment_quota(), assessment_my_list(), assessment_providers_admin_list() to authenticated;
grant execute on function assessment_request(text, text, boolean, text, numeric, uuid), assessment_result(uuid), assessment_dispute(uuid, text) to authenticated;
grant execute on function assessment_provider_register(text, text, text[], text[]), assessment_provider_record_test(text, boolean, text), assessment_provider_set_status(text, text),
  assessment_family_set(text, text, boolean, integer), assessment_request_ack(uuid, text, text, text), assessment_result_record(uuid, jsonb) to authenticated;
