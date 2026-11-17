-- Lot G7 (profil Étudiant) — messagerie, opportunités, coéquipiers, mentors, vœux, salons vocaux : garde-fous restants.
--  1. Messagerie : le plafond de 20 messages par minute n'existait que dans les fonctions « start_* » ; l'envoi dans une conversation existante
--     (insertion directe) n'avait AUCUN plafond serveur (anti-spam contournable). Un déclencheur l'applique désormais à tout envoi.
--  2. Opportunités : candidature = 20 par jour au plus, compte suspendu refusé avec un message clair, offre d'une personne qui a bloqué le candidat
--     refusée, doublon concurrent (double envoi) traduit en message clair ; « Non merci » à une invitation signale une invitation introuvable.
--  3. Coéquipiers : invitation refusée si blocage ou profil retiré de l'annuaire, pas d'invitation en double (déjà coéquipiers, invitation croisée),
--     7 jours d'attente après un refus ; réponse à une invitation et messages d'équipe refusés pour un compte suspendu ou après blocage ;
--     une seule invitation en attente par paire (index unique).
--  4. Mentors : un mentor suspendu n'est plus joignable (demande, fiche, histoires), l'acceptation exige un profil encore actif et vérifié,
--     avis et histoires refusés à un compte suspendu, demande refusée après blocage.
--  5. Vœux : un vœu d'un auteur suspendu n'est plus ouvert aux précommandes ni listé ; une précommande d'une campagne close ne se retire plus
--     (les créateurs et les précommandeurs ont déjà été prévenus du résultat).
--  6. Salons vocaux : compte suspendu refusé à la création et à l'entrée, quatre salons créés par heure au plus (chaque ouverture notifie tous les membres).
-- Aucune donnée existante n'est modifiée ni supprimée. Rejouable.
-- Retour arrière : drop trigger if exists trg_messages_rate on messages; drop function if exists messages_rate_guard();
--   drop index if exists teammate_invites_pending_uk ; puis recréer opp_apply, opp_invite_decline (20261117080000 / 20261114003800), teammate_invite
--   (20261117060000), teammate_invite_decide (20261115200400), teammate_message_send (20261114002200), mentor_request, mentor_request_decide,
--   mentor_review, mentor_story_save, mentor_stories, mentor_detail (20261117080200), wish_preorder, wishes_market (20261115200000),
--   study_room_create, study_room_enter (20261114002100).

-- ============================================================ 1. Messagerie : plafond serveur sur tout envoi
create or replace function messages_rate_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and new.sender_id = auth.uid()
     and (select count(*) from messages where sender_id = new.sender_id and created_at > now() - interval '1 minute') >= 20 then
    raise exception 'Trop de messages : patientez un instant';
  end if;
  return new;
end $$;
revoke all on function messages_rate_guard() from public, anon, authenticated;
drop trigger if exists trg_messages_rate on messages;
create trigger trg_messages_rate before insert on messages for each row execute function messages_rate_guard();

-- ============================================================ 2. Opportunités
create or replace function opp_apply(p_id uuid, p_message text, p_cv_link text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_id uuid; v_last timestamptz; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : candidature impossible'; end if;
  select * into o from opportunities where id = p_id and status = 'published';
  if not found or (o.deadline is not null and o.deadline < current_date) then raise exception 'Cette offre n''accepte plus de candidatures'; end if;
  if not o.apply_in_app then raise exception 'Cette offre se postule uniquement par WhatsApp'; end if;
  if o.poster_id = auth.uid() then raise exception 'C''est votre propre offre'; end if;
  if is_blocked_between(o.poster_id, auth.uid()) then raise exception 'Cette offre n''accepte plus de candidatures'; end if;
  if o.iut_only and not _is_verified_iut_student(auth.uid()) then raise exception 'Offre réservée aux étudiants de l''IUT'; end if;
  if char_length(btrim(coalesce(p_message, ''))) < 20 then raise exception 'Écrivez votre lettre de motivation (20 caractères minimum)'; end if;
  if char_length(btrim(coalesce(p_cv_link, ''))) > 0 and btrim(p_cv_link) !~* '^https?://' then raise exception 'Le lien du CV doit commencer par http'; end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_id and applicant_id = auth.uid()) then raise exception 'Vous avez déjà postulé'; end if;
  select max(withdrawn_at), count(*) into v_last, v_n from opportunity_withdrawals where opportunity_id = p_id and applicant_id = auth.uid();
  if v_n >= 3 then raise exception 'Vous avez déjà retiré trois fois votre candidature à cette offre'; end if;
  if v_last is not null and v_last > now() - interval '24 hours' then raise exception 'Vous avez retiré votre candidature il y a moins de 24 h : patientez avant de postuler de nouveau'; end if;
  if (select count(*) from opportunity_applications where applicant_id = auth.uid() and created_at > now() - interval '1 day') >= 20 then
    raise exception 'Vingt candidatures par jour au plus : reprenez demain';
  end if;
  begin
    insert into opportunity_applications (opportunity_id, applicant_id, message, cv_link) values (p_id, auth.uid(), btrim(p_message), btrim(coalesce(p_cv_link, ''))) returning id into v_id;
  exception when unique_violation then
    raise exception 'Vous avez déjà postulé';
  end;
  perform notify_user(o.poster_id, 'opportunity_application', 'Nouvelle candidature', display_name(auth.uid()) || ' postule à « ' || left(o.title, 60) || ' ».', jsonb_build_object('opportunity', p_id, 'application', v_id));
  return v_id;
end $$;
revoke all on function opp_apply(uuid, text, text) from public, anon;
grant execute on function opp_apply(uuid, text, text) to authenticated;

create or replace function opp_invite_decline(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  update opportunity_invites set status = 'declined' where opportunity_id = p_id and student_id = auth.uid() and status = 'invited';
  if not found then raise exception 'Invitation introuvable ou déjà traitée'; end if;
end $$;
revoke all on function opp_invite_decline(uuid) from public, anon;
grant execute on function opp_invite_decline(uuid) to authenticated;

-- ============================================================ 3. Coéquipiers
do $$ begin
  create unique index if not exists teammate_invites_pending_uk on teammate_invites (from_user, to_user) where status = 'pending';
exception when others then
  raise notice 'teammate_invites_pending_uk non créé (doublons existants à résoudre) : %', sqlerrm;
end $$;

create or replace function teammate_invite(p_user uuid, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_reply boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Les invitations d''équipe sont réservées aux étudiants'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous inviter vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user and role::text = 'student' and not coalesce(suspended, false)) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from user_blocks where (blocker_id = auth.uid() and blocked_id = p_user) or (blocker_id = p_user and blocked_id = auth.uid())) then
    raise exception 'Cette personne ne peut pas recevoir vos invitations';
  end if;
  if exists (select 1 from teammate_invites where status = 'accepted' and ((from_user = auth.uid() and to_user = p_user) or (from_user = p_user and to_user = auth.uid()))) then
    raise exception 'Vous êtes déjà coéquipiers : écrivez-lui depuis « Mes invitations »';
  end if;
  if exists (select 1 from teammate_invites where from_user = p_user and to_user = auth.uid() and status = 'pending') then
    raise exception 'Cet étudiant vous a déjà invité : répondez à son invitation depuis « Mes invitations »';
  end if;
  v_reply := exists (select 1 from teammate_invites where from_user = p_user and to_user = auth.uid());
  if not v_reply and not (exists (select 1 from mate_consents where user_id = p_user and visible) and profile_in_directory(p_user)) then
    raise exception 'Cet étudiant n''est pas dans l''annuaire des coéquipiers';
  end if;
  if exists (select 1 from teammate_invites where from_user = auth.uid() and to_user = p_user and status = 'pending') then raise exception 'Une invitation est déjà en attente pour cet étudiant'; end if;
  if exists (select 1 from teammate_invites where from_user = auth.uid() and to_user = p_user and status = 'declined' and decided_at > now() - interval '7 days') then
    raise exception 'Cet étudiant a décliné votre dernière invitation : patientez 7 jours avant de le réinviter';
  end if;
  if (select count(*) from teammate_invites where from_user = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix invitations par jour au plus'; end if;
  begin
    insert into teammate_invites (from_user, to_user, message) values (auth.uid(), p_user, left(btrim(coalesce(p_message, '')), 500)) returning id into v_id;
  exception when unique_violation then
    raise exception 'Une invitation est déjà en attente pour cet étudiant';
  end;
  perform notify_user(p_user, 'teammate_invite', 'Invitation d''équipe', display_name(auth.uid()) || ' vous invite à rejoindre son équipe.', jsonb_build_object('invite', v_id));
  return v_id;
end $$;
revoke all on function teammate_invite(uuid, text) from public, anon;
grant execute on function teammate_invite(uuid, text) to authenticated;

create or replace function teammate_invite_decide(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare i teammate_invites%rowtype; t record;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : réponse impossible'; end if;
  select * into i from teammate_invites where id = p_id and to_user = auth.uid() for update;
  if not found then raise exception 'Invitation introuvable'; end if;
  if i.status <> 'pending' then raise exception 'Cette invitation a déjà reçu une réponse'; end if;
  if coalesce(p_accept, false) then
    if exists (select 1 from profiles where id = i.from_user and coalesce(suspended, false)) then raise exception 'Cette invitation n''est plus valable'; end if;
    if exists (select 1 from user_blocks where (blocker_id = auth.uid() and blocked_id = i.from_user) or (blocker_id = i.from_user and blocked_id = auth.uid())) then
      raise exception 'Cette invitation n''est plus valable';
    end if;
  end if;
  update teammate_invites set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where id = p_id;
  if p_accept then
    for t in
      select ct.id, ct.name from contest_teams ct join contests c on c.id = ct.contest_id
      where ct.captain_id = i.from_user and not ct.solo and not ct.hidden and c.status = 'published' and now() <= c.reg_close_at
        and (select count(*) from contest_members m where m.team_id = ct.id) < 5
        and not exists (select 1 from contest_members m join contest_teams x on x.id = m.team_id where x.contest_id = ct.contest_id and m.user_id = auth.uid() and m.status in ('captain', 'member'))
    loop
      insert into contest_members (team_id, user_id, status) values (t.id, auth.uid(), 'member') on conflict (team_id, user_id) do update set status = 'member';
      perform notify_user(auth.uid(), 'contest', 'Vous avez rejoint une équipe', left('Équipe « ' || t.name || ' ».', 500), jsonb_build_object('team_id', t.id));
    end loop;
  end if;
  perform notify_user(i.from_user, 'teammate_invite', case when p_accept then 'Invitation acceptée' else 'Invitation déclinée' end,
    display_name(auth.uid()) || case when p_accept then ' rejoint votre équipe : écrivez-lui pour vous organiser.' else ' ne peut pas rejoindre votre équipe.' end, jsonb_build_object('invite', p_id));
  return case when p_accept then 'accepted' else 'declined' end;
end $$;
revoke all on function teammate_invite_decide(uuid, boolean) from public, anon;
grant execute on function teammate_invite_decide(uuid, boolean) to authenticated;

create or replace function teammate_message_send(p_invite uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare i teammate_invites%rowtype; v_other uuid; v_id bigint; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : message impossible'; end if;
  select * into i from teammate_invites where id = p_invite and status = 'accepted' and auth.uid() in (from_user, to_user);
  if not found then raise exception 'Conversation introuvable : l''invitation doit être acceptée'; end if;
  v_other := case when i.from_user = auth.uid() then i.to_user else i.from_user end;
  if exists (select 1 from user_blocks where (blocker_id = auth.uid() and blocked_id = v_other) or (blocker_id = v_other and blocked_id = auth.uid())) then
    raise exception 'Cette personne ne peut pas recevoir vos messages';
  end if;
  if char_length(v_body) not between 1 and 1000 then raise exception 'Le message doit contenir entre 1 et 1000 caractères'; end if;
  if (select count(*) from teammate_messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then raise exception 'Trop de messages en peu de temps. Réessayez dans une minute.'; end if;
  insert into teammate_messages (invite_id, sender_id, body) values (i.id, auth.uid(), v_body) returning id into v_id;
  if not exists (select 1 from notifications where user_id = v_other and kind = 'teammate_message' and read_at is null and (data->>'invite') = i.id::text and created_at > now() - interval '10 minutes') then
    insert into notifications (user_id, kind, title, body, data)
      values (v_other, 'teammate_message', 'Message de ' || display_name(auth.uid()), left(v_body, 120), jsonb_build_object('invite', i.id));
  end if;
  return v_id;
end $$;
revoke all on function teammate_message_send(uuid, text) from public, anon;
grant execute on function teammate_message_send(uuid, text) to authenticated;

-- ============================================================ 4. Mentors
create or replace function mentor_request(p_mentor uuid, p_topic text, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare m mentor_profiles%rowtype; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select m0.* into m from mentor_profiles m0 join profiles p on p.id = m0.user_id
    where m0.user_id = p_mentor and m0.active and m0.status = 'verified' and not coalesce(p.suspended, false);
  if not found then raise exception 'Mentor introuvable'; end if;
  if p_mentor = auth.uid() then raise exception 'Vous ne pouvez pas vous choisir comme mentor'; end if;
  if exists (select 1 from user_blocks where (blocker_id = auth.uid() and blocked_id = p_mentor) or (blocker_id = p_mentor and blocked_id = auth.uid())) then
    raise exception 'Mentor introuvable';
  end if;
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
revoke all on function mentor_request(uuid, text, text) from public, anon;
grant execute on function mentor_request(uuid, text, text) to authenticated;

create or replace function mentor_request_decide(p_id uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select * into q from mentor_requests where id = p_id and mentor_id = auth.uid() for update;
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'requested' then raise exception 'Cette demande a déjà reçu une réponse'; end if;
  if p_accept and exists (select 1 from mentor_profiles where user_id = auth.uid() and availability = 'busy') then
    raise exception 'Vous êtes indiqué(e) « pas disponible » : changez votre disponibilité avant d''accepter';
  end if;
  if p_accept and not exists (select 1 from mentor_profiles where user_id = auth.uid() and active and status = 'verified') then
    raise exception 'Votre profil mentor doit être actif et vérifié pour accepter une demande';
  end if;
  update mentor_requests set status = case when p_accept then 'accepted' else 'declined' end, decided_at = now() where id = p_id;
  perform notify_user(q.student_id, 'mentor_request', case when p_accept then 'Mentor trouvé' else 'Demande déclinée' end,
    display_name(auth.uid()) || case when p_accept then ' a accepté de vous aider : écrivez-lui pour convenir d''un moment.' else ' ne peut pas vous accompagner pour le moment.' end, jsonb_build_object('request', p_id));
  return case when p_accept then 'accepted' else 'declined' end;
end $$;
revoke all on function mentor_request_decide(uuid, boolean) from public, anon;
grant execute on function mentor_request_decide(uuid, boolean) to authenticated;

create or replace function mentor_review(p_request uuid, p_rating integer, p_comment text default '') returns void
language plpgsql security definer set search_path = public as $$
declare q mentor_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select * into q from mentor_requests where id = p_request and student_id = auth.uid();
  if not found then raise exception 'Demande introuvable'; end if;
  if q.status <> 'accepted' then raise exception 'Vous pouvez noter un mentor une fois sa demande acceptée'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'La note va de 1 à 5 étoiles'; end if;
  if exists (select 1 from mentor_reviews where request_id = p_request and created_at < now() - interval '7 days') then raise exception 'Votre avis ne peut plus être modifié (7 jours après sa publication)'; end if;
  insert into mentor_reviews (request_id, mentor_id, student_id, rating, comment) values (p_request, q.mentor_id, auth.uid(), p_rating, left(btrim(coalesce(p_comment, '')), 400))
  on conflict (request_id) do update set rating = excluded.rating, comment = excluded.comment;
  perform notify_user(q.mentor_id, 'mentor_request', 'Nouvel avis', display_name(auth.uid()) || ' vous a mis ' || p_rating || ' étoile' || case when p_rating > 1 then 's' else '' end || '.', jsonb_build_object('request', p_request));
end $$;
revoke all on function mentor_review(uuid, integer, text) from public, anon;
grant execute on function mentor_review(uuid, integer, text) to authenticated;

create or replace function mentor_story_save(p_title text, p_body text, p_company text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : publication impossible'; end if;
  if not exists (select 1 from mentor_profiles where user_id = auth.uid() and active) then raise exception 'Réservé aux mentors : créez d''abord votre profil mentor'; end if;
  if not exists (select 1 from mentor_profiles where user_id = auth.uid() and status = 'verified') then raise exception 'Votre profil mentor doit d''abord être vérifié par l''équipe'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Donnez un titre à votre histoire'; end if;
  if char_length(btrim(coalesce(p_body, ''))) < 20 then raise exception 'Racontez votre parcours en 20 caractères minimum'; end if;
  if (select count(*) from mentor_stories where author_id = auth.uid() and created_at > now() - interval '1 day') >= 3 then raise exception 'Trois histoires par jour au plus'; end if;
  insert into mentor_stories (author_id, title, body, company) values (auth.uid(), btrim(p_title), btrim(p_body), left(btrim(coalesce(p_company, '')), 100)) returning id into v_id;
  return v_id;
end $$;
revoke all on function mentor_story_save(text, text, text) from public, anon;
grant execute on function mentor_story_save(text, text, text) to authenticated;

create or replace function mentor_stories(p_limit integer default 20) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', s.id, 'title', s.title, 'body', s.body, 'company', s.company, 'author', display_name(s.author_id), 'author_id', s.author_id, 'created_at', s.created_at) order by s.created_at desc), '[]'::jsonb)
  from (select * from mentor_stories st where st.status = 'published'
          and exists (select 1 from mentor_profiles m join profiles p on p.id = m.user_id where m.user_id = st.author_id and m.status = 'verified' and not coalesce(p.suspended, false))
        order by st.created_at desc limit least(greatest(coalesce(p_limit, 20), 1), 50)) s
$$;
revoke all on function mentor_stories(integer) from public;
grant execute on function mentor_stories(integer) to anon, authenticated;

create or replace function mentor_detail(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare m mentor_profiles%rowtype;
begin
  select m0.* into m from mentor_profiles m0 join profiles p on p.id = m0.user_id
    where m0.user_id = p_user and (((m0.active and m0.status = 'verified') and not coalesce(p.suspended, false)) or m0.user_id = auth.uid() or is_platform_staff());
  if not found then raise exception 'Mentor introuvable'; end if;
  return _mentor_card(m) || jsonb_build_object(
    'review_list', coalesce((select jsonb_agg(jsonb_build_object('rating', r.rating, 'comment', r.comment, 'author', display_name(r.student_id), 'created_at', r.created_at) order by r.created_at desc)
                             from (select * from mentor_reviews where mentor_id = p_user order by created_at desc limit 20) r), '[]'::jsonb),
    'my_request', (select to_jsonb(q) - 'mentor_id' - 'student_id' from (select id, topic, status, created_at from mentor_requests where mentor_id = p_user and student_id = auth.uid() order by created_at desc limit 1) q));
end $$;
revoke all on function mentor_detail(uuid) from public;
grant execute on function mentor_detail(uuid) to anon, authenticated;

-- ============================================================ 5. Vœux
create or replace function wish_preorder(p_wish uuid, p_on boolean default true) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); w wishes%rowtype; n integer; added boolean := false; v_ended boolean;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : précommande impossible'; end if;
  select * into w from wishes where id = p_wish;
  if not found or not _wish_is_open(w.status, w.publish_at) or exists (select 1 from profiles a where a.id = w.author_id and coalesce(a.suspended, false)) then
    raise exception 'Ce vœu n''est pas ouvert aux précommandes';
  end if;
  v_ended := w.opened_at is not null and w.duration_days is not null and w.opened_at + make_interval(days => w.duration_days) <= now();
  if coalesce(p_on, true) then
    if w.author_id = uid then raise exception 'Vous ne pouvez pas précommander votre propre vœu'; end if;
    if v_ended then raise exception 'Les précommandes de ce vœu sont closes'; end if;
    if (select count(*) from wish_preorders where user_id = uid and created_at > now() - interval '1 day') >= 30 then raise exception 'Trente précommandes par jour au plus'; end if;
    insert into wish_preorders (wish_id, user_id) values (w.id, uid) on conflict do nothing;
    get diagnostics n = row_count;
    added := n > 0;
  else
    if v_ended then raise exception 'Les précommandes de ce vœu sont closes : votre intention est conservée'; end if;
    delete from wish_preorders where wish_id = w.id and user_id = uid;
  end if;
  select count(*)::int into n from wish_preorders where wish_id = w.id;
  if added and (n = 1 or n = w.threshold or n % 10 = 0) then
    perform notify_user(w.author_id, 'wish', case when w.threshold is not null and n >= w.threshold then 'Seuil de précommandes atteint' else 'Nouvelle précommande' end,
      left('« ' || w.title || ' » : ' || n || case when w.threshold is not null then ' / ' || w.threshold else '' end || ' intention(s) de précommande.', 500),
      jsonb_build_object('wish_id', w.id, 'count', n));
  end if;
  return jsonb_build_object('mine', coalesce(p_on, true), 'count', n, 'threshold', w.threshold, 'reached', w.threshold is not null and n >= w.threshold);
end $$;
revoke all on function wish_preorder(uuid, boolean) from public, anon;
grant execute on function wish_preorder(uuid, boolean) to authenticated;

create or replace function wishes_market(p_filter text default 'all', p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); f text := coalesce(nullif(btrim(p_filter), ''), 'all');
begin
  return coalesce((select jsonb_agg(c order by
      case when f = 'near' then (c->>'count')::int end desc nulls last,
      case when f = 'new' then c->>'opened_at' end desc nulls last,
      c->>'created_at' desc)
    from (
      select _wish_card(w, uid) c
      from wishes w
      where _wish_is_open(w.status, w.publish_at)
        and not exists (select 1 from profiles a where a.id = w.author_id and coalesce(a.suspended, false))
        and (w.opened_at is null or w.duration_days is null or w.opened_at + make_interval(days => w.duration_days) > now())
        and (f <> 'new' or coalesce(w.opened_at, w.created_at) >= now() - interval '7 days')
        and (f <> 'mine' or (uid is not null and exists (select 1 from wish_preorders x where x.wish_id = w.id and x.user_id = uid)))
        and (f <> 'near' or (coalesce(w.threshold, 0) > 0
             and (select count(*) from wish_preorders x where x.wish_id = w.id) * 10 >= w.threshold * 7
             and (select count(*) from wish_preorders x where x.wish_id = w.id) < w.threshold))
      order by w.created_at desc
      limit least(greatest(coalesce(p_limit, 50), 1), 100)) q), '[]'::jsonb);
end $$;
revoke all on function wishes_market(text, integer) from public;
grant execute on function wishes_market(text, integer) to anon, authenticated;

-- ============================================================ 6. Salons vocaux
create or replace function study_room_create(p_community uuid, p_title text, p_topic text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  if not is_community_member(p_community) then raise exception 'Réservé aux membres de la communauté'; end if;
  if not exists (select 1 from communities where id = p_community and status = 'active') then raise exception 'Communauté indisponible'; end if;
  if char_length(btrim(coalesce(p_title, ''))) < 3 then raise exception 'Donnez un titre au salon (3 lettres au moins)'; end if;
  perform study_rooms_sweep();
  if (select count(*) from study_rooms where community_id = p_community and status = 'open') >= 3 then raise exception 'Trois salons ouverts au plus : fermez-en un d''abord'; end if;
  if (select count(*) from study_rooms where host_id = auth.uid() and created_at > now() - interval '1 hour') >= 4 then raise exception 'Quatre salons par heure au plus : patientez avant d''en ouvrir un autre'; end if;
  insert into study_rooms (community_id, host_id, title, topic) values (p_community, auth.uid(), left(btrim(p_title), 80), left(btrim(coalesce(p_topic, '')), 200)) returning id into v_id;
  select name into v_name from communities where id = p_community;
  insert into notifications (user_id, kind, title, body, data)
    select m.user_id, 'study_room', 'Salon vocal ouvert', display_name(auth.uid()) || ' ouvre « ' || left(btrim(p_title), 80) || ' » dans « ' || v_name || ' ».', jsonb_build_object('community', p_community, 'room', v_id)
    from community_members m where m.community_id = p_community and m.status = 'active' and m.user_id <> auth.uid();
  return v_id;
end $$;
revoke all on function study_room_create(uuid, text, text) from public, anon;
grant execute on function study_room_create(uuid, text, text) to authenticated;

create or replace function study_room_enter(p_room uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r study_rooms%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  perform study_rooms_sweep();
  select * into r from study_rooms where id = p_room and status = 'open';
  if not found then raise exception 'Ce salon est fermé'; end if;
  if not is_community_member(r.community_id) then raise exception 'Réservé aux membres de la communauté'; end if;
  return jsonb_build_object('id', r.id, 'title', r.title, 'topic', r.topic, 'community_id', r.community_id, 'host_id', r.host_id, 'self_id', auth.uid(), 'name', display_name(auth.uid()),
    'can_close', r.host_id = auth.uid() or community_rank(r.community_id, auth.uid()) >= 2);
end $$;
revoke all on function study_room_enter(uuid) from public, anon;
grant execute on function study_room_enter(uuid) to authenticated;
