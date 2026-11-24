-- Lot H9 / EVAL-SQL (1/3) : validation humaine et traitement des contestations (CDC 8.2, 8.5).
--  1. nouvelle permission d'équipe « tech.assessments » (équipe Technique), SENSIBLE, attribuée explicitement par l'administrateur global via admin_team_member_set :
--     elle n'est dans AUCUN jeu de droits par défaut (_admin_team_defaults inchangé) : aucun droit existant n'est élargi ;
--  2. assessment_review_queue() : file des résultats en attente de validation humaine et des contestations à traiter ;
--  3. assessment_human_validate() : enregistre « validee_humainement » ou « non_verifiable_a_distance » avec motif obligatoire ; un évaluateur ne valide jamais sa propre évaluation ;
--     ces deux statuts ne peuvent être posés que par cette RPC (garde _assessment_result_guard de 20261125095000) ;
--  4. assessment_dispute_handle() : ouverte -> en_examen -> close avec résolution motivée ; le candidat est notifié (notifications existantes) ;
--  5. une contestation close est immuable (ni modifiable ni supprimable), même par une écriture directe ; la suppression en cascade d'un compte reste possible.
-- Aucune donnée insérée hors catalogue de permission. Additive et rejouable. Retour arrière :
--   drop trigger trg_assessment_dispute_guard on assessment_disputes; drop function _assessment_dispute_guard(), _assessment_reviewer(), assessment_review_queue(), assessment_human_validate(uuid, text, text),
--     assessment_dispute_handle(uuid, text, text); delete from admin_team_members where 'tech.assessments' = any (permissions) (retirer d'abord la permission des agents) ; delete from admin_permissions where code = 'tech.assessments';
--   puis recréer la politique « contestations d'évaluation : candidat, support » depuis 20261125095000.

-- ============================================================ 1. Permission
insert into admin_permissions (code, team_code, label, description, sensitive, position) values
  ('tech.assessments', 'tech', 'Évaluations de talents', 'Valider humainement un résultat d''évaluation (ou le déclarer non vérifiable à distance) et traiter les contestations des candidats.', true, 5)
on conflict (code) do update set team_code = excluded.team_code, label = excluded.label, description = excluded.description, sensitive = excluded.sensitive, position = excluded.position;

create or replace function _assessment_reviewer() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not has_admin_permission('tech.assessments') then raise exception 'Réservé : exige la permission de validation des évaluations'; end if;
  perform _require_staff_aal2();
end $$;
revoke all on function _assessment_reviewer() from public, anon, authenticated;

drop policy if exists "contestations d'évaluation : candidat, support" on assessment_disputes;
create policy "contestations d'évaluation : candidat, support" on assessment_disputes for select to authenticated
  using (candidate_id = auth.uid() or has_admin_permission('support.disputes') or has_admin_permission('tech.assessments'));

-- ============================================================ 2. File de l'évaluateur
create or replace function assessment_review_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _assessment_reviewer();
  return jsonb_build_object(
    'results', coalesce((select jsonb_agg(jsonb_build_object(
        'result_id', r.id, 'request_id', r.request_id, 'family_code', q.family_code, 'mode', q.mode, 'candidate', display_name(r.candidate_id),
        'competences', r.competences, 'criteria', r.criteria, 'evidence', r.evidence, 'limits', r.limits, 'validation_status', r.validation_status, 'created_at', r.created_at)
        order by r.created_at)
      from assessment_results r join assessment_requests q on q.id = r.request_id where r.validation_status = 'validation_humaine_requise'), '[]'::jsonb),
    'disputes', coalesce((select jsonb_agg(jsonb_build_object(
        'id', d.id, 'result_id', d.result_id, 'status', d.status, 'reason', d.reason, 'candidate', display_name(d.candidate_id), 'created_at', d.created_at,
        'family_code', q.family_code, 'mode', q.mode, 'limits', r.limits, 'validation_status', r.validation_status) order by d.created_at)
      from assessment_disputes d join assessment_results r on r.id = d.result_id join assessment_requests q on q.id = r.request_id
      where d.status in ('ouverte', 'en_examen')), '[]'::jsonb));
end $$;

-- ============================================================ 3. Validation humaine
create or replace function assessment_human_validate(p_result uuid, p_outcome text, p_note text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r assessment_results; v_note text := btrim(coalesce(p_note, ''));
begin
  perform _assessment_reviewer();
  if p_outcome is null or p_outcome not in ('validee_humainement', 'non_verifiable_a_distance') then raise exception 'Décision inconnue'; end if;
  if char_length(v_note) < 10 or char_length(v_note) > 1000 then raise exception 'Motivez la décision en 10 à 1000 caractères'; end if;
  select * into r from assessment_results where id = p_result for update;
  if r.id is null then raise exception 'Résultat introuvable'; end if;
  if r.candidate_id = auth.uid() then raise exception 'Vous ne pouvez pas valider votre propre évaluation'; end if;
  if r.validation_status <> 'validation_humaine_requise' then raise exception 'Ce résultat n''attend pas de validation humaine (statut : %)', r.validation_status; end if;
  perform set_config('app.assessment_human_review', auth.uid()::text, true);
  update assessment_results set validation_status = p_outcome, reviewed_by = auth.uid(), reviewed_at = now(), review_note = v_note where id = r.id;
  perform set_config('app.assessment_human_review', '', true);
  perform _assessment_audit('Validation humaine d''un résultat d''évaluation : ' || p_outcome, r.id::text);
  perform notify_user(r.candidate_id, 'assessment',
    case p_outcome when 'validee_humainement' then 'Votre évaluation est validée par un évaluateur' else 'Évaluation : compétence non vérifiable à distance' end,
    left(v_note, 300), jsonb_build_object('result', r.id, 'validation_status', p_outcome));
  return jsonb_build_object('ok', true, 'result', r.id, 'validation_status', p_outcome);
end $$;

-- ============================================================ 4. Traitement des contestations
create or replace function assessment_dispute_handle(p_id uuid, p_action text, p_resolution text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d assessment_disputes; v_res text := btrim(coalesce(p_resolution, ''));
begin
  perform _assessment_reviewer();
  if p_action is null or p_action not in ('take', 'close') then raise exception 'Action inconnue (take ou close)'; end if;
  select * into d from assessment_disputes where id = p_id for update;
  if d.id is null then raise exception 'Contestation introuvable'; end if;
  if d.candidate_id = auth.uid() then raise exception 'Vous ne pouvez pas traiter votre propre contestation'; end if;
  if p_action = 'take' then
    if d.status <> 'ouverte' then raise exception 'Cette contestation n''est plus ouverte (statut : %)', d.status; end if;
    update assessment_disputes set status = 'en_examen' where id = d.id;
    perform notify_user(d.candidate_id, 'assessment', 'Votre contestation est en cours d''examen', 'Un évaluateur examine votre contestation.', jsonb_build_object('dispute', d.id, 'result', d.result_id));
    perform _assessment_audit('Contestation d''évaluation prise en examen', d.id::text, 'Info');
    return jsonb_build_object('ok', true, 'id', d.id, 'status', 'en_examen');
  end if;
  if d.status <> 'en_examen' then raise exception 'Seule une contestation en examen peut être close (statut : %)', d.status; end if;
  if char_length(v_res) < 20 or char_length(v_res) > 2000 then raise exception 'Motivez la résolution en 20 à 2000 caractères'; end if;
  update assessment_disputes set status = 'close', resolution = v_res, resolved_at = now() where id = d.id;
  perform notify_user(d.candidate_id, 'assessment', 'Votre contestation est close', left(v_res, 300), jsonb_build_object('dispute', d.id, 'result', d.result_id));
  perform _assessment_audit('Contestation d''évaluation close', d.id::text);
  return jsonb_build_object('ok', true, 'id', d.id, 'status', 'close');
end $$;

-- ============================================================ 5. Immuabilité d'une contestation close
create or replace function _assessment_dispute_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    -- la suppression en cascade d'un compte (profondeur > 1) reste possible ; une suppression directe ne l'est pas
    if old.status = 'close' and pg_trigger_depth() = 1 then raise exception 'Une contestation close ne peut être ni modifiée ni supprimée'; end if;
    return old;
  end if;
  if old.status = 'close' then raise exception 'Une contestation close ne peut être ni modifiée ni supprimée'; end if;
  if new.reason is distinct from old.reason or new.result_id is distinct from old.result_id or new.candidate_id is distinct from old.candidate_id then
    raise exception 'Le motif d''une contestation n''est pas modifiable';
  end if;
  if new.status = 'close' and (char_length(btrim(coalesce(new.resolution, ''))) = 0 or old.status <> 'en_examen') then
    raise exception 'Une contestation se clôt depuis « en_examen » avec une résolution motivée';
  end if;
  if new.status = 'ouverte' and old.status <> 'ouverte' then raise exception 'Une contestation ne revient pas à « ouverte »'; end if;
  return new;
end $$;
drop trigger if exists trg_assessment_dispute_guard on assessment_disputes;
create trigger trg_assessment_dispute_guard before update or delete on assessment_disputes for each row execute function _assessment_dispute_guard();

revoke all on function assessment_review_queue(), assessment_human_validate(uuid, text, text), assessment_dispute_handle(uuid, text, text) from public, anon;
grant execute on function assessment_review_queue(), assessment_human_validate(uuid, text, text), assessment_dispute_handle(uuid, text, text) to authenticated;
