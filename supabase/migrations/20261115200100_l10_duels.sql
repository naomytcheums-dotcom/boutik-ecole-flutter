-- Lot L10 (2/5) : duels de talents (écrans 219, 220, 221).
--  1. anti-fraude minimale sur les votes : compte de 24 h au moins ou vérifié, pas de vote du créateur, dix votes par jour au plus ;
--  2. clôture réelle : close_duels() (tâche pg_cron toutes les 5 minutes) fixe le gagnant (le plus de votes, à égalité la participation la plus ancienne),
--     le persiste (duels.winner_entry_id, winner_id) et notifie le créateur, le gagnant et les participants ;
--  3. messages de validation exacts à la création et à la participation ; cinq duels par jour au plus ;
--  4. duels_list expose le gagnant, mon vote et (aux comptes connectés) l'identifiant de l'auteur pour ouvrir son dossier.
-- Le prix d'un duel reste un texte convenu entre le créateur et le gagnant : aucun séquestre n'existe pour les duels.
-- Retour arrière : voir le bas du fichier.

alter table duels add column if not exists closed_at timestamptz;
alter table duels add column if not exists winner_entry_id uuid references duel_entries(id) on delete set null;
alter table duels add column if not exists winner_id uuid references profiles(id) on delete set null;
create index if not exists duels_to_close on duels (ends_at) where closed_at is null;

create or replace function duel_create(p_need text, p_prize text, p_hours int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('admin', 'direction', 'dept', 'company', 'client') then raise exception 'Action non autorisée'; end if;
  if char_length(trim(coalesce(p_need, ''))) not between 3 and 160 then raise exception 'Besoin : 3 à 160 caractères'; end if;
  if char_length(trim(coalesce(p_prize, ''))) > 120 then raise exception 'Prix : 120 caractères au plus'; end if;
  if p_hours is null or p_hours not between 1 and 336 then raise exception 'Durée invalide (1 à 336 heures)'; end if;
  if (select count(*) from duels where created_by = auth.uid() and created_at > now() - interval '1 day') >= 5 then raise exception 'Cinq duels par jour au plus'; end if;
  insert into duels (need_title, prize, ends_at, created_by) values (trim(p_need), coalesce(trim(p_prize), ''), now() + make_interval(hours => p_hours), auth.uid()) returning id into v;
  return v;
end $$;

create or replace function duel_enter(p_duel uuid, p_title text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v uuid; d duels%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'student' then raise exception 'Réservé aux étudiants'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 2 and 160 then raise exception 'Titre de la proposition : 2 à 160 caractères'; end if;
  select * into d from duels where id = p_duel;
  if not found or d.ends_at <= now() then raise exception 'Duel terminé ou introuvable'; end if;
  if d.created_by = auth.uid() then raise exception 'Vous ne pouvez pas participer à votre propre duel'; end if;
  insert into duel_entries (duel_id, author_id, title) values (p_duel, auth.uid(), trim(p_title)) returning id into v;
  perform notify_user(d.created_by, 'duel', 'Nouvelle proposition', left('Une proposition a été déposée pour « ' || d.need_title || ' ».', 500), jsonb_build_object('duel_id', d.id));
  return v;
exception when unique_violation then raise exception 'Vous participez déjà à ce duel';
end $$;

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
  if d.created_by = auth.uid() then raise exception 'Le créateur du duel ne vote pas'; end if;
  if (select count(*) from duel_votes where voter_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix votes par jour au plus'; end if;
  insert into duel_votes (duel_id, entry_id, voter_id) values (e.duel_id, e.id, auth.uid());
exception when unique_violation then raise exception 'Vous avez déjà voté pour ce duel';
end $$;

-- Gagnant d'un duel : le plus de votes (au moins un), à égalité la participation déposée en premier.
create or replace function _duel_winner(p_duel uuid) returns table (entry_id uuid, author_id uuid, votes integer)
language sql stable security definer set search_path = public as $$
  select e.id, e.author_id, count(v.voter_id)::int
  from duel_entries e left join duel_votes v on v.entry_id = e.id
  where e.duel_id = p_duel
  group by e.id, e.author_id, e.created_at
  having count(v.voter_id) > 0
  order by count(v.voter_id) desc, e.created_at asc
  limit 1
$$;
revoke all on function _duel_winner(uuid) from public, anon, authenticated;

create or replace function close_duels() returns integer
language plpgsql security definer set search_path = public as $$
declare d record; w record; n integer := 0; p record;
begin
  for d in select * from duels where closed_at is null and ends_at <= now() order by ends_at limit 200 for update skip locked loop
    select * into w from _duel_winner(d.id);
    if found then
      update duels set closed_at = now(), winner_entry_id = w.entry_id, winner_id = w.author_id where id = d.id;
      perform notify_user(d.created_by, 'duel', 'Duel terminé', left('« ' || d.need_title || ' » : le gagnant est ' || display_name(w.author_id) || ' (' || w.votes || ' vote(s)).', 500), jsonb_build_object('duel_id', d.id, 'winner', w.author_id));
      perform notify_user(w.author_id, 'duel', 'Vous avez gagné le duel', left('« ' || d.need_title || ' »' || case when d.prize <> '' then ' · prix annoncé : ' || d.prize else '' end || '. Le créateur du duel peut vous contacter.', 500), jsonb_build_object('duel_id', d.id, 'winner', w.author_id));
      for p in select distinct e.author_id from duel_entries e where e.duel_id = d.id and e.author_id <> w.author_id loop
        perform notify_user(p.author_id, 'duel', 'Duel terminé', left('« ' || d.need_title || ' » : le gagnant est ' || display_name(w.author_id) || '.', 500), jsonb_build_object('duel_id', d.id, 'winner', w.author_id));
      end loop;
    else
      update duels set closed_at = now() where id = d.id;
      perform notify_user(d.created_by, 'duel', 'Duel terminé sans gagnant', left('« ' || d.need_title || ' » : aucun vote n''a été enregistré.', 500), jsonb_build_object('duel_id', d.id));
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function close_duels() from public, anon, authenticated;

do $$ begin
  create extension if not exists pg_cron;
  perform cron.schedule('close-duels', '*/5 * * * *', 'select public.close_duels()');
exception when others then
  raise notice 'pg_cron indisponible : les duels ne sont clôturés que si close_duels() est planifiée (%).', sqlerrm;
end $$;

create or replace function duels_list() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'need', d.need_title, 'prize', d.prize, 'ends_at', d.ends_at, 'open', d.ends_at > now(),
    'mine', d.created_by = auth.uid(),
    'winner_entry', case when d.ends_at > now() then null else coalesce(d.winner_entry_id, (select w.entry_id from _duel_winner(d.id) w)) end,
    'winner_id', case when auth.uid() is null or d.ends_at > now() then null else coalesce(d.winner_id, (select w.author_id from _duel_winner(d.id) w)) end,
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'title', e.title, 'author', coalesce(nullif(display_name(e.author_id), ''), 'Étudiant'),
                  'author_id', case when auth.uid() is not null then e.author_id end,
                  'votes', (select count(*)::int from duel_votes v where v.entry_id = e.id),
                  'my_vote', auth.uid() is not null and exists (select 1 from duel_votes v where v.entry_id = e.id and v.voter_id = auth.uid())) order by e.created_at)
                from duel_entries e where e.duel_id = d.id), '[]'::jsonb)
  ) order by d.created_at desc), '[]'::jsonb)
  from (select * from duels order by created_at desc limit 50) d;
$$;

revoke all on function duel_create(text, text, int), duel_enter(uuid, text), duel_vote(uuid) from public, anon;
grant execute on function duel_create(text, text, int), duel_enter(uuid, text), duel_vote(uuid) to authenticated;
revoke all on function duels_list() from public;
grant execute on function duels_list() to anon, authenticated;

-- Retour arrière : recréer duel_create, duel_enter, duel_vote et duels_list depuis 20261105001000 / 20261114004100 ;
--   select cron.unschedule('close-duels') ; drop function close_duels(), _duel_winner(uuid) ;
--   alter table duels drop column closed_at, drop column winner_entry_id, drop column winner_id.
