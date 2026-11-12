-- Trouver des coéquipiers : recherche d'étudiants par compétence, filière ou nom, catégories de filtre gérées par l'administrateur (ajout, modification, suppression
-- depuis l'application, sans nouvelle version), et invitation d'équipe avec réponse (acceptée ou déclinée) notifiée à l'étudiant qui invite.
-- Retour arrière : drop function mate_categories_list(), mate_category_save(uuid, text, text[], integer, boolean), mate_category_delete(uuid), mates_search(text, uuid, text, integer),
--   teammate_invite(uuid, text), teammate_invite_decide(uuid, boolean), my_teammate_invites(text); drop table teammate_invites, mate_categories.

create table if not exists mate_categories (
  id uuid primary key default gen_random_uuid(),
  label text not null check (char_length(btrim(label)) between 2 and 40),
  keywords text[] not null default '{}' check (cardinality(keywords) between 1 and 30),
  position integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index if not exists mate_categories_label on mate_categories (lower(label));
alter table mate_categories enable row level security;
revoke all on mate_categories from anon, authenticated;

insert into mate_categories (label, keywords, position) values
  ('Développeurs', array['dev', 'développ', 'developp', 'code', 'flutter', 'web', 'api', 'informatique', 'python', 'java', 'javascript', 'mobile', 'logiciel', 'react'], 1),
  ('Designers', array['design', 'graph', 'ui', 'ux', 'figma', 'photo', 'vidéo', 'video', 'montage', 'motion', 'audiovisuel', 'identité', 'illustration'], 2),
  ('Business', array['business', 'gestion', 'marketing', 'vente', 'commerce', 'finance', 'entrepreneu', 'comptab'], 3),
  ('IA et data', array['ia', 'data', 'machine', 'learning', 'analyse', 'statisti', 'intelligence'], 4)
on conflict do nothing;

create table if not exists teammate_invites (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references profiles(id) on delete cascade,
  to_user uuid not null references profiles(id) on delete cascade,
  message text not null default '' check (char_length(message) <= 500),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  check (from_user <> to_user)
);
create index if not exists teammate_invites_to on teammate_invites (to_user, created_at desc);
create index if not exists teammate_invites_from on teammate_invites (from_user, created_at desc);
alter table teammate_invites enable row level security;
revoke all on teammate_invites from anon, authenticated;

create or replace function mate_categories_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', c.id, 'label', c.label, 'keywords', to_jsonb(c.keywords), 'position', c.position, 'active', c.active) order by c.position, c.label), '[]'::jsonb)
  from mate_categories c where c.active or coalesce(current_role_name()::text, '') = 'admin'
$$;

create or replace function mate_category_save(p_id uuid, p_label text, p_keywords text[], p_position integer default 0, p_active boolean default true) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_kw text[];
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if char_length(btrim(coalesce(p_label, ''))) < 2 then raise exception 'Donnez un nom à la catégorie'; end if;
  select array_agg(distinct lower(btrim(k))) into v_kw from unnest(coalesce(p_keywords, '{}'::text[])) k where char_length(btrim(k)) between 1 and 40;
  if v_kw is null then raise exception 'Indiquez au moins un mot-clé de compétence'; end if;
  if p_id is null then
    insert into mate_categories (label, keywords, position, active) values (btrim(p_label), v_kw, coalesce(p_position, 0), coalesce(p_active, true)) returning id into v_id;
  else
    update mate_categories set label = btrim(p_label), keywords = v_kw, position = coalesce(p_position, 0), active = coalesce(p_active, true) where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Catégorie introuvable'; end if;
  end if;
  return v_id;
exception when unique_violation then raise exception 'Une catégorie porte déjà ce nom';
end $$;

create or replace function mate_category_delete(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  delete from mate_categories where id = p_id;
  if not found then raise exception 'Catégorie introuvable'; end if;
end $$;

-- Recherche d'étudiants qui ont renseigné leurs compétences ; jamais soi-même ; filtre par catégorie (mots-clés), filière et texte libre.
create or replace function mates_search(p_query text default '', p_category uuid default null, p_department text default '', p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_kw text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_category is not null then select keywords into v_kw from mate_categories where id = p_category and active; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', display_name(t.id), 'department', coalesce(t.department, ''), 'skills', coalesce(t.skills, ''), 'avatar_url', t.avatar_url,
      'certified', t.certification::text = 'approved',
      'invite', (select i.status from teammate_invites i where i.from_user = auth.uid() and i.to_user = t.id order by i.created_at desc limit 1)) order by (t.certification::text = 'approved') desc, t.created_at desc)
    from (select * from profiles
          where role::text = 'student' and not coalesce(suspended, false) and id <> auth.uid() and nullif(btrim(coalesce(skills, '')), '') is not null
            and (nullif(btrim(coalesce(p_query, '')), '') is null or name ilike '%' || btrim(p_query) || '%' or skills ilike '%' || btrim(p_query) || '%' or coalesce(department, '') ilike '%' || btrim(p_query) || '%')
            and (nullif(btrim(coalesce(p_department, '')), '') is null or coalesce(department, '') ilike '%' || btrim(p_department) || '%')
            and (v_kw is null or exists (select 1 from unnest(v_kw) k where lower(skills || ' ' || coalesce(department, '')) ~ ('(^|[^a-zà-ÿ0-9])' || regexp_replace(k, '([.*+?^$()\[\]{}|\\])', '\\\1', 'g'))))
          order by created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) t), '[]'::jsonb);
end $$;

create or replace function teammate_invite(p_user uuid, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous inviter vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user and role::text = 'student' and not coalesce(suspended, false)) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from teammate_invites where from_user = auth.uid() and to_user = p_user and status = 'pending') then raise exception 'Une invitation est déjà en attente pour cet étudiant'; end if;
  if (select count(*) from teammate_invites where from_user = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix invitations par jour au plus'; end if;
  insert into teammate_invites (from_user, to_user, message) values (auth.uid(), p_user, left(btrim(coalesce(p_message, '')), 500)) returning id into v_id;
  perform notify_user(p_user, 'teammate_invite', 'Invitation d''équipe', display_name(auth.uid()) || ' vous invite à rejoindre son équipe.', jsonb_build_object('invite', v_id));
  return v_id;
end $$;

create or replace function teammate_invite_decide(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare i teammate_invites%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into i from teammate_invites where id = p_id and to_user = auth.uid();
  if not found then raise exception 'Invitation introuvable'; end if;
  if i.status <> 'pending' then raise exception 'Cette invitation a déjà reçu une réponse'; end if;
  update teammate_invites set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where id = p_id;
  perform notify_user(i.from_user, 'teammate_invite', case when p_accept then 'Invitation acceptée' else 'Invitation déclinée' end,
    display_name(auth.uid()) || case when p_accept then ' rejoint votre équipe : écrivez-lui pour vous organiser.' else ' ne peut pas rejoindre votre équipe.' end, jsonb_build_object('invite', p_id));
  return case when p_accept then 'accepted' else 'declined' end;
end $$;

create or replace function my_teammate_invites(p_role text default 'received') returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'status', i.status, 'message', i.message, 'created_at', i.created_at,
      'other_id', case when p_role = 'sent' then i.to_user else i.from_user end, 'other', display_name(case when p_role = 'sent' then i.to_user else i.from_user end)) order by i.created_at desc), '[]'::jsonb)
  from teammate_invites i where case when p_role = 'sent' then i.from_user = auth.uid() else i.to_user = auth.uid() end
$$;

revoke all on function mate_category_save(uuid, text, text[], integer, boolean), mate_category_delete(uuid), mates_search(text, uuid, text, integer), teammate_invite(uuid, text),
  teammate_invite_decide(uuid, boolean), my_teammate_invites(text) from public, anon;
grant execute on function mate_category_save(uuid, text, text[], integer, boolean), mate_category_delete(uuid), mates_search(text, uuid, text, integer), teammate_invite(uuid, text),
  teammate_invite_decide(uuid, boolean), my_teammate_invites(text) to authenticated;
revoke all on function mate_categories_list() from public;
grant execute on function mate_categories_list() to anon, authenticated;
