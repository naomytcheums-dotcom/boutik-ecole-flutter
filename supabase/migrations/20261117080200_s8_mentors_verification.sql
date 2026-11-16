-- Lot S8 (profil Étudiant-vendeur) — mentors : vérification minimale avant d'être listé, règles de demande plus strictes.
--  S8-15  Un profil mentor n'est listé (annuaire, fiche, match, histoires, demandes) qu'une fois vérifié : soit la personne a une pièce d'identité
--         d'étudiant ou de formation vérifiée par l'équipe (carte d'étudiant, certificat de scolarité, diplôme, certificat), soit l'équipe
--         (administration, support, département) a validé le profil (mentor_validate). Les autres profils restent « en attente ».
--  S8-17  Demande de mentor : compte suspendu refusé, 7 jours d'attente après un refus du même mentor, acceptation impossible quand le mentor est
--         « pas disponible », avis modifiable 7 jours seulement.
-- Les profils mentors existants sans pièce vérifiée passent en « pending » (non listés) jusqu'à validation : aucune ligne n'est supprimée.
-- Rejouable. Retour arrière : voir le bas du fichier.

alter table mentor_profiles add column if not exists status text not null default 'pending' check (status in ('pending', 'verified', 'rejected'));
alter table mentor_profiles add column if not exists verified_at timestamptz;
alter table mentor_profiles add column if not exists reviewed_by uuid references profiles(id) on delete set null;
alter table mentor_profiles add column if not exists review_note text check (review_note is null or char_length(review_note) <= 500);

-- Preuve minimale : une pièce d'étudiant ou de formation vérifiée par l'équipe, ou un compte d'équipe.
create or replace function _mentor_has_proof(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from user_documents d where d.owner_id = p_user and d.status = 'verified' and d.kind in ('student_card', 'enrollment_certificate', 'diploma', 'certificate'))
      or exists (select 1 from profiles p where p.id = p_user and p.role::text in ('admin', 'support', 'dept') and not coalesce(p.suspended, false))
$$;
revoke all on function _mentor_has_proof(uuid) from public, anon, authenticated;

-- Appelée quand une pièce est vérifiée : le profil mentor en attente est publié et la personne prévenue.
create or replace function _mentor_auto_verify(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_user is null or not _mentor_has_proof(p_user) then return; end if;
  update mentor_profiles set status = 'verified', verified_at = now() where user_id = p_user and status = 'pending';
  if found then
    perform notify_user(p_user, 'mentor_profile', 'Profil mentor validé', 'Votre profil mentor est maintenant visible dans l''annuaire des mentors.', '{}'::jsonb);
  end if;
end $$;
revoke all on function _mentor_auto_verify(uuid) from public, anon, authenticated;

update mentor_profiles set status = 'verified', verified_at = now() where status = 'pending' and verified_at is null and _mentor_has_proof(user_id);

create or replace function mentor_save(p_works_at text, p_promo text, p_topics text[], p_bio text, p_availability text default 'available', p_evening boolean default false, p_active boolean default true) returns void
language plpgsql security definer set search_path = public as $$
declare v_topics text[]; v_old text; v_status text; r record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') in ('client', 'visitor', '') then raise exception 'Réservé aux étudiants, anciens et professionnels'; end if;
  if char_length(btrim(coalesce(p_works_at, ''))) < 2 then raise exception 'Indiquez où vous travaillez ou étudiez maintenant'; end if;
  select array_agg(btrim(t)) into v_topics from unnest(coalesce(p_topics, '{}'::text[])) t where char_length(btrim(t)) between 2 and 60;
  if v_topics is null or cardinality(v_topics) not between 1 and 10 then raise exception 'Indiquez de 1 à 10 sujets sur lesquels vous pouvez aider'; end if;
  if p_availability not in ('this_week', 'available', 'busy') then raise exception 'Disponibilité inconnue'; end if;
  select status into v_old from mentor_profiles where user_id = auth.uid();
  v_status := case when _mentor_has_proof(auth.uid()) or v_old = 'verified' then 'verified' else 'pending' end;
  insert into mentor_profiles (user_id, works_at, promo, topics, bio, availability, evening, active, status, verified_at)
  values (auth.uid(), btrim(p_works_at), left(btrim(coalesce(p_promo, '')), 40), v_topics, left(btrim(coalesce(p_bio, '')), 600), p_availability, coalesce(p_evening, false), coalesce(p_active, true),
          v_status, case when v_status = 'verified' then now() end)
  on conflict (user_id) do update set works_at = excluded.works_at, promo = excluded.promo, topics = excluded.topics, bio = excluded.bio, availability = excluded.availability,
    evening = excluded.evening, active = excluded.active, status = excluded.status, verified_at = coalesce(mentor_profiles.verified_at, excluded.verified_at);
  if v_status = 'pending' and v_old is distinct from 'pending' then
    for r in select id from profiles where role::text in ('admin', 'support') and not coalesce(suspended, false) loop
      perform notify_user(r.id, 'verification', 'Profil mentor à vérifier', display_name(auth.uid()) || ' demande à devenir mentor : ' || left(btrim(p_works_at), 80) || '.', jsonb_build_object('mentor', auth.uid()));
    end loop;
  end if;
end $$;

-- Validation d'un profil mentor par l'équipe.
create or replace function mentor_validate(p_user uuid, p_approve boolean, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (is_platform_staff() or coalesce(current_role_name()::text, '') = 'dept') then raise exception 'Action non autorisée'; end if;
  if p_approve is null then raise exception 'Décision manquante'; end if;
  update mentor_profiles set status = case when p_approve then 'verified' else 'rejected' end, verified_at = case when p_approve then now() end,
    reviewed_by = auth.uid(), review_note = left(nullif(btrim(coalesce(p_note, '')), ''), 500)
  where user_id = p_user;
  if not found then raise exception 'Profil mentor introuvable'; end if;
  perform notify_user(p_user, 'mentor_profile', case when p_approve then 'Profil mentor validé' else 'Profil mentor refusé' end,
    case when p_approve then 'Votre profil mentor est maintenant visible dans l''annuaire des mentors.'
         else 'Votre profil mentor n''a pas été validé' || coalesce(' : ' || nullif(btrim(left(p_note, 200)), ''), '') || '.' end, '{}'::jsonb);
end $$;

create or replace function mentors_pending() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (is_platform_staff() or coalesce(current_role_name()::text, '') = 'dept') then raise exception 'Action non autorisée'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('user_id', m.user_id, 'name', p.name, 'department', p.department, 'works_at', m.works_at, 'promo', m.promo,
      'topics', to_jsonb(m.topics), 'bio', m.bio, 'created_at', m.created_at) order by m.created_at)
    from mentor_profiles m join profiles p on p.id = m.user_id where m.status = 'pending'), '[]'::jsonb);
end $$;

create or replace function _mentor_card(m mentor_profiles) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('user_id', m.user_id, 'name', display_name(m.user_id), 'avatar_url', p.avatar_url, 'department', p.department, 'promo', m.promo, 'works_at', m.works_at,
    'topics', to_jsonb(m.topics), 'bio', m.bio, 'availability', m.availability, 'evening', m.evening, 'status', m.status,
    'rating', (select round(avg(r.rating)::numeric, 1) from mentor_reviews r where r.mentor_id = m.user_id),
    'reviews', (select count(*)::int from mentor_reviews r where r.mentor_id = m.user_id),
    'helped', (select count(*)::int from mentor_requests q where q.mentor_id = m.user_id and q.status = 'accepted'))
  from profiles p where p.id = m.user_id
$$;
revoke all on function _mentor_card(mentor_profiles) from public, anon, authenticated;

create or replace function mentors_list(p_q text default null, p_topic text default null) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(c order by (c->>'availability' = 'busy'), coalesce((c->>'rating')::numeric, 0) desc, (c->>'helped')::int desc), '[]'::jsonb) from (
    select _mentor_card(m) c from mentor_profiles m join profiles p on p.id = m.user_id
    where m.active and m.status = 'verified' and not coalesce(p.suspended, false) and m.user_id is distinct from auth.uid()
      and (nullif(btrim(coalesce(p_topic, '')), '') is null or exists (select 1 from unnest(m.topics) t where lower(t) like '%' || lower(btrim(p_topic)) || '%'))
      and (nullif(btrim(coalesce(p_q, '')), '') is null or lower(m.works_at || ' ' || m.bio || ' ' || coalesce(p.department, '') || ' ' || array_to_string(m.topics, ' ') || ' ' || p.name) like '%' || lower(btrim(p_q)) || '%')
    limit 100) x
$$;

-- Fiche : publique pour un mentor vérifié et visible ; la personne elle-même et l'équipe voient aussi un profil en attente.
create or replace function mentor_detail(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m mentor_profiles%rowtype;
begin
  select * into m from mentor_profiles where user_id = p_user and ((active and status = 'verified') or user_id = auth.uid() or is_platform_staff());
  if not found then raise exception 'Mentor introuvable'; end if;
  return _mentor_card(m) || jsonb_build_object(
    'review_list', coalesce((select jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.student_id), 'created_at', r.created_at) order by r.created_at desc)
                             from (select * from mentor_reviews where mentor_id = p_user order by created_at desc limit 20) r), '[]'::jsonb),
    'my_request', (select to_jsonb(q) - 'mentor_id' - 'student_id' from (select id, topic, status, created_at from mentor_requests where mentor_id = p_user and student_id = auth.uid() order by created_at desc limit 1) q));
end $$;

create or replace function mentor_match(p_topic text, p_evening boolean default null, p_limit integer default 3) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_dept text; v_words text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select lower(coalesce(department, '')) into v_dept from profiles where id = auth.uid();
  select array_agg(distinct w) into v_words from unnest(regexp_split_to_array(lower(btrim(coalesce(p_topic, ''))), '[^a-zà-ÿ0-9+#]+')) w where char_length(w) >= 3;
  if v_words is null then raise exception 'Dites ce que vous voulez apprendre (ex. Flutter)'; end if;
  return coalesce((select jsonb_agg(c || jsonb_build_object('score', s) order by s desc, coalesce((c->>'rating')::numeric, 0) desc) from (
    select _mentor_card(m) c,
      (select count(*)::int * 10 from unnest(v_words) w where lower(array_to_string(m.topics, ' ') || ' ' || m.bio) like '%' || w || '%')
      + case when v_dept <> '' and lower(coalesce(p.department, '')) = v_dept then 5 else 0 end
      + case m.availability when 'this_week' then 4 when 'available' then 2 else -20 end
      + case when coalesce(p_evening, false) and m.evening then 3 else 0 end
      + coalesce((select round(avg(r.rating))::int from mentor_reviews r where r.mentor_id = m.user_id), 0) as s
    from mentor_profiles m join profiles p on p.id = m.user_id
    where m.active and m.status = 'verified' and m.availability <> 'busy' and not coalesce(p.suspended, false) and m.user_id <> auth.uid()
      and exists (select 1 from unnest(v_words) w where lower(array_to_string(m.topics, ' ') || ' ' || m.bio) like '%' || w || '%')
    order by 2 desc limit least(greatest(coalesce(p_limit, 3), 1), 10)) z(c, s)), '[]'::jsonb);
end $$;

create or replace function mentor_request(p_mentor uuid, p_topic text, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare m mentor_profiles%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select * into m from mentor_profiles where user_id = p_mentor and active and status = 'verified';
  if not found then raise exception 'Mentor introuvable'; end if;
  if p_mentor = auth.uid() then raise exception 'Vous ne pouvez pas vous choisir comme mentor'; end if;
  if m.availability = 'busy' then raise exception 'Ce mentor n''est pas disponible pour le moment'; end if;
  if char_length(btrim(coalesce(p_topic, ''))) < 2 then raise exception 'Indiquez ce que vous voulez apprendre'; end if;
  if exists (select 1 from mentor_requests where mentor_id = p_mentor and student_id = auth.uid() and status = 'requested') then raise exception 'Une demande est déjà en attente auprès de ce mentor'; end if;
  if exists (select 1 from mentor_requests where mentor_id = p_mentor and student_id = auth.uid() and status = 'declined' and decided_at > now() - interval '7 days') then
    raise exception 'Ce mentor a décliné votre dernière demande : patientez 7 jours avant de lui écrire de nouveau';
  end if;
  if (select count(*) from mentor_requests where student_id = auth.uid() and status = 'requested') >= 5 then raise exception 'Cinq demandes en attente au plus : attendez une réponse'; end if;
  insert into mentor_requests (mentor_id, student_id, topic, message) values (p_mentor, auth.uid(), btrim(p_topic), left(btrim(coalesce(p_message, '')), 600)) returning id into v_id;
  perform notify_user(p_mentor, 'mentor_request', 'Demande de mentor', display_name(auth.uid()) || ' souhaite votre aide : ' || btrim(p_topic), jsonb_build_object('request', v_id));
  return v_id;
end $$;

create or replace function mentor_request_decide(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from mentor_requests where id = p_id and mentor_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'requested' then raise exception 'Cette demande a déjà reçu une réponse'; end if;
  if p_accept and exists (select 1 from mentor_profiles where user_id = auth.uid() and availability = 'busy') then
    raise exception 'Vous êtes indiqué(e) « pas disponible » : changez votre disponibilité avant d''accepter';
  end if;
  update mentor_requests set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where id = p_id;
  perform notify_user(q.student_id, 'mentor_request', case when p_accept then 'Mentor trouvé' else 'Demande déclinée' end,
    display_name(auth.uid()) || case when p_accept then ' a accepté de vous aider : écrivez-lui pour convenir d''un moment.' else ' ne peut pas vous accompagner pour le moment.' end, jsonb_build_object('request', p_id));
  return case when p_accept then 'accepted' else 'declined' end;
end $$;

-- Avis : après acceptation ; modifiable pendant 7 jours seulement.
create or replace function mentor_review(p_request uuid, p_rating integer, p_comment text default '') returns void
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from mentor_requests where id = p_request and student_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'accepted' then raise exception 'Vous pouvez noter un mentor une fois sa demande acceptée'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'La note va de 1 à 5 étoiles'; end if;
  if exists (select 1 from mentor_reviews where request_id = p_request and created_at < now() - interval '7 days') then raise exception 'Votre avis ne peut plus être modifié (7 jours après sa publication)'; end if;
  insert into mentor_reviews (request_id, mentor_id, student_id, rating, comment) values (p_request, q.mentor_id, auth.uid(), p_rating, left(btrim(coalesce(p_comment, '')), 400))
  on conflict (request_id) do update set rating = excluded.rating, comment = excluded.comment;
  perform notify_user(q.mentor_id, 'mentor_request', 'Nouvel avis', display_name(auth.uid()) || ' vous a mis ' || p_rating || ' étoile' || case when p_rating > 1 then 's' else '' end || '.', jsonb_build_object('request', p_request));
end $$;

create or replace function mentor_story_save(p_title text, p_body text, p_company text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from mentor_profiles where user_id = auth.uid() and active) then raise exception 'Réservé aux mentors : créez d''abord votre profil mentor'; end if;
  if not exists (select 1 from mentor_profiles where user_id = auth.uid() and status = 'verified') then raise exception 'Votre profil mentor doit d''abord être vérifié par l''équipe'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Donnez un titre à votre histoire'; end if;
  if char_length(btrim(coalesce(p_body, ''))) < 20 then raise exception 'Racontez votre parcours en 20 caractères minimum'; end if;
  if (select count(*) from mentor_stories where author_id = auth.uid() and created_at > now() - interval '1 day') >= 3 then raise exception 'Trois histoires par jour au plus'; end if;
  insert into mentor_stories (author_id, title, body, company) values (auth.uid(), btrim(p_title), btrim(p_body), left(btrim(coalesce(p_company, '')), 100)) returning id into v_id;
  return v_id;
end $$;

create or replace function mentor_stories(p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'title', s.title, 'body', s.body, 'company', s.company, 'author', display_name(s.author_id), 'author_id', s.author_id, 'created_at', s.created_at) order by s.created_at desc), '[]'::jsonb)
  from (select * from mentor_stories st where st.status = 'published' and exists (select 1 from mentor_profiles m where m.user_id = st.author_id and m.status = 'verified')
        order by st.created_at desc limit least(greatest(coalesce(p_limit, 20), 1), 50)) s
$$;

revoke all on function mentor_save(text, text, text[], text, text, boolean, boolean), mentor_validate(uuid, boolean, text), mentors_pending(), mentor_match(text, boolean, integer),
  mentor_request(uuid, text, text), mentor_request_decide(uuid, boolean), mentor_review(uuid, integer, text), mentor_story_save(text, text, text) from public, anon;
grant execute on function mentor_save(text, text, text[], text, text, boolean, boolean), mentor_validate(uuid, boolean, text), mentors_pending(), mentor_match(text, boolean, integer),
  mentor_request(uuid, text, text), mentor_request_decide(uuid, boolean), mentor_review(uuid, integer, text), mentor_story_save(text, text, text) to authenticated;
revoke all on function mentors_list(text, text), mentor_detail(uuid), mentor_stories(integer) from public;
grant execute on function mentors_list(text, text), mentor_detail(uuid), mentor_stories(integer) to anon, authenticated;

-- Retour arrière :
--   drop function mentor_validate(uuid, boolean, text), mentors_pending(), _mentor_auto_verify(uuid), _mentor_has_proof(uuid) ; recréer document_review (20261104000100) AVANT de supprimer _mentor_auto_verify ;
--   recréer mentor_save (20261115000100), _mentor_card, mentors_list, mentor_detail, mentor_match, mentor_request, mentor_request_decide, mentor_review, mentor_story_save, mentor_stories (20261114001100) ;
--   alter table mentor_profiles drop column status, drop column verified_at, drop column reviewed_by, drop column review_note;
