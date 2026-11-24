-- H10 SOCIAL : publications programmées fiables.
--  * publish_due_posts() ne tournait que sous pg_cron (extension parfois absente) et plus jamais depuis le client : une publication échue pouvait rester
--    « pending » indéfiniment. publish_my_due_posts() publie les seules publications échues de la personne connectée (ouverture de « Mes programmées »).
--  * schedule_post() acceptait des médias de type inconnu, un lien invalide ou plus de 10 médias/étiquettes : l'échec n'apparaissait qu'à l'échéance.
--    Ces règles de create_post_v2 sont désormais vérifiées dès la programmation.
--  * Une publication qui échoue à l'échéance prévient son auteur (notification) au lieu de rester silencieuse.
-- Retour arrière : recréer schedule_post (20261114002400) et publish_due_posts (20261113000000) ; drop function publish_my_due_posts(), _publish_scheduled_post(scheduled_posts).

create or replace function _publish_scheduled_post(r scheduled_posts) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform create_post_v2(r.caption, r.media, r.link, r.tags, null, null);
  update scheduled_posts set status = 'published', error = null where id = r.id;
  return true;
exception when others then
  update scheduled_posts set status = 'failed', error = left(sqlerrm, 300) where id = r.id;
  insert into notifications (user_id, kind, title, body, data)
    values (r.author_id, 'post', 'Publication programmée non publiée', left('Votre publication prévue n''a pas pu être publiée : ' || sqlerrm, 500), jsonb_build_object('scheduled_post', r.id));
  return false;
end $$;
revoke all on function _publish_scheduled_post(scheduled_posts) from public, anon, authenticated;

-- Tâche planifiée : publie, au nom de chaque auteur, les publications échues (50 au plus par passage).
create or replace function publish_due_posts() returns int
language plpgsql security definer set search_path = public as $$
declare r scheduled_posts%rowtype; done int := 0; old_claims text := current_setting('request.jwt.claims', true); old_sub text := current_setting('request.jwt.claim.sub', true);
begin
  for r in select * from scheduled_posts where status = 'pending' and publish_at <= now() order by publish_at limit 50 for update skip locked loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.author_id, 'role', 'authenticated')::text, true);
    perform set_config('request.jwt.claim.sub', r.author_id::text, true);
    if _publish_scheduled_post(r) then done := done + 1; end if;
  end loop;
  perform set_config('request.jwt.claims', coalesce(old_claims, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(old_sub, ''), true);
  return done;
end $$;
revoke all on function publish_due_posts() from public, anon, authenticated;

-- Repli sans pg_cron : la personne connectée publie ses propres publications échues (jamais celles d'un autre compte).
create or replace function publish_my_due_posts() returns int
language plpgsql security definer set search_path = public as $$
declare r scheduled_posts%rowtype; done int := 0;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  for r in select * from scheduled_posts where author_id = auth.uid() and status = 'pending' and publish_at <= now() order by publish_at limit 20 for update skip locked loop
    if _publish_scheduled_post(r) then done := done + 1; end if;
  end loop;
  return done;
end $$;
revoke all on function publish_my_due_posts() from public, anon;
grant execute on function publish_my_due_posts() to authenticated;

create or replace function schedule_post(p_caption text, p_media jsonb, p_link text, p_tags text[], p_at timestamptz) returns uuid
language plpgsql security definer set search_path = public as $$
declare me profiles%rowtype; sid uuid; m jsonb; v_link text := nullif(btrim(coalesce(p_link, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Publication réservée aux étudiants et au département'; end if;
  if p_at is null or p_at < now() + interval '1 minute' then raise exception 'Choisissez une date et une heure à venir'; end if;
  if p_at > now() + interval '6 months' then raise exception 'La programmation est limitée à 6 mois'; end if;
  p_media := coalesce(p_media, '[]'::jsonb);
  if jsonb_typeof(p_media) <> 'array' then raise exception 'Médias invalides'; end if;
  if jsonb_array_length(p_media) > 10 then raise exception '10 médias au plus par publication'; end if;
  if char_length(btrim(coalesce(p_caption, ''))) = 0 and jsonb_array_length(p_media) = 0 and v_link is null then raise exception 'Rien à publier'; end if;
  if v_link is not null and (v_link !~* '^https?://[^[:space:]]+$' or char_length(v_link) > 480) then raise exception 'Lien invalide : il doit commencer par http:// ou https://'; end if;
  if cardinality(coalesce(p_tags, '{}')) > 10 then raise exception '10 étiquettes au plus'; end if;
  for m in select * from jsonb_array_elements(p_media) loop
    if split_part(coalesce(m->>'path', ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
    if coalesce(m->>'kind', '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  end loop;
  if (select count(*) from scheduled_posts where author_id = auth.uid() and status = 'pending') >= 200 then raise exception '200 publications programmées au plus'; end if;
  insert into scheduled_posts (author_id, caption, media, link, tags, publish_at)
  values (auth.uid(), left(btrim(coalesce(p_caption, '')), 5000), p_media, v_link, coalesce(p_tags, '{}'), p_at) returning id into sid;
  return sid;
end $$;
revoke all on function schedule_post(text, jsonb, text, text[], timestamptz) from public, anon;
grant execute on function schedule_post(text, jsonb, text, text[], timestamptz) to authenticated;
