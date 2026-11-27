-- H13 · Quiz de replay côté hôte / co-hôte (suite de 20261127300100). Strictement additif (create or replace de fonctions, aucune table modifiée).
--  * replay_quiz_can_edit(replay) : vrai pour l'hôte, un co-hôte approuvé du live ou l'administration (même règle que _live_can_edit) ;
--  * replay_quiz_get_host(replay) : le quiz complet AVEC les bonnes réponses, réservé aux éditeurs (un membre ne reçoit jamais « correct » : replay_quiz_get inchangée) ;
--  * replay_quiz_set : élargie au co-hôte approuvé et à l'administration, validation stricte (énoncés et options de type texte, longueurs, options distinctes, bonne réponse entière
--    dans les options, seuil de réussite entier 50-100) ; les textes sont nettoyés (liens et balises retirés) ;
--  * replay_quiz_delete : suppression du quiz par un éditeur ; les personnes ayant terminé le replay et qui attendaient la réussite du quiz reçoivent alors leur badge / certificat ;
--  * _replay_award : quand le replay a un quiz, le badge « J'ai suivi » ET le certificat exigent la complétion réelle ET un quiz réussi (sans quiz : complétion seule, comme avant).
--    Les badges déjà attribués ne sont jamais retirés. Aucun nouveau type de badge (le score des talents n'est pas modifié) ;
--  * replay_quiz_submit : même correction serveur, retourne en plus « completed », « badge » et « attempts_left » ; ne renvoie jamais la bonne réponse.
-- Une modification du quiz n'invalide pas les réussites antérieures (décision documentée dans docs/transformation/H13_LIVE_REPLAY.md).
-- Retour arrière : recréer replay_quiz_set / replay_quiz_submit / _replay_award depuis 20261127300100 ; drop function replay_quiz_can_edit(uuid), replay_quiz_get_host(uuid), replay_quiz_delete(uuid), _replay_quiz_editor(uuid, uuid).

create or replace function _replay_quiz_editor(p_recording uuid, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_user is not null and exists (select 1 from live_recordings r where r.id = p_recording and _live_can_edit(r.live_id, p_user, false))
$$;
revoke all on function _replay_quiz_editor(uuid, uuid) from public, anon, authenticated;

create or replace function replay_quiz_can_edit(p_recording uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select _replay_quiz_editor(p_recording, auth.uid())
$$;
revoke all on function replay_quiz_can_edit(uuid) from public;
grant execute on function replay_quiz_can_edit(uuid) to anon, authenticated;

create or replace function replay_quiz_get_host(p_recording uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare z replay_quizzes%rowtype;
begin
  perform _assert_active();
  if not _replay_quiz_editor(p_recording, auth.uid()) then raise exception 'Action non autorisée'; end if;
  select * into z from replay_quizzes where recording_id = p_recording;
  if not found then return jsonb_build_object('defined', false); end if;
  return jsonb_build_object('defined', true, 'title', z.title, 'pass_pct', z.pass_pct, 'questions', z.questions, 'updated_at', z.updated_at,
    'attempts', (select count(*)::int from replay_quiz_attempts where recording_id = p_recording),
    'takers', (select count(distinct user_id)::int from replay_quiz_attempts where recording_id = p_recording),
    'passers', (select count(distinct user_id)::int from replay_quiz_attempts where recording_id = p_recording and passed));
end $$;
revoke all on function replay_quiz_get_host(uuid) from public, anon;
grant execute on function replay_quiz_get_host(uuid) to authenticated;

create or replace function replay_quiz_set(p_recording uuid, p_title text, p_pass_pct integer, p_questions jsonb) returns boolean
language plpgsql security definer set search_path = public as $$
declare q jsonb; o jsonb; n integer := 0; k integer; stmt text; opt text; opts text[]; norm jsonb := '[]'::jsonb; title text := nullif(left(_clean_live_title(p_title), 120), ''); pct integer := coalesce(p_pass_pct, 70);
begin
  perform _assert_active();
  if not exists (select 1 from live_recordings where id = p_recording) then raise exception 'Replay introuvable'; end if;
  if not _replay_quiz_editor(p_recording, auth.uid()) then raise exception 'Action non autorisée'; end if;
  if pct not between 50 and 100 then raise exception 'Le seuil de réussite est compris entre 50 %% et 100 %%'; end if;
  if p_questions is null or jsonb_typeof(p_questions) <> 'array' or jsonb_array_length(p_questions) not between 1 and 20 then raise exception 'Un quiz comporte 1 à 20 questions'; end if;
  for q in select * from jsonb_array_elements(p_questions) loop
    n := n + 1;
    if jsonb_typeof(q) <> 'object' or jsonb_typeof(q->'q') is distinct from 'string' or jsonb_typeof(q->'options') is distinct from 'array'
       or jsonb_typeof(q->'correct') is distinct from 'number' or (q->>'correct') !~ '^[0-9]{1,2}$' then
      raise exception 'Question % invalide (énoncé, 2 à 6 options, bonne réponse)', n;
    end if;
    stmt := left(_clean_live_title(q->>'q'), 300);
    if stmt = '' or char_length(_clean_live_title(q->>'q')) > 300 then raise exception 'Question % invalide : énoncé de 1 à 300 caractères (sans lien)', n; end if;
    if jsonb_array_length(q->'options') not between 2 and 6 then raise exception 'Question % invalide : 2 à 6 options', n; end if;
    opts := '{}';
    for o in select * from jsonb_array_elements(q->'options') loop
      if jsonb_typeof(o) <> 'string' then raise exception 'Question % invalide : les options sont du texte', n; end if;
      opt := _clean_live_title(o #>> '{}');
      if opt = '' or char_length(opt) > 200 then raise exception 'Question % invalide : option de 1 à 200 caractères (sans lien)', n; end if;
      if lower(opt) = any (select lower(x) from unnest(opts) x) then raise exception 'Question % invalide : deux options identiques', n; end if;
      opts := array_append(opts, opt);
    end loop;
    k := (q->>'correct')::int;
    if k >= array_length(opts, 1) then raise exception 'Question % invalide : la bonne réponse doit être l''une des options', n; end if;
    norm := norm || jsonb_build_array(jsonb_build_object('q', stmt, 'options', to_jsonb(opts), 'correct', k));
  end loop;
  insert into replay_quizzes (recording_id, title, pass_pct, questions) values (p_recording, coalesce(title, 'Quiz'), pct, norm)
    on conflict (recording_id) do update set title = excluded.title, pass_pct = excluded.pass_pct, questions = excluded.questions, updated_at = now();
  return true;
end $$;
revoke all on function replay_quiz_set(uuid, text, integer, jsonb) from public, anon;
grant execute on function replay_quiz_set(uuid, text, integer, jsonb) to authenticated;

-- Badge « J'ai suivi » et certificat : complétion réelle ET, si le replay a un quiz, quiz réussi. Idempotent.
create or replace function _replay_award(p_user uuid, p_recording uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare r live_recordings%rowtype; l lives%rowtype; m replay_meta; holder text; c text; has_quiz boolean; quiz_ok boolean;
begin
  select * into r from live_recordings where id = p_recording;
  select * into l from lives where id = r.live_id;
  if not exists (select 1 from replay_completions where user_id = p_user and recording_id = p_recording) then return; end if;
  has_quiz := exists (select 1 from replay_quizzes where recording_id = p_recording);
  quiz_ok := exists (select 1 from replay_quiz_attempts a where a.recording_id = p_recording and a.user_id = p_user and a.passed);
  if has_quiz and not quiz_ok then return; end if;
  insert into user_badges (user_id, code, label, ref_kind, ref_id) values (p_user, 'jai_suivi', 'J''ai suivi', 'replay', p_recording) on conflict do nothing;
  if found then
    insert into notifications (user_id, kind, title, body, data) values (p_user, 'live', 'Badge « J''ai suivi »', left('Vous avez suivi « ' || l.title || ' » jusqu''au bout.', 500), jsonb_build_object('recording', p_recording));
  end if;
  m := _replay_meta(p_recording);
  if m.certificate_enabled and not exists (select 1 from replay_certificates where user_id = p_user and recording_id = p_recording) then
    select name into holder from profiles where id = p_user;
    c := 'BE-SUIVI-' || upper(encode(gen_random_bytes(4), 'hex'));
    insert into replay_certificates (code, user_id, recording_id, holder_name, title, fingerprint)
      values (c, p_user, p_recording, coalesce(nullif(btrim(holder), ''), 'Membre'), l.title, encode(digest(c || '|' || p_user::text || '|' || p_recording::text || '|' || now()::text, 'sha256'), 'hex'))
      on conflict (user_id, recording_id) do nothing;
    if found then
      insert into notifications (user_id, kind, title, body, data) values (p_user, 'live', 'Certificat de suivi', 'Votre certificat de suivi ' || c || ' est disponible.', jsonb_build_object('recording', p_recording, 'code', c));
    end if;
  end if;
end $$;
revoke all on function _replay_award(uuid, uuid) from public, anon, authenticated;

create or replace function replay_quiz_delete(p_recording uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  perform _assert_active();
  if not exists (select 1 from live_recordings where id = p_recording) then raise exception 'Replay introuvable'; end if;
  if not _replay_quiz_editor(p_recording, auth.uid()) then raise exception 'Action non autorisée'; end if;
  delete from replay_quizzes where recording_id = p_recording;
  if not found then return false; end if;
  for r in select user_id from replay_completions where recording_id = p_recording order by completed_at limit 1000 loop
    perform _replay_award(r.user_id, p_recording);
  end loop;
  return true;
end $$;
revoke all on function replay_quiz_delete(uuid) from public, anon;
grant execute on function replay_quiz_delete(uuid) to authenticated;

create or replace function replay_quiz_submit(p_recording uuid, p_answers jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); z replay_quizzes%rowtype; acc text; total integer; good integer := 0; i integer; pct integer; ok boolean; used integer; done boolean;
begin
  perform _assert_active();
  acc := _replay_access(p_recording, uid);
  if acc <> 'ok' then raise exception '%', _replay_msg(acc); end if;
  select * into z from replay_quizzes where recording_id = p_recording;
  if not found then raise exception 'Ce replay n''a pas de quiz'; end if;
  select count(*) into used from replay_quiz_attempts where user_id = uid and recording_id = p_recording and created_at > now() - interval '1 day';
  if used >= 10 then raise exception 'Trop de tentatives aujourd''hui : réessayez demain'; end if;
  total := jsonb_array_length(z.questions);
  if p_answers is null or jsonb_typeof(p_answers) <> 'array' or jsonb_array_length(p_answers) <> total then raise exception 'Répondez à toutes les questions'; end if;
  for i in 0 .. total - 1 loop
    if jsonb_typeof(p_answers->i) = 'number' and (p_answers->>i) ~ '^[0-9]+$' and (p_answers->>i)::int = (z.questions->i->>'correct')::int then good := good + 1; end if;
  end loop;
  pct := round(100.0 * good / total);
  ok := pct >= z.pass_pct;
  insert into replay_quiz_attempts (recording_id, user_id, score_pct, passed) values (p_recording, uid, pct, ok);
  if ok then perform _replay_award(uid, p_recording); end if;
  done := exists (select 1 from replay_completions where user_id = uid and recording_id = p_recording);
  return jsonb_build_object('score_pct', pct, 'passed', ok, 'pass_pct', z.pass_pct, 'completed', done, 'attempts_left', 9 - used,
    'badge', exists (select 1 from user_badges where user_id = uid and code = 'jai_suivi' and ref_kind = 'replay' and ref_id = p_recording));
end $$;
revoke all on function replay_quiz_submit(uuid, jsonb) from public, anon;
grant execute on function replay_quiz_submit(uuid, jsonb) to authenticated;
