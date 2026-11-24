-- H10 Talent (5/5) : recrutement APRÈS présélection (CDC 7.5-7 à 7.5-10, B-762, B-763, B-764, B-765).
-- Une candidature présélectionnée (opportunity_applications.status = 'shortlisted') peut recevoir, dans cet ordre libre mais traçable :
--  1. une évaluation liée (facultative) : un résultat assessment_results que le CANDIDAT a choisi de joindre à cette candidature, ou un résultat qu'il a déjà partagé avec l'organisation
--     (campagne). Jamais un résultat non partagé. Les résultats « à validation humaine requise » le restent affichés comme tels.
--  2. un entretien (planifié, réalisé ou annulé ; le candidat est notifié).
--  3. une DÉCISION HUMAINE motivée (retenu / non retenu), signée par la personne qui la prend et journalisée ; aucun calcul, aucun score ne la déclenche.
--     « Non retenu » passe la candidature à « rejected » (même circuit qu'opp_application_decide) ; « retenu » ne change PAS le statut : il autorise seulement une proposition.
--  4. une PROPOSITION = simple message au candidat, sans engagement juridique : l'avertissement est stocké, renvoyé et inclus dans la notification. Aucun contrat n'est généré
--     (modèles contractuels et juridiction = décision du propriétaire, B-765). Le candidat répond « intéressé » ou « décline » ; cela ne crée aucune obligation.
-- Données privées de l'organisation : RLS fermée, RPC seulement ; écriture = propriétaire ou administrateur d'équipe, lecture = + finance/lecteur (_opp_can). Le candidat ne voit que
-- son entretien, sa proposition et ce qu'il a lui-même joint (jamais le motif interne de la décision ni le journal).
-- Additive et rejouable. Retour arrière : drop function opp_recruit_get(uuid), opp_recruit_evaluation_link(uuid, uuid), opp_interview_set(uuid, timestamptz, text, text, text),
--   opp_interview_cancel(uuid, text), opp_interview_done(uuid, text), opp_recruit_decide(uuid, text, text), opp_offer_send(uuid, text), opp_offer_respond(uuid, text),
--   _recruit_load(uuid, boolean), _recruit_event(uuid, text, jsonb) ; drop table opportunity_recruitment_events, opportunity_recruitment.

create table if not exists opportunity_recruitment (
  application_id uuid primary key references opportunity_applications (id) on delete cascade,
  evaluation_result_id uuid references assessment_results (id) on delete set null,
  evaluation_linked_by uuid references profiles (id) on delete set null,
  evaluation_consent text check (evaluation_consent is null or evaluation_consent in ('candidat', 'campagne')),
  interview_status text check (interview_status is null or interview_status in ('planifie', 'realise', 'annule')),
  interview_at timestamptz,
  interview_mode text check (interview_mode is null or interview_mode in ('visio', 'presentiel', 'telephone')),
  interview_place text check (interview_place is null or char_length(interview_place) <= 200),
  interview_note text check (interview_note is null or char_length(interview_note) <= 1000),
  decision text check (decision is null or decision in ('retenu', 'non_retenu')),
  decision_reason text check (decision_reason is null or char_length(decision_reason) <= 1000),
  decided_by uuid references profiles (id) on delete set null,
  decided_at timestamptz,
  offer_message text check (offer_message is null or char_length(offer_message) <= 2000),
  offer_sent_by uuid references profiles (id) on delete set null,
  offer_sent_at timestamptz,
  offer_response text check (offer_response is null or offer_response in ('interesse', 'decline')),
  offer_responded_at timestamptz,
  updated_at timestamptz not null default now()
);
create table if not exists opportunity_recruitment_events (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references opportunity_applications (id) on delete cascade,
  actor_id uuid references profiles (id) on delete set null,
  kind text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists opportunity_recruitment_events_app on opportunity_recruitment_events (application_id, created_at);
alter table opportunity_recruitment enable row level security;
alter table opportunity_recruitment_events enable row level security;
revoke all on opportunity_recruitment, opportunity_recruitment_events from public, anon, authenticated;

-- Candidature accessible : équipe de l'organisation (écriture ou lecture). Le candidat lui-même est traité à part (opp_recruit_get, opp_offer_respond, lien d'évaluation).
create or replace function _recruit_load(p_app uuid, p_write boolean) returns opportunity_applications
language plpgsql stable security definer set search_path = public as $$
declare a opportunity_applications%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select ap.* into a from opportunity_applications ap join opportunities o on o.id = ap.opportunity_id where ap.id = p_app and _opp_can(o.poster_id, coalesce(p_write, true));
  if a.id is null then raise exception 'Candidature introuvable'; end if;
  return a;
end $$;
revoke all on function _recruit_load(uuid, boolean) from public, anon, authenticated;

create or replace function _recruit_event(p_app uuid, p_kind text, p_detail jsonb default '{}'::jsonb) returns void
language sql security definer set search_path = public as $$
  insert into opportunity_recruitment_events (application_id, actor_id, kind, detail) values (p_app, auth.uid(), p_kind, coalesce(p_detail, '{}'::jsonb))
$$;
revoke all on function _recruit_event(uuid, text, jsonb) from public, anon, authenticated;

-- ============================================================ lecture
create or replace function opp_recruit_get(p_app uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; r opportunity_recruitment%rowtype; v_org boolean; v_eval jsonb := null; res assessment_results%rowtype; q assessment_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from opportunity_applications where id = p_app;
  if a.id is null then raise exception 'Candidature introuvable'; end if;
  select * into o from opportunities where id = a.opportunity_id;
  v_org := _opp_can(o.poster_id, false);
  if not v_org and a.applicant_id <> auth.uid() then raise exception 'Candidature introuvable'; end if;
  select * into r from opportunity_recruitment where application_id = p_app;
  if r.evaluation_result_id is not null then
    select * into res from assessment_results where id = r.evaluation_result_id;
    select * into q from assessment_requests where id = res.request_id;
    v_eval := jsonb_build_object('result_id', res.id, 'family_code', q.family_code, 'mode', q.mode, 'competences', res.competences, 'limits', res.limits, 'recommendations', res.recommendations,
      'validation_status', res.validation_status, 'human_validation_required', res.validation_status = 'validation_humaine_requise', 'consent', r.evaluation_consent, 'at', res.created_at);
  end if;
  return jsonb_build_object('application_id', a.id, 'opportunity_id', o.id, 'title', o.title, 'status', a.status, 'viewer', case when v_org then 'organisation' else 'candidat' end,
    'can_manage', v_org and _opp_can(o.poster_id, true), 'shortlisted', a.status = 'shortlisted',
    'evaluation', v_eval,
    'interview', case when r.interview_status is null then null else jsonb_build_object('status', r.interview_status, 'at', r.interview_at, 'mode', r.interview_mode, 'place', r.interview_place,
        'note', case when v_org then r.interview_note else null end) end,
    'decision', case when r.decision is null or not v_org then null else jsonb_build_object('decision', r.decision, 'reason', r.decision_reason, 'by', display_name(r.decided_by), 'at', r.decided_at, 'automatic', false) end,
    'offer', case when r.offer_sent_at is null then null else jsonb_build_object('message', r.offer_message, 'sent_at', r.offer_sent_at, 'by', display_name(r.offer_sent_by), 'response', r.offer_response,
        'responded_at', r.offer_responded_at,
        'notice', 'Ce message est une proposition sans engagement juridique : il ne constitue pas un contrat. Toute contractualisation se fait hors de la plateforme.') end,
    'events', case when v_org then coalesce((select jsonb_agg(jsonb_build_object('kind', e.kind, 'by', display_name(e.actor_id), 'at', e.created_at, 'detail', e.detail) order by e.created_at, e.id)
                                              from opportunity_recruitment_events e where e.application_id = a.id), '[]'::jsonb) else null end,
    'automatic_decision', false,
    'notice', 'Les étapes de recrutement sont décidées par des personnes : aucun score ni classement ne décide à leur place.');
end $$;

-- ============================================================ évaluation liée (facultative)
-- p_result null : détache le résultat (candidat ou organisation). Sinon : le candidat joint un de ses résultats ; l'organisation ne peut lier qu'un résultat déjà partagé par le candidat (campagne).
create or replace function opp_recruit_evaluation_link(p_app uuid, p_result uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; res assessment_results%rowtype; v_consent text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from opportunity_applications where id = p_app;
  if a.id is null then raise exception 'Candidature introuvable'; end if;
  select * into o from opportunities where id = a.opportunity_id;
  if not _opp_can(o.poster_id, true) and a.applicant_id <> auth.uid() then raise exception 'Candidature introuvable'; end if;
  if p_result is null then
    update opportunity_recruitment set evaluation_result_id = null, evaluation_linked_by = null, evaluation_consent = null, updated_at = now() where application_id = p_app;
    perform _recruit_event(p_app, 'evaluation_detachee');
    return jsonb_build_object('linked', false);
  end if;
  if a.status <> 'shortlisted' then raise exception 'L''évaluation se lie après la présélection'; end if;
  select * into res from assessment_results where id = p_result and candidate_id = a.applicant_id;
  if res.id is null then raise exception 'Résultat introuvable'; end if;
  if a.applicant_id = auth.uid() then
    v_consent := 'candidat';
  elsif _assessment_result_shared_with_org(p_result) then
    v_consent := 'campagne';
  else
    raise exception 'Ce résultat n''est pas partagé par le candidat';
  end if;
  insert into opportunity_recruitment (application_id, evaluation_result_id, evaluation_linked_by, evaluation_consent) values (p_app, p_result, auth.uid(), v_consent)
  on conflict (application_id) do update set evaluation_result_id = excluded.evaluation_result_id, evaluation_linked_by = excluded.evaluation_linked_by,
    evaluation_consent = excluded.evaluation_consent, updated_at = now();
  perform _recruit_event(p_app, 'evaluation_liee', jsonb_build_object('consent', v_consent));
  if a.applicant_id = auth.uid() then
    perform notify_user(o.poster_id, 'opportunity_recruitment', 'Évaluation jointe à une candidature', left(display_name(a.applicant_id) || ' : ' || o.title, 80), jsonb_build_object('opportunity', o.id, 'application', a.id));
  end if;
  return jsonb_build_object('linked', true, 'consent', v_consent);
end $$;

-- ============================================================ entretien
create or replace function opp_interview_set(p_app uuid, p_at timestamptz, p_mode text, p_place text default '', p_note text default '') returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; r opportunity_recruitment%rowtype;
begin
  a := _recruit_load(p_app, true);
  select * into o from opportunities where id = a.opportunity_id;
  if a.status <> 'shortlisted' then raise exception 'L''entretien suit la présélection'; end if;
  select * into r from opportunity_recruitment where application_id = p_app;
  if r.decision is not null then raise exception 'La décision est déjà prise'; end if;
  if r.interview_status = 'realise' then raise exception 'L''entretien a déjà eu lieu'; end if;
  if p_at is null or p_at <= now() then raise exception 'Choisissez une date d''entretien à venir'; end if;
  if p_at > now() + interval '1 year' then raise exception 'Date d''entretien trop lointaine'; end if;
  if p_mode not in ('visio', 'presentiel', 'telephone') then raise exception 'Mode d''entretien inconnu'; end if;
  insert into opportunity_recruitment (application_id, interview_status, interview_at, interview_mode, interview_place, interview_note)
  values (p_app, 'planifie', p_at, p_mode, left(_clean_text(p_place), 200), left(_clean_text(p_note), 1000))
  on conflict (application_id) do update set interview_status = 'planifie', interview_at = excluded.interview_at, interview_mode = excluded.interview_mode,
    interview_place = excluded.interview_place, interview_note = excluded.interview_note, updated_at = now();
  perform _recruit_event(p_app, 'entretien_planifie', jsonb_build_object('at', p_at, 'mode', p_mode));
  perform notify_user(a.applicant_id, 'opportunity_interview', 'Entretien proposé', left(o.org_name || ' : ' || o.title, 60) || ' - ' || to_char(p_at at time zone 'UTC', 'DD/MM/YYYY HH24:MI') || ' UTC',
    jsonb_build_object('opportunity', o.id, 'application', a.id));
  return opp_recruit_get(p_app);
end $$;

create or replace function opp_interview_cancel(p_app uuid, p_reason text default '') returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype;
begin
  a := _recruit_load(p_app, true);
  select * into o from opportunities where id = a.opportunity_id;
  update opportunity_recruitment set interview_status = 'annule', updated_at = now() where application_id = p_app and interview_status = 'planifie';
  if not found then raise exception 'Aucun entretien planifié'; end if;
  perform _recruit_event(p_app, 'entretien_annule', jsonb_build_object('reason', left(_clean_text(p_reason), 300)));
  perform notify_user(a.applicant_id, 'opportunity_interview', 'Entretien annulé', left(o.org_name || ' : ' || o.title, 60), jsonb_build_object('opportunity', o.id, 'application', a.id));
  return opp_recruit_get(p_app);
end $$;

create or replace function opp_interview_done(p_app uuid, p_note text default '') returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype;
begin
  a := _recruit_load(p_app, true);
  update opportunity_recruitment set interview_status = 'realise', interview_note = coalesce(nullif(left(_clean_text(p_note), 1000), ''), interview_note), updated_at = now()
  where application_id = p_app and interview_status = 'planifie' and interview_at <= now();
  if not found then raise exception 'Aucun entretien planifié à marquer comme réalisé (la date doit être passée)'; end if;
  perform _recruit_event(p_app, 'entretien_realise');
  return opp_recruit_get(p_app);
end $$;

-- ============================================================ décision humaine
create or replace function opp_recruit_decide(p_app uuid, p_decision text, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; r opportunity_recruitment%rowtype; v_reason text := left(_clean_text(p_reason), 1000);
begin
  a := _recruit_load(p_app, true);
  if a.status <> 'shortlisted' then raise exception 'La décision se prend sur une candidature présélectionnée'; end if;
  if p_decision not in ('retenu', 'non_retenu') then raise exception 'Décision inconnue'; end if;
  if char_length(v_reason) < 10 then raise exception 'Motivez la décision (10 caractères au moins)'; end if;
  select * into r from opportunity_recruitment where application_id = p_app;
  if r.decision is not null then raise exception 'La décision est déjà prise'; end if;
  if r.interview_status = 'planifie' then raise exception 'Un entretien est encore planifié : marquez-le réalisé ou annulez-le'; end if;
  insert into opportunity_recruitment (application_id, decision, decision_reason, decided_by, decided_at) values (p_app, p_decision, v_reason, auth.uid(), now())
  on conflict (application_id) do update set decision = excluded.decision, decision_reason = excluded.decision_reason, decided_by = excluded.decided_by, decided_at = excluded.decided_at, updated_at = now();
  perform _recruit_event(p_app, 'decision_' || p_decision, jsonb_build_object('reason', v_reason));
  if p_decision = 'non_retenu' then perform opp_application_decide(p_app, 'rejected'); end if;
  return opp_recruit_get(p_app);
end $$;

-- ============================================================ proposition (message sans engagement juridique)
create or replace function opp_offer_send(p_app uuid, p_message text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; r opportunity_recruitment%rowtype; v_msg text := left(_clean_text(p_message), 2000);
begin
  a := _recruit_load(p_app, true);
  select * into o from opportunities where id = a.opportunity_id;
  select * into r from opportunity_recruitment where application_id = p_app;
  if a.status <> 'shortlisted' or r.decision is distinct from 'retenu' then raise exception 'Une proposition suit une décision « retenu » prise par l''organisation'; end if;
  if r.offer_response is not null then raise exception 'Le candidat a déjà répondu à la proposition'; end if;
  if char_length(v_msg) < 20 then raise exception 'Rédigez la proposition (20 caractères au moins)'; end if;
  update opportunity_recruitment set offer_message = v_msg, offer_sent_by = auth.uid(), offer_sent_at = now(), updated_at = now() where application_id = p_app;
  perform _recruit_event(p_app, 'proposition_envoyee');
  perform notify_user(a.applicant_id, 'opportunity_offer', 'Proposition de ' || left(o.org_name, 40),
    'Message sans engagement juridique (aucun contrat). ' || left(o.title, 60), jsonb_build_object('opportunity', o.id, 'application', a.id, 'legal_commitment', false));
  return opp_recruit_get(p_app);
end $$;

create or replace function opp_offer_respond(p_app uuid, p_response text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; r opportunity_recruitment%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into a from opportunity_applications where id = p_app and applicant_id = auth.uid();
  if a.id is null then raise exception 'Candidature introuvable'; end if;
  if p_response not in ('interesse', 'decline') then raise exception 'Réponse inconnue'; end if;
  select * into r from opportunity_recruitment where application_id = p_app;
  if r.offer_sent_at is null then raise exception 'Aucune proposition à laquelle répondre'; end if;
  if r.offer_response is not null then raise exception 'Vous avez déjà répondu'; end if;
  select * into o from opportunities where id = a.opportunity_id;
  update opportunity_recruitment set offer_response = p_response, offer_responded_at = now(), updated_at = now() where application_id = p_app;
  perform _recruit_event(p_app, 'proposition_' || p_response);
  perform notify_user(o.poster_id, 'opportunity_offer', 'Réponse à votre proposition', left(display_name(a.applicant_id) || ' : ' || case p_response when 'interesse' then 'intéressé' else 'décline' end || ' - ' || o.title, 120),
    jsonb_build_object('opportunity', o.id, 'application', a.id));
  return opp_recruit_get(p_app);
end $$;

revoke all on function opp_recruit_get(uuid), opp_recruit_evaluation_link(uuid, uuid), opp_interview_set(uuid, timestamptz, text, text, text), opp_interview_cancel(uuid, text),
  opp_interview_done(uuid, text), opp_recruit_decide(uuid, text, text), opp_offer_send(uuid, text), opp_offer_respond(uuid, text) from public, anon;
grant execute on function opp_recruit_get(uuid), opp_recruit_evaluation_link(uuid, uuid), opp_interview_set(uuid, timestamptz, text, text, text), opp_interview_cancel(uuid, text),
  opp_interview_done(uuid, text), opp_recruit_decide(uuid, text, text), opp_offer_send(uuid, text), opp_offer_respond(uuid, text) to authenticated;
