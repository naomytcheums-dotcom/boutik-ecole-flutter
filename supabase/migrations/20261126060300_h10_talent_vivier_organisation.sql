-- H10 Talent (4/5) : Enterprise Talent Cloud rattaché à l'ORGANISATION (CDC 7.4, B-731, B-733, B-738 à B-742, B-745 à B-751, B-754, B-755).
-- Avant : une liste appartenait à un COMPTE (talent_lists.owner_id) ; les membres d'équipe (company_members) ne partageaient pas le vivier ; l'écran n'envoyait jamais de note ;
-- aucun rappel, aucune comparaison, aucun historique de contact, aucune alerte.
--  1. talent_lists.org_id (organisation = propriétaire de la fiche entreprise ; pour un département ou l'administration : le compte lui-même). Rattrapage SANS PERTE : org_id = owner_id
--     pour toutes les listes existantes, avec leurs membres et notes ; un déclencheur pose org_id = owner_id si l'insertion ne le précise pas (anciens appelants).
--     L'unicité du nom passe de (compte, nom) à (organisation, nom insensible à la casse).
--  2. Droits : propriétaire et administrateurs d'équipe écrivent ; le lecteur lit ; « finance » n'a aucun accès au vivier ; une autre organisation, un tiers ou l'anonyme : refusé.
--     L'organisation doit être approuvée (les membres héritent de la vérification). Les anciens RPC talent_list* gardent leur signature et délèguent aux nouveaux pool_*.
--  3. Données privées de l'organisation (RLS fermée, RPC seulement) : étape et étiquettes par talent (talent_pool_profiles), notes internes datées et signées (talent_pool_notes),
--     historique de contact manuel (talent_pool_contacts) fusionné avec les contacts émis par la plateforme (talent_contacts), rappels (talent_pool_reminders, notification à l'échéance),
--     alertes de disponibilité (talent_pool_alerts + déclencheur sur student_availability).
--  4. pool_compare : comparaison côte à côte (compétences, niveau, années, justificatif, disponibilité, et critères d'une offre) ; seules les rubriques PARTAGÉES du passeport sont utilisées.
--  5. pool_search (filtres étape, étiquette, compétence, niveau, disponibilité, filière), pool_overview (indicateurs), pool_import_applications (candidats d'une offre -> vivier).
-- Un talent devenu invisible aux recruteurs, non vérifié ou suspendu n'est plus listé (_talent_listable) ; ses notes restent privées à l'organisation.
-- Additive et rejouable. Retour arrière : recréer talent_lists_get, talent_list_create, talent_list_delete, talent_list_add, talent_list_remove, talent_list_members_get depuis 20261118010000 ;
--   drop function pool_* , _pool_org(uuid, boolean), _pool_alert_on_availability() ; drop trigger trg_pool_alert_availability, trg_talent_lists_org ; drop table talent_pool_alerts, talent_pool_reminders,
--   talent_pool_contacts, talent_pool_notes, talent_pool_profiles ; alter table talent_lists drop column org_id (recréer unique (owner_id, name)).

alter table talent_lists add column if not exists org_id uuid references profiles (id) on delete cascade;
update talent_lists set org_id = owner_id where org_id is null;
alter table talent_lists alter column org_id set not null;
alter table talent_lists drop constraint if exists talent_lists_owner_id_name_key;
create unique index if not exists talent_lists_org_name on talent_lists (org_id, lower(name));
create index if not exists talent_lists_org on talent_lists (org_id);

create or replace function _talent_lists_org_default() returns trigger
language plpgsql set search_path = public as $$
begin
  new.org_id := coalesce(new.org_id, new.owner_id);
  return new;
end $$;
drop trigger if exists trg_talent_lists_org on talent_lists;
create trigger trg_talent_lists_org before insert on talent_lists for each row execute function _talent_lists_org_default();
alter table talent_lists alter column org_id drop not null;
alter table talent_lists alter column org_id set not null;

create table if not exists talent_pool_profiles (
  org_id uuid not null references profiles (id) on delete cascade,
  student_id uuid not null references profiles (id) on delete cascade,
  stage text check (stage is null or stage in ('candidat', 'preselectionne', 'evalue', 'recommande', 'ancien_collaborateur', 'favori', 'a_recontacter')),
  tags text[] not null default '{}' check (cardinality(tags) <= 8),
  updated_by uuid references profiles (id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (org_id, student_id)
);
create table if not exists talent_pool_notes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references profiles (id) on delete cascade,
  student_id uuid not null references profiles (id) on delete cascade,
  author_id uuid references profiles (id) on delete set null,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists talent_pool_notes_org on talent_pool_notes (org_id, student_id, created_at desc);
create table if not exists talent_pool_contacts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references profiles (id) on delete cascade,
  student_id uuid not null references profiles (id) on delete cascade,
  author_id uuid references profiles (id) on delete set null,
  channel text not null check (channel in ('message', 'appel', 'entretien', 'email', 'autre')),
  summary text not null check (char_length(btrim(summary)) between 2 and 500),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists talent_pool_contacts_org on talent_pool_contacts (org_id, student_id, occurred_at desc);
create table if not exists talent_pool_reminders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references profiles (id) on delete cascade,
  student_id uuid not null references profiles (id) on delete cascade,
  author_id uuid references profiles (id) on delete set null,
  due_on date not null,
  note text not null default '' check (char_length(note) <= 300),
  status text not null default 'ouvert' check (status in ('ouvert', 'fait')),
  notified_at timestamptz,
  done_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists talent_pool_reminders_org on talent_pool_reminders (org_id, status, due_on);
create table if not exists talent_pool_alerts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references profiles (id) on delete cascade,
  student_id uuid not null references profiles (id) on delete cascade,
  created_by uuid references profiles (id) on delete set null,
  last_notified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (org_id, student_id)
);
alter table talent_pool_profiles enable row level security;
alter table talent_pool_notes enable row level security;
alter table talent_pool_contacts enable row level security;
alter table talent_pool_reminders enable row level security;
alter table talent_pool_alerts enable row level security;
revoke all on talent_pool_profiles, talent_pool_notes, talent_pool_contacts, talent_pool_reminders, talent_pool_alerts from public, anon, authenticated;

-- Organisation visée et droit de la personne connectée : écriture = propriétaire ou administrateur d'équipe ; lecture = + lecteur ; « finance » exclu.
create or replace function _pool_org(p_org uuid, p_write boolean) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := coalesce(p_org, auth.uid()); v_role text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_org = auth.uid() then
    perform _talent_guard();
    return v_org;
  end if;
  v_role := company_role_of(v_org);
  if v_role is null or v_role = 'finance' then raise exception 'Accès refusé à cette organisation'; end if;
  if not _org_approved(v_org) then raise exception 'Votre organisation doit être vérifiée par l''administrateur avant de constituer un vivier de talents.'; end if;
  if coalesce(p_write, true) and v_role not in ('owner', 'admin') then raise exception 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  return v_org;
end $$;
revoke all on function _pool_org(uuid, boolean) from public, anon, authenticated;

create or replace function _pool_in_pool(p_org uuid, p_student uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from talent_list_members m join talent_lists l on l.id = m.list_id where l.org_id = p_org and m.student_id = p_student)
$$;
revoke all on function _pool_in_pool(uuid, uuid) from public, anon, authenticated;

-- ============================================================ listes
create or replace function pool_lists_get(p_org uuid default null, p_student uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false);
begin
  if v_org = auth.uid() then
    insert into talent_lists (owner_id, org_id, name) values (auth.uid(), v_org, 'Favoris') on conflict do nothing;
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name,
      'count', (select count(*)::int from talent_list_members m where m.list_id = l.id and _talent_listable(m.student_id)),
      'has', case when p_student is null then null else exists (select 1 from talent_list_members m where m.list_id = l.id and m.student_id = p_student) end)
      order by (l.name = 'Favoris') desc, l.name)
    from talent_lists l where l.org_id = v_org), '[]'::jsonb);
end $$;

create or replace function pool_list_create(p_name text, p_org uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_id uuid; v_name text := btrim(coalesce(p_name, ''));
begin
  if char_length(v_name) < 2 then raise exception 'Donnez un nom d''au moins 2 caractères'; end if;
  if (select count(*) from talent_lists where org_id = v_org) >= 20 then raise exception '20 listes au plus'; end if;
  if exists (select 1 from talent_lists where org_id = v_org and lower(name) = lower(v_name)) then raise exception 'Une liste porte déjà ce nom'; end if;
  insert into talent_lists (owner_id, org_id, name) values (auth.uid(), v_org, left(v_name, 40)) returning id into v_id;
  return v_id;
end $$;

create or replace function pool_list_delete(p_list uuid, p_org uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  if exists (select 1 from talent_lists where id = p_list and org_id = v_org and name = 'Favoris') then raise exception 'La liste Favoris ne peut pas être supprimée'; end if;
  delete from talent_lists where id = p_list and org_id = v_org;
end $$;

create or replace function pool_list_add(p_list uuid, p_student uuid, p_note text default '', p_org uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  if not exists (select 1 from talent_lists where id = p_list and org_id = v_org) then raise exception 'Liste introuvable'; end if;
  if not _talent_listable(p_student) or not exists (select 1 from profiles where id = p_student and role::text = 'student' and not suspended) then raise exception 'Étudiant introuvable'; end if;
  if (select count(*) from talent_list_members where list_id = p_list) >= 500 then raise exception '500 étudiants au plus par liste'; end if;
  insert into talent_list_members (list_id, student_id, note) values (p_list, p_student, left(_clean_text(p_note), 200))
  on conflict (list_id, student_id) do update set note = excluded.note;
end $$;

create or replace function pool_list_remove(p_list uuid, p_student uuid, p_org uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  delete from talent_list_members m using talent_lists l where m.list_id = l.id and l.id = p_list and l.org_id = v_org and m.student_id = p_student;
end $$;

create or replace function pool_list_members_get(p_list uuid, p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false);
begin
  if not exists (select 1 from talent_lists where id = p_list and org_id = v_org) then raise exception 'Liste introuvable'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.student_id, 'name', display_name(m.student_id), 'department', pr.department, 'note', m.note, 'added_at', m.added_at,
      'stage', pp.stage, 'tags', to_jsonb(coalesce(pp.tags, '{}'::text[])), 'available', coalesce(cardinality(av.kinds) > 0, false), 'availability', to_jsonb(coalesce(av.kinds, '{}'::text[])),
      'alert', exists (select 1 from talent_pool_alerts a where a.org_id = v_org and a.student_id = m.student_id),
      'open_reminders', (select count(*)::int from talent_pool_reminders r where r.org_id = v_org and r.student_id = m.student_id and r.status = 'ouvert'),
      'notes_count', (select count(*)::int from talent_pool_notes n where n.org_id = v_org and n.student_id = m.student_id)) order by m.added_at desc)
    from talent_list_members m join profiles pr on pr.id = m.student_id
    left join talent_pool_profiles pp on pp.org_id = v_org and pp.student_id = m.student_id
    left join student_availability av on av.user_id = m.student_id
    where m.list_id = p_list and _talent_listable(m.student_id)), '[]'::jsonb);
end $$;

-- Anciens RPC : même signature, même résultat pour le propriétaire, délégation aux versions d'organisation.
create or replace function talent_lists_get(p_student uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
begin return pool_lists_get(null, p_student); end $$;
create or replace function talent_list_create(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
begin return pool_list_create(p_name, null); end $$;
create or replace function talent_list_delete(p_list uuid) returns void
language plpgsql security definer set search_path = public as $$
begin perform pool_list_delete(p_list, null); end $$;
create or replace function talent_list_add(p_list uuid, p_student uuid, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
begin perform pool_list_add(p_list, p_student, p_note, null); end $$;
create or replace function talent_list_remove(p_list uuid, p_student uuid) returns void
language plpgsql security definer set search_path = public as $$
begin perform pool_list_remove(p_list, p_student, null); end $$;
create or replace function talent_list_members_get(p_list uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin return pool_list_members_get(p_list, null); end $$;

-- ============================================================ étape, étiquettes, notes
create or replace function pool_talent_set(p_student uuid, p_stage text, p_tags text[] default '{}', p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_tags text[];
begin
  if not _pool_in_pool(v_org, p_student) or not _talent_listable(p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  if nullif(p_stage, '') is not null and p_stage not in ('candidat', 'preselectionne', 'evalue', 'recommande', 'ancien_collaborateur', 'favori', 'a_recontacter') then raise exception 'Étape inconnue'; end if;
  select coalesce(array_agg(t order by ord), '{}') into v_tags from (
    select distinct on (lower(x)) x t, ord from (select left(_clean_text(u), 30) x, ord from unnest(coalesce(p_tags, '{}'::text[])) with ordinality as w(u, ord)) z where char_length(x) >= 2 order by lower(x), ord) d;
  if cardinality(v_tags) > 8 then raise exception '8 étiquettes au plus'; end if;
  insert into talent_pool_profiles (org_id, student_id, stage, tags, updated_by) values (v_org, p_student, nullif(p_stage, ''), v_tags, auth.uid())
  on conflict (org_id, student_id) do update set stage = excluded.stage, tags = excluded.tags, updated_by = excluded.updated_by, updated_at = now();
  return jsonb_build_object('stage', nullif(p_stage, ''), 'tags', to_jsonb(v_tags));
end $$;

create or replace function pool_note_add(p_student uuid, p_body text, p_org uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_id uuid; v_body text := left(_clean_text(p_body), 1000);
begin
  if not _pool_in_pool(v_org, p_student) or not _talent_listable(p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  if char_length(v_body) < 1 then raise exception 'Écrivez une note'; end if;
  insert into talent_pool_notes (org_id, student_id, author_id, body) values (v_org, p_student, auth.uid(), v_body) returning id into v_id;
  return v_id;
end $$;

create or replace function pool_notes_get(p_student uuid, p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); v_write boolean := company_role_of(coalesce(p_org, auth.uid())) in ('owner', 'admin') or coalesce(p_org, auth.uid()) = auth.uid();
begin
  if not _pool_in_pool(v_org, p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'body', n.body, 'created_at', n.created_at, 'author', coalesce(display_name(n.author_id), 'Un membre'), 'mine', n.author_id = auth.uid(),
      'can_delete', n.author_id = auth.uid() or v_write) order by n.created_at desc)
    from talent_pool_notes n where n.org_id = v_org and n.student_id = p_student), '[]'::jsonb);
end $$;

create or replace function pool_note_delete(p_note uuid, p_org uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  delete from talent_pool_notes where id = p_note and org_id = v_org and (author_id = auth.uid() or company_role_of(v_org) in ('owner', 'admin') or v_org = auth.uid());
  if not found then raise exception 'Note introuvable'; end if;
end $$;

-- ============================================================ historique de contact
create or replace function pool_contact_log(p_student uuid, p_channel text, p_summary text, p_org uuid default null, p_when timestamptz default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_id uuid; v_sum text := left(_clean_text(p_summary), 500);
begin
  if not _pool_in_pool(v_org, p_student) or not _talent_listable(p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  if p_channel not in ('message', 'appel', 'entretien', 'email', 'autre') then raise exception 'Canal inconnu'; end if;
  if char_length(v_sum) < 2 then raise exception 'Résumez le contact (2 caractères au moins)'; end if;
  if p_when is not null and p_when > now() + interval '1 day' then raise exception 'Un contact enregistré ne peut pas être dans le futur'; end if;
  insert into talent_pool_contacts (org_id, student_id, author_id, channel, summary, occurred_at) values (v_org, p_student, auth.uid(), p_channel, v_sum, coalesce(p_when, now())) returning id into v_id;
  return v_id;
end $$;

-- Contacts manuels de l'organisation + contacts émis par la plateforme (talent_contacts) par le propriétaire et les membres actifs.
create or replace function pool_contacts_get(p_student uuid, p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false);
begin
  if not _pool_in_pool(v_org, p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  return coalesce((select jsonb_agg(x.j order by x.at desc) from (
      select c.occurred_at at, jsonb_build_object('id', c.id, 'source', 'manuel', 'channel', c.channel, 'summary', c.summary, 'at', c.occurred_at, 'author', coalesce(display_name(c.author_id), 'Un membre')) j
      from talent_pool_contacts c where c.org_id = v_org and c.student_id = p_student
      union all
      select t.created_at, jsonb_build_object('id', t.id, 'source', 'plateforme', 'channel', case t.kind when 'internship_offer' then 'proposition_de_stage' else 'message' end,
        'summary', t.message, 'at', t.created_at, 'author', coalesce(display_name(t.sender_id), 'Un membre'))
      from talent_contacts t where t.target_id = p_student
        and (t.sender_id = v_org or exists (select 1 from company_members m where m.owner_id = v_org and m.user_id = t.sender_id and m.status = 'active'))) x), '[]'::jsonb);
end $$;

-- ============================================================ rappels
create or replace function pool_reminder_set(p_student uuid, p_due date, p_note text default '', p_org uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); v_id uuid;
begin
  if not _pool_in_pool(v_org, p_student) or not _talent_listable(p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
  if p_due is null then raise exception 'Indiquez la date du rappel'; end if;
  if p_due < current_date then raise exception 'La date du rappel ne peut pas être passée'; end if;
  if p_due > current_date + 730 then raise exception 'Rappel trop lointain (2 ans au plus)'; end if;
  if (select count(*) from talent_pool_reminders where org_id = v_org and status = 'ouvert') >= 200 then raise exception '200 rappels ouverts au plus'; end if;
  insert into talent_pool_reminders (org_id, student_id, author_id, due_on, note) values (v_org, p_student, auth.uid(), p_due, left(_clean_text(p_note), 300)) returning id into v_id;
  return v_id;
end $$;

create or replace function pool_reminder_done(p_id uuid, p_org uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  update talent_pool_reminders set status = 'fait', done_at = now() where id = p_id and org_id = v_org and status = 'ouvert';
  if not found then raise exception 'Rappel introuvable'; end if;
end $$;

-- Notification de l'auteur à l'échéance (une seule fois). Appelée à l'ouverture de la liste des rappels ; sans effet pour un autre.
create or replace function pool_reminders_dispatch(p_org uuid default null) returns integer
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); r record; v_n integer := 0;
begin
  for r in select * from talent_pool_reminders where org_id = v_org and status = 'ouvert' and due_on <= current_date and notified_at is null and author_id is not null loop
    insert into notifications (user_id, kind, title, body, data)
    values (r.author_id, 'talent_pool_reminder', 'Rappel vivier de talents', left(display_name(r.student_id) || ' : ' || coalesce(nullif(r.note, ''), 'recontacter'), 500),
            jsonb_build_object('org', v_org, 'student', r.student_id, 'reminder', r.id));
    update talent_pool_reminders set notified_at = now() where id = r.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

create or replace function pool_reminders_get(p_org uuid default null, p_include_done boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false);
begin
  perform pool_reminders_dispatch(p_org);
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'student_id', r.student_id, 'name', display_name(r.student_id), 'due_on', r.due_on, 'note', r.note, 'status', r.status,
      'due', r.status = 'ouvert' and r.due_on <= current_date, 'author', coalesce(display_name(r.author_id), 'Un membre')) order by (r.status = 'ouvert') desc, r.due_on, r.created_at)
    from talent_pool_reminders r where r.org_id = v_org and (r.status = 'ouvert' or coalesce(p_include_done, false)) and _talent_listable(r.student_id)), '[]'::jsonb);
end $$;

-- ============================================================ alertes de disponibilité
create or replace function pool_alert_set(p_student uuid, p_on boolean, p_org uuid default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true);
begin
  if coalesce(p_on, true) then
    if not _pool_in_pool(v_org, p_student) or not _talent_listable(p_student) then raise exception 'Talent introuvable dans votre vivier'; end if;
    insert into talent_pool_alerts (org_id, student_id, created_by) values (v_org, p_student, auth.uid()) on conflict (org_id, student_id) do update set created_by = excluded.created_by;
    return true;
  end if;
  delete from talent_pool_alerts where org_id = v_org and student_id = p_student;
  return false;
end $$;

create or replace function pool_alerts_get(p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false);
begin
  return coalesce((select jsonb_agg(jsonb_build_object('student_id', a.student_id, 'name', display_name(a.student_id), 'last_notified_at', a.last_notified_at,
      'available', coalesce(cardinality(av.kinds) > 0, false)) order by a.created_at)
    from talent_pool_alerts a left join student_availability av on av.user_id = a.student_id where a.org_id = v_org and _talent_listable(a.student_id)), '[]'::jsonb);
end $$;

-- Un talent surveillé devient disponible (nouvelle disponibilité déclarée) : l'auteur de l'alerte est prévenu, tant qu'il est encore autorisé et que le talent reste visible.
create or replace function _pool_alert_on_availability() returns trigger
language plpgsql security definer set search_path = public as $$
declare a record;
begin
  if cardinality(new.kinds) = 0 then return new; end if;
  if tg_op = 'UPDATE' and new.kinds <@ old.kinds then return new; end if;
  if not _talent_listable(new.user_id) then return new; end if;
  for a in select * from talent_pool_alerts where student_id = new.user_id and created_by is not null loop
    if a.org_id = a.created_by and not _org_approved(a.org_id) and coalesce((select role::text from profiles where id = a.org_id), '') in ('company', 'other') then continue; end if;
    if a.org_id <> a.created_by and not (_org_approved(a.org_id) and exists (select 1 from company_members m join profiles me on me.id = m.user_id
         where m.owner_id = a.org_id and m.user_id = a.created_by and m.status = 'active' and m.role in ('admin') and not me.suspended)) then continue; end if;
    insert into notifications (user_id, kind, title, body, data)
    values (a.created_by, 'talent_available', 'Talent disponible', left(display_name(new.user_id) || ' a indiqué une disponibilité.', 500), jsonb_build_object('org', a.org_id, 'student', new.user_id));
    update talent_pool_alerts set last_notified_at = now() where id = a.id;
  end loop;
  return new;
end $$;
drop trigger if exists trg_pool_alert_availability on student_availability;
create trigger trg_pool_alert_availability after insert or update of kinds on student_availability for each row execute function _pool_alert_on_availability();

-- ============================================================ recherche, indicateurs, import
create or replace function pool_search(p_org uuid default null, p_stage text default null, p_tag text default null, p_skill text default null, p_min_level text default null,
                                       p_available boolean default null, p_department text default null, p_list uuid default null, p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 100); v_skill text := _skill_norm(p_skill);
begin
  if p_min_level is not null and _talent_level_rank(p_min_level) is null then raise exception 'Niveau inconnu'; end if;
  if p_stage is not null and p_stage not in ('candidat', 'preselectionne', 'evalue', 'recommande', 'ancien_collaborateur', 'favori', 'a_recontacter') then raise exception 'Étape inconnue'; end if;
  return coalesce((select jsonb_agg(x.j order by x.n) from (
    select display_name(s.id) n, jsonb_build_object('id', s.id, 'name', display_name(s.id), 'department', coalesce(s.department, ''), 'stage', pp.stage, 'tags', to_jsonb(coalesce(pp.tags, '{}'::text[])),
      'available', coalesce(cardinality(av.kinds) > 0, false), 'availability', to_jsonb(coalesce(av.kinds, '{}'::text[])), 'skills', coalesce(s.skills, '')) j
    from profiles s
    left join talent_pool_profiles pp on pp.org_id = v_org and pp.student_id = s.id
    left join student_availability av on av.user_id = s.id
    where s.role::text = 'student' and _talent_listable(s.id)
      and exists (select 1 from talent_list_members m join talent_lists l on l.id = m.list_id where l.org_id = v_org and m.student_id = s.id and (p_list is null or l.id = p_list))
      and (p_stage is null or pp.stage = p_stage)
      and (nullif(btrim(p_tag), '') is null or exists (select 1 from unnest(coalesce(pp.tags, '{}'::text[])) t where lower(t) = lower(btrim(p_tag))))
      and (p_available is null or (coalesce(cardinality(av.kinds) > 0, false) = p_available))
      and (nullif(btrim(p_department), '') is null or _skill_norm(coalesce(s.department, '')) like '%' || _skill_norm(btrim(p_department)) || '%')
      and (v_skill = '' or position(v_skill in _skill_norm(coalesce(s.skills, ''))) > 0
           or (_passport_audience_ok(s.id, 'competences', v_org) and exists (select 1 from talent_skills t where t.owner_id = s.id and position(v_skill in _skill_norm(t.skill)) > 0)))
      and (p_min_level is null or (v_skill <> '' and _passport_audience_ok(s.id, 'competences', v_org) and exists (
            select 1 from talent_skills t where t.owner_id = s.id and position(v_skill in _skill_norm(t.skill)) > 0 and _talent_level_rank(t.level) >= _talent_level_rank(p_min_level))))
    limit v_lim) x), '[]'::jsonb);
end $$;

create or replace function pool_overview(p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); v_total integer; v_by jsonb;
begin
  perform pool_reminders_dispatch(p_org);
  select count(distinct m.student_id)::int into v_total from talent_list_members m join talent_lists l on l.id = m.list_id where l.org_id = v_org and _talent_listable(m.student_id);
  select coalesce(jsonb_object_agg(coalesce(z.stage, 'sans_etape'), z.n), '{}'::jsonb) into v_by from (
    select pp.stage, count(*)::int n from (select distinct m.student_id from talent_list_members m join talent_lists l on l.id = m.list_id where l.org_id = v_org and _talent_listable(m.student_id)) t
    left join talent_pool_profiles pp on pp.org_id = v_org and pp.student_id = t.student_id group by pp.stage) z;
  return jsonb_build_object('total', v_total, 'by_stage', v_by,
    'lists', (select count(*)::int from talent_lists where org_id = v_org),
    'available', (select count(distinct m.student_id)::int from talent_list_members m join talent_lists l on l.id = m.list_id join student_availability av on av.user_id = m.student_id
                  where l.org_id = v_org and cardinality(av.kinds) > 0 and _talent_listable(m.student_id)),
    'reminders_open', (select count(*)::int from talent_pool_reminders r where r.org_id = v_org and r.status = 'ouvert' and _talent_listable(r.student_id)),
    'reminders_due', (select count(*)::int from talent_pool_reminders r where r.org_id = v_org and r.status = 'ouvert' and r.due_on <= current_date and _talent_listable(r.student_id)),
    'alerts', (select count(*)::int from talent_pool_alerts a where a.org_id = v_org and _talent_listable(a.student_id)),
    'contacts_30d', (select count(*)::int from talent_pool_contacts c where c.org_id = v_org and c.occurred_at > now() - interval '30 days'),
    'my_role', coalesce(company_role_of(v_org), 'owner'));
end $$;

-- Candidats d'une offre de l'organisation -> vivier : étape « candidat » ou « présélectionné » posée seulement si aucune étape n'existe ; talents non listables ignorés.
create or replace function pool_import_applications(p_opp uuid, p_list uuid, p_org uuid default null) returns integer
language plpgsql security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, true); a record; v_n integer := 0;
begin
  if not exists (select 1 from opportunities where id = p_opp and poster_id = v_org) then raise exception 'Offre introuvable'; end if;
  if not exists (select 1 from talent_lists where id = p_list and org_id = v_org) then raise exception 'Liste introuvable'; end if;
  for a in select ap.applicant_id, ap.status from opportunity_applications ap where ap.opportunity_id = p_opp and ap.status <> 'rejected' order by ap.created_at loop
    continue when not _talent_listable(a.applicant_id) or not exists (select 1 from profiles where id = a.applicant_id and role::text = 'student' and not suspended);
    exit when (select count(*) from talent_list_members where list_id = p_list) >= 500;
    insert into talent_list_members (list_id, student_id) values (p_list, a.applicant_id) on conflict do nothing;
    insert into talent_pool_profiles (org_id, student_id, stage, updated_by)
    values (v_org, a.applicant_id, case when a.status in ('shortlisted', 'hired') then 'preselectionne' else 'candidat' end, auth.uid())
    on conflict (org_id, student_id) do update set stage = coalesce(talent_pool_profiles.stage, excluded.stage) where talent_pool_profiles.stage is null;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ============================================================ comparaison
create or replace function pool_compare(p_students uuid[], p_opp uuid default null, p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid := _pool_org(p_org, false); o opportunities%rowtype; s uuid; v_seen uuid[] := '{}'; v_talents jsonb := '[]'; v_cells jsonb := '[]'; v_rows jsonb := '[]';
        v_core jsonb; v_detail boolean; v_shared_c boolean; v_cr jsonb; v_cell jsonb; v_cores jsonb := '{}'::jsonb; v_i integer; pr profiles%rowtype;
begin
  if p_students is null or cardinality(p_students) < 2 or cardinality(p_students) > 5 then raise exception 'Choisissez de 2 à 5 talents à comparer'; end if;
  if p_opp is not null then
    select * into o from opportunities where id = p_opp and poster_id = v_org;
    if o.id is null then raise exception 'Offre introuvable'; end if;
  end if;
  foreach s in array p_students loop
    if s = any (v_seen) then raise exception 'Un talent est en double'; end if;
    v_seen := v_seen || s;
    if not (_pool_in_pool(v_org, s) or (p_opp is not null and exists (select 1 from opportunity_applications a where a.opportunity_id = p_opp and a.applicant_id = s))) or not _talent_listable(s) then
      raise exception 'Talent introuvable dans votre vivier';
    end if;
    select * into pr from profiles where id = s;
    v_shared_c := _passport_audience_ok(s, 'competences', v_org)
                  or (p_opp is not null and exists (select 1 from opportunity_applications a where a.opportunity_id = p_opp and a.applicant_id = s));
    v_talents := v_talents || jsonb_build_array(jsonb_build_object('id', s, 'name', display_name(s), 'department', coalesce(pr.department, ''), 'institution', coalesce(pr.institution, ''),
      'certified', pr.certification::text = 'approved',
      'stage', (select stage from talent_pool_profiles where org_id = v_org and student_id = s), 'tags', to_jsonb(coalesce((select tags from talent_pool_profiles where org_id = v_org and student_id = s), '{}'::text[])),
      'availability', (select jsonb_build_object('kinds', to_jsonb(a.kinds), 'available_from', a.available_from) from student_availability a where a.user_id = s),
      'skills_shared', v_shared_c,
      'skills', case when v_shared_c then coalesce((select jsonb_agg(jsonb_build_object('skill', t.skill, 'level', t.level, 'years', t.years, 'has_proof', t.proof_document_id is not null,
                                                  'proof_verified', coalesce(d.status = 'verified', false)) order by _talent_level_rank(t.level) desc, t.skill)
                                                from talent_skills t left join user_documents d on d.id = t.proof_document_id where t.owner_id = s), '[]'::jsonb)
                   else null end,
      'skills_text', case when v_shared_c then null else coalesce(pr.skills, '') end,
      'certificates', case when _passport_audience_ok(s, 'certificats', v_org) then (select count(*)::int from certificates c where c.holder_id = s and not c.revoked) else null end,
      'missions', case when _passport_audience_ok(s, 'missions', v_org) then (select count(*)::int from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = s and mp.status = 'accepted'
                                                                              where m.status in ('delivered', 'closed')) else null end,
      'notes_count', (select count(*)::int from talent_pool_notes n where n.org_id = v_org and n.student_id = s)));
    if p_opp is not null then
      v_detail := v_shared_c;
      v_core := _talent_match_core(o, s, v_detail);
      v_cores := v_cores || jsonb_build_object(s::text, v_core);
      v_talents := jsonb_set(v_talents, array[(jsonb_array_length(v_talents) - 1)::text, 'match'], jsonb_build_object('score', v_core -> 'score', 'satisfied', v_core -> 'satisfied', 'missing', v_core -> 'missing',
        'mandatory_unmet', v_core -> 'mandatory_unmet', 'meets_all_mandatory', v_core -> 'meets_all_mandatory', 'detail', v_core -> 'detail'));
    end if;
  end loop;
  if p_opp is not null then
    v_i := 0;
    for v_cr in select value from jsonb_array_elements(coalesce((v_cores -> (p_students[1])::text) -> 'criteria', '[]'::jsonb)) loop
      v_cells := '[]'::jsonb;
      foreach s in array p_students loop
        select x into v_cell from jsonb_array_elements((v_cores -> s::text) -> 'criteria') x where x ->> 'skill' = v_cr ->> 'skill' limit 1;
        v_cells := v_cells || jsonb_build_array(jsonb_build_object('student_id', s, 'status', v_cell ->> 'status', 'level', v_cell -> 'level', 'years', v_cell -> 'years', 'proof', v_cell -> 'proof'));
      end loop;
      v_rows := v_rows || jsonb_build_array(jsonb_build_object('skill', v_cr ->> 'skill', 'importance', v_cr ->> 'importance', 'min_level', v_cr -> 'min_level', 'min_years', v_cr -> 'min_years', 'cells', v_cells));
    end loop;
  end if;
  return jsonb_build_object('talents', v_talents, 'criteria', v_rows, 'opportunity', case when p_opp is null then null else jsonb_build_object('id', o.id, 'title', o.title) end,
    'automatic_decision', false, 'notice', 'La comparaison aide à choisir ; elle ne décide de rien. Seules les rubriques partagées par chaque talent sont utilisées.');
end $$;

revoke all on function pool_lists_get(uuid, uuid), pool_list_create(text, uuid), pool_list_delete(uuid, uuid), pool_list_add(uuid, uuid, text, uuid), pool_list_remove(uuid, uuid, uuid),
  pool_list_members_get(uuid, uuid), talent_lists_get(uuid), talent_list_create(text), talent_list_delete(uuid), talent_list_add(uuid, uuid, text), talent_list_remove(uuid, uuid), talent_list_members_get(uuid),
  pool_talent_set(uuid, text, text[], uuid), pool_note_add(uuid, text, uuid), pool_notes_get(uuid, uuid), pool_note_delete(uuid, uuid), pool_contact_log(uuid, text, text, uuid, timestamptz),
  pool_contacts_get(uuid, uuid), pool_reminder_set(uuid, date, text, uuid), pool_reminder_done(uuid, uuid), pool_reminders_dispatch(uuid), pool_reminders_get(uuid, boolean),
  pool_alert_set(uuid, boolean, uuid), pool_alerts_get(uuid), pool_search(uuid, text, text, text, text, boolean, text, uuid, integer), pool_overview(uuid), pool_import_applications(uuid, uuid, uuid),
  pool_compare(uuid[], uuid, uuid) from public, anon;
grant execute on function pool_lists_get(uuid, uuid), pool_list_create(text, uuid), pool_list_delete(uuid, uuid), pool_list_add(uuid, uuid, text, uuid), pool_list_remove(uuid, uuid, uuid),
  pool_list_members_get(uuid, uuid), talent_lists_get(uuid), talent_list_create(text), talent_list_delete(uuid), talent_list_add(uuid, uuid, text), talent_list_remove(uuid, uuid), talent_list_members_get(uuid),
  pool_talent_set(uuid, text, text[], uuid), pool_note_add(uuid, text, uuid), pool_notes_get(uuid, uuid), pool_note_delete(uuid, uuid), pool_contact_log(uuid, text, text, uuid, timestamptz),
  pool_contacts_get(uuid, uuid), pool_reminder_set(uuid, date, text, uuid), pool_reminder_done(uuid, uuid), pool_reminders_dispatch(uuid), pool_reminders_get(uuid, boolean),
  pool_alert_set(uuid, boolean, uuid), pool_alerts_get(uuid), pool_search(uuid, text, text, text, text, boolean, text, uuid, integer), pool_overview(uuid), pool_import_applications(uuid, uuid, uuid),
  pool_compare(uuid[], uuid, uuid) to authenticated;
