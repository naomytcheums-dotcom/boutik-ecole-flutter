-- Lot H12 / TOP100-A (3/4) : événements d'activité, registre de points, score et normalisation par filière (CDC Top 100, 1.3, 1.4 et 9).
--  1. talent_events : UNE ligne par activité traçable (règle + origine + identifiant d'origine, unique) ; statuts confirmed / cancelled / neutralized ;
--     talent_score_ledger : registre de points en ajout seul (attribution ou annulation, version de règle, solde après), jamais modifié ni supprimé ;
--     talent_scores : total courant par étudiant, toujours égal à la somme du registre.
--  2. Les points viennent UNIQUEMENT des règles serveur (talent_score_rules, 010100) : une règle inactive ou à 0 point n'attribue rien (l'événement reste tracé) ;
--     points_attribués = points * ((1 - w) + w * qualité) ramené aux plafonds par jour UTC et par mois de la règle ; une qualité non mesurée compte 0 pour la part « qualité ».
--     Un événement n'est compté qu'une fois ; une activité annulée / remboursée / révoquée retire exactement les points attribués (écriture d'annulation) ;
--     une activité neutralisée (fraude) n'attribue rien. Les vues et les likes n'ont aucune règle : aucun événement possible.
--  3. Collecte par déclencheurs (jamais bloquants : une erreur de collecte n'empêche pas l'opération d'origine) : vente confirmée (commande payée, non annulée, remise confirmée,
--     non remboursée en totalité), avis lié à un achat réel, mission validée (tous les jalons validés), certificat émis et non révoqué, participation à un challenge,
--     évaluation validée par un humain, projet approuvé avec preuves. Les familles dont la source arrive dans des migrations ultérieures (replay, badge, live, atelier,
--     compétence, collaboration) s'alimentent par _talent_event_record (serveur uniquement).
--  4. Normalisation : _talent_percentiles = rang centile de l'étudiant dans sa filière, son établissement et au niveau national parmi les étudiants au rattachement
--     VÉRIFIÉ ; centile nul (« cohorte insuffisante ») sous le paramètre min_cohort. Aucun classement n'est publié ici.
--  5. RPC : my_talent_score_explain, my_talent_dashboard (étudiant), admin_talent_recompute, admin_talent_events_list (permission ranking.moderate).
-- Aucune donnée n'est insérée. Additive et rejouable. Retour arrière :
--   drop trigger trg_talent_* sur orders, order_lines, order_refunds, reviews, mission_milestones, missions, mission_agreements, certificates, challenge_entries, assessment_results, projects ;
--   drop function my_talent_score_explain(integer), my_talent_dashboard(), admin_talent_recompute(uuid, text), admin_talent_events_list(uuid, integer), _talent_percentiles(uuid),
--     _talent_event_record(uuid, text, text, text, timestamptz, numeric, uuid, jsonb), _talent_event_cancel(text, text, text, text), _talent_award(bigint), _talent_reverse(bigint, text, text),
--     _talent_ledger_add(bigint, uuid, text, integer, text, integer, text), _talent_precheck(uuid, text, text, text, uuid), _talent_is_student(uuid), _talent_sync_order(uuid), _talent_sync_mission(uuid), _talent_trg_*() ;
--   drop table talent_score_ledger, talent_scores, talent_events.

-- ============================================================ 1. Tables
create table if not exists talent_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  rule_code text not null references talent_score_rules (code),
  source_kind text not null check (source_kind ~ '^[a-z_]{2,40}$'),
  source_id text not null check (char_length(source_id) between 1 and 80),
  occurred_at timestamptz not null default now(),
  quality numeric(4, 3) check (quality is null or quality between 0 and 1),
  actor_id uuid references profiles (id) on delete set null,
  meta jsonb not null default '{}'::jsonb,
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled', 'neutralized')),
  status_reason text check (status_reason is null or char_length(status_reason) <= 300),
  status_changed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (rule_code, source_kind, source_id)
);
create index if not exists talent_events_user on talent_events (user_id, id desc);
create index if not exists talent_events_status on talent_events (user_id, status);

create table if not exists talent_score_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references profiles (id) on delete cascade,
  event_id bigint not null references talent_events (id) on delete cascade,
  revision integer not null check (revision >= 1),
  rule_code text not null,
  rule_version integer not null,
  kind text not null check (kind in ('award', 'reversal')),
  points integer not null check (points <> 0 and ((kind = 'award' and points > 0) or (kind = 'reversal' and points < 0))),
  balance_after integer not null check (balance_after >= 0),
  period text not null check (period ~ '^[0-9]{4}-[0-9]{2}$'),
  reason text check (reason is null or char_length(reason) <= 300),
  created_at timestamptz not null default now(),
  unique (event_id, revision)
);
create index if not exists talent_score_ledger_user on talent_score_ledger (user_id, id desc);
create index if not exists talent_score_ledger_period on talent_score_ledger (period, user_id);
create index if not exists talent_score_ledger_rule_day on talent_score_ledger (user_id, rule_code, created_at) where kind = 'award';

create table if not exists talent_scores (
  user_id uuid primary key references profiles (id) on delete cascade,
  total integer not null default 0 check (total >= 0),
  updated_at timestamptz not null default now()
);

alter table talent_events enable row level security;
alter table talent_score_ledger enable row level security;
alter table talent_scores enable row level security;
revoke all on talent_events, talent_score_ledger, talent_scores from public, anon, authenticated;

-- Le registre et l'identité d'un événement ne se modifient jamais ; seul le statut avance, via les fonctions du moteur. Suppression directe interdite (la cascade d'un compte supprimé reste possible).
create or replace function _talent_ledger_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then raise exception 'Le registre de points est en ajout seul'; end if;
  if tg_op = 'DELETE' and pg_trigger_depth() = 1 then
    if not exists (select 1 from profiles where id = old.user_id) then return old; end if;
    raise exception 'Le registre de points est en ajout seul';
  end if;
  return old;
end $$;
revoke all on function _talent_ledger_guard() from public, anon, authenticated;
drop trigger if exists trg_talent_ledger_guard on talent_score_ledger;
create trigger trg_talent_ledger_guard before update or delete on talent_score_ledger for each row execute function _talent_ledger_guard();

create or replace function _talent_event_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if not exists (select 1 from profiles where id = old.user_id) then return old; end if;
    raise exception 'Un événement de score ne se supprime pas : annulez-le';
  end if;
  if new.user_id is distinct from old.user_id or new.rule_code is distinct from old.rule_code or new.source_kind is distinct from old.source_kind
     or new.source_id is distinct from old.source_id or new.occurred_at is distinct from old.occurred_at then
    raise exception 'Un événement de score n''est pas modifiable';
  end if;
  return new;
end $$;
revoke all on function _talent_event_guard() from public, anon, authenticated;
drop trigger if exists trg_talent_event_guard on talent_events;
create trigger trg_talent_event_guard before update or delete on talent_events for each row execute function _talent_event_guard();

-- ============================================================ 2. Moteur
create or replace function _talent_is_student(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = p_user and role::text = 'student' and not coalesce(suspended, false))
$$;
revoke all on function _talent_is_student(uuid) from public, anon, authenticated;

-- Contrôle avant comptage : motif de neutralisation ou nul. Étendu par la migration anti-fraude (CREATE OR REPLACE).
create or replace function _talent_precheck(p_user uuid, p_rule text, p_kind text, p_source text, p_actor uuid) returns text
language plpgsql stable security definer set search_path = public as $$
begin
  if p_actor is not null and p_actor = p_user then return 'Auto-interaction : le bénéficiaire est aussi l''auteur de l''action'; end if;
  return null;
end $$;
revoke all on function _talent_precheck(uuid, text, text, text, uuid) from public, anon, authenticated;

create or replace function _talent_ledger_add(p_event bigint, p_user uuid, p_kind text, p_points integer, p_rule text, p_version integer, p_reason text) returns integer
language plpgsql security definer set search_path = public as $$
declare v_rev integer; v_total integer;
begin
  insert into talent_scores (user_id) values (p_user) on conflict (user_id) do nothing;
  select total into v_total from talent_scores where user_id = p_user for update;
  select coalesce(max(revision), 0) + 1 into v_rev from talent_score_ledger where event_id = p_event;
  v_total := v_total + p_points;
  insert into talent_score_ledger (user_id, event_id, revision, rule_code, rule_version, kind, points, balance_after, period, reason)
  values (p_user, p_event, v_rev, p_rule, p_version, p_kind, p_points, v_total, to_char(now() at time zone 'utc', 'YYYY-MM'), left(p_reason, 300));
  update talent_scores set total = v_total, updated_at = now() where user_id = p_user;
  return v_total;
end $$;
revoke all on function _talent_ledger_add(bigint, uuid, text, integer, text, integer, text) from public, anon, authenticated;

-- Attribue les points d'un événement confirmé, une seule fois. Renvoie les points écrits (0 : règle inactive, plafond atteint ou déjà attribué).
create or replace function _talent_award(p_event bigint) returns integer
language plpgsql security definer set search_path = public as $$
declare e talent_events; r talent_score_rules; v_net integer; v_pts integer; v_day integer; v_month integer; v_period text := to_char(now() at time zone 'utc', 'YYYY-MM');
begin
  select * into e from talent_events where id = p_event;
  if e.id is null or e.status <> 'confirmed' then return 0; end if;
  select * into r from talent_score_rules where code = e.rule_code;
  if r.code is null or not r.active or r.points <= 0 then return 0; end if;
  insert into talent_scores (user_id) values (e.user_id) on conflict (user_id) do nothing;
  perform 1 from talent_scores where user_id = e.user_id for update;
  select coalesce(sum(points), 0) into v_net from talent_score_ledger where event_id = e.id;
  if v_net > 0 then return 0; end if;
  v_pts := round(r.points * ((1 - r.quality_weight) + r.quality_weight * coalesce(e.quality, 0)))::integer;
  if r.cap_per_day is not null then
    select coalesce(sum(points), 0) into v_day from talent_score_ledger
      where user_id = e.user_id and rule_code = r.code and kind = 'award' and (created_at at time zone 'utc')::date = (now() at time zone 'utc')::date;
    v_pts := least(v_pts, greatest(r.cap_per_day - v_day, 0));
  end if;
  if r.cap_per_period is not null then
    select coalesce(sum(points), 0) into v_month from talent_score_ledger where user_id = e.user_id and rule_code = r.code and kind = 'award' and period = v_period;
    v_pts := least(v_pts, greatest(r.cap_per_period - v_month, 0));
  end if;
  if v_pts <= 0 then return 0; end if;
  perform _talent_ledger_add(e.id, e.user_id, 'award', v_pts, r.code, r.version, null);
  return v_pts;
end $$;
revoke all on function _talent_award(bigint) from public, anon, authenticated;

-- Retire exactement les points attribués à un événement et le passe à cancelled ou neutralized.
create or replace function _talent_reverse(p_event bigint, p_status text, p_reason text) returns integer
language plpgsql security definer set search_path = public as $$
declare e talent_events; v_net integer;
begin
  select * into e from talent_events where id = p_event for update;
  if e.id is null or e.status = p_status then return 0; end if;
  insert into talent_scores (user_id) values (e.user_id) on conflict (user_id) do nothing;
  perform 1 from talent_scores where user_id = e.user_id for update;
  select coalesce(sum(points), 0) into v_net from talent_score_ledger where event_id = e.id;
  if v_net > 0 then
    perform _talent_ledger_add(e.id, e.user_id, 'reversal', -v_net, e.rule_code, (select version from talent_score_rules where code = e.rule_code), p_reason);
  end if;
  update talent_events set status = p_status, status_reason = left(p_reason, 300), status_changed_at = now() where id = e.id;
  return v_net;
end $$;
revoke all on function _talent_reverse(bigint, text, text) from public, anon, authenticated;

create or replace function _talent_event_record(p_user uuid, p_rule text, p_kind text, p_source text, p_at timestamptz, p_quality numeric, p_actor uuid, p_meta jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_id bigint; e talent_events; v_block text;
begin
  if p_user is null or p_source is null or not _talent_is_student(p_user) then return null; end if;
  if not exists (select 1 from talent_score_rules where code = p_rule) then return null; end if;
  insert into talent_events (user_id, rule_code, source_kind, source_id, occurred_at, quality, actor_id, meta)
  values (p_user, p_rule, p_kind, p_source, coalesce(p_at, now()), p_quality, p_actor, coalesce(p_meta, '{}'::jsonb))
  on conflict (rule_code, source_kind, source_id) do nothing returning id into v_id;
  if v_id is null then
    select * into e from talent_events where rule_code = p_rule and source_kind = p_kind and source_id = p_source;
    if e.status = 'cancelled' and e.user_id = p_user then
      update talent_events set status = 'confirmed', status_reason = null, status_changed_at = now(), quality = coalesce(p_quality, quality) where id = e.id;
      v_id := e.id;
    else
      return e.id;
    end if;
  end if;
  v_block := _talent_precheck(p_user, p_rule, p_kind, p_source, p_actor);
  if v_block is not null then
    perform _talent_reverse(v_id, 'neutralized', v_block);
  else
    perform _talent_award(v_id);
  end if;
  return v_id;
end $$;
revoke all on function _talent_event_record(uuid, text, text, text, timestamptz, numeric, uuid, jsonb) from public, anon, authenticated;

create or replace function _talent_event_cancel(p_rule text, p_kind text, p_source text, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  select id into v_id from talent_events where rule_code = p_rule and source_kind = p_kind and source_id = p_source and status = 'confirmed';
  if v_id is not null then perform _talent_reverse(v_id, 'cancelled', p_reason); end if;
end $$;
revoke all on function _talent_event_cancel(text, text, text, text) from public, anon, authenticated;

-- ============================================================ 3. Collecte (déclencheurs jamais bloquants)
create or replace function _talent_sync_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; l record; rv record; v_ok boolean;
begin
  select * into o from orders where id = p_order;
  v_ok := o.id is not null and o.paid and not coalesce(o.cancelled, false)
          and not exists (select 1 from order_refunds f where f.order_id = o.id and f.status = 'refunded' and f.kind = 'full');
  for l in select ol.id, ol.confirmed_at, ol.unit_price, ol.qty, li.seller_id from order_lines ol join listings li on li.id = ol.listing_id where ol.order_id = p_order loop
    if v_ok and l.confirmed_at is not null and l.seller_id is not null then
      perform _talent_event_record(l.seller_id, 'sale_confirmed', 'order_line', l.id::text, l.confirmed_at, null, o.buyer_id, jsonb_build_object('order', o.number, 'amount', l.unit_price * l.qty));
    else
      perform _talent_event_cancel('sale_confirmed', 'order_line', l.id::text, 'Vente annulée, remboursée ou non confirmée');
    end if;
  end loop;
  for rv in select r.id, r.rating, r.created_at, r.reviewer_id, li.seller_id from reviews r join listings li on li.id = r.listing_id where r.order_id = p_order loop
    if v_ok and rv.seller_id is not null then
      perform _talent_event_record(rv.seller_id, 'review_verified', 'review', rv.id::text, rv.created_at, (rv.rating - 1) / 4.0, rv.reviewer_id, jsonb_build_object('rating', rv.rating));
    else
      perform _talent_event_cancel('review_verified', 'review', rv.id::text, 'Avis lié à une commande annulée ou remboursée');
    end if;
  end loop;
end $$;
revoke all on function _talent_sync_order(uuid) from public, anon, authenticated;

create or replace function _talent_sync_mission(p_mission uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m missions; a mission_agreements; v_n integer; v_open integer; v_at timestamptz;
begin
  select * into m from missions where id = p_mission;
  select * into a from mission_agreements where mission_id = p_mission;
  select count(*), count(*) filter (where status <> 'validated'), max(updated_at) into v_n, v_open, v_at from mission_milestones where mission_id = p_mission;
  if m.id is not null and a.provider_id is not null and m.status <> 'cancelled' and v_n > 0 and v_open = 0 then
    perform _talent_event_record(a.provider_id, 'mission_validated', 'mission', p_mission::text, v_at, null, m.client_id, jsonb_build_object('number', m.number, 'amount', a.amount));
  else
    perform _talent_event_cancel('mission_validated', 'mission', p_mission::text, 'Mission non validée, rouverte ou annulée');
  end if;
end $$;
revoke all on function _talent_sync_mission(uuid) from public, anon, authenticated;

create or replace function _talent_trg_order() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_order uuid;
begin
  begin
    if tg_table_name = 'orders' then v_order := new.id; else v_order := new.order_id; end if;
    perform _talent_sync_order(v_order);
  exception when others then raise warning 'talent collecte (commande) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _talent_trg_order() from public, anon, authenticated;
drop trigger if exists trg_talent_orders on orders;
create trigger trg_talent_orders after update of paid, cancelled on orders for each row execute function _talent_trg_order();
drop trigger if exists trg_talent_order_lines on order_lines;
create trigger trg_talent_order_lines after insert or update of confirmed_at on order_lines for each row execute function _talent_trg_order();
drop trigger if exists trg_talent_order_refunds on order_refunds;
create trigger trg_talent_order_refunds after insert or update of status on order_refunds for each row execute function _talent_trg_order();
drop trigger if exists trg_talent_reviews on reviews;
create trigger trg_talent_reviews after insert on reviews for each row execute function _talent_trg_order();

create or replace function _talent_trg_review_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    perform _talent_event_cancel('review_verified', 'review', old.id::text, 'Avis supprimé');
  exception when others then raise warning 'talent collecte (avis) : %', sqlerrm;
  end;
  return old;
end $$;
revoke all on function _talent_trg_review_delete() from public, anon, authenticated;
drop trigger if exists trg_talent_reviews_delete on reviews;
create trigger trg_talent_reviews_delete after delete on reviews for each row execute function _talent_trg_review_delete();

create or replace function _talent_trg_mission() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_id uuid := case when tg_op = 'DELETE' then old.mission_id else new.mission_id end;
begin
  begin
    perform _talent_sync_mission(v_id);
  exception when others then raise warning 'talent collecte (mission) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_mission() from public, anon, authenticated;
drop trigger if exists trg_talent_milestones on mission_milestones;
create trigger trg_talent_milestones after insert or update of status or delete on mission_milestones for each row execute function _talent_trg_mission();
drop trigger if exists trg_talent_agreements on mission_agreements;
create trigger trg_talent_agreements after insert or update of provider_id on mission_agreements for each row execute function _talent_trg_mission();

create or replace function _talent_trg_mission_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    perform _talent_sync_mission(new.id);
  exception when others then raise warning 'talent collecte (mission) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _talent_trg_mission_status() from public, anon, authenticated;
drop trigger if exists trg_talent_missions on missions;
create trigger trg_talent_missions after update of status on missions for each row execute function _talent_trg_mission_status();

create or replace function _talent_trg_certificate() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.holder_id is not null and not new.revoked then
      perform _talent_event_record(new.holder_id, 'certificate_verified', 'certificate', new.id::text, new.issued_at, null, new.issued_by, jsonb_build_object('code', new.code, 'kind', new.subject_kind));
    else
      perform _talent_event_cancel('certificate_verified', 'certificate', new.id::text, 'Certificat révoqué ou sans titulaire');
    end if;
  exception when others then raise warning 'talent collecte (certificat) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _talent_trg_certificate() from public, anon, authenticated;
drop trigger if exists trg_talent_certificates on certificates;
create trigger trg_talent_certificates after insert or update of revoked, holder_id on certificates for each row execute function _talent_trg_certificate();

create or replace function _talent_trg_challenge() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if tg_op = 'DELETE' then
      perform _talent_event_cancel('challenge_participation', 'challenge_entry', old.id::text, 'Participation retirée');
      return old;
    end if;
    perform _talent_event_record(new.author_id, 'challenge_participation', 'challenge_entry', new.id::text, new.created_at, null, null, jsonb_build_object('challenge', new.challenge_id));
  exception when others then raise warning 'talent collecte (challenge) : %', sqlerrm;
  end;
  return coalesce(new, old);
end $$;
revoke all on function _talent_trg_challenge() from public, anon, authenticated;
drop trigger if exists trg_talent_challenges on challenge_entries;
create trigger trg_talent_challenges after insert or delete on challenge_entries for each row execute function _talent_trg_challenge();

create or replace function _talent_trg_assessment() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    if new.validation_status = 'validee_humainement' then
      perform _talent_event_record(new.candidate_id, 'assessment_validated', 'assessment_result', new.id::text, coalesce(new.reviewed_at, now()), null, new.reviewed_by, jsonb_build_object('provider', new.provider_code));
    else
      perform _talent_event_cancel('assessment_validated', 'assessment_result', new.id::text, 'Validation humaine retirée');
    end if;
  exception when others then raise warning 'talent collecte (évaluation) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _talent_trg_assessment() from public, anon, authenticated;
drop trigger if exists trg_talent_assessments on assessment_results;
create trigger trg_talent_assessments after insert or update of validation_status on assessment_results for each row execute function _talent_trg_assessment();

create or replace function _talent_trg_project() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_proof boolean;
begin
  begin
    v_proof := (case when jsonb_typeof(new.media) = 'array' then jsonb_array_length(new.media) > 0 else false end)
            or (case jsonb_typeof(new.links) when 'array' then jsonb_array_length(new.links) > 0 when 'object' then new.links <> '{}'::jsonb else false end);
    if new.status = 'approved' and v_proof then
      perform _talent_event_record(new.owner_id, 'project_published_with_proof', 'project', new.id::text, new.updated_at, null, null, jsonb_build_object('kind', new.kind));
    else
      perform _talent_event_cancel('project_published_with_proof', 'project', new.id::text, 'Projet retiré de la publication ou sans preuve');
    end if;
  exception when others then raise warning 'talent collecte (projet) : %', sqlerrm;
  end;
  return new;
end $$;
revoke all on function _talent_trg_project() from public, anon, authenticated;
drop trigger if exists trg_talent_projects on projects;
create trigger trg_talent_projects after insert or update of status, media, links on projects for each row execute function _talent_trg_project();

-- ============================================================ 4. Normalisation par filière / établissement / national
create or replace function _talent_percentiles(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare a student_affiliations; v_min integer := _talent_setting('min_cohort', 5)::integer; v_period text := to_char(now() at time zone 'utc', 'YYYY-MM'); v_out jsonb := '{}'::jsonb; s text; x record;
begin
  select * into a from student_affiliations where user_id = p_user and status = 'verified' and ended_at is null;
  if a.id is null then
    return jsonb_build_object('affiliated', false, 'min_cohort', v_min, 'reason', 'Aucun rattachement vérifié à une filière : la comparaison par filière est impossible.');
  end if;
  foreach s in array array['program', 'institution', 'national'] loop
    select count(*)::integer size,
           count(*) filter (where c.total < me.total)::integer lt_total, count(*) filter (where c.total = me.total)::integer eq_total,
           count(*) filter (where c.mp < me.mp)::integer lt_month, count(*) filter (where c.mp = me.mp)::integer eq_month
      into x
      from (select sa.user_id, coalesce(ts.total, 0) total,
                   coalesce((select sum(l.points) from talent_score_ledger l where l.user_id = sa.user_id and l.period = v_period), 0) mp
            from student_affiliations sa left join talent_scores ts on ts.user_id = sa.user_id
            where sa.status = 'verified' and sa.ended_at is null
              and (s = 'national' or (s = 'institution' and sa.institution_id = a.institution_id) or (s = 'program' and sa.program_id = a.program_id))) c
      cross join (select coalesce((select total from talent_scores where user_id = p_user), 0) total,
                         coalesce((select sum(points) from talent_score_ledger where user_id = p_user and period = v_period), 0) mp) me;
    v_out := v_out || jsonb_build_object(s, case when x.size < v_min
      then jsonb_build_object('cohort_size', x.size, 'percentile_total', null, 'percentile_month', null, 'reason', 'cohorte_insuffisante')
      else jsonb_build_object('cohort_size', x.size,
        'percentile_total', round(100.0 * (x.lt_total + 0.5 * x.eq_total) / x.size, 1),
        'percentile_month', round(100.0 * (x.lt_month + 0.5 * x.eq_month) / x.size, 1)) end);
  end loop;
  return v_out || jsonb_build_object('affiliated', true, 'min_cohort', v_min, 'program_id', a.program_id, 'institution_id', a.institution_id);
end $$;
revoke all on function _talent_percentiles(uuid) from public, anon, authenticated;

-- ============================================================ 5. RPC
create or replace function my_talent_score_explain(p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_period text := to_char(now() at time zone 'utc', 'YYYY-MM'); v_prev text := to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM'); v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  return jsonb_build_object(
    'total', coalesce((select total from talent_scores where user_id = v_uid), 0),
    'period', v_period,
    'month_points', coalesce((select sum(points) from talent_score_ledger where user_id = v_uid and period = v_period), 0),
    'previous_month_points', coalesce((select sum(points) from talent_score_ledger where user_id = v_uid and period = v_prev), 0),
    'by_rule', coalesce((select jsonb_agg(jsonb_build_object('code', r.code, 'label', r.label, 'active', r.active and r.points > 0, 'points_per_activity', r.points, 'cap_per_day', r.cap_per_day,
        'cap_per_period', r.cap_per_period, 'quality_weight', r.quality_weight, 'activities', coalesce(g.n, 0), 'points', coalesce(g.p, 0)) order by r.label)
      from talent_score_rules r
      left join (select e.rule_code, count(*) filter (where e.status = 'confirmed') n, (select coalesce(sum(l.points), 0) from talent_score_ledger l where l.user_id = v_uid and l.rule_code = e.rule_code) p
                 from talent_events e where e.user_id = v_uid group by e.rule_code) g on g.rule_code = r.code), '[]'::jsonb),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('at', x.created_at, 'rule', x.rule_code, 'label', x.label, 'kind', x.kind, 'points', x.points, 'balance_after', x.balance_after,
        'source_kind', x.source_kind, 'reason', x.reason) order by x.id desc)
      from (select l.*, r.label, e.source_kind from talent_score_ledger l join talent_score_rules r on r.code = l.rule_code join talent_events e on e.id = l.event_id
            where l.user_id = v_uid order by l.id desc limit v_lim) x), '[]'::jsonb),
    'without_points', coalesce((select jsonb_agg(jsonb_build_object('at', e.occurred_at, 'rule', e.rule_code, 'label', r.label,
        'cause', case when not r.active or r.points <= 0 then 'rule_inactive' else 'cap_or_quality' end) order by e.id desc)
      from (select * from talent_events where user_id = v_uid and status = 'confirmed'
              and not exists (select 1 from talent_score_ledger l where l.event_id = talent_events.id group by l.event_id having sum(l.points) > 0)
            order by id desc limit 50) e join talent_score_rules r on r.code = e.rule_code), '[]'::jsonb),
    'not_counted', coalesce((select jsonb_agg(jsonb_build_object('at', e.status_changed_at, 'rule', e.rule_code, 'label', r.label, 'status', e.status,
        'reason', case e.status when 'neutralized' then 'Non comptabilisée après vérification : vous pouvez contester.' else e.status_reason end) order by e.status_changed_at desc)
      from (select * from talent_events where user_id = v_uid and status in ('cancelled', 'neutralized') order by status_changed_at desc nulls last limit 50) e
      join talent_score_rules r on r.code = e.rule_code), '[]'::jsonb),
    'normalization', _talent_percentiles(v_uid));
end $$;

create or replace function my_talent_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_period text := to_char(now() at time zone 'utc', 'YYYY-MM'); v_prev text := to_char((now() at time zone 'utc') - interval '1 month', 'YYYY-MM'); v_m integer; v_p integer;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(v_uid) then raise exception 'Réservé aux comptes étudiants'; end if;
  select coalesce(sum(points), 0) into v_m from talent_score_ledger where user_id = v_uid and period = v_period;
  select coalesce(sum(points), 0) into v_p from talent_score_ledger where user_id = v_uid and period = v_prev;
  return jsonb_build_object(
    'total', coalesce((select total from talent_scores where user_id = v_uid), 0),
    'period', v_period, 'month_points', v_m, 'previous_month_points', v_p, 'progression', v_m - v_p,
    'activities', jsonb_build_object(
      'confirmed', (select count(*) from talent_events where user_id = v_uid and status = 'confirmed'),
      'cancelled', (select count(*) from talent_events where user_id = v_uid and status = 'cancelled'),
      'not_counted', (select count(*) from talent_events where user_id = v_uid and status = 'neutralized')),
    'rules_active', (select count(*) from talent_score_rules where active and points > 0),
    'affiliation', (select jsonb_build_object('status', a.status, 'program', g.name, 'institution', i.name, 'promotion', a.promotion)
                    from student_affiliations a join programs g on g.id = a.program_id join institutions i on i.id = a.institution_id
                    where a.user_id = v_uid and a.ended_at is null and a.status in ('pending', 'verified') order by (a.status = 'verified') desc limit 1),
    'normalization', _talent_percentiles(v_uid),
    'rank', null,
    'rank_note', 'Aucun classement n''est publié pour le moment.');
end $$;

create or replace function admin_talent_recompute(p_user uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_reason text := btrim(coalesce(p_reason, '')); e record; v_n integer := 0; v_awarded integer := 0; v_pts integer := 0; v_p integer;
begin
  perform _top100_admin('ranking.moderate');
  if char_length(v_reason) not between 10 and 500 then raise exception 'Motivez la recomposition en 10 à 500 caractères'; end if;
  if p_user is null then raise exception 'Étudiant obligatoire'; end if;
  for e in select id from talent_events where user_id = p_user and status = 'confirmed' order by occurred_at, id loop
    v_n := v_n + 1;
    v_p := _talent_award(e.id);
    if v_p > 0 then v_awarded := v_awarded + 1; v_pts := v_pts + v_p; end if;
  end loop;
  perform _top100_audit('Score recomposé : ' || p_user::text, v_reason);
  return jsonb_build_object('ok', true, 'user', p_user, 'events_examined', v_n, 'events_awarded', v_awarded, 'points_added', v_pts,
    'total', coalesce((select total from talent_scores where user_id = p_user), 0),
    'consistent', coalesce((select total from talent_scores where user_id = p_user), 0) = (select coalesce(sum(points), 0) from talent_score_ledger where user_id = p_user));
end $$;

create or replace function admin_talent_events_list(p_user uuid, p_limit integer default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('ranking.moderate') then raise exception 'Réservé : exige la permission ranking.moderate'; end if;
  if p_user is null then raise exception 'Étudiant obligatoire'; end if;
  return jsonb_build_object(
    'total', coalesce((select total from talent_scores where user_id = p_user), 0),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'rule', e.rule_code, 'source_kind', e.source_kind, 'source_id', e.source_id, 'occurred_at', e.occurred_at, 'quality', e.quality,
        'status', e.status, 'status_reason', e.status_reason, 'points', coalesce((select sum(l.points) from talent_score_ledger l where l.event_id = e.id), 0),
        'ledger', (select coalesce(jsonb_agg(jsonb_build_object('revision', l.revision, 'kind', l.kind, 'points', l.points, 'balance_after', l.balance_after, 'period', l.period, 'rule_version', l.rule_version, 'at', l.created_at) order by l.revision), '[]'::jsonb)
                   from talent_score_ledger l where l.event_id = e.id)) order by e.id desc)
      from (select * from talent_events where user_id = p_user order by id desc limit least(greatest(coalesce(p_limit, 100), 1), 500)) e), '[]'::jsonb));
end $$;

revoke all on function my_talent_score_explain(integer), my_talent_dashboard(), admin_talent_recompute(uuid, text), admin_talent_events_list(uuid, integer) from public, anon;
grant execute on function my_talent_score_explain(integer), my_talent_dashboard(), admin_talent_recompute(uuid, text), admin_talent_events_list(uuid, integer) to authenticated;
