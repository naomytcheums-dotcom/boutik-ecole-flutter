-- H13.2 (agent 6) : exports et rapports d'administration — droits ajustés et accès journalisés.
-- Constats (scénario h132_admin.mjs, section E) :
--  * sponsor_report(sponsor) : le rapport complet (montants de toutes les contributions) s'ouvrait à toute personne « is_platform_staff() » (support, sécurité…) alors que la lecture des sponsors
--    et contributions est réservée à la permission finance.read (H7), et refusait en revanche un agent Finance avec finance.read. Désormais : propriétaire du sponsor, ou permission finance.read
--    (l'administrateur global la porte), ou responsable de département pour ses seules contributions (inchangé).
--  * export_my_data() : l'export de toutes les données personnelles n'était pas journalisé ; il l'est (« Exports », Info) — utile pour repérer un export après détournement de compte.
--  * message_reports_list() : montre des messages privés (10 derniers de la conversation signalée) à l'équipe de modération sans trace ; l'accès est journalisé (« Modération », Sensible),
--    une ligne au plus toutes les 10 minutes par agent.
--  * direction_consolidated_report() : rapport consolidé (montants encaissés, partenariats) sans trace ; journalisé (« Exports », Info).
-- Strictement additive : fonctions remplacées (mêmes signatures et droits d'exécution), une fonction interne renommée (aucune suppression). Rejouable.
-- Retour arrière : recréer export_my_data / sponsor_report / message_reports_list depuis leurs migrations d'origine ; renommer _h132_direction_consolidated_report en direction_consolidated_report.

create or replace function sponsor_report(p_sponsor uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s sponsors; v_all boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into s from sponsors where id = p_sponsor;
  v_all := s.id is not null and (coalesce(s.owner_id = auth.uid(), false) or has_admin_permission('finance.read'));
  if s.id is null or not (v_all or exists (select 1 from sponsorships x where x.sponsor_id = s.id and _dept_sees_name(x.department))) then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object(
    'sponsor', s.name,
    'total', (select coalesce(sum(amount), 0)::bigint from sponsorships where sponsor_id = s.id and (v_all or _dept_sees_name(department))),
    'students', (select coalesce(sum(students), 0)::int from sponsorships where sponsor_id = s.id and (v_all or _dept_sees_name(department))),
    'projects', (select coalesce(jsonb_agg(jsonb_build_object('title', title, 'department', coalesce(department, ''), 'amount', amount, 'students', students, 'outcome', coalesce(outcome, ''), 'status', status, 'year', year) order by year desc, created_at desc), '[]'::jsonb)
                 from sponsorships where sponsor_id = s.id and (v_all or _dept_sees_name(department)))
  );
end $$;

create or replace function export_my_data() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin /*h13:throttle*/
  perform _rpc_throttle('export_my_data');
  v := _rl_export_my_data();
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Compte'), auth.uid(), 'Export de mes données', 'Export personnel', 'Exports', 'Info');
  return v;
end $$;

create or replace function message_reports_list(p_status text default 'open', p_limit integer default 50) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  if not has_admin_permission('security.reports') then raise exception 'Action non autorisée'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', x.id, 'conversation', x.conversation_id, 'reason', x.reason, 'status', x.status, 'created_at', x.created_at,
      'reporter', (select name from profiles where id = x.reporter_id),
      'messages', coalesce((select jsonb_agg(jsonb_build_object('sender', (select name from profiles where id = m.sender_id), 'kind', m.kind, 'body', m.body, 'at', m.created_at) order by m.id)
                            from (select * from messages where conversation_id = x.conversation_id order by id desc limit 10) m), '[]'::jsonb)
    ) order by x.created_at desc), '[]'::jsonb) into v
  from (select * from message_reports where (nullif(p_status, '') is null or status = p_status) order by created_at desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) x;
  if jsonb_array_length(v) > 0 and not exists (select 1 from audit_log where actor_id = auth.uid() and action = 'Lecture des signalements de messages' and created_at > now() - interval '10 minutes') then
    insert into audit_log (actor, actor_id, action, target, category, level)
    values (coalesce((select name from profiles where id = auth.uid()), 'Modération'), auth.uid(), 'Lecture des signalements de messages', jsonb_array_length(v) || ' signalement(s) avec extraits de messages privés', 'Modération', 'Sensible');
  end if;
  return v;
end $$;

do $$
begin
  if to_regprocedure('_h132_direction_consolidated_report(date, date)') is null then
    alter function direction_consolidated_report(date, date) rename to _h132_direction_consolidated_report;
  end if;
end $$;
revoke all on function _h132_direction_consolidated_report(date, date) from public, anon, authenticated;

create or replace function direction_consolidated_report(p_from date default null, p_to date default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  v := _h132_direction_consolidated_report(p_from, p_to);
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Direction'), auth.uid(), 'Rapport consolidé de la direction', left(coalesce(v ->> 'from', '') || ' → ' || coalesce(v ->> 'to', ''), 200), 'Exports', 'Info');
  return v;
end $$;
revoke all on function direction_consolidated_report(date, date) from public, anon;
grant execute on function direction_consolidated_report(date, date) to authenticated;
