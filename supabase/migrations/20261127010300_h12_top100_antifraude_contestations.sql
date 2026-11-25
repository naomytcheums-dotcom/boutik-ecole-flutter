-- Lot H12 / TOP100-A (4/4) : anti-fraude, modération et contestations du score de talent (CDC Top 100, 1.3 et 9).
--  1. Contrôle avant comptage (_talent_precheck, remplace la version minimale de 20261127010200) : une activité est NEUTRALISÉE (0 point, tracée, réversible par un humain) si
--     a) le bénéficiaire est l'auteur de l'action (auto-interaction) ;
--     b) l'auteur de l'action et le bénéficiaire partagent le même matricule ou la même adresse e-mail à l'alias près (comptes liés ; le téléphone est déjà unique par compte) ;
--     c) un même auteur a déjà généré « actor_repeat » avis ou ventes (défaut 3) pour ce bénéficiaire sur 30 jours (achats fictifs, faux avis en série) ;
--     d) le bénéficiaire cumule « burst_count » activités en « burst_minutes » minutes (défauts 10 et 10) : rafale d'allure automatisée.
--     Chaque neutralisation automatique ouvre une alerte (talent_fraud_flags) pour la modération. Seules les activités RÉELLES de la plateforme comptent : vues et likes n'ont pas de règle.
--  2. Modération (permission ranking.moderate, 2FA si facteur vérifié, motif obligatoire, audit) : admin_talent_flags_list, admin_talent_event_neutralize, admin_talent_event_restore.
--  3. Contestation : l'étudiant ouvre une contestation sur une de ses activités (talent_score_dispute_open, une ouverte par activité, 5 ouvertes au plus) et suit sa décision
--     (my_talent_disputes) ; la modération tranche (admin_talent_disputes_list, admin_talent_dispute_decide) : « accepted » rétablit une activité neutralisée et attribue les points sous
--     les règles en vigueur, « rejected » exige une réponse motivée. my_talent_events liste ses activités (identifiants à contester).
--  4. Nouveau paramètre technique « actor_repeat » : la contrainte des clés est ÉLARGIE et admin_talent_setting_set l'accepte (rien n'est retiré).
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière :
--   drop trigger trg_talent_event_flag on talent_events ; drop function _talent_email_key(text), _talent_event_flag(), my_talent_events(text, integer), talent_score_dispute_open(bigint, text), my_talent_disputes(),
--     admin_talent_flags_list(text, integer), admin_talent_event_neutralize(bigint, text), admin_talent_event_restore(bigint, text), admin_talent_disputes_list(text, integer),
--     admin_talent_dispute_decide(uuid, text, text), _talent_restore(bigint, uuid, text) ; drop table talent_score_disputes, talent_fraud_flags ;
--   remettre _talent_precheck de 20261127010200 (auto-interaction seule) et admin_talent_setting_set de 20261127010100.

-- ============================================================ 1. Paramètre élargi
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'talent_score_settings'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%min_cohort%' and conname not like '%v2' loop
    execute format('alter table talent_score_settings drop constraint %I', c.conname);
  end loop;
  if not exists (select 1 from pg_constraint where conname = 'talent_score_settings_key_check_v2') then
    alter table talent_score_settings add constraint talent_score_settings_key_check_v2 check (key in ('min_cohort', 'burst_count', 'burst_minutes', 'actor_repeat'));
  end if;
end $$;

create or replace function admin_talent_setting_set(p_key text, p_value numeric, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, ''));
begin
  perform _top100_admin('ranking.rules');
  if p_key is null or p_key not in ('min_cohort', 'burst_count', 'burst_minutes', 'actor_repeat') then raise exception 'Paramètre inconnu'; end if;
  if p_value is null or p_value <= 0 or p_value > 100000 then raise exception 'Valeur invalide'; end if;
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez le changement en 10 à 500 caractères'; end if;
  insert into talent_score_settings (key, value, updated_by) values (p_key, p_value, auth.uid())
  on conflict (key) do update set value = excluded.value, updated_by = auth.uid(), updated_at = now();
  perform _top100_audit('Paramètre de score modifié : ' || p_key || ' = ' || p_value, v_reason);
  return jsonb_build_object('ok', true, 'key', p_key, 'value', p_value);
end $$;

-- ============================================================ 2. Tables
create table if not exists talent_fraud_flags (
  id uuid primary key default gen_random_uuid(),
  event_id bigint not null references talent_events (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  signal text not null check (signal in ('self_dealing', 'linked_accounts', 'repeat_actor', 'burst', 'moderation', 'other')),
  detail text check (detail is null or char_length(detail) <= 300),
  detected_by text not null default 'auto' check (detected_by in ('auto', 'moderator')),
  status text not null default 'open' check (status in ('open', 'confirmed', 'dismissed')),
  created_at timestamptz not null default now(),
  decided_by uuid references profiles (id) on delete set null,
  decided_at timestamptz,
  decision_note text check (decision_note is null or char_length(decision_note) <= 500)
);
create index if not exists talent_fraud_flags_status on talent_fraud_flags (status, created_at);
create index if not exists talent_fraud_flags_event on talent_fraud_flags (event_id);

create table if not exists talent_score_disputes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  event_id bigint not null references talent_events (id) on delete cascade,
  message text not null check (char_length(btrim(message)) between 10 and 1000),
  status text not null default 'open' check (status in ('open', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  decided_by uuid references profiles (id) on delete set null,
  decided_at timestamptz,
  resolution text check (resolution is null or char_length(resolution) <= 1000)
);
create unique index if not exists talent_score_disputes_one_open on talent_score_disputes (event_id) where status = 'open';
create index if not exists talent_score_disputes_user on talent_score_disputes (user_id, created_at desc);

alter table talent_fraud_flags enable row level security;
alter table talent_score_disputes enable row level security;
revoke all on talent_fraud_flags, talent_score_disputes from public, anon, authenticated;

-- ============================================================ 3. Contrôle avant comptage
-- Clé d'adresse e-mail sans alias : casse, points et « +étiquette » ignorés dans la partie locale.
create or replace function _talent_email_key(p_email text) returns text
language sql immutable set search_path = public as $$
  select lower(replace(split_part(split_part(btrim(p_email), '@', 1), '+', 1), '.', '') || '@' || split_part(btrim(p_email), '@', 2))
$$;
revoke all on function _talent_email_key(text) from public, anon, authenticated;

create or replace function _talent_precheck(p_user uuid, p_rule text, p_kind text, p_source text, p_actor uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_burst integer := _talent_setting('burst_count', 10)::integer; v_minutes numeric := _talent_setting('burst_minutes', 10);
        v_repeat integer := _talent_setting('actor_repeat', 3)::integer; n integer;
begin
  if p_actor is not null then
    if p_actor = p_user then return 'Auto-interaction : le bénéficiaire est aussi l''auteur de l''action'; end if;
    if exists (select 1 from profiles a join profiles b on b.id = p_user where a.id = p_actor
               and ((nullif(btrim(a.matricule), '') is not null and lower(btrim(a.matricule)) = lower(btrim(b.matricule)))
                    or (a.email is not null and b.email is not null and _talent_email_key(a.email) = _talent_email_key(b.email)))) then
      return 'Comptes liés : même matricule ou même adresse e-mail (à l''alias près) que l''auteur de l''action';
    end if;
    if p_rule in ('sale_confirmed', 'review_verified') then
      select count(*) into n from talent_events
        where user_id = p_user and actor_id = p_actor and rule_code = p_rule and status = 'confirmed' and created_at > now() - interval '30 days'
          and not (source_kind = p_kind and source_id = p_source);
      if n >= v_repeat then return 'Répétition suspecte : même auteur, ' || (n + 1) || ' activités en 30 jours'; end if;
    end if;
  end if;
  select count(*) into n from talent_events
    where user_id = p_user and status <> 'cancelled' and created_at > now() - make_interval(secs => v_minutes * 60)
      and not (rule_code = p_rule and source_kind = p_kind and source_id = p_source);
  if n >= v_burst then return 'Rafale d''activités anormale : ' || (n + 1) || ' activités en ' || v_minutes::integer || ' minutes'; end if;
  return null;
end $$;
revoke all on function _talent_precheck(uuid, text, text, text, uuid) from public, anon, authenticated;

create or replace function _talent_event_flag() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'neutralized' and (tg_op = 'INSERT' or old.status is distinct from 'neutralized') and coalesce(current_setting('app.talent_manual', true), '') <> 'on' then
    insert into talent_fraud_flags (event_id, user_id, signal, detail)
    values (new.id, new.user_id,
      case when new.status_reason like 'Auto-interaction%' then 'self_dealing' when new.status_reason like 'Comptes liés%' then 'linked_accounts'
           when new.status_reason like 'Répétition%' then 'repeat_actor' when new.status_reason like 'Rafale%' then 'burst' else 'other' end,
      left(new.status_reason, 300));
  end if;
  return new;
end $$;
revoke all on function _talent_event_flag() from public, anon, authenticated;
drop trigger if exists trg_talent_event_flag on talent_events;
create trigger trg_talent_event_flag after insert or update of status on talent_events for each row execute function _talent_event_flag();

-- Rétablit une activité neutralisée : décision humaine, points attribués sous les règles en vigueur.
create or replace function _talent_restore(p_event bigint, p_by uuid, p_note text) returns integer
language plpgsql security definer set search_path = public as $$
declare e talent_events;
begin
  select * into e from talent_events where id = p_event for update;
  if e.id is null or e.status <> 'neutralized' then raise exception 'Seule une activité neutralisée peut être rétablie'; end if;
  update talent_events set status = 'confirmed', status_reason = null, status_changed_at = now() where id = e.id;
  update talent_fraud_flags set status = 'dismissed', decided_by = p_by, decided_at = now(), decision_note = left(p_note, 500) where event_id = e.id and status in ('open', 'confirmed');
  return _talent_award(e.id);
end $$;
revoke all on function _talent_restore(bigint, uuid, text) from public, anon, authenticated;

-- ============================================================ 4. RPC : modération
create or replace function admin_talent_flags_list(p_status text default 'open', p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.moderate') then raise exception 'Réservé : exige la permission ranking.moderate'; end if;
  if p_status is not null and p_status not in ('open', 'confirmed', 'dismissed') then raise exception 'Statut inconnu'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'event_id', f.event_id, 'user_id', f.user_id, 'student', display_name(f.user_id), 'signal', f.signal, 'detail', f.detail,
      'detected_by', f.detected_by, 'status', f.status, 'rule', e.rule_code, 'source_kind', e.source_kind, 'created_at', f.created_at, 'decided_at', f.decided_at, 'decision_note', f.decision_note) order by f.created_at desc)
    from (select * from talent_fraud_flags where p_status is null or status = p_status order by created_at desc limit least(greatest(coalesce(p_limit, 100), 1), 500)) f
    join talent_events e on e.id = f.event_id), '[]'::jsonb);
end $$;

create or replace function admin_talent_event_neutralize(p_event bigint, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); e talent_events; v_back integer;
begin
  perform _top100_admin('ranking.moderate');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez la neutralisation en 10 à 500 caractères'; end if;
  select * into e from talent_events where id = p_event;
  if e.id is null then raise exception 'Activité introuvable'; end if;
  if e.status <> 'confirmed' then raise exception 'Seule une activité confirmée peut être neutralisée'; end if;
  perform set_config('app.talent_manual', 'on', true);
  v_back := _talent_reverse(e.id, 'neutralized', 'Modération : ' || v_reason);
  perform set_config('app.talent_manual', '', true);
  insert into talent_fraud_flags (event_id, user_id, signal, detail, detected_by, status, decided_by, decided_at, decision_note)
  values (e.id, e.user_id, 'moderation', left(v_reason, 300), 'moderator', 'confirmed', auth.uid(), now(), left(v_reason, 500));
  perform _top100_audit('Activité de score neutralisée : ' || e.id, v_reason);
  perform notify_user(e.user_id, 'profile', 'Une activité n''est plus comptée dans votre score', 'Elle a été neutralisée après vérification. Vous pouvez la contester depuis votre score.', jsonb_build_object('event', e.id));
  return jsonb_build_object('ok', true, 'event', e.id, 'points_removed', v_back, 'status', 'neutralized');
end $$;

create or replace function admin_talent_event_restore(p_event bigint, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); e talent_events; v_pts integer;
begin
  perform _top100_admin('ranking.moderate');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez le rétablissement en 10 à 500 caractères'; end if;
  select * into e from talent_events where id = p_event;
  if e.id is null then raise exception 'Activité introuvable'; end if;
  v_pts := _talent_restore(e.id, auth.uid(), v_reason);
  perform _top100_audit('Activité de score rétablie : ' || e.id, v_reason);
  perform notify_user(e.user_id, 'profile', 'Une activité est de nouveau comptée dans votre score', left(v_reason, 300), jsonb_build_object('event', e.id, 'points', v_pts));
  return jsonb_build_object('ok', true, 'event', e.id, 'points_added', v_pts, 'status', 'confirmed');
end $$;

-- ============================================================ 5. RPC : activités et contestations
create or replace function my_talent_events(p_status text default null, p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  if p_status is not null and p_status not in ('confirmed', 'cancelled', 'neutralized') then raise exception 'Statut inconnu'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'at', e.occurred_at, 'rule', e.rule_code, 'label', r.label, 'status', e.status,
      'points', coalesce((select sum(l.points) from talent_score_ledger l where l.event_id = e.id), 0),
      'reason', case e.status when 'neutralized' then 'Non comptabilisée après vérification : vous pouvez contester.' when 'cancelled' then e.status_reason else null end,
      'open_dispute', exists (select 1 from talent_score_disputes d where d.event_id = e.id and d.status = 'open')) order by e.id desc)
    from (select * from talent_events where user_id = v_uid and (p_status is null or status = p_status) order by id desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) e
    join talent_score_rules r on r.code = e.rule_code), '[]'::jsonb);
end $$;

create or replace function talent_score_dispute_open(p_event bigint, p_message text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_msg text := btrim(coalesce(p_message, '')); e talent_events; v_id uuid;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  if char_length(v_msg) not between 10 and 1000 then raise exception 'Expliquez votre contestation en 10 à 1000 caractères'; end if;
  select * into e from talent_events where id = p_event and user_id = v_uid;
  if e.id is null then raise exception 'Activité introuvable'; end if;
  if (select count(*) from talent_score_disputes where user_id = v_uid and status = 'open') >= 5 then raise exception 'Vous avez déjà 5 contestations en cours'; end if;
  begin
    insert into talent_score_disputes (user_id, event_id, message) values (v_uid, e.id, v_msg) returning id into v_id;
  exception when unique_violation then raise exception 'Une contestation est déjà en cours pour cette activité';
  end;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', 'open');
end $$;

create or replace function my_talent_disputes() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'event_id', d.event_id, 'rule', e.rule_code, 'label', r.label, 'message', d.message, 'status', d.status,
      'created_at', d.created_at, 'decided_at', d.decided_at, 'resolution', d.resolution) order by d.created_at desc)
    from talent_score_disputes d join talent_events e on e.id = d.event_id join talent_score_rules r on r.code = e.rule_code where d.user_id = auth.uid()), '[]'::jsonb);
end $$;

create or replace function admin_talent_disputes_list(p_status text default 'open', p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.moderate') then raise exception 'Réservé : exige la permission ranking.moderate'; end if;
  if p_status is not null and p_status not in ('open', 'accepted', 'rejected') then raise exception 'Statut inconnu'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'event_id', d.event_id, 'user_id', d.user_id, 'student', display_name(d.user_id), 'rule', e.rule_code,
      'event_status', e.status, 'event_reason', e.status_reason, 'message', d.message, 'status', d.status, 'created_at', d.created_at, 'resolution', d.resolution) order by d.created_at)
    from (select * from talent_score_disputes where p_status is null or status = p_status order by created_at limit least(greatest(coalesce(p_limit, 100), 1), 500)) d
    join talent_events e on e.id = d.event_id), '[]'::jsonb);
end $$;

create or replace function admin_talent_dispute_decide(p_id uuid, p_decision text, p_note text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_note text := btrim(coalesce(p_note, '')); d talent_score_disputes; e talent_events; v_pts integer := 0;
begin
  perform _top100_admin('ranking.moderate');
  if p_decision is null or p_decision not in ('accepted', 'rejected') then raise exception 'Décision inconnue (accepted ou rejected)'; end if;
  if char_length(v_note) not between 10 and 1000 then raise exception 'Motivez la décision en 10 à 1000 caractères'; end if;
  select * into d from talent_score_disputes where id = p_id for update;
  if d.id is null then raise exception 'Contestation introuvable'; end if;
  if d.status <> 'open' then raise exception 'Cette contestation a déjà été traitée'; end if;
  if d.user_id = auth.uid() then raise exception 'Vous ne pouvez pas traiter votre propre contestation'; end if;
  select * into e from talent_events where id = d.event_id;
  if p_decision = 'accepted' and e.status = 'neutralized' then v_pts := _talent_restore(e.id, auth.uid(), v_note); end if;
  update talent_score_disputes set status = p_decision, decided_by = auth.uid(), decided_at = now(), resolution = left(v_note, 1000) where id = d.id;
  perform _top100_audit('Contestation de score : ' || p_decision, d.id::text, 'Info');
  perform notify_user(d.user_id, 'profile', case p_decision when 'accepted' then 'Votre contestation de score est acceptée' else 'Votre contestation de score est refusée' end, left(v_note, 300),
    jsonb_build_object('dispute', d.id, 'event', d.event_id, 'status', p_decision));
  return jsonb_build_object('ok', true, 'id', d.id, 'status', p_decision, 'event_restored', p_decision = 'accepted' and e.status = 'neutralized', 'points_added', v_pts);
end $$;

revoke all on function my_talent_events(text, integer), talent_score_dispute_open(bigint, text), my_talent_disputes(), admin_talent_flags_list(text, integer), admin_talent_event_neutralize(bigint, text),
  admin_talent_event_restore(bigint, text), admin_talent_disputes_list(text, integer), admin_talent_dispute_decide(uuid, text, text), admin_talent_setting_set(text, numeric, text) from public, anon;
grant execute on function my_talent_events(text, integer), talent_score_dispute_open(bigint, text), my_talent_disputes(), admin_talent_flags_list(text, integer), admin_talent_event_neutralize(bigint, text),
  admin_talent_event_restore(bigint, text), admin_talent_disputes_list(text, integer), admin_talent_dispute_decide(uuid, text, text), admin_talent_setting_set(text, numeric, text) to authenticated;
