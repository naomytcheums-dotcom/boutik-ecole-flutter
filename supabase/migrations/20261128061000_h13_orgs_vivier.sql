-- H13 ORGS (2/4) : viviers de talents de l'organisation — renommage, notes réservées aux talents encore visibles, rappels fiables, export CSV consenti.
--   1. pool_list_rename(p_list, p_name, p_org) : renomme une liste de l'organisation (propriétaire ou administrateur ; « Favoris » reste fixe ; nom unique sans tenir compte de la casse).
--      pool_list_create et pool_list_rename ramènent une double soumission (deux clics) à « Une liste porte déjà ce nom » (plus d'erreur technique d'unicité).
--   2. pool_notes_get : les notes internes d'un talent qui n'est plus listable (retrait de « Me proposer aux recruteurs », vérification perdue, compte suspendu ou hors annuaire) ne sont plus lues ;
--      elles restent en base, privées à l'organisation, et reviennent si le talent redevient visible. Les notes ne sont jamais exposées au talent (tables fermées, RPC réservées aux organisations).
--   3. Rappels : pool_reminders_dispatch devient atomique (une seule notification même si deux membres ouvrent la liste en même temps), n'écrit qu'à un auteur encore autorisé (propriétaire ou
--      administrateur actif) et pour un talent encore listable ; pool_reminders_sweep() (tâche planifiée, pg_cron 07h10) fait de même pour toutes les organisations sans qu'un membre ouvre l'écran ;
--      pool_reminder_delete(p_id) retire un rappel ouvert.
--   4. pool_export(p_list, p_org) : export CSV du vivier (propriétaire et administrateurs ; lecteurs et finance refusés ; autre organisation refusée). Seuls les talents encore listables et sans
--      alerte de fraude sont exportés ; le nom complet, les compétences et les disponibilités n'y figurent que si le talent a partagé la rubrique avec les organisations (passeport) ; JAMAIS
--      d'e-mail, de téléphone ni de note interne ; neutralisation des formules de tableur (=, +, -, @) ; l'export est tracé dans le journal d'audit.
-- Additive et rejouable. Retour arrière : recréer pool_list_create, pool_notes_get, pool_reminders_dispatch (20261126060300) ; drop function pool_list_rename(uuid, text, uuid), pool_reminder_delete(uuid, uuid),
--   pool_reminders_sweep(), pool_export(uuid, uuid), _pool_author_ok(uuid, uuid), _csv_cell(text) ; select cron.unschedule('pool-reminders-sweep').

create or replace function pool_list_create(p_name text, p_org uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_id uuid; v_name text := btrim(coalesce(p_name, ''));
begin
  if char_length(v_name) < 2 then raise exception 'Donnez un nom d''au moins 2 caractères'; end if;
  if (select count(*) from talent_lists where org_id = v_org) >= 20 then raise exception '20 listes au plus'; end if;
  if exists (select 1 from talent_lists where org_id = v_org and lower(name) = lower(left(v_name, 40))) then raise exception 'Une liste porte déjà ce nom'; end if;
  begin
    insert into talent_lists (owner_id, org_id, name) values (auth.uid(), v_org, left(v_name, 40)) returning id into v_id;
  exception when unique_violation then
    raise exception 'Une liste porte déjà ce nom';
  end;
  return v_id;
end $$;

create or replace function pool_list_rename(p_list uuid, p_name text, p_org uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_name text := left(btrim(coalesce(p_name, '')), 40); l talent_lists%rowtype;
begin
  select * into l from talent_lists where id = p_list and org_id = v_org for update;
  if not found then raise exception 'Liste introuvable'; end if;
  if l.name = 'Favoris' then raise exception 'La liste Favoris ne peut pas être renommée'; end if;
  if char_length(v_name) < 2 then raise exception 'Donnez un nom d''au moins 2 caractères'; end if;
  if lower(v_name) = lower(l.name) and v_name = l.name then return v_name; end if;
  if lower(v_name) = 'favoris' or exists (select 1 from talent_lists where org_id = v_org and lower(name) = lower(v_name) and id <> l.id) then raise exception 'Une liste porte déjà ce nom'; end if;
  begin
    update talent_lists set name = v_name where id = l.id;
  exception when unique_violation then
    raise exception 'Une liste porte déjà ce nom';
  end;
  return v_name;
end $$;

-- Notes internes : lues seulement tant que le talent est visible des recruteurs.
create or replace function pool_notes_get(p_student uuid, p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); v_write boolean := company_role_of(coalesce(p_org, auth.uid())) in ('owner', 'admin') or coalesce(p_org, auth.uid()) = auth.uid();
begin
  if not _pool_in_pool(v_org, p_student) or not _talent_listable(p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'body', n.body, 'created_at', n.created_at, 'author', coalesce(display_name(n.author_id), 'Un membre'), 'mine', n.author_id = auth.uid(),
      'can_delete', n.author_id = auth.uid() or v_write) order by n.created_at desc)
    from talent_pool_notes n where n.org_id = v_org and n.student_id = p_student), '[]'::jsonb);
end $$;

-- ============================================================ rappels
create or replace function _pool_author_ok(p_org uuid, p_author uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p_author is not null and exists (select 1 from profiles a where a.id = p_author and not coalesce(a.suspended, false))
    and (p_author = p_org or exists (select 1 from company_members m where m.owner_id = p_org and m.user_id = p_author and m.status = 'active' and m.role = 'admin'))
$$;
revoke all on function _pool_author_ok(uuid, uuid) from public, anon, authenticated;

create or replace function pool_reminders_dispatch(p_org uuid default null) returns integer
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); r record; v_n integer := 0;
begin
  for r in select * from talent_pool_reminders where org_id = v_org and status = 'ouvert' and due_on <= current_date and notified_at is null and author_id is not null
           order by due_on limit 200 for update skip locked loop
    continue when not _pool_author_ok(v_org, r.author_id) or not _talent_listable(r.student_id);
    update talent_pool_reminders set notified_at = now() where id = r.id;
    insert into notifications (user_id, kind, title, body, data)
    values (r.author_id, 'talent_pool_reminder', 'Rappel vivier de talents', left(display_name(r.student_id) || ' : ' || coalesce(nullif(r.note, ''), 'recontacter'), 500),
            jsonb_build_object('org', v_org, 'student', r.student_id, 'reminder', r.id));
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

create or replace function pool_reminders_sweep() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; v_n integer := 0;
begin
  for r in select * from talent_pool_reminders where status = 'ouvert' and due_on <= current_date and notified_at is null and author_id is not null
           order by due_on limit 500 for update skip locked loop
    continue when not _pool_author_ok(r.org_id, r.author_id) or not _talent_listable(r.student_id)
      or not (_org_approved(r.org_id) or exists (select 1 from profiles o where o.id = r.org_id and o.role::text in ('dept', 'admin')));
    update talent_pool_reminders set notified_at = now() where id = r.id;
    insert into notifications (user_id, kind, title, body, data)
    values (r.author_id, 'talent_pool_reminder', 'Rappel vivier de talents', left(display_name(r.student_id) || ' : ' || coalesce(nullif(r.note, ''), 'recontacter'), 500),
            jsonb_build_object('org', r.org_id, 'student', r.student_id, 'reminder', r.id));
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke all on function pool_reminders_sweep() from public, anon, authenticated;

create or replace function pool_reminder_delete(p_id uuid, p_org uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  delete from talent_pool_reminders where id = p_id and org_id = v_org and status = 'ouvert';
  if not found then raise exception 'Rappel introuvable'; end if;
end $$;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.unschedule('pool-reminders-sweep') where exists (select 1 from cron.job where jobname = 'pool-reminders-sweep');
  perform cron.schedule('pool-reminders-sweep', '10 7 * * *', 'select public.pool_reminders_sweep()');
exception when others then
  raise notice 'pg_cron indisponible : pool_reminders_sweep() doit être planifiée autrement (%).', sqlerrm;
end $$;

-- ============================================================ export CSV
create or replace function _csv_cell(p_text text) returns text
language sql immutable set search_path = public as $$
  select '"' || replace(case when left(coalesce(p_text, ''), 1) in ('=', '+', '-', '@', chr(9), chr(13)) then '''' || coalesce(p_text, '') else coalesce(p_text, '') end, '"', '""') || '"'
$$;
revoke all on function _csv_cell(text) from public, anon, authenticated;

create or replace function pool_export(p_list uuid default null, p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); r record; v_csv text; v_n integer := 0; v_name text; v_skills text; v_avail text; v_last timestamptz; v_stage text; v_tags text;
begin
  if p_list is not null and not exists (select 1 from talent_lists where id = p_list and org_id = v_org) then raise exception 'Liste introuvable'; end if;
  v_csv := '"Nom";"Filière";"Étape";"Étiquettes";"Listes";"Disponibilité";"Compétences";"Dernier contact";"Rappels ouverts";"Ajouté le"' || E'\r\n';
  for r in
    select m.student_id, min(m.added_at) as added_at, string_agg(distinct l.name, ' | ' order by l.name) as lists
      from talent_list_members m join talent_lists l on l.id = m.list_id
     where l.org_id = v_org and (p_list is null or l.id = p_list) and _talent_listable(m.student_id)
       and not exists (select 1 from talent_fraud_flags f where f.user_id = m.student_id and f.status in ('open', 'confirmed'))
     group by m.student_id order by display_name(m.student_id), m.student_id limit 5000
  loop
    v_n := v_n + 1;
    v_name := case when _passport_audience_ok(r.student_id, 'identite', v_org) then (select name from profiles where id = r.student_id) else display_name(r.student_id) end;
    select pp.stage, array_to_string(pp.tags, ', ') into v_stage, v_tags from talent_pool_profiles pp where pp.org_id = v_org and pp.student_id = r.student_id;
    v_skills := case when _passport_audience_ok(r.student_id, 'competences', v_org)
      then (select string_agg(s.skill, ', ' order by s.skill) from (select skill from talent_skills where owner_id = r.student_id order by skill limit 15) s) else '' end;
    v_avail := case when _passport_audience_ok(r.student_id, 'disponibilites', v_org)
      then (select array_to_string(a.kinds, ', ') from student_availability a where a.user_id = r.student_id) else '' end;
    select max(x.ts) into v_last from (
      select c.occurred_at as ts from talent_pool_contacts c where c.org_id = v_org and c.student_id = r.student_id
      union all
      select t.created_at from talent_contacts t where t.target_id = r.student_id
        and (t.sender_id = v_org or exists (select 1 from company_members cm where cm.owner_id = v_org and cm.user_id = t.sender_id and cm.status = 'active'))) x;
    v_csv := v_csv || _csv_cell(v_name) || ';' || _csv_cell((select coalesce(department, '') from profiles where id = r.student_id)) || ';' || _csv_cell(coalesce(v_stage, '')) || ';'
      || _csv_cell(coalesce(v_tags, '')) || ';' || _csv_cell(r.lists) || ';' || _csv_cell(coalesce(v_avail, '')) || ';' || _csv_cell(coalesce(v_skills, '')) || ';'
      || _csv_cell(coalesce(to_char(v_last, 'YYYY-MM-DD'), '')) || ';'
      || _csv_cell((select count(*)::text from talent_pool_reminders rm where rm.org_id = v_org and rm.student_id = r.student_id and rm.status = 'ouvert')) || ';'
      || _csv_cell(to_char(r.added_at, 'YYYY-MM-DD')) || E'\r\n';
  end loop;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Export CSV du vivier de talents', v_n || ' talent(s)', 'Entreprise', 'Info');
  return jsonb_build_object('filename', 'vivier-talents-' || to_char(now(), 'YYYYMMDD') || '.csv', 'count', v_n, 'csv', v_csv, 'generated_at', now(),
    'notice', 'Export limité aux talents visibles des recruteurs ; nom complet, compétences et disponibilités uniquement s''ils les ont partagés avec les organisations ; ni e-mail, ni téléphone, ni notes internes.');
end $$;

revoke all on function pool_list_create(text, uuid), pool_list_rename(uuid, text, uuid), pool_notes_get(uuid, uuid), pool_reminders_dispatch(uuid), pool_reminder_delete(uuid, uuid),
  pool_export(uuid, uuid) from public, anon;
grant execute on function pool_list_create(text, uuid), pool_list_rename(uuid, text, uuid), pool_notes_get(uuid, uuid), pool_reminders_dispatch(uuid), pool_reminder_delete(uuid, uuid),
  pool_export(uuid, uuid) to authenticated;
