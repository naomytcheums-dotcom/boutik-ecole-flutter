-- Publier (photo, vidéo, histoire, programmation) et créer un live ne sont plus réservés aux étudiants : tous les profils connectés non suspendus
-- (client, étudiant-vendeur, entreprise, autre rôle, équipe) remplissent leur profil et publient. Les actions propres aux étudiants restent réservées
-- (répondre à un besoin d'entreprise, soumettre un projet, inscrire une équipe à un concours, duels).
-- Retour arrière : rejouer les définitions de create_post, create_post_v2, create_story, schedule_post, create_live et save_live depuis
--   20261101000600_reels_defis.sql, 20261110000000_reseau_social_live.sql, 20261113000000_reseau_avance.sql et leurs successeurs (condition de rôle d'origine).

CREATE OR REPLACE FUNCTION public.create_live(p_title text, p_description text DEFAULT ''::text, p_cover_path text DEFAULT NULL::text, p_scheduled_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me profiles%rowtype; lid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Les Lives sont réservés aux étudiants et au département'; end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 3 and 100 then raise exception 'Le titre doit contenir entre 3 et 100 caractères'; end if;
  if p_cover_path is not null and split_part(p_cover_path, '/', 1) <> auth.uid()::text then raise exception 'Couverture invalide : déposez-la d''abord dans votre dossier'; end if;
  if (select count(*) from lives where host_id = auth.uid() and status = 'scheduled') >= 10 then raise exception '10 lives programmés au plus'; end if;
  insert into lives (host_id, title, description, cover_path, scheduled_at) values (auth.uid(), btrim(p_title), left(btrim(coalesce(p_description, '')), 500), p_cover_path, p_scheduled_at) returning id into lid;
  return lid;
end $function$;

CREATE OR REPLACE FUNCTION public.create_post(p_media_path text, p_media_kind text, p_caption text, p_tags text[], p_listing uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me profiles%rowtype; pid uuid; st text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Publication réservée aux étudiants et au département'; end if;
  if p_media_path is null or split_part(p_media_path, '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  if p_listing is not null and not exists (select 1 from listings where id = p_listing and seller_id = auth.uid() and status = 'approved') then
    raise exception 'Le lien « Boutique » ne peut viser qu''une de vos annonces validées';
  end if;
  st := case when me.certification = 'approved' or me.role::text in ('dept', 'admin') then 'published' else 'pending' end;
  insert into posts (author_id, media_path, media_kind, caption, tags, listing_id, status, published_at)
    values (auth.uid(), p_media_path, p_media_kind, left(trim(coalesce(p_caption, '')), 300),
            coalesce((select array_agg(distinct lower(left(trim(t), 30))) from unnest(coalesce(p_tags, '{}')) t where trim(t) <> ''), '{}'),
            p_listing, st, case when st = 'published' then now() end)
    returning id into pid;
  return jsonb_build_object('id', pid, 'status', st);
end $function$;

CREATE OR REPLACE FUNCTION public.create_post_v2(p_caption text, p_media jsonb, p_link text, p_tags text[], p_listing uuid, p_repost_of uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me profiles%rowtype; pid uuid; st text; m jsonb; i int := 0; n int; first_path text; first_kind text; txt text; lnk text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Publication réservée aux étudiants et au département'; end if;
  p_media := coalesce(p_media, '[]'::jsonb);
  if jsonb_typeof(p_media) <> 'array' then raise exception 'Médias invalides'; end if;
  n := jsonb_array_length(p_media);
  if n > 10 then raise exception '10 médias au plus par publication'; end if;
  txt := left(btrim(coalesce(p_caption, '')), 2000);
  lnk := nullif(btrim(coalesce(p_link, '')), '');
  if lnk is not null and lnk !~* '^https?://[^[:space:]]+$' or char_length(lnk) > 480 then raise exception 'Lien invalide : il doit commencer par http:// ou https://'; end if;
  if n = 0 and txt = '' and lnk is null and p_repost_of is null then raise exception 'Écrivez un texte ou ajoutez un média, un lien ou une republication'; end if;
  if p_repost_of is not null and not exists (select 1 from posts where id = p_repost_of and status = 'published') then raise exception 'Publication à republier introuvable'; end if;
  if p_listing is not null and not exists (select 1 from listings where id = p_listing and seller_id = auth.uid() and status = 'approved') then
    raise exception 'Le lien « Boutique » ne peut viser qu''une de vos annonces validées';
  end if;
  for m in select * from jsonb_array_elements(p_media) loop
    if split_part(coalesce(m->>'path', ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
    if coalesce(m->>'kind', '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  end loop;
  if n > 0 then
    first_path := p_media->0->>'path';
    first_kind := p_media->0->>'kind';
  end if;
  st := case when me.certification = 'approved' or me.role::text in ('dept', 'admin') then 'published' else 'pending' end;
  insert into posts (author_id, kind, media_path, media_kind, caption, body, link_url, repost_of, tags, listing_id, status, published_at)
    values (auth.uid(), case when n > 0 then 'media' else 'text' end, first_path, first_kind,
            case when n > 0 then left(txt, 300) else '' end, case when n = 0 then nullif(txt, '') end, lnk, p_repost_of,
            coalesce((select array_agg(distinct lower(left(trim(t), 30))) from unnest(coalesce(p_tags, '{}')) t where trim(t) <> ''), '{}'),
            p_listing, st, case when st = 'published' then now() end)
    returning id into pid;
  for m in select * from jsonb_array_elements(p_media) loop
    insert into post_media (post_id, pos, path, kind, width, height)
      values (pid, i, m->>'path', m->>'kind', nullif(m->>'w', '')::int, nullif(m->>'h', '')::int);
    i := i + 1;
  end loop;
  return jsonb_build_object('id', pid, 'status', st);
end $function$;

CREATE OR REPLACE FUNCTION public.create_story(p_path text, p_kind text, p_caption text DEFAULT ''::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me profiles%rowtype; sid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Histoires réservées aux étudiants et au département'; end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  if coalesce(p_kind, '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  if (select count(*) from stories where author_id = auth.uid() and created_at > now() - interval '24 hours') >= 30 then raise exception '30 histoires par jour au plus'; end if;
  insert into stories (author_id, media_path, media_kind, caption) values (auth.uid(), p_path, p_kind, left(btrim(coalesce(p_caption, '')), 200)) returning id into sid;
  return sid;
end $function$;

CREATE OR REPLACE FUNCTION public.create_story(p_path text, p_kind text, p_caption text, p_hours integer, p_sticker jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me profiles%rowtype; sid uuid; h int; st jsonb := null; t text; n int;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Histoires réservées aux étudiants et au département'; end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  if coalesce(p_kind, '') not in ('image', 'video') then raise exception 'Type de média invalide'; end if;
  if (select count(*) from stories where author_id = auth.uid() and created_at > now() - interval '24 hours') >= 30 then raise exception '30 histoires par jour au plus'; end if;
  h := case when p_hours in (24, 48, 72) then p_hours else 24 end;
  if p_sticker is not null and jsonb_typeof(p_sticker) = 'object' then
    t := p_sticker->>'type';
    if t not in ('poll', 'question') then raise exception 'Autocollant invalide'; end if;
    if char_length(coalesce(p_sticker->>'text', '')) not between 1 and 120 then raise exception 'La question doit faire de 1 à 120 caractères'; end if;
    if t = 'poll' then
      n := coalesce(jsonb_array_length(p_sticker->'options'), 0);
      if n not between 2 and 4 then raise exception 'Un sondage propose de 2 à 4 choix'; end if;
      if exists (select 1 from jsonb_array_elements_text(p_sticker->'options') o where char_length(o) not between 1 and 40) then raise exception 'Chaque choix fait de 1 à 40 caractères'; end if;
      st := jsonb_build_object('type', 'poll', 'text', left(btrim(p_sticker->>'text'), 120), 'options', p_sticker->'options');
    else
      st := jsonb_build_object('type', 'question', 'text', left(btrim(p_sticker->>'text'), 120));
    end if;
  end if;
  insert into stories (author_id, media_path, media_kind, caption, sticker, expires_at)
  values (auth.uid(), p_path, p_kind, left(btrim(coalesce(p_caption, '')), 200), st, now() + make_interval(hours => h)) returning id into sid;
  return sid;
end $function$;

CREATE OR REPLACE FUNCTION public.save_live(p_title text, p_starts_at text, p_product text, p_schedule boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare lid uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 120 then raise exception 'Titre du live : 3 à 120 caractères'; end if;
  if p_schedule and char_length(trim(coalesce(p_starts_at, ''))) < 3 then raise exception 'Indiquez la date et l''heure du live'; end if;
  insert into scheduled_lives (host_id, title, starts_at, product_title, status)
  values (auth.uid(), trim(p_title), nullif(left(trim(coalesce(p_starts_at, '')), 60), ''), nullif(left(trim(coalesce(p_product, '')), 120), ''), case when p_schedule then 'scheduled' else 'draft' end)
  returning id into lid;
  return lid;
end $function$;

CREATE OR REPLACE FUNCTION public.schedule_post(p_caption text, p_media jsonb, p_link text, p_tags text[], p_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me profiles%rowtype; sid uuid; m jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into me from profiles where id = auth.uid();
  if me.suspended then raise exception 'Publication réservée aux étudiants et au département'; end if;
  if p_at is null or p_at < now() + interval '1 minute' then raise exception 'Choisissez une date et une heure à venir'; end if;
  if p_at > now() + interval '6 months' then raise exception 'La programmation est limitée à 6 mois'; end if;
  if char_length(btrim(coalesce(p_caption, ''))) = 0 and coalesce(jsonb_array_length(p_media), 0) = 0 and coalesce(p_link, '') = '' then raise exception 'Rien à publier'; end if;
  for m in select * from jsonb_array_elements(coalesce(p_media, '[]'::jsonb)) loop
    if split_part(coalesce(m->>'path', ''), '/', 1) <> auth.uid()::text then raise exception 'Média invalide : déposez-le d''abord dans votre dossier'; end if;
  end loop;
  if (select count(*) from scheduled_posts where author_id = auth.uid() and status = 'pending') >= 200 then raise exception '200 publications programmées au plus'; end if;
  insert into scheduled_posts (author_id, caption, media, link, tags, publish_at)
  values (auth.uid(), left(btrim(coalesce(p_caption, '')), 5000), coalesce(p_media, '[]'::jsonb), nullif(btrim(coalesce(p_link, '')), ''), coalesce(p_tags, '{}'), p_at) returning id into sid;
  return sid;
end $function$;
