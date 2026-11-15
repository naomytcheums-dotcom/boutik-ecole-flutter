-- Lot L8 (profil Client) : opportunités, mentors, communautés.
--  1. Opportunités : retrait d'une candidature (l'auteur de l'offre est prévenu), score de correspondance de la personne connectée
--     (« Pourquoi cette offre ? »), offres recommandées classées par ce score, candidatures reçues sur mes offres, préférences d'alerte
--     réellement lues par les notifications (nouvelles offres de la filière, résultats de candidature).
--  2. Mentors : annulation d'une demande en attente (elle libérait enfin l'une des cinq places de demande).
--  3. Communautés : publication, chat, questions, événements et fichiers refusés tant que la communauté n'est pas validée ; liste des membres
--     réservée aux membres pour une communauté sur approbation ; annuaire paginé, filtré par type et lisible par identifiant ; recherche
--     d'une personne à inviter (responsables seulement).
-- Aucune donnée existante n'est modifiée ni supprimée. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Opportunités
create table if not exists opportunity_alert_prefs (
  user_id uuid primary key references profiles(id) on delete cascade,
  offers boolean not null default true,
  results boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table opportunity_alert_prefs enable row level security;
revoke all on opportunity_alert_prefs from anon, authenticated;

create or replace function alert_prefs_get() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('offers', coalesce((select p.offers from opportunity_alert_prefs p where p.user_id = auth.uid()), true),
                            'results', coalesce((select p.results from opportunity_alert_prefs p where p.user_id = auth.uid()), true))
$$;

create or replace function alert_prefs_set(p_offers boolean, p_results boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_offers is null or p_results is null then raise exception 'Préférences incomplètes'; end if;
  insert into opportunity_alert_prefs (user_id, offers, results) values (auth.uid(), p_offers, p_results)
  on conflict (user_id) do update set offers = excluded.offers, results = excluded.results, updated_at = now();
end $$;

-- Les personnes qui ont désactivé « nouvelles offres » ne sont plus prévenues.
create or replace function _opp_alert_matching(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; r record;
begin
  select * into o from opportunities where id = p_id;
  if not found then return; end if;
  for r in select distinct a.user_id from opportunity_alerts a
           left join opportunity_alert_prefs pf on pf.user_id = a.user_id
           where a.user_id <> o.poster_id and coalesce(pf.offers, true)
             and (o.department_target = '' or lower(o.department_target) like '%' || lower(a.department) || '%' or lower(a.department) like '%' || lower(o.department_target) || '%') limit 300 loop
    perform notify_user(r.user_id, 'opportunity_alert', 'Nouvelle offre pour votre filière', o.org_name || ' : ' || o.title, jsonb_build_object('opportunity', p_id));
  end loop;
end $$;
revoke all on function _opp_alert_matching(uuid) from public, anon, authenticated;

-- La personne qui a désactivé « résultats de candidature » n'est plus prévenue du changement de statut.
create or replace function opp_application_decide(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_status not in ('viewed', 'shortlisted', 'rejected', 'hired') then raise exception 'Statut inconnu'; end if;
  select * into a from opportunity_applications where id = p_id;
  if not found then raise exception 'Candidature introuvable'; end if;
  select * into o from opportunities where id = a.opportunity_id and poster_id = auth.uid();
  if not found then raise exception 'Candidature introuvable'; end if;
  update opportunity_applications set status = p_status where id = p_id;
  if coalesce((select pf.results from opportunity_alert_prefs pf where pf.user_id = a.applicant_id), true) then
    perform notify_user(a.applicant_id, 'opportunity_application', case p_status when 'hired' then 'Félicitations !' when 'shortlisted' then 'Candidature retenue' when 'rejected' then 'Candidature non retenue' else 'Candidature consultée' end,
      o.org_name || ' : ' || left(o.title, 60), jsonb_build_object('opportunity', o.id, 'application', p_id));
  end if;
end $$;

-- Retrait d'une candidature par la personne qui a postulé (tant qu'aucune décision définitive n'a été prise) ; l'auteur de l'offre est prévenu.
create or replace function opp_withdraw_application(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select * into a from opportunity_applications where id = p_id and applicant_id = auth.uid();
  if not found then raise exception 'Candidature introuvable'; end if;
  if a.status in ('rejected', 'hired') then raise exception 'Cette candidature a déjà reçu une réponse définitive'; end if;
  delete from opportunity_applications where id = p_id;
  select * into o from opportunities where id = a.opportunity_id;
  if found then
    perform notify_user(o.poster_id, 'opportunity_application', 'Candidature retirée', display_name(auth.uid()) || ' a retiré sa candidature à « ' || left(o.title, 60) || ' ».', jsonb_build_object('opportunity', o.id));
  end if;
end $$;
revoke all on function opp_withdraw_application(uuid) from public, anon;
grant execute on function opp_withdraw_application(uuid) to authenticated;

-- Mes candidatures : même résultat qu'avant, avec l'auteur de l'offre (pour lui écrire) et l'état de l'offre.
create or replace function opp_my_applications() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'status', a.status, 'created_at', a.created_at, 'opportunity_id', o.id, 'title', o.title, 'org', o.org_name,
      'poster_id', o.poster_id, 'offer_status', o.status, 'deadline', o.deadline,
      'published', exists (select 1 from opportunity_hires h where h.application_id = a.id)) order by a.created_at desc), '[]'::jsonb)
  from opportunity_applications a join opportunities o on o.id = a.opportunity_id where a.applicant_id = auth.uid()
$$;

-- Score de correspondance de la personne connectée avec une offre publiée, détaillé (compétences retrouvées ou manquantes, filière, disponibilité, profil).
create or replace function opp_my_match(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype; pr profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_id and status = 'published';
  if not found then raise exception 'Offre introuvable'; end if;
  select * into pr from profiles where id = auth.uid();
  return coalesce(_opp_match(o, auth.uid()), '{}'::jsonb) || jsonb_build_object(
    'id', o.id, 'title', o.title, 'org', o.org_name, 'iut_only', o.iut_only, 'department_target', o.department_target, 'my_department', coalesce(pr.department, ''),
    'applied', exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = auth.uid()),
    'mine', o.poster_id = auth.uid(),
    'skills_detail', coalesce((
      select jsonb_agg(jsonb_build_object('skill', btrim(sk), 'found', exists (
        select 1 from regexp_split_to_table(lower(coalesce(pr.skills, '')), '[,;\n•]+') t
        where btrim(t) <> '' and (btrim(t) like '%' || lower(btrim(sk)) || '%' or lower(btrim(sk)) like '%' || btrim(t) || '%'))))
      from unnest(o.skills) sk where btrim(sk) <> ''), '[]'::jsonb));
end $$;
revoke all on function opp_my_match(uuid) from public, anon;
grant execute on function opp_my_match(uuid) to authenticated;

-- Offres recommandées : publiées, non échues, ni les miennes ni celles où j'ai déjà postulé, classées par score de correspondance.
create or replace function opps_recommended(p_limit integer default 10) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_inst text; v_lim integer := least(greatest(coalesce(p_limit, 10), 1), 30);
begin
  if uid is null then return '[]'::jsonb; end if;
  select lower(coalesce(institution, '')) into v_inst from profiles where id = uid;
  return coalesce((
    select jsonb_agg(y.c order by y.s desc, y.created desc) from (
      select x.c, coalesce((x.c->'match'->>'score')::int, 0) s, x.c->>'created_at' created from (
        select _opp_card(o, uid) || jsonb_build_object('match', _opp_match(o, uid)) c
        from opportunities o
        where o.status = 'published' and (o.deadline is null or o.deadline >= current_date) and o.poster_id <> uid
          and (not o.iut_only or coalesce(v_inst, '') like '%iut%')
          and not exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = uid)
        order by o.created_at desc limit 200) x
      order by 2 desc, 3 desc limit v_lim) y), '[]'::jsonb);
end $$;
revoke all on function opps_recommended(integer) from public, anon;
grant execute on function opps_recommended(integer) to authenticated;

-- Candidatures reçues sur toutes mes offres, avec le score de chaque candidat (les mieux classés d'abord).
create or replace function opp_applications_received(p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_lim integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(z.j order by z.s desc, z.j->>'created_at' desc) from (
      select jsonb_build_object('id', a.id, 'opportunity_id', o.id, 'title', o.title, 'applicant_id', a.applicant_id, 'name', display_name(a.applicant_id), 'department', coalesce(pr.department, ''),
               'status', a.status, 'created_at', a.created_at, 'match', _opp_match(o, a.applicant_id)) j,
             coalesce((_opp_match(o, a.applicant_id)->>'score')::int, 0) s
      from opportunity_applications a join opportunities o on o.id = a.opportunity_id join profiles pr on pr.id = a.applicant_id
      where o.poster_id = auth.uid()
      order by a.created_at desc limit v_lim) z), '[]'::jsonb);
end $$;
revoke all on function opp_applications_received(integer) from public, anon;
grant execute on function opp_applications_received(integer) to authenticated;

revoke all on function alert_prefs_get(), alert_prefs_set(boolean, boolean) from public, anon;
grant execute on function alert_prefs_get(), alert_prefs_set(boolean, boolean) to authenticated;

-- ============================================================ 2. Mentors : annuler une demande en attente
create or replace function mentor_request_cancel(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from mentor_requests where id = p_id and student_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'requested' then raise exception 'Seule une demande en attente peut être annulée'; end if;
  update mentor_requests set status = 'cancelled', decided_at = now() where id = p_id;
  return 'cancelled';
end $$;
revoke all on function mentor_request_cancel(uuid) from public, anon;
grant execute on function mentor_request_cancel(uuid) to authenticated;

-- ============================================================ 3. Communautés
-- Une communauté en attente de validation, refusée ou suspendue n'accepte ni publication, ni chat, ni question, ni événement, ni fichier.
create or replace function _community_is_active(p_community uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from communities where id = p_community and status = 'active')
$$;
revoke all on function _community_is_active(uuid) from public, anon, authenticated;

create or replace function create_community_post(p_community uuid, p_body text, p_style text default null, p_media_path text default null, p_media_kind text default null, p_link text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_body text := btrim(coalesce(p_body, '')); v_link text := nullif(btrim(coalesce(p_link, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _community_is_active(p_community) then raise exception 'Cette communauté n''est pas encore validée'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 1 and 2000 then raise exception 'La publication doit contenir entre 1 et 2000 caractères'; end if;
  if p_style is not null and char_length(v_body) > 280 then raise exception 'Avec un fond design, le texte est limité à 280 caractères'; end if;
  if p_media_path is not null then
    if split_part(p_media_path, '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
    if coalesce(p_media_kind, '') not in ('image', 'video') then raise exception 'Type de média inconnu'; end if;
    if p_style is not null then raise exception 'Un fond design ne se combine pas avec une photo ou une vidéo'; end if;
  end if;
  if v_link is not null and (v_link !~* '^https?://[^ ]+$' or char_length(v_link) > 500) then raise exception 'Le lien doit commencer par https:// et ne pas contenir d''espace'; end if;
  if (select count(*) from posts where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de publications en peu de temps. Réessayez dans une minute.'; end if;
  insert into posts (author_id, kind, body, community_id, status, published_at, style, media_path, media_kind, link_url)
    values (auth.uid(), 'text', v_body, p_community, 'published', now(), p_style, p_media_path, case when p_media_path is null then null else p_media_kind end, v_link) returning id into v_id;
  return v_id;
end $$;

create or replace function community_chat_send(p_community uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_id bigint; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _community_is_active(p_community) then raise exception 'Cette communauté n''est pas encore validée'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 1 and 1000 then raise exception 'Un message contient de 1 à 1000 caractères'; end if;
  if (select count(*) from community_messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then raise exception 'Trop de messages en peu de temps. Réessayez dans une minute.'; end if;
  insert into community_messages (community_id, sender_id, body) values (p_community, auth.uid(), v_body) returning id into v_id;
  return v_id;
end $$;

create or replace function community_ask(p_community uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _community_is_active(p_community) then raise exception 'Cette communauté n''est pas encore validée'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(v_body) not between 5 and 600 then raise exception 'Posez votre question en 5 à 600 caractères'; end if;
  if (select count(*) from community_questions where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then raise exception 'Trop de questions en peu de temps. Réessayez dans une minute.'; end if;
  insert into community_questions (community_id, author_id, body) values (p_community, auth.uid(), v_body) returning id into v_id;
  return v_id;
end $$;

create or replace function community_event_create(p_community uuid, p_title text, p_kind text, p_starts timestamptz, p_place text default '', p_description text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _community_is_active(p_community) then raise exception 'Cette communauté n''est pas encore validée'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 100 then raise exception 'Le titre contient de 3 à 100 caractères'; end if;
  if p_kind not in ('meeting', 'live', 'revision', 'other') then raise exception 'Type d''événement inconnu'; end if;
  if p_starts is null or p_starts < now() - interval '1 hour' then raise exception 'La date doit être dans le futur'; end if;
  if (select count(*) from community_events where creator_id = auth.uid() and created_at > now() - interval '1 hour') >= 5 then raise exception 'Trop d''événements créés en peu de temps'; end if;
  insert into community_events (community_id, creator_id, title, kind, starts_at, place, description)
    values (p_community, auth.uid(), btrim(p_title), p_kind, p_starts, left(btrim(coalesce(p_place, '')), 100), left(btrim(coalesce(p_description, '')), 500)) returning id into v_id;
  insert into community_event_rsvps (event_id, user_id) values (v_id, auth.uid());
  for r in select user_id from community_members where community_id = p_community and status = 'active' and user_id <> auth.uid() limit 200 loop
    perform notify_user(r.user_id, 'community_event', 'Nouvel événement', btrim(p_title) || ' · ' || to_char(p_starts at time zone 'Africa/Douala', 'DD/MM HH24:MI'), jsonb_build_object('community', p_community, 'event', v_id));
  end loop;
  return v_id;
end $$;

create or replace function community_file_add(p_community uuid, p_title text, p_kind text, p_path text, p_size integer, p_mime text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not _community_is_active(p_community) then raise exception 'Cette communauté n''est pas encore validée'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 2 and 120 then raise exception 'Le titre contient de 2 à 120 caractères'; end if;
  if p_kind not in ('course', 'pdf', 'exam', 'template', 'other') then raise exception 'Type de fichier inconnu'; end if;
  if left(coalesce(p_path, ''), 37) <> p_community::text || '/' then raise exception 'Chemin de fichier invalide'; end if;
  if (select count(*) from community_files where uploader_id = auth.uid() and created_at > now() - interval '1 hour') >= 20 then raise exception 'Trop de fichiers déposés en peu de temps'; end if;
  insert into community_files (community_id, uploader_id, title, kind, path, size_bytes, mime)
    values (p_community, auth.uid(), btrim(p_title), p_kind, p_path, greatest(coalesce(p_size, 0), 0), left(coalesce(p_mime, ''), 120)) returning id into v_id;
  return v_id;
end $$;

-- Liste des membres : seule une communauté publique est lisible par tout compte connecté (approbation et invitation : membres et équipe).
create or replace function community_members_list(p_community uuid, p_limit integer default 100)
returns table (user_id uuid, name text, role text, joined_at timestamptz, mine boolean)
language sql stable security definer set search_path = public as $$
  select m.user_id, display_name(m.user_id), m.role, m.created_at, m.user_id = auth.uid()
  from community_members m join communities c on c.id = m.community_id
  where m.community_id = p_community and m.status = 'active' and c.status = 'active'
    and (c.privacy = 'public' or is_community_member(c.id) or is_platform_staff())
  order by case m.role when 'owner' then 0 when 'admin' then 1 when 'moderator' then 2 when 'mentor' then 3 else 4 end, m.created_at
  limit least(greatest(coalesce(p_limit, 100), 1), 300)
$$;

-- Annuaire : pagination (p_offset), filtre par type (p_kind) et lecture d'une seule communauté (p_id), en plus de la recherche existante.
drop function if exists communities_list(text, integer);
create or replace function communities_list(p_query text default '', p_limit integer default 30, p_offset integer default 0, p_kind text default null, p_id uuid default null)
returns table (id uuid, name text, description text, category text, privacy text, members integer, my_status text, my_role text, status text, department text, decision_note text,
               kind text, promo_year text, interest text, official boolean, created_at timestamptz, last_activity timestamptz, posts_week integer, owner_kind text, expires_at timestamptz)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.category, c.privacy,
         (select count(*)::int from community_members m where m.community_id = c.id and m.status = 'active'),
         (select m.status from community_members m where m.community_id = c.id and m.user_id = auth.uid()),
         (select m.role from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status = 'active'),
         c.status, d.name, c.decision_note,
         c.kind, c.promo_year, c.interest, c.official, c.created_at,
         (select max(p.published_at) from posts p where p.community_id = c.id and p.status = 'published'),
         (select count(*)::int from posts p where p.community_id = c.id and p.status = 'published' and p.published_at > now() - interval '7 days'),
         (select case when o.role::text in ('dept', 'direction') then 'teacher' when o.role::text = 'student' then 'student' else 'staff' end from profiles o where o.id = c.owner_id),
         c.expires_at
  from communities c left join departments d on d.id = c.department_id
  where (c.expires_at is null or c.expires_at > now())
    and (p_id is null or c.id = p_id)
    and (nullif(btrim(coalesce(p_kind, '')), '') is null or c.kind = btrim(p_kind))
    and (
      (c.status = 'active' and (c.privacy in ('public', 'approval') or exists (select 1 from community_members m where m.community_id = c.id and m.user_id = auth.uid() and m.status in ('active', 'invited'))))
      or (c.owner_id = auth.uid() and c.status in ('pending', 'rejected'))
    )
    and (coalesce(btrim(p_query), '') = '' or c.name ilike '%' || btrim(p_query) || '%' or c.category ilike '%' || btrim(p_query) || '%' or d.name ilike '%' || btrim(p_query) || '%'
         or coalesce(c.interest, '') ilike '%' || btrim(p_query) || '%' or coalesce(c.promo_year, '') ilike '%' || btrim(p_query) || '%' or c.description ilike '%' || btrim(p_query) || '%')
  order by (c.status <> 'active') desc, 6 desc, c.created_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100) offset greatest(coalesce(p_offset, 0), 0)
$$;
revoke all on function communities_list(text, integer, integer, text, uuid) from public, anon;
grant execute on function communities_list(text, integer, integer, text, uuid) to authenticated, anon;

-- Recherche d'une personne à inviter (propriétaire, administrateurs et modérateurs seulement) : nom abrégé et filière, personnes déjà liées exclues.
create or replace function community_invite_search(p_community uuid, p_q text, p_limit integer default 10)
returns table (user_id uuid, name text, department text)
language plpgsql stable security definer set search_path = public as $$
declare v_q text := replace(replace(replace(btrim(coalesce(p_q, '')), '\', '\\'), '%', '\%'), '_', '\_');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if community_rank(p_community, auth.uid()) < 2 then raise exception 'Action non autorisée'; end if;
  if char_length(btrim(coalesce(p_q, ''))) < 3 then return; end if;
  return query
    select p.id, display_name(p.id), coalesce(p.department, '')
    from profiles p
    where not coalesce(p.suspended, false) and p.id <> auth.uid() and p.name ilike '%' || v_q || '%'
      and not exists (select 1 from community_members m where m.community_id = p_community and m.user_id = p.id)
    order by p.name
    limit least(greatest(coalesce(p_limit, 10), 1), 20);
end $$;
revoke all on function community_invite_search(uuid, text, integer) from public, anon;
grant execute on function community_invite_search(uuid, text, integer) to authenticated;

-- RETOUR ARRIÈRE : drop function opp_withdraw_application(uuid), opp_my_match(uuid), opps_recommended(integer), opp_applications_received(integer), alert_prefs_get(), alert_prefs_set(boolean, boolean),
--   mentor_request_cancel(uuid), community_invite_search(uuid, text, integer), _community_is_active(uuid), communities_list(text, integer, integer, text, uuid) ; drop table opportunity_alert_prefs ;
--   recréer opp_my_applications, _opp_alert_matching et opp_application_decide (20261114001300), create_community_post (20261114001700), community_chat_send, community_ask, community_event_create, community_file_add (20261114001000),
--   community_members_list (20261111000000), communities_list(text, integer) (20261114001200).
