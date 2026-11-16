-- Lot S6 (4/4) : duels, ateliers et lives (S6-48, S6-49, S6-50, S6-51, S6-55, S6-68, S6-69).
--  1. duels : une proposition peut joindre un lien (visuel, portfolio, maquette) ; les participants d'un duel n'y votent plus (pas de vote pour un concurrent) ;
--     les compteurs de votes restent masqués tant que le duel est ouvert (pas d'effet d'entraînement) ; l'étudiant peut retirer sa proposition tant que le duel est ouvert ;
--     duels_list accepte une portée (ouverts / terminés) et une pagination au lieu de ne renvoyer que les 50 plus récents toutes catégories confondues ;
--  2. lives : « Prochains lives » ne montre plus les lives programmés sans date ou dont l'heure est passée depuis plus de 3 h ; lives_expire_stale() les annule
--     (appelée aussi à la création d'un live par son hôte) ; un compte étudiant doit avoir 24 h d'ancienneté (ou être vérifié) pour créer un live.
-- Retour arrière : voir le bas du fichier.

-- ============================================================ duels
alter table duel_entries add column if not exists link text;
alter table duel_entries drop constraint if exists duel_entries_link_check;
alter table duel_entries add constraint duel_entries_link_check check (link is null or (char_length(link) <= 300 and link ~ '^https?://[^[:space:]]+\.[^[:space:]]+$'));

drop function if exists duel_enter(uuid, text);
create or replace function duel_enter(p_duel uuid, p_title text, p_link text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; d duels%rowtype; v_link text := nullif(btrim(coalesce(p_link, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Réservé aux étudiants'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 2 and 160 then raise exception 'Titre de la proposition : 2 à 160 caractères'; end if;
  if v_link is not null and (char_length(v_link) > 300 or v_link !~ '^https?://[^[:space:]]+\.[^[:space:]]+$') then raise exception 'Le lien doit commencer par https:// (300 caractères au plus)'; end if;
  select * into d from duels where id = p_duel;
  if not found or d.ends_at <= now() then raise exception 'Duel terminé ou introuvable'; end if;
  if d.created_by = auth.uid() then raise exception 'Vous ne pouvez pas participer à votre propre duel'; end if;
  insert into duel_entries (duel_id, author_id, title, link) values (p_duel, auth.uid(), trim(p_title), v_link) returning id into v;
  perform notify_user(d.created_by, 'duel', 'Nouvelle proposition', left('Une proposition a été déposée pour « ' || d.need_title || ' ».', 500), jsonb_build_object('duel_id', d.id));
  return v;
exception when unique_violation then raise exception 'Vous participez déjà à ce duel';
end $$;

-- Les participants d'un duel ne votent pas dans ce duel (un vote pour un concurrent était possible).
create or replace function duel_vote(p_entry uuid) returns void
language plpgsql security definer set search_path = public as $$
declare e duel_entries%rowtype; d duels%rowtype; me profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : vote impossible'; end if;
  select * into me from profiles where id = auth.uid();
  if not (me.created_at <= now() - interval '24 hours' or me.certification::text = 'approved') then
    raise exception 'Pour voter, votre compte doit avoir au moins 24 heures ou être vérifié';
  end if;
  select * into e from duel_entries where id = p_entry;
  if not found then raise exception 'Participation introuvable'; end if;
  select * into d from duels where id = e.duel_id;
  if d.ends_at <= now() then raise exception 'Duel terminé'; end if;
  if e.author_id = auth.uid() then raise exception 'Vous ne pouvez pas voter pour vous-même'; end if;
  if exists (select 1 from duel_entries x where x.duel_id = d.id and x.author_id = auth.uid()) then raise exception 'Les participants du duel ne votent pas : seul le public départage'; end if;
  if d.created_by = auth.uid() then raise exception 'Le créateur du duel ne vote pas'; end if;
  if (select count(*) from duel_votes where voter_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix votes par jour au plus'; end if;
  insert into duel_votes (duel_id, entry_id, voter_id) values (e.duel_id, e.id, auth.uid());
exception when unique_violation then raise exception 'Vous avez déjà voté pour ce duel';
end $$;

-- Retirer sa proposition tant que le duel est ouvert (les votes qu'elle avait reçus sont libérés).
create or replace function duel_withdraw(p_duel uuid) returns text
language plpgsql security definer set search_path = public as $$
declare d duels%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into d from duels where id = p_duel;
  if not found or d.ends_at <= now() then raise exception 'Duel terminé ou introuvable'; end if;
  delete from duel_entries where duel_id = p_duel and author_id = auth.uid();
  if not found then raise exception 'Vous ne participez pas à ce duel'; end if;
  return 'withdrawn';
end $$;

-- Liste des duels : portée « open » (ouverts), « done » (terminés) ou « all », pagination (offset) ; votes masqués tant que le duel est ouvert.
drop function if exists duels_list();
create or replace function duels_list(p_scope text default 'all', p_limit integer default 50, p_offset integer default 0) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'need', d.need_title, 'prize', d.prize, 'ends_at', d.ends_at, 'open', d.ends_at > now(),
    'mine', d.created_by = auth.uid(),
    'my_entry', auth.uid() is not null and exists (select 1 from duel_entries x where x.duel_id = d.id and x.author_id = auth.uid()),
    'winner_entry', case when d.ends_at > now() then null else coalesce(d.winner_entry_id, (select w.entry_id from _duel_winner(d.id) w)) end,
    'winner_id', case when auth.uid() is null or d.ends_at > now() then null else coalesce(d.winner_id, (select w.author_id from _duel_winner(d.id) w)) end,
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'link', e.link, 'author', coalesce(nullif(display_name(e.author_id), ''), 'Étudiant'),
                  'author_id', case when auth.uid() is not null then e.author_id end,
                  'mine', auth.uid() is not null and e.author_id = auth.uid(),
                  'votes', case when d.ends_at > now() then null else (select count(*)::int from duel_votes v where v.entry_id = e.id) end,
                  'my_vote', auth.uid() is not null and exists (select 1 from duel_votes v where v.entry_id = e.id and v.voter_id = auth.uid())) order by e.created_at)
                from duel_entries e where e.duel_id = d.id), '[]'::jsonb)
  ) order by d.created_at desc), '[]'::jsonb)
  from (select * from duels x
        where case coalesce(nullif(btrim(p_scope), ''), 'all') when 'open' then x.ends_at > now() when 'done' then x.ends_at <= now() else true end
        order by x.created_at desc
        limit least(greatest(coalesce(p_limit, 50), 1), 100) offset greatest(coalesce(p_offset, 0), 0)) d;
$$;

revoke all on function duel_enter(uuid, text, text), duel_vote(uuid), duel_withdraw(uuid) from public, anon;
grant execute on function duel_enter(uuid, text, text), duel_vote(uuid), duel_withdraw(uuid) to authenticated;
revoke all on function duels_list(text, integer, integer) from public;
grant execute on function duels_list(text, integer, integer) to anon, authenticated;

-- ============================================================ lives
-- Lives programmés devenus fantômes (sans date depuis 6 h, ou date dépassée de plus de 3 h) : annulés, ce qui libère le quota de lives programmés.
create or replace function lives_expire_stale() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update lives set status = 'cancelled', ended_at = now(), viewer_count = 0
  where status = 'scheduled' and ((scheduled_at is null and created_at < now() - interval '6 hours') or scheduled_at < now() - interval '3 hours');
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function lives_expire_stale() from public, anon, authenticated;

-- « Prochains lives » : mêmes règles de date que l'agenda (lives_agenda), colonnes inchangées.
create or replace function lives_now(p_limit integer default 30)
returns table (id uuid, host_id uuid, host text, host_avatar text, host_verified boolean, title text, description text, cover_path text, status text, scheduled_at timestamptz, started_at timestamptz, viewer_count integer)
language sql stable security definer set search_path = public as $$
  select l.id, l.host_id, _live_author(l.host_id), a.avatar_url, a.certification::text = 'approved', l.title, l.description, l.cover_path, l.status, l.scheduled_at, l.started_at, l.viewer_count
  from lives l join profiles a on a.id = l.host_id and not a.suspended
  where l.status = 'live' or (l.status = 'scheduled' and l.scheduled_at is not null and l.scheduled_at > now() - interval '3 hours')
  order by (l.status = 'live') desc, coalesce(l.started_at, l.scheduled_at, l.created_at) desc
  limit least(greatest(coalesce(p_limit, 30), 1), 60)
$$;
grant execute on function lives_now(integer) to anon, authenticated;

-- Création d'un live : reprend la dernière définition (20261115170000) ; ajoute le nettoyage des lives fantômes de l'hôte et l'ancienneté d'un compte étudiant.
create or replace function create_live(p_title text, p_description text default '', p_cover_path text default null, p_scheduled_at timestamptz default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare lid uuid; v_title text := _clean_live_title(p_title); me profiles%rowtype;
begin
  perform _assert_active();
  if not _can_broadcast(auth.uid()) then raise exception 'La diffusion en direct est réservée aux étudiants, au département et aux comptes certifiés. Vous pouvez regarder tous les lives.'; end if;
  select * into me from profiles where id = auth.uid();
  if me.role::text = 'student' and me.certification::text <> 'approved' and me.created_at > now() - interval '24 hours' then
    raise exception 'Pour diffuser, votre compte étudiant doit avoir au moins 24 heures ou être vérifié. Vous pouvez déjà regarder tous les lives.';
  end if;
  if char_length(v_title) not between 3 and 100 then raise exception 'Le titre doit contenir entre 3 et 100 caractères (sans lien)'; end if;
  if p_cover_path is not null and split_part(p_cover_path, '/', 1) <> auth.uid()::text then raise exception 'Couverture invalide : déposez-la d''abord dans votre dossier'; end if;
  if p_scheduled_at is not null and (p_scheduled_at < now() + interval '1 minute' or p_scheduled_at > now() + interval '90 days') then
    raise exception 'Choisissez une date et une heure à venir (90 jours au plus)';
  end if;
  update lives set status = 'cancelled', ended_at = now(), viewer_count = 0
    where host_id = auth.uid() and status = 'scheduled' and ((scheduled_at is null and created_at < now() - interval '6 hours') or scheduled_at < now() - interval '3 hours');
  if (select count(*) from lives where host_id = auth.uid() and status = 'scheduled') >= 10 then raise exception '10 lives programmés au plus'; end if;
  insert into lives (host_id, title, description, cover_path, scheduled_at)
    values (auth.uid(), v_title, left(_clean_live_title(p_description), 500), p_cover_path, p_scheduled_at) returning id into lid;
  return lid;
end $$;
revoke all on function create_live(text, text, text, timestamptz) from public, anon;
grant execute on function create_live(text, text, text, timestamptz) to authenticated;

-- Retour arrière : recréer duel_enter(uuid, text), duel_vote(uuid) et duels_list() depuis 20261115200100_l10_duels.sql, create_live depuis 20261115170000, lives_now depuis 20261110000000 ;
--   drop function duel_enter(uuid, text, text), duel_withdraw(uuid), duels_list(text, integer, integer), lives_expire_stale() ;
--   alter table duel_entries drop column link.
