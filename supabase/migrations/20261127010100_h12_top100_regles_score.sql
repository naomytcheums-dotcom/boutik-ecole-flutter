-- Lot H12 / TOP100-A (2/4) : règles de score des talents, configurables par l'administration, versionnées et auditées (CDC Top 100, 1.3).
--  1. permissions SENSIBLES « ranking.rules », « ranking.publish », « ranking.moderate » (équipe « ranking » créée par 20261127010000) : attribuées explicitement,
--     aucune n'est dans un jeu de droits par défaut ; l'administrateur global les a toutes (has_admin_permission) ;
--  2. talent_score_rules : UNE règle par famille d'activité (13 familles). Elles sont créées en BROUILLON : 0 point, inactive, version 1 — décision du propriétaire :
--     aucun poids n'est fixé par le code, l'administration choisit les valeurs. Une règle inactive ou à 0 point ne rapporte jamais rien.
--     Les vues et les likes n'ont AUCUNE famille : ils ne peuvent pas produire de points.
--     points = points de base ; cap_per_day / cap_per_period = plafonds de points (par jour UTC, par mois civil) ; null = pas de plafond ;
--     quality_weight (0..1) = part des points qui dépend de la qualité de l'activité : points_attribués = points * ((1 - w) + w * qualité), qualité dans [0,1] ;
--  3. talent_score_rule_history : chaque état de chaque version (valeurs, auteur, motif) ; talent_score_settings : paramètres techniques du moteur (aucune ligne par défaut,
--     valeurs de repli codées dans _talent_setting : min_cohort 5, burst_count 10, burst_minutes 10) ;
--  4. RPC : talent_rules_public (règles actives, lisibles par tout connecté), admin_talent_rules_list, admin_talent_rule_set (2FA si facteur vérifié, motif obligatoire, audit),
--     admin_talent_rule_history, admin_talent_setting_set.
-- Additive et rejouable. Retour arrière : drop function talent_rules_public(), admin_talent_rules_list(), admin_talent_rule_set(text, integer, integer, integer, numeric, boolean, text),
--   admin_talent_rule_history(text), admin_talent_setting_set(text, numeric, text), _talent_setting(text, numeric), _talent_rule_log(); drop table talent_score_rule_history, talent_score_rules, talent_score_settings ;
--   delete from admin_team_members where permissions && array['ranking.rules','ranking.publish','ranking.moderate'] (retirer d'abord) ; delete from admin_permissions where code like 'ranking.%'.

insert into admin_permissions (code, team_code, label, description, sensitive, position) values
  ('ranking.rules', 'ranking', 'Règles de score des talents', 'Consulter et modifier les règles de points, plafonds et pondérations du score de talent (chaque changement est versionné et audité).', true, 2),
  ('ranking.publish', 'ranking', 'Publier les classements', 'Publier un classement mensuel et le corriger de façon auditée.', true, 3),
  ('ranking.moderate', 'ranking', 'Modérer les scores', 'Examiner les alertes de fraude, neutraliser ou rétablir des événements, corriger un score après contestation.', true, 4)
on conflict (code) do update set team_code = excluded.team_code, label = excluded.label, description = excluded.description, sensitive = excluded.sensitive, position = excluded.position;

create table if not exists talent_score_rules (
  code text primary key check (code in ('live_hosted', 'replay_completed_100', 'badge_verified', 'certificate_verified', 'project_published_with_proof', 'challenge_participation',
    'review_verified', 'sale_confirmed', 'mission_validated', 'skill_demonstrated', 'collaboration', 'event_attended', 'assessment_validated')),
  label text not null,
  description text not null,
  points integer not null default 0 check (points between 0 and 1000),
  cap_per_day integer check (cap_per_day is null or cap_per_day >= 0),
  cap_per_period integer check (cap_per_period is null or cap_per_period >= 0),
  quality_weight numeric(3, 2) not null default 0 check (quality_weight between 0 and 1),
  active boolean not null default false,
  version integer not null default 1,
  updated_by uuid references profiles (id) on delete set null,
  updated_at timestamptz not null default now(),
  check (not active or points > 0)
);

create table if not exists talent_score_rule_history (
  id bigint generated always as identity primary key,
  code text not null references talent_score_rules (code) on delete cascade,
  version integer not null,
  points integer not null,
  cap_per_day integer,
  cap_per_period integer,
  quality_weight numeric(3, 2) not null,
  active boolean not null,
  changed_by uuid references profiles (id) on delete set null,
  reason text,
  changed_at timestamptz not null default now()
);
create index if not exists talent_score_rule_history_code on talent_score_rule_history (code, id desc);

create table if not exists talent_score_settings (
  key text primary key check (key in ('min_cohort', 'burst_count', 'burst_minutes')),
  value numeric not null check (value > 0),
  updated_by uuid references profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table talent_score_rules enable row level security;
alter table talent_score_rule_history enable row level security;
alter table talent_score_settings enable row level security;
revoke all on talent_score_rules, talent_score_rule_history, talent_score_settings from public, anon, authenticated;

-- Historique : chaque version est tracée par le serveur, y compris la création en brouillon.
create or replace function _talent_rule_log() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' and (new.points, new.cap_per_day, new.cap_per_period, new.quality_weight, new.active) is distinct from (old.points, old.cap_per_day, old.cap_per_period, old.quality_weight, old.active) then
    new.version := old.version + 1;
  end if;
  return new;
end $$;
revoke all on function _talent_rule_log() from public, anon, authenticated;
drop trigger if exists trg_talent_rule_version on talent_score_rules;
create trigger trg_talent_rule_version before update on talent_score_rules for each row execute function _talent_rule_log();

create or replace function _talent_rule_history_row() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.version is distinct from old.version then
    insert into talent_score_rule_history (code, version, points, cap_per_day, cap_per_period, quality_weight, active, changed_by, reason)
    values (new.code, new.version, new.points, new.cap_per_day, new.cap_per_period, new.quality_weight, new.active, auth.uid(),
            case when tg_op = 'INSERT' then 'Création en brouillon (0 point, inactive)' else nullif(current_setting('app.talent_rule_reason', true), '') end);
  end if;
  return new;
end $$;
revoke all on function _talent_rule_history_row() from public, anon, authenticated;
drop trigger if exists trg_talent_rule_history on talent_score_rules;
create trigger trg_talent_rule_history after insert or update on talent_score_rules for each row execute function _talent_rule_history_row();

-- Règles en brouillon : points 0, inactives (décision du propriétaire : aucun poids fixé par le code).
insert into talent_score_rules (code, label, description) values
  ('live_hosted', 'Live animé', 'Un live réellement animé et terminé, avec des participants.'),
  ('replay_completed_100', 'Replay suivi à 100 %', 'Un replay regardé jusqu''au bout (progression réelle de 100 %).'),
  ('badge_verified', 'Badge vérifié', 'Un badge dont l''obtention est vérifiable.'),
  ('certificate_verified', 'Certificat vérifié', 'Un certificat émis et non révoqué.'),
  ('project_published_with_proof', 'Projet publié avec preuves', 'Un projet publié accompagné de preuves de réalisation.'),
  ('challenge_participation', 'Participation à un challenge', 'Une participation effective à un challenge ou une compétition.'),
  ('review_verified', 'Avis vérifié reçu', 'Un avis lié à un achat réel, reçu sur une annonce de l''étudiant.'),
  ('sale_confirmed', 'Vente confirmée', 'Une vente dont la commande est payée et non remboursée.'),
  ('mission_validated', 'Mission validée', 'Une mission réalisée et validée par le client.'),
  ('skill_demonstrated', 'Compétence démontrée', 'Une compétence démontrée et reconnue.'),
  ('collaboration', 'Collaboration professionnelle', 'Une contribution ou collaboration professionnelle confirmée.'),
  ('event_attended', 'Participation à un événement', 'Présence confirmée à un atelier, une masterclass ou un événement.'),
  ('assessment_validated', 'Évaluation validée', 'Une évaluation technique ou professionnelle validée par un évaluateur humain.')
on conflict (code) do nothing;

create or replace function _talent_setting(p_key text, p_default numeric) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select value from talent_score_settings where key = p_key), p_default)
$$;
revoke all on function _talent_setting(text, numeric) from public, anon, authenticated;

-- ============================================================ RPC
create or replace function talent_rules_public() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label, 'description', r.description, 'points', r.points,
      'cap_per_day', r.cap_per_day, 'cap_per_period', r.cap_per_period, 'quality_weight', r.quality_weight, 'version', r.version) order by r.label)
    from talent_score_rules r where r.active and r.points > 0), '[]'::jsonb);
end $$;

create or replace function admin_talent_rules_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.rules') then raise exception 'Réservé : exige la permission ranking.rules'; end if;
  return jsonb_build_object(
    'rules', coalesce((select jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label, 'description', r.description, 'points', r.points, 'cap_per_day', r.cap_per_day,
        'cap_per_period', r.cap_per_period, 'quality_weight', r.quality_weight, 'active', r.active, 'version', r.version, 'updated_at', r.updated_at) order by r.label) from talent_score_rules r), '[]'::jsonb),
    'settings', coalesce((select jsonb_object_agg(s.key, s.value) from talent_score_settings s), '{}'::jsonb));
end $$;

create or replace function admin_talent_rule_set(p_code text, p_points integer, p_cap_day integer, p_cap_period integer, p_quality_weight numeric, p_active boolean, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r talent_score_rules; v_reason text := btrim(coalesce(p_reason, ''));
begin
  perform _top100_admin('ranking.rules');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez le changement en 10 à 500 caractères'; end if;
  select * into r from talent_score_rules where code = p_code for update;
  if r.code is null then raise exception 'Règle inconnue'; end if;
  if p_points is null or p_points not between 0 and 1000 then raise exception 'Points : entre 0 et 1000'; end if;
  if coalesce(p_cap_day, 0) < 0 or coalesce(p_cap_period, 0) < 0 then raise exception 'Plafond négatif refusé'; end if;
  if p_quality_weight is null or p_quality_weight not between 0 and 1 then raise exception 'Poids qualité : entre 0 et 1'; end if;
  if coalesce(p_active, false) and p_points = 0 then raise exception 'Une règle active doit rapporter au moins 1 point'; end if;
  perform set_config('app.talent_rule_reason', v_reason, true);
  update talent_score_rules set points = p_points, cap_per_day = p_cap_day, cap_per_period = p_cap_period, quality_weight = p_quality_weight, active = coalesce(p_active, false), updated_by = auth.uid()
    where code = p_code returning * into r;
  perform set_config('app.talent_rule_reason', '', true);
  perform _top100_audit('Règle de score modifiée : ' || p_code || ' v' || r.version, p_code);
  return jsonb_build_object('ok', true, 'code', r.code, 'version', r.version, 'points', r.points, 'active', r.active);
end $$;

create or replace function admin_talent_rule_history(p_code text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.rules') then raise exception 'Réservé : exige la permission ranking.rules'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('code', h.code, 'version', h.version, 'points', h.points, 'cap_per_day', h.cap_per_day, 'cap_per_period', h.cap_per_period,
      'quality_weight', h.quality_weight, 'active', h.active, 'reason', h.reason, 'changed_at', h.changed_at, 'changed_by', (select name from profiles where id = h.changed_by)) order by h.id desc)
    from (select * from talent_score_rule_history where p_code is null or code = p_code order by id desc limit 200) h), '[]'::jsonb);
end $$;

create or replace function admin_talent_setting_set(p_key text, p_value numeric, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, ''));
begin
  perform _top100_admin('ranking.rules');
  if p_key is null or p_key not in ('min_cohort', 'burst_count', 'burst_minutes') then raise exception 'Paramètre inconnu'; end if;
  if p_value is null or p_value <= 0 or p_value > 100000 then raise exception 'Valeur invalide'; end if;
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez le changement en 10 à 500 caractères'; end if;
  insert into talent_score_settings (key, value, updated_by) values (p_key, p_value, auth.uid())
  on conflict (key) do update set value = excluded.value, updated_by = auth.uid(), updated_at = now();
  perform _top100_audit('Paramètre de score modifié : ' || p_key || ' = ' || p_value, v_reason);
  return jsonb_build_object('ok', true, 'key', p_key, 'value', p_value);
end $$;

revoke all on function talent_rules_public(), admin_talent_rules_list(), admin_talent_rule_set(text, integer, integer, integer, numeric, boolean, text),
  admin_talent_rule_history(text), admin_talent_setting_set(text, numeric, text) from public, anon;
grant execute on function talent_rules_public(), admin_talent_rules_list(), admin_talent_rule_set(text, integer, integer, integer, numeric, boolean, text),
  admin_talent_rule_history(text), admin_talent_setting_set(text, numeric, text) to authenticated;
