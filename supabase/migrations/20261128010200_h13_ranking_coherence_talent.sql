-- Lot H13 / RANKING (3/5) : cohérence profil / compétences / badges / collaborations / replays / projets / score d'un talent.
--  _talent_consistency(p_user) : compare les SOURCES réelles (talent_skills + justificatifs, user_badges, replay_completions, projects + project_members, lives, présences) avec les activités et le registre de score
--  et signale les écarts RÉELS, sans rien corriger automatiquement (lecture seule : aucune écriture, aucune neutralisation, aucun recalcul). Chaque écart : code, gravité (error | warning | info), famille, message, nombre, références (10 au plus).
--   error   : le score contient des points non étayés par une source (badge sans complétion, collaboration sans membres, total ≠ registre, points non retirés d'une activité annulée…) ;
--   warning : une source valable n'a pas d'activité de score (vérifiée avant la collecte, compétence au justificatif non vérifié…) ou une entrée publiée d'un étudiant devenu inéligible ;
--   info    : déclaration sans preuve (aucun point), consentement sans rattachement vérifié, rubrique partagée vide.
--  RPC : admin_talent_consistency_check(p_user) (permission ranking.moderate ou ranking.publish) et my_talent_consistency() (étudiant, ses propres données). Une correction reste une décision humaine
--  (admin_talent_recompute, neutralisation / rétablissement, ranking_correct).
-- Additive et rejouable, aucune donnée insérée. Retour arrière : drop function my_talent_consistency(), admin_talent_consistency_check(uuid), _talent_consistency(uuid), _talent_issue(text, text, text, text, jsonb).

create or replace function _talent_issue(p_code text, p_severity text, p_family text, p_message text, p_refs jsonb) returns jsonb
language sql immutable set search_path = public as $$
  select case when p_refs is null or jsonb_typeof(p_refs) <> 'array' or jsonb_array_length(p_refs) = 0 then null
    else jsonb_build_object('code', p_code, 'severity', p_severity, 'family', p_family, 'message', p_message, 'count', jsonb_array_length(p_refs),
      'refs', (select coalesce(jsonb_agg(x.v), '[]'::jsonb) from (select v from jsonb_array_elements(p_refs) v limit 10) x)) end
$$;
revoke all on function _talent_issue(text, text, text, text, jsonb) from public, anon, authenticated;

create or replace function _talent_consistency(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v jsonb := '[]'::jsonb; i jsonb; v_total integer; v_sum integer; v_last integer; v_cons jsonb; v_err integer; v_warn integer; v_info integer;
begin
  if p_user is null or not exists (select 1 from profiles where id = p_user and role::text = 'student') then
    return jsonb_build_object('applicable', false, 'reason', 'Réservé aux comptes étudiants', 'issues', '[]'::jsonb);
  end if;

  -- compétences
  i := _talent_issue('skill_without_proof', 'info', 'skills', 'Compétence déclarée sans justificatif : elle est affichée comme non prouvée et ne rapporte aucun point.',
    (select to_jsonb(array_agg(s.id)) from talent_skills s where s.owner_id = p_user and s.proof_document_id is null));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('skill_proof_not_verified', 'warning', 'skills', 'Le justificatif de la compétence n''est pas vérifié (en attente, refusé ou d''un autre compte) : aucun point.',
    (select to_jsonb(array_agg(s.id)) from talent_skills s left join user_documents d on d.id = s.proof_document_id
       where s.owner_id = p_user and s.proof_document_id is not null and (d.id is null or d.status <> 'verified' or d.owner_id <> s.owner_id)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('skill_verified_without_event', 'warning', 'skills', 'Compétence au justificatif vérifié sans activité de score (vérifiée avant la collecte automatique) : à examiner par la modération.',
    (select to_jsonb(array_agg(s.id)) from talent_skills s join user_documents d on d.id = s.proof_document_id and d.status = 'verified' and d.owner_id = s.owner_id
       where s.owner_id = p_user and not exists (select 1 from talent_events e where e.rule_code = 'skill_demonstrated' and e.source_kind = 'talent_skill' and e.source_id = s.id::text and e.status in ('confirmed', 'neutralized'))));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('skill_event_unsupported', 'error', 'skills', 'Des points de compétence reposent sur une compétence sans justificatif vérifié.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'skill_demonstrated' and e.status = 'confirmed'
       and not exists (select 1 from talent_skills s join user_documents d on d.id = s.proof_document_id and d.status = 'verified' and d.owner_id = s.owner_id where s.id::text = e.source_id and s.owner_id = e.user_id)));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- badges
  i := _talent_issue('badge_without_completion', 'error', 'badges', 'Badge de replay sans complétion réelle du replay correspondant.',
    (select to_jsonb(array_agg(b.id)) from user_badges b where b.user_id = p_user and b.ref_kind = 'replay'
       and not exists (select 1 from replay_completions c where c.user_id = b.user_id and c.recording_id = b.ref_id)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('badge_without_event', 'warning', 'badges', 'Badge adossé à une complétion réelle, sans activité de score (attribué avant la collecte automatique).',
    (select to_jsonb(array_agg(b.id)) from user_badges b where b.user_id = p_user and b.ref_kind = 'replay'
       and exists (select 1 from replay_completions c where c.user_id = b.user_id and c.recording_id = b.ref_id)
       and not exists (select 1 from talent_events e where e.rule_code = 'badge_verified' and e.source_kind = 'user_badge' and e.source_id = b.id::text and e.status in ('confirmed', 'neutralized'))));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('badge_event_unsupported', 'error', 'badges', 'Des points de badge reposent sur un badge absent ou sans complétion de replay.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'badge_verified' and e.status = 'confirmed'
       and not exists (select 1 from user_badges b where b.id::text = e.source_id and b.user_id = e.user_id and b.ref_kind = 'replay'
                         and exists (select 1 from replay_completions c where c.user_id = b.user_id and c.recording_id = b.ref_id))));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- replays
  i := _talent_issue('replay_without_event', 'warning', 'replays', 'Replay terminé sans activité de score (terminé avant la collecte automatique).',
    (select to_jsonb(array_agg(c.id)) from replay_completions c where c.user_id = p_user
       and not exists (select 1 from talent_events e where e.rule_code = 'replay_completed_100' and e.source_kind = 'replay_completion' and e.source_id = c.id::text and e.status in ('confirmed', 'neutralized'))));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('replay_event_unsupported', 'error', 'replays', 'Des points de replay reposent sur une complétion absente.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'replay_completed_100' and e.status = 'confirmed'
       and not exists (select 1 from replay_completions c where c.id::text = e.source_id and c.user_id = e.user_id)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('live_event_unsupported', 'error', 'replays', 'Des points de live animé reposent sur un live non terminé ou supprimé.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'live_hosted' and e.status = 'confirmed'
       and not exists (select 1 from lives l where l.id::text = e.source_id and l.host_id = e.user_id and l.status = 'ended')));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- collaborations
  i := _talent_issue('collaboration_without_members', 'error', 'collaborations', 'Points de collaboration sur un projet non approuvé ou sans au moins deux étudiants réels.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'collaboration' and e.status = 'confirmed'
       and not exists (select 1 from projects pr where pr.id::text = split_part(e.source_id, ':', 1) and pr.status = 'approved'
         and (select count(*) from (select pr.owner_id uid union select pm.user_id from project_members pm where pm.project_id = pr.id and pm.status = 'accepted') x where _talent_is_student(x.uid)) >= 2)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('collaboration_without_event', 'warning', 'collaborations', 'Projet approuvé réalisé à plusieurs étudiants réels, sans activité de collaboration (approuvé avant la collecte automatique).',
    (select to_jsonb(array_agg(pr.id)) from projects pr where pr.status = 'approved' and (pr.owner_id = p_user or exists (select 1 from project_members pm where pm.project_id = pr.id and pm.user_id = p_user and pm.status = 'accepted'))
       and (select count(*) from (select pr.owner_id uid union select pm.user_id from project_members pm where pm.project_id = pr.id and pm.status = 'accepted') x where _talent_is_student(x.uid)) >= 2
       and not exists (select 1 from talent_events e where e.rule_code = 'collaboration' and e.source_kind = 'project' and e.source_id = pr.id::text || ':' || p_user::text and e.status in ('confirmed', 'neutralized'))));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('project_member_not_countable', 'warning', 'collaborations', 'Membre accepté d''un projet approuvé dont le compte n''est pas un étudiant actif : non compté comme collaborateur.',
    (select to_jsonb(array_agg(distinct pr.id)) from projects pr join project_members pm on pm.project_id = pr.id and pm.status = 'accepted'
       where pr.status = 'approved' and (pr.owner_id = p_user or pm.user_id = p_user) and not _talent_is_student(pm.user_id)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('project_invitations_pending', 'info', 'collaborations', 'Projet approuvé dont des invitations de membres sont encore en attente : elles ne comptent pas comme collaboration.',
    (select to_jsonb(array_agg(distinct pr.id)) from projects pr join project_members pm on pm.project_id = pr.id and pm.status = 'invited' where pr.status = 'approved' and pr.owner_id = p_user));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- projets avec preuves
  i := _talent_issue('project_event_unsupported', 'error', 'projects', 'Points de projet sur un projet non approuvé, sans preuve ou supprimé.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'project_published_with_proof' and e.status = 'confirmed'
       and not exists (select 1 from projects pr where pr.id::text = e.source_id and pr.owner_id = e.user_id and pr.status = 'approved'
         and ((case when jsonb_typeof(pr.media) = 'array' then jsonb_array_length(pr.media) > 0 else false end)
              or (case jsonb_typeof(pr.links) when 'array' then jsonb_array_length(pr.links) > 0 when 'object' then pr.links <> '{}'::jsonb else false end)))));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- présence aux événements
  i := _talent_issue('attendance_event_unsupported', 'error', 'events', 'Points de présence à un événement sans présence confirmée ou sans inscription valable.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.rule_code = 'event_attended' and e.status = 'confirmed'
       and not exists (select 1 from event_attendance a where a.status = 'confirmed' and a.user_id = e.user_id and a.event_id::text || ':' || a.user_id::text = e.source_id
                         and _event_registration_valid(a.event_id, a.user_id))));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- score
  select coalesce((select total from talent_scores where user_id = p_user), 0), coalesce((select sum(points) from talent_score_ledger where user_id = p_user), 0)::integer,
         (select balance_after from talent_score_ledger where user_id = p_user order by id desc limit 1)
    into v_total, v_sum, v_last;
  i := _talent_issue('score_ledger_mismatch', 'error', 'score', 'Le total du score ne correspond pas à la somme du registre de points.', case when v_total <> v_sum then jsonb_build_array(v_total::text, v_sum::text) end);
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('score_balance_mismatch', 'error', 'score', 'Le dernier solde du registre ne correspond pas au total du score.', case when v_last is not null and v_last <> v_total then jsonb_build_array(v_total::text, v_last::text) end);
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('points_on_inactive_event', 'error', 'score', 'Des points restent attribués à une activité annulée ou neutralisée.',
    (select to_jsonb(array_agg(e.id)) from talent_events e where e.user_id = p_user and e.status <> 'confirmed' and coalesce((select sum(l.points) from talent_score_ledger l where l.event_id = e.id), 0) <> 0));
  if i is not null then v := v || jsonb_build_array(i); end if;

  -- profil, consentement et classement
  i := _talent_issue('ranked_but_ineligible', 'warning', 'ranking', 'Entrée publiée d''un étudiant devenu inéligible (suspendu, non vérifié ou alerte de fraude) : une correction auditée est à envisager.',
    (select to_jsonb(array_agg(distinct pp.period)) from ranking_entries en join ranking_periods pp on pp.id = en.period_id
       where en.user_id = p_user and en.voided_at is null and not _ranking_still_eligible(en.user_id)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('consent_without_affiliation', 'info', 'profile', 'Classement public accepté, mais aucun rattachement vérifié à une filière : l''étudiant ne peut pas être classé.',
    (select to_jsonb(array_agg('affiliation'::text)) from talent_visibility_settings s where s.user_id = p_user and s.public_ranking
       and not exists (select 1 from student_affiliations a where a.user_id = p_user and a.status = 'verified' and a.ended_at is null)));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('shared_section_empty', 'info', 'profile', 'Rubrique partagée vide : compétences, badges ou projets partagés sans contenu.',
    (select to_jsonb(array_agg(x.sec)) from (
       select 'skills'::text sec from talent_visibility_settings s where s.user_id = p_user and 'skills' = any (s.shared_sections) and not exists (select 1 from talent_skills t where t.owner_id = p_user)
       union all select 'badges' from talent_visibility_settings s where s.user_id = p_user and 'badges' = any (s.shared_sections) and jsonb_array_length(_ranking_badges(p_user)) = 0
       union all select 'projects' from talent_visibility_settings s where s.user_id = p_user and 'projects' = any (s.shared_sections) and not exists (select 1 from projects pr where pr.owner_id = p_user and pr.status = 'approved')) x));
  if i is not null then v := v || jsonb_build_array(i); end if;
  i := _talent_issue('points_without_verified_status', 'info', 'profile', 'Des points existent mais le compte n''est pas un étudiant vérifié : il ne peut pas figurer au classement.',
    case when v_total > 0 and not is_verified_student(p_user) then jsonb_build_array('student_status'::text) end);
  if i is not null then v := v || jsonb_build_array(i); end if;

  select count(*) filter (where x ->> 'severity' = 'error'), count(*) filter (where x ->> 'severity' = 'warning'), count(*) filter (where x ->> 'severity' = 'info') into v_err, v_warn, v_info from jsonb_array_elements(v) x;
  v_cons := jsonb_build_object('applicable', true, 'user', p_user, 'consistent', v_err = 0 and v_warn = 0, 'summary', jsonb_build_object('errors', v_err, 'warnings', v_warn, 'infos', v_info),
    'issues', v, 'score', jsonb_build_object('total', v_total, 'ledger_sum', v_sum), 'auto_correction', false,
    'note', 'Lecture seule : rien n''est corrigé automatiquement. Une correction reste une décision humaine.');
  return v_cons;
end $$;
revoke all on function _talent_consistency(uuid) from public, anon, authenticated;

create or replace function admin_talent_consistency_check(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_res jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not (has_admin_permission('ranking.moderate') or has_admin_permission('ranking.publish')) then raise exception 'Réservé : exige la permission ranking.moderate ou ranking.publish'; end if;
  if p_user is null or not exists (select 1 from profiles where id = p_user) then raise exception 'Compte introuvable'; end if;
  v_res := _talent_consistency(p_user);
  return v_res || jsonb_build_object('student', display_name(p_user));
end $$;

create or replace function my_talent_consistency() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _talent_is_student(auth.uid()) then raise exception 'Réservé aux comptes étudiants'; end if;
  return _talent_consistency(auth.uid());
end $$;

revoke all on function admin_talent_consistency_check(uuid), my_talent_consistency() from public, anon;
grant execute on function admin_talent_consistency_check(uuid), my_talent_consistency() to authenticated;
