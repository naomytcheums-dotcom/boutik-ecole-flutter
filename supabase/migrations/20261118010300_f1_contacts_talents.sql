-- Lot F1 (4/6) — contacts avec les talents, CV, passeport, prix de concours (E5-3, E5-5, E5-6, E5-11, E6-8, décision 4).
--   · talent_contact_request : entreprise ou organisation APPROUVÉE (ou département / administration) ; un client ne peut qu'adresser une demande de contact (pas de proposition de stage) ;
--     talent vérifié, proposé aux recruteurs, dans l'annuaire et CV publié ; texte nettoyé (caractères de contrôle), proposition de stage d'au moins 10 caractères,
--     même texte limité à 3 talents par jour ; dix demandes par jour (quota serveur) ; l'expéditeur est nommé par sa fiche entreprise approuvée ;
--   · start_direct_conversation : une entreprise ou organisation ne CRÉE une conversation qu'avec un talent visible (vérifié, proposé aux recruteurs, dans l'annuaire) ou avec
--     l'équipe de la plateforme, fiche approuvée, 10 nouvelles conversations par jour ; la réponse reste possible dans une conversation existante ; texte nettoyé ;
--   · cv_public : entreprise non approuvée refusée, talent « non proposé aux recruteurs » refusé aux organisations ; nom complet seulement pour la personne, l'équipe de la
--     plateforme et les organisations approuvées (lien de CV publié = consentement) ; nom abrégé pour les autres comptes ;
--   · talent_passport (accès visiteur) : jamais le nom complet ; organisation non approuvée : pas de passeport d'étudiant ; organisation approuvée : nom complet seulement avec CV publié ;
--   · public_profile : nom abrégé d'un étudiant pour un visiteur et pour une organisation (nom complet seulement si organisation approuvée ET CV publié) ;
--   · send_cv_to_recruiter : seules les entreprises et organisations approuvées reçoivent le CV (réponse inchangée : aucune énumération d'adresses) ;
--   · ann_prize_award : le gagnant doit être un étudiant vérifié lié à l'annonce (enregistrée, rappel ou victoire déclarée) ; réponse unique « not_eligible » (plus d'oracle
--     d'adresses ; sans exception, pour que la tentative reste comptée) et dix tentatives par jour.
-- Retour arrière : recréer talent_contact_request (20261117080000), start_direct_conversation (20261115000100), cv_public (20261117020100), talent_passport (20261117020200),
--   public_profile (20261117991000), send_cv_to_recruiter (20261117020000), ann_prize_award (20261114004000) ; drop function _clean_text(text), _talent_sender_label(uuid) ; drop table prize_award_attempts.

create or replace function _clean_text(p_text text) returns text
language sql immutable set search_path = public as $$
  select btrim(regexp_replace(coalesce(p_text, ''), '[' || chr(1) || '-' || chr(8) || chr(11) || chr(12) || chr(14) || '-' || chr(31) || chr(127) || ']', '', 'g'))
$$;
revoke all on function _clean_text(text) from public, anon, authenticated;

-- Nom sous lequel un expéditeur est présenté aux talents : sa fiche entreprise approuvée, sinon son nom abrégé.
create or replace function _talent_sender_label(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select nullif(btrim(c.company_name), '') from company_profiles c join profiles p on p.id = c.owner_id
                   where c.owner_id = p_user and c.status = 'approved' and p.role::text in ('company', 'other')), display_name(p_user))
$$;
revoke all on function _talent_sender_label(uuid) from public, anon, authenticated;

-- ============================================================ contact d'un talent
create or replace function talent_contact_request(p_user uuid, p_kind text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare v_role text := coalesce(current_role_name()::text, ''); v_msg text := left(_clean_text(p_message), 500); v_label text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role not in ('company', 'other', 'client', 'dept', 'admin') then raise exception 'Cette demande est réservée aux entreprises, aux organisations, aux clients et au département'; end if;
  if v_role in ('company', 'other') and not _org_approved(auth.uid()) then
    raise exception '% doit être vérifiée par l''administrateur avant de contacter des talents : complétez votre fiche entreprise et envoyez vos pièces justificatives.', case when v_role = 'other' then 'Votre organisation' else 'Votre entreprise' end;
  end if;
  if p_kind not in ('internship_offer', 'contact') then raise exception 'Type de demande inconnu'; end if;
  if p_kind = 'internship_offer' and v_role = 'client' then raise exception 'Une proposition de stage est réservée aux entreprises vérifiées, aux organisations et au département'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not _talent_listable(p_user) then raise exception 'Talent introuvable'; end if;
  if not _cv_published(p_user) then raise exception 'Ce talent n''a pas publié son CV'; end if;
  if p_kind = 'internship_offer' and char_length(v_msg) < 10 then raise exception 'Précisez votre proposition de stage (10 caractères minimum).'; end if;
  if (select count(*) from talent_contacts where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix demandes par jour au plus'; end if;
  if v_msg <> '' and (select count(*) from talent_contacts where sender_id = auth.uid() and message = v_msg and created_at > now() - interval '1 day') >= 3 then
    raise exception 'Ce même message a déjà été envoyé à trois talents aujourd''hui : personnalisez-le.';
  end if;
  begin
    insert into talent_contacts (sender_id, target_id, kind, message) values (auth.uid(), p_user, p_kind, v_msg);
  exception when unique_violation then
    raise exception 'Vous avez déjà adressé cette demande à ce talent aujourd''hui';
  end;
  v_label := _talent_sender_label(auth.uid());
  perform notify_user(p_user, 'talent_contact', case p_kind when 'internship_offer' then 'Proposition de stage' else 'Demande de contact' end,
    left(v_label || case p_kind when 'internship_offer' then ' vous propose un stage' else ' souhaite vous contacter' end || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('from', auth.uid(), 'kind', p_kind));
  return 'sent';
end $$;
revoke all on function talent_contact_request(uuid, text, text) from public, anon;
grant execute on function talent_contact_request(uuid, text, text) to authenticated;

-- ============================================================ message direct
create or replace function start_direct_conversation(p_user uuid, p_body text) returns uuid
language plpgsql security definer set search_path = public as $$
declare cid uuid; v_role text := coalesce(current_role_name()::text, ''); v_body text := left(_clean_text(p_body), 4000); v_target text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if v_role = '' then raise exception 'Compte suspendu : message impossible'; end if;
  if v_body = '' then raise exception 'Message vide'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous écrire à vous-même'; end if;
  select role::text into v_target from profiles where id = p_user and not coalesce(suspended, false);
  if v_target is null then raise exception 'Destinataire introuvable'; end if;
  perform chat_guard(p_user);
  select c.id into cid from conversations c
    where c.listing_id is null and c.order_number is null
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = auth.uid())
      and exists (select 1 from conversation_participants p where p.conversation_id = c.id and p.user_id = p_user)
      and (select count(*) from conversation_participants p where p.conversation_id = c.id) = 2
    limit 1;
  if cid is null then
    -- Une entreprise ou organisation n'ouvre une conversation qu'avec un talent visible ou l'équipe de la plateforme.
    if v_role in ('company', 'other') then
      if not _org_approved(auth.uid()) then
        raise exception '% doit être vérifiée par l''administrateur avant de contacter des talents : complétez votre fiche entreprise et envoyez vos pièces justificatives.', case when v_role = 'other' then 'Votre organisation' else 'Votre entreprise' end;
      end if;
      if not (_talent_listable(p_user) or v_target in ('admin', 'dept', 'support', 'direction', 'finance')) then raise exception 'Destinataire introuvable'; end if;
      if (select count(*) from conversations where created_by = auth.uid() and listing_id is null and order_number is null and created_at > now() - interval '1 day') >= 10 then
        raise exception 'Dix nouvelles conversations par jour au plus pour une entreprise : poursuivez vos échanges en cours.';
      end if;
    end if;
    if (select count(*) from conversations where created_by = auth.uid() and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Trop de nouvelles conversations aujourd''hui';
    end if;
    insert into conversations (listing_id, created_by) values (null, auth.uid()) returning id into cid;
    insert into conversation_participants (conversation_id, user_id, last_read_at)
      values (cid, auth.uid(), now()), (cid, p_user, timestamptz 'epoch');
  end if;
  insert into messages (conversation_id, sender_id, body) values (cid, auth.uid(), v_body);
  return cid;
end $$;
revoke all on function start_direct_conversation(uuid, text) from public, anon;
grant execute on function start_direct_conversation(uuid, text) to authenticated;

-- ============================================================ CV et passeport
create or replace function cv_public(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c cv_links%rowtype; v_class text; v_cv jsonb; v_other boolean := p_user is distinct from auth.uid();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_class := _viewer_class();
  if v_class = 'suspended' then raise exception 'Compte suspendu : consultation impossible'; end if;
  if v_other and v_class = 'org_locked' then
    raise exception 'Votre entreprise doit être vérifiée par l''administrateur avant de consulter les CV des talents.';
  end if;
  if v_other and v_class = 'org_ok' and not _talent_visible(p_user) then return null; end if;
  if not profile_visible(p_user) then return null; end if;
  select * into c from cv_links where owner_id = p_user and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then return null; end if;
  v_cv := _cv_payload(c);
  if v_cv is null then return null; end if;
  if v_other and v_class not in ('staff', 'org_ok') then v_cv := jsonb_set(v_cv, '{nom}', to_jsonb(_short_name(v_cv ->> 'nom'))); end if;
  return v_cv || jsonb_build_object('user_id', p_user);
end $$;
revoke all on function cv_public(uuid) from public, anon;
grant execute on function cv_public(uuid) to authenticated;

create or replace function talent_passport(p_user uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_user uuid := coalesce(p_user, auth.uid()); v_own boolean; p profiles%rowtype; v_points integer; v_class text := _viewer_class(); v_full boolean;
begin
  if v_user is null then return null; end if;
  v_own := v_user = auth.uid();
  select * into p from profiles where id = v_user and not coalesce(suspended, false);
  if not found or not profile_visible(v_user) then return null; end if;
  if not v_own and v_class = 'org_locked' and p.role::text = 'student' then return null; end if;
  v_full := v_own or v_class in ('staff', 'other') or (v_class = 'org_ok' and (p.role::text <> 'student' or _cv_published(v_user)));
  v_points := points_total(v_user);
  return jsonb_build_object(
    'user_id', p.id, 'own', v_own, 'name', case when v_full then p.name else _short_name(p.name) end, 'certified', p.certification::text = 'approved',
    'points', v_points, 'level', point_level(v_points),
    'skills', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'domain', s.domain, 'job', s.job, 'skill', s.skill, 'level', s.level, 'years', s.years,
                                          'description', case when v_own then s.description else '' end,
                                          'has_proof', s.proof_document_id is not null, 'proof_verified', coalesce(d.status = 'verified', false))
                       order by case s.level when 'expert' then 0 when 'avance' then 1 when 'intermediaire' then 2 else 3 end, s.created_at)
      from talent_skills s left join user_documents d on d.id = s.proof_document_id where s.owner_id = v_user), '[]'::jsonb),
    'badges', coalesce((
      select jsonb_agg(jsonb_build_object('code', b.code, 'count', b.n) order by b.ord)
      from (
        select 1 as ord, 'certified'::text as code, 1 as n where p.certification::text = 'approved'
        union all select 2, 'certificates', count(*)::int from certificates c where c.holder_id = v_user and not c.revoked having count(*) > 0
        union all select 3, 'verified_documents', count(*)::int from user_documents d where d.owner_id = v_user and d.status = 'verified' having count(*) > 0
        union all select 4, 'proven_skills', count(*)::int from talent_skills s join user_documents d on d.id = s.proof_document_id and d.status = 'verified'
                   where s.owner_id = v_user having count(*) > 0
        union all select 5, 'expert_skills', count(*)::int from talent_skills s where s.owner_id = v_user and s.level = 'expert' having count(*) > 0
        union all select 6, 'missions', count(*)::int from missions m join mission_proposals mp on mp.mission_id = m.id and mp.author_id = v_user and mp.status = 'accepted'
                   where m.status in ('delivered', 'closed') having count(*) > 0
        union all select 7, 'helper', 1 where point_level(v_points) <> 'none'
      ) b), '[]'::jsonb));
end $$;
revoke all on function talent_passport(uuid) from public;
grant execute on function talent_passport(uuid) to anon, authenticated;

-- public_profile (dernière définition : 20261117991000) : un étudiant n'est nommé en entier ni à un visiteur, ni à une organisation sans CV publié.
create or replace function public_profile(p_user uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id,
    'name', case when auth.uid() is null then _short_name(p.name)
                 when p.id <> auth.uid() and p.role::text = 'student' and _viewer_class() in ('org_ok', 'org_locked') and not (_viewer_class() = 'org_ok' and _cv_published(p.id)) then _short_name(p.name)
                 else p.name end,
    'role', case when p.role::text in ('student', 'company', 'other') then p.role::text else 'student' end,
    'city', coalesce(p.city, ''),
    'institution', coalesce(p.institution, ''),
    'department', coalesce(p.department, ''),
    'bio', coalesce(p.bio, ''),
    'skills', coalesce(p.skills, ''),
    'avatar_url', p.avatar_url,
    'certified', p.certification::text = 'approved',
    'posts_count', (select count(*)::int from posts x where x.author_id = p.id and x.status = 'published' and x.kind = 'media' and x.community_id is null),
    'followers_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.ref = p.id::text and e.status = 'active'),
    'following_count', (select count(*)::int from engagements e where e.kind = 'follow' and e.user_id = p.id and e.status = 'active'),
    'rating', coalesce((select round(avg(r.rating)::numeric, 2) from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id), 0),
    'rating_count', (select count(*)::int from reviews r join listings l on l.id = r.listing_id where l.seller_id = p.id)
  )
  from profiles p
  where p.id = p_user and not coalesce(p.suspended, false)
    and profile_visible(p.id)
    and (
      p.id = auth.uid()
      or (p.role::text in ('student', 'company', 'other'))
      or (p.role::text not in ('admin', 'direction', 'finance', 'support', 'client', 'visitor')
          and (exists (select 1 from posts x where x.author_id = p.id and x.status = 'published' and x.community_id is null)
            or exists (select 1 from listings l where l.seller_id = p.id and l.status = 'approved')))
    );
$$;

-- ============================================================ envoi de CV
create or replace function send_cv_to_recruiter(p_email text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c cv_links%rowtype; r profiles%rowtype; v_mail text := lower(btrim(coalesce(p_email, ''))); v_msg text := left(_clean_text(p_message), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : envoi impossible'; end if;
  select * into c from cv_links where owner_id = auth.uid() and revoked_at is null and (expires_at is null or expires_at > now());
  if not found then raise exception 'Créez d''abord le lien de votre CV (écran « Partager mon CV »)'; end if;
  if v_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or char_length(v_mail) > 254 then raise exception 'Adresse e-mail invalide'; end if;
  -- Limite sur les tentatives, qu'elles aboutissent ou non : sinon la limite ne protège pas contre le sondage d'adresses.
  if (select count(*) from cv_send_attempts where sender_id = auth.uid() and at > now() - interval '1 day') >= 5 then raise exception 'Cinq envois de CV par jour au plus'; end if;
  insert into cv_send_attempts (sender_id) values (auth.uid());
  delete from cv_send_attempts where at < now() - interval '2 days';
  select * into r from profiles where lower(email) = v_mail and role::text in ('company', 'other') and not coalesce(suspended, false) and _org_approved(id);
  if found and not exists (select 1 from cv_sends where sender_id = auth.uid() and recipient_id = r.id and created_at > now() - interval '1 day') then
    insert into cv_sends (sender_id, recipient_id, token, message) values (auth.uid(), r.id, c.token, v_msg);
    perform notify_user(r.id, 'cv_shared', 'CV reçu', left(display_name(auth.uid()) || ' vous envoie son CV' || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
      jsonb_build_object('cv_token', c.token, 'from', auth.uid()));
  end if;
  return 'sent';
end $$;
revoke all on function send_cv_to_recruiter(text, text) from public, anon;
grant execute on function send_cv_to_recruiter(text, text) to authenticated;

-- ============================================================ gagnant d'un concours à récompense
create table if not exists prize_award_attempts (
  sponsor_id uuid not null references profiles(id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists prize_award_attempts_sponsor on prize_award_attempts (sponsor_id, at desc);
alter table prize_award_attempts enable row level security;
revoke all on prize_award_attempts from public, anon, authenticated;

create or replace function ann_prize_award(p_ann uuid, p_winner_email text) returns text
language plpgsql security definer set search_path = public as $$
declare a contest_announcements%rowtype; w profiles%rowtype; e money_entries%rowtype; r record; v_mail text := lower(btrim(coalesce(p_winner_email, '')));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select * into a from contest_announcements where id = p_ann and poster_id = auth.uid();
  if not found then raise exception 'Annonce introuvable'; end if;
  if a.prize_status <> 'held' then raise exception 'Aucune récompense en séquestre à attribuer'; end if;
  if (select count(*) from prize_award_attempts where sponsor_id = auth.uid() and at > now() - interval '1 day') >= 10 then raise exception 'Dix tentatives par jour au plus'; end if;
  insert into prize_award_attempts (sponsor_id) values (auth.uid());
  delete from prize_award_attempts where at < now() - interval '2 days';
  select * into w from profiles where lower(email) = v_mail and role = 'student' and not suspended and is_verified_student(id)
    and (exists (select 1 from contest_ann_saves s where s.announcement_id = a.id and s.user_id = profiles.id)
      or exists (select 1 from contest_ann_reminders m where m.announcement_id = a.id and m.user_id = profiles.id)
      or exists (select 1 from contest_ann_wins x where x.announcement_id = a.id and x.student_id = profiles.id and x.status <> 'rejected'));
  if not found then
    -- Pas d'exception : elle annulerait l'enregistrement de la tentative et la limite quotidienne ne compterait que les réussites.
    return 'not_eligible';
  end if;
  if w.id = a.poster_id then raise exception 'Vous ne pouvez pas vous attribuer la récompense'; end if;
  select * into e from money_entries where id = a.prize_entry for update;
  if not found or e.status <> 'held' then raise exception 'Le séquestre de cette récompense n''est plus disponible'; end if;
  update money_entries set beneficiary_id = w.id, beneficiary_amount = a.prize_amount, platform_amount = e.gross - a.prize_amount, split = 'défi : 100 % au gagnant' where id = e.id;
  update contest_announcements set prize_status = 'awarded', prize_winner = w.id where id = a.id;
  perform notify_user(w.id, 'contest_prize', 'Récompense attribuée', 'Bravo ! ' || a.organizer || ' vous attribue ' || a.prize_amount || ' FCFA pour « ' || a.title || ' ». L''équipe Boutik-École la débloque sur votre solde.', jsonb_build_object('announcement', a.id));
  for r in select id from profiles where role = 'admin' and not suspended limit 20 loop
    perform notify_user(r.id, 'contest_prize', 'Récompense à débloquer', a.prize_amount || ' FCFA pour « ' || a.title || ' » : le gagnant est désigné, à débloquer dans Séquestre.', jsonb_build_object('announcement', a.id, 'entry', e.id));
  end loop;
  return 'awarded';
end $$;
revoke all on function ann_prize_award(uuid, text) from public, anon;
grant execute on function ann_prize_award(uuid, text) to authenticated;
