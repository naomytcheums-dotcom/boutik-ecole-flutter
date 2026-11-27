-- H13 · Administration, sécurité, performance (5/7) : exports CSV serveur de trois listes d'administration, avec permission, limite de débit et écriture au journal d'audit.
-- admin_export_csv(genre, filtres) → { kind, filename, rows, truncated, csv } ; genres :
--   'audit'          journal d'audit (permission security.audit ou tech.logs, ou administrateur) ; filtres : category (ou categories : liste), level, from, to, q (recherche dans acteur, action, cible)
--   'rattachements'  file de rattachement des comptes Département (administrateur) ; filtre : state ('all' pour inclure les comptes déjà rattachés)
--   'contestations'  contestations de score du Top 100 (permission ranking.moderate, soit l'administrateur) ; filtre : status (open · accepted · rejected)
-- Chaque export : refusé sans permission, plafonné à 5 000 lignes (« truncated » le dit), limité à 20 par heure et par compte, et journalisé (« Export CSV », Sensible) avec le nombre de lignes et les filtres.
-- Neutralisation des formules de tableur (=, +, -, @ en début de cellule). Additive et rejouable. Retour arrière : drop function admin_export_csv(text, jsonb), _h13_csv_cell(text).

create or replace function _h13_csv_cell(p_text text) returns text
language sql immutable set search_path = public as $$
  select '"' || replace(case when left(coalesce(p_text, ''), 1) in ('=', '+', '-', '@', chr(9), chr(13)) then '''' || coalesce(p_text, '') else coalesce(p_text, '') end, '"', '""') || '"'
$$;
revoke all on function _h13_csv_cell(text) from public, anon, authenticated;

insert into rpc_rate_limits (rpc, max_per_client, window_seconds, max_global, note)
values ('admin_export_csv', 20, 3600, null, 'exports CSV de l''administration')
on conflict (rpc) do nothing;

create or replace function admin_export_csv(p_kind text, p_filters jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  f jsonb := coalesce(p_filters, '{}'::jsonb);
  v_csv text; v_n integer := 0; v_trunc boolean := false; v_file text; v_desc text := '';
  v_cat text := nullif(btrim(f ->> 'category'), ''); v_lvl text := nullif(btrim(f ->> 'level'), ''); v_q text := nullif(btrim(f ->> 'q'), '');
  v_from timestamptz; v_to timestamptz; v_status text := nullif(btrim(f ->> 'status'), ''); v_state text := nullif(btrim(f ->> 'state'), '');
  v_cats text[]; r record; c_max constant integer := 5000;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if jsonb_typeof(f) <> 'object' then raise exception 'Filtres invalides'; end if;
  if p_kind = 'audit' then
    if not has_any_admin_permission(array['security.audit', 'tech.logs']) then raise exception 'Réservé : exige la permission security.audit ou tech.logs'; end if;
  elsif p_kind = 'rattachements' then
    if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  elsif p_kind = 'contestations' then
    if not has_admin_permission('ranking.moderate') then raise exception 'Réservé : exige la permission ranking.moderate'; end if;
  else
    raise exception 'Export inconnu';
  end if;
  perform _rpc_throttle('admin_export_csv');
  begin v_from := nullif(btrim(f ->> 'from'), '')::timestamptz; v_to := nullif(btrim(f ->> 'to'), '')::timestamptz; exception when others then raise exception 'Date invalide'; end;
  if jsonb_typeof(f -> 'categories') = 'array' then select coalesce(array_agg(left(x, 40)), '{}') into v_cats from jsonb_array_elements_text(f -> 'categories') x; end if;
  if v_lvl is not null and v_lvl not in ('Normal', 'Info', 'Sensible', 'Critique') then raise exception 'Niveau inconnu'; end if;
  if v_status is not null and v_status not in ('open', 'accepted', 'rejected') then raise exception 'Statut inconnu'; end if;
  if v_state is not null and v_state not in ('all', 'unattached', 'unverified', 'ambiguous') then raise exception 'État inconnu'; end if;

  if p_kind = 'audit' then
    v_file := 'journal-audit.csv';
    v_csv := '"Date";"Acteur";"Action";"Cible";"Catégorie";"Niveau"' || E'\r\n';
    for r in
      select a.created_at, a.actor, a.action, a.target, a.category, a.level from audit_log a
      where (v_cat is null or a.category = v_cat) and (v_cats is null or a.category = any (v_cats)) and (v_lvl is null or a.level = v_lvl)
        and (v_from is null or a.created_at >= v_from) and (v_to is null or a.created_at < v_to)
        and (v_q is null or strpos(lower(a.actor), lower(v_q)) > 0 or strpos(lower(a.action), lower(v_q)) > 0 or strpos(lower(a.target), lower(v_q)) > 0)
      order by a.created_at desc, a.id desc limit c_max + 1
    loop
      v_n := v_n + 1;
      if v_n > c_max then v_trunc := true; v_n := c_max; exit; end if;
      v_csv := v_csv || concat_ws(';', _h13_csv_cell(to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS')), _h13_csv_cell(r.actor), _h13_csv_cell(r.action), _h13_csv_cell(r.target), _h13_csv_cell(r.category), _h13_csv_cell(r.level)) || E'\r\n';
    end loop;
    v_desc := concat_ws(', ', 'catégorie=' || v_cat, 'niveau=' || v_lvl, case when v_from is not null then 'depuis=' || to_char(v_from, 'YYYY-MM-DD') end,
                        case when v_to is not null then 'jusqu''au=' || to_char(v_to, 'YYYY-MM-DD') end, case when v_q is not null then 'recherche=oui' end);
  elsif p_kind = 'rattachements' then
    v_file := 'rattachements-departements.csv';
    v_csv := '"Nom";"E-mail";"État";"Département déclaré";"Établissement déclaré";"Département actuel";"Compte suspendu";"Inscrit le"' || E'\r\n';
    for r in
      select p.name, p.email, _dept_attachment_state(p.id) as st, p.department, p.institution, coalesce(p.suspended, false) as susp, p.created_at,
             (select d.name from department_accounts a join departments d on d.id = a.department_id where a.user_id = p.id) as cur
      from profiles p where p.role::text = 'dept' and (coalesce(v_state, 'unattached') = 'all' or _dept_attachment_state(p.id) <> 'ok')
        and (v_state is null or v_state in ('all', 'unattached') or _dept_attachment_state(p.id) = v_state)
      order by coalesce(p.suspended, false), p.created_at, p.id limit c_max + 1
    loop
      v_n := v_n + 1;
      if v_n > c_max then v_trunc := true; v_n := c_max; exit; end if;
      v_csv := v_csv || concat_ws(';', _h13_csv_cell(r.name), _h13_csv_cell(r.email),
        _h13_csv_cell(case r.st when 'ok' then 'Rattaché' when 'unverified' then 'Département non vérifié' when 'ambiguous' then 'Nom de département ambigu' else 'Aucun rattachement' end),
        _h13_csv_cell(r.department), _h13_csv_cell(r.institution), _h13_csv_cell(r.cur), _h13_csv_cell(case when r.susp then 'Oui' else 'Non' end),
        _h13_csv_cell(to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD'))) || E'\r\n';
    end loop;
    v_desc := 'état=' || coalesce(v_state, 'unattached');
  else
    v_file := 'contestations-score.csv';
    v_csv := '"Date";"Étudiant";"Règle";"Statut de la contestation";"Statut de l''événement";"Message";"Décision";"Décidée le"' || E'\r\n';
    for r in
      select d.created_at, display_name(d.user_id) as student, e.rule_code, d.status, e.status as ev_status, d.message, d.resolution, d.decided_at
      from talent_score_disputes d join talent_events e on e.id = d.event_id where v_status is null or d.status = v_status
      order by d.created_at desc, d.id limit c_max + 1
    loop
      v_n := v_n + 1;
      if v_n > c_max then v_trunc := true; v_n := c_max; exit; end if;
      v_csv := v_csv || concat_ws(';', _h13_csv_cell(to_char(r.created_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI')), _h13_csv_cell(r.student), _h13_csv_cell(r.rule_code),
        _h13_csv_cell(case r.status when 'open' then 'Ouverte' when 'accepted' then 'Acceptée' when 'rejected' then 'Rejetée' else r.status end), _h13_csv_cell(r.ev_status), _h13_csv_cell(r.message),
        _h13_csv_cell(r.resolution), _h13_csv_cell(case when r.decided_at is null then '' else to_char(r.decided_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') end)) || E'\r\n';
    end loop;
    v_desc := 'statut=' || coalesce(v_status, 'tous');
  end if;

  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Export CSV : ' || p_kind,
          left(v_n || ' ligne(s)' || case when v_trunc then ' (tronqué à ' || c_max || ')' else '' end || case when v_desc <> '' then ' — ' || v_desc else '' end, 200), 'Exports', 'Sensible');
  return jsonb_build_object('kind', p_kind, 'filename', v_file, 'rows', v_n, 'truncated', v_trunc, 'csv', v_csv);
end $$;
revoke all on function admin_export_csv(text, jsonb) from public, anon;
grant execute on function admin_export_csv(text, jsonb) to authenticated;
