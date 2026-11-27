-- Lot H13 / RANKING (5/5) : durcissement anti-fraude configurable, délai de contestation, ordre de publication.
--  1. Paramètres techniques ajoutés (talent_score_settings, valeurs de repli codées, jamais insérées par la migration) : attendance_grace_minutes (15), attendance_default_hours (4),
--     attendance_max_failures (5), attendance_lock_minutes (10) [présence aux événements, 20261128010000], event_min_notice_minutes (30), dispute_days (60).
--     La contrainte des clés est ÉLARGIE (rien n'est retiré) et admin_talent_setting_set les accepte avec des bornes ; admin_talent_rules_list expose en plus « effective » (valeur en vigueur, repli compris).
--  2. _talent_precheck (remplace la version de 20261127010300, tout son contrôle est conservé) ajoute : événement suspect (une présence à un événement créé moins de event_min_notice_minutes avant son début est
--     NEUTRALISÉE : 0 point, alerte, réversible par un humain) ; la répétition d'un même auteur sur 30 jours (actor_repeat) couvre aussi les missions validées et les certificats émis (en plus des ventes et avis).
--  3. Contestation : talent_score_dispute_open refuse une activité plus ancienne que dispute_days (60 par défaut) depuis son dernier changement de statut (ou sa création).
--  4. Ordre de publication : _ranking_blockers refuse la publication d'un mois si un classement PLUS RÉCENT est déjà publié (l'historique et les deltas restent reproductibles ; un mois ne s'insère pas après coup).
-- Additive et rejouable. Retour arrière : remettre _talent_precheck et admin_talent_setting_set (20261127010300), _ranking_blockers (20261127020000), talent_score_dispute_open (20261127010300), admin_talent_rules_list (20261127010100) ;
--   alter table talent_score_settings drop constraint talent_score_settings_key_check_v3 (puis recréer la contrainte v2 de 20261127010300).

-- ============================================================ 1. Paramètres
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'talent_score_settings'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%min_cohort%' and conname <> 'talent_score_settings_key_check_v3' loop
    execute format('alter table talent_score_settings drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'talent_score_settings_key_check_v3') then
    alter table talent_score_settings add constraint talent_score_settings_key_check_v3 check (key in ('min_cohort', 'burst_count', 'burst_minutes', 'actor_repeat',
      'attendance_grace_minutes', 'attendance_default_hours', 'attendance_max_failures', 'attendance_lock_minutes', 'event_min_notice_minutes', 'dispute_days'));
  end if;
end $$;

create or replace function _talent_setting_defaults() returns jsonb
language sql immutable set search_path = public as $$
  select jsonb_build_object('min_cohort', 5, 'burst_count', 10, 'burst_minutes', 10, 'actor_repeat', 3, 'attendance_grace_minutes', 15, 'attendance_default_hours', 4,
    'attendance_max_failures', 5, 'attendance_lock_minutes', 10, 'event_min_notice_minutes', 30, 'dispute_days', 60)
$$;
revoke all on function _talent_setting_defaults() from public, anon, authenticated;

create or replace function admin_talent_setting_set(p_key text, p_value numeric, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); v_max numeric;
begin
  perform _top100_admin('ranking.rules');
  if p_key is null or not (_talent_setting_defaults() ? p_key) then raise exception 'Paramètre inconnu'; end if;
  v_max := case p_key when 'attendance_grace_minutes' then 240 when 'attendance_default_hours' then 48 when 'attendance_max_failures' then 50 when 'attendance_lock_minutes' then 1440 when 'dispute_days' then 365 else 100000 end;
  if p_value is null or p_value <= 0 or p_value > v_max then raise exception 'Valeur invalide (de 1 à %)', v_max; end if;
  if p_key <> 'burst_minutes' and p_value <> trunc(p_value) then raise exception 'Valeur invalide : un nombre entier est attendu'; end if;
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez le changement en 10 à 500 caractères'; end if;
  insert into talent_score_settings (key, value, updated_by) values (p_key, p_value, auth.uid())
  on conflict (key) do update set value = excluded.value, updated_by = auth.uid(), updated_at = now();
  perform _top100_audit('Paramètre de score modifié : ' || p_key || ' = ' || p_value, v_reason);
  return jsonb_build_object('ok', true, 'key', p_key, 'value', p_value);
end $$;

create or replace function admin_talent_rules_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.rules') then raise exception 'Réservé : exige la permission ranking.rules'; end if;
  return jsonb_build_object(
    'rules', coalesce((select jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label, 'description', r.description, 'points', r.points, 'cap_per_day', r.cap_per_day,
        'cap_per_period', r.cap_per_period, 'quality_weight', r.quality_weight, 'active', r.active, 'version', r.version, 'updated_at', r.updated_at) order by r.label) from talent_score_rules r), '[]'::jsonb),
    'settings', coalesce((select jsonb_object_agg(s.key, s.value) from talent_score_settings s), '{}'::jsonb),
    'effective', (select jsonb_object_agg(d.key, coalesce(s.value, d.value::text::numeric)) from jsonb_each(_talent_setting_defaults()) d left join talent_score_settings s on s.key = d.key));
end $$;

-- ============================================================ 2. Contrôle avant comptage durci
create or replace function _talent_precheck(p_user uuid, p_rule text, p_kind text, p_source text, p_actor uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_burst integer := _talent_setting('burst_count', 10)::integer; v_minutes numeric := _talent_setting('burst_minutes', 10);
        v_repeat integer := _talent_setting('actor_repeat', 3)::integer; v_notice integer := _talent_setting('event_min_notice_minutes', 30)::integer; n integer; ev events;
begin
  if p_actor is not null then
    if p_actor = p_user then return 'Auto-interaction : le bénéficiaire est aussi l''auteur de l''action'; end if;
    if exists (select 1 from profiles a join profiles b on b.id = p_user where a.id = p_actor
               and ((nullif(btrim(a.matricule), '') is not null and lower(btrim(a.matricule)) = lower(btrim(b.matricule)))
                    or (a.email is not null and b.email is not null and _talent_email_key(a.email) = _talent_email_key(b.email)))) then
      return 'Comptes liés : même matricule ou même adresse e-mail (à l''alias près) que l''auteur de l''action';
    end if;
    if p_rule in ('sale_confirmed', 'review_verified', 'mission_validated', 'certificate_verified') then
      select count(*) into n from talent_events
        where user_id = p_user and actor_id = p_actor and rule_code = p_rule and status = 'confirmed' and created_at > now() - interval '30 days'
          and not (source_kind = p_kind and source_id = p_source);
      if n >= v_repeat then return 'Répétition suspecte : même auteur, ' || (n + 1) || ' activités en 30 jours'; end if;
    end if;
  end if;
  if p_rule = 'event_attended' then
    select e.* into ev from events e where e.id::text = split_part(p_source, ':', 1);
    if ev.id is not null and ev.created_at > ev.starts_at - make_interval(mins => v_notice) then
      return 'Événement suspect : créé moins de ' || v_notice || ' minutes avant son début';
    end if;
  end if;
  select count(*) into n from talent_events
    where user_id = p_user and status <> 'cancelled' and created_at > now() - make_interval(secs => v_minutes * 60)
      and not (rule_code = p_rule and source_kind = p_kind and source_id = p_source);
  if n >= v_burst then return 'Rafale d''activités anormale : ' || (n + 1) || ' activités en ' || v_minutes::integer || ' minutes'; end if;
  return null;
end $$;
revoke all on function _talent_precheck(uuid, text, text, text, uuid) from public, anon, authenticated;

-- ============================================================ 3. Contestation : délai
create or replace function talent_score_dispute_open(p_event bigint, p_message text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_msg text := btrim(coalesce(p_message, '')); e talent_events; v_id uuid; v_days integer := _talent_setting('dispute_days', 60)::integer;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  if char_length(v_msg) not between 10 and 1000 then raise exception 'Expliquez votre contestation en 10 à 1000 caractères'; end if;
  select * into e from talent_events where id = p_event and user_id = v_uid;
  if e.id is null then raise exception 'Activité introuvable'; end if;
  if coalesce(e.status_changed_at, e.created_at) < now() - make_interval(days => v_days) then raise exception 'Le délai de contestation (% jours) est dépassé pour cette activité', v_days; end if;
  if (select count(*) from talent_score_disputes where user_id = v_uid and status = 'open') >= 5 then raise exception 'Vous avez déjà 5 contestations en cours'; end if;
  begin
    insert into talent_score_disputes (user_id, event_id, message) values (v_uid, e.id, v_msg) returning id into v_id;
  exception when unique_violation then raise exception 'Une contestation est déjà en cours pour cette activité';
  end;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', 'open');
end $$;

-- ============================================================ 4. Ordre de publication
create or replace function _ranking_blockers(p_period text) returns text[]
language plpgsql stable security definer set search_path = public as $$
declare s ranking_settings; v text[] := '{}';
begin
  if p_period is null or not _ranking_period_ok(p_period) then return array['Période invalide ou future (format AAAA-MM, au plus le mois en cours)']; end if;
  select * into s from ranking_settings where id;
  if s.id is null or s.min_score is null or s.entries_limit is null or cardinality(s.scopes) = 0 then
    v := array_append(v, 'Réglages du classement non décidés (seuil minimal, nombre d''entrées, portées)');
  end if;
  if not exists (select 1 from talent_score_rules where active and points > 0) then v := array_append(v, 'Aucune règle de score active'); end if;
  if exists (select 1 from ranking_periods where period = p_period) then v := array_append(v, 'Ce mois est déjà publié : une publication ne change plus'); end if;
  if exists (select 1 from ranking_periods where period > p_period) then v := array_append(v, 'Un classement plus récent est déjà publié : les mois se publient dans l''ordre'); end if;
  return v;
end $$;
revoke all on function _ranking_blockers(text) from public, anon, authenticated;

revoke all on function admin_talent_setting_set(text, numeric, text), admin_talent_rules_list(), talent_score_dispute_open(bigint, text) from public, anon;
grant execute on function admin_talent_setting_set(text, numeric, text), admin_talent_rules_list(), talent_score_dispute_open(bigint, text) to authenticated;
