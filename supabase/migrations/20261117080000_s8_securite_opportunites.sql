-- Lot S8 (profil Étudiant-vendeur) — sécurité des opportunités.
--  1. S8-1  Offres réservées à l'IUT : l'éligibilité repose sur un établissement VÉRIFIÉ du référentiel rattaché au profil (jamais sur un texte libre).
--  2. S8-2  Réglage « Me proposer aux recruteurs » (par défaut oui ; l'étudiant peut le retirer) respecté par les suggestions et les invitations.
--  3. S8-3  « Partager mon recrutement » : confirmation explicite, retrait du partage, visiteur : prénom seulement.
--  4. S8-14 Retrait de candidature : historique conservé, une nouvelle candidature à la même offre est espacée (24 h) et limitée (3 retraits).
-- Aucune donnée existante n'est supprimée. Rejouable. Retour arrière : voir le bas du fichier.

-- ============================================================ 1. Étudiant d'un établissement IUT vérifié
-- Vrai si la personne est un « étudiant vérifié » au sens du lot S1 (is_verified_student : certification approuvée ou carte d'étudiant / certificat de
-- scolarité validé par l'équipe) ET si l'établissement (ou le département) rattaché au profil existe dans le référentiel avec le statut « verified » et
-- s'appelle IUT. Les établissements proposés par un utilisateur ne comptent jamais tant que l'équipe ne les a pas publiés ; le texte libre non plus.
-- Dépend de is_verified_student(uuid) (migration 20261117010000_s1_etudiant_verifie).
create or replace function _is_verified_iut_student(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_verified_student(p_user) and coalesce((
    select (i.status = 'verified' and (lower(coalesce(i.short_name, '')) ~ '^iut\M' or lower(i.name) ~ '^(iut\M|institut universitaire de technologie)'))
        or (d.id is not null and d.status = 'verified' and i.status = 'verified' and lower(d.name) ~ '^(iut\M|institut universitaire de technologie)')
    from profiles p
    left join institutions i on i.id = p.institution_id
    left join departments d on d.id = p.department_id and d.institution_id = p.institution_id
    where p.id = p_user and i.id is not null), false)
$$;
revoke all on function _is_verified_iut_student(uuid) from public, anon, authenticated;

-- ============================================================ 4. Historique des retraits de candidature (S8-14)
create table if not exists opportunity_withdrawals (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  applicant_id uuid not null references profiles(id) on delete cascade,
  previous_status text not null,
  withdrawn_at timestamptz not null default now()
);
create index if not exists opportunity_withdrawals_key on opportunity_withdrawals (opportunity_id, applicant_id, withdrawn_at desc);
alter table opportunity_withdrawals enable row level security;
revoke all on opportunity_withdrawals from anon, authenticated;

-- Retrait : la ligne est supprimée comme avant mais l'historique est conservé ; l'auteur de l'offre est prévenu.
create or replace function opp_withdraw_application(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  select * into a from opportunity_applications where id = p_id and applicant_id = auth.uid();
  if not found then raise exception 'Candidature introuvable'; end if;
  if a.status in ('rejected', 'hired') then raise exception 'Cette candidature a déjà reçu une réponse définitive'; end if;
  insert into opportunity_withdrawals (opportunity_id, applicant_id, previous_status) values (a.opportunity_id, a.applicant_id, a.status);
  delete from opportunity_applications where id = p_id;
  select * into o from opportunities where id = a.opportunity_id;
  if found then
    perform notify_user(o.poster_id, 'opportunity_application', 'Candidature retirée', display_name(auth.uid()) || ' a retiré sa candidature à « ' || left(o.title, 60) || ' ».', jsonb_build_object('opportunity', o.id));
  end if;
end $$;
revoke all on function opp_withdraw_application(uuid) from public, anon;
grant execute on function opp_withdraw_application(uuid) to authenticated;

-- Candidature : IUT sur référentiel vérifié (S8-1) ; après un retrait, 24 h d'attente et 3 retraits au plus par offre (S8-14).
create or replace function opp_apply(p_id uuid, p_message text, p_cv_link text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_id uuid; v_last timestamptz; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_id and status = 'published';
  if not found or (o.deadline is not null and o.deadline < current_date) then raise exception 'Cette offre n''accepte plus de candidatures'; end if;
  if not o.apply_in_app then raise exception 'Cette offre se postule uniquement par WhatsApp'; end if;
  if o.poster_id = auth.uid() then raise exception 'C''est votre propre offre'; end if;
  if o.iut_only and not _is_verified_iut_student(auth.uid()) then raise exception 'Offre réservée aux étudiants de l''IUT'; end if;
  if char_length(btrim(coalesce(p_message, ''))) < 20 then raise exception 'Écrivez votre lettre de motivation (20 caractères minimum)'; end if;
  if char_length(btrim(coalesce(p_cv_link, ''))) > 0 and btrim(p_cv_link) !~* '^https?://' then raise exception 'Le lien du CV doit commencer par http'; end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_id and applicant_id = auth.uid()) then raise exception 'Vous avez déjà postulé'; end if;
  select max(withdrawn_at), count(*) into v_last, v_n from opportunity_withdrawals where opportunity_id = p_id and applicant_id = auth.uid();
  if v_n >= 3 then raise exception 'Vous avez déjà retiré trois fois votre candidature à cette offre'; end if;
  if v_last is not null and v_last > now() - interval '24 hours' then raise exception 'Vous avez retiré votre candidature il y a moins de 24 h : patientez avant de postuler de nouveau'; end if;
  insert into opportunity_applications (opportunity_id, applicant_id, message, cv_link) values (p_id, auth.uid(), btrim(p_message), btrim(coalesce(p_cv_link, ''))) returning id into v_id;
  perform notify_user(o.poster_id, 'opportunity_application', 'Nouvelle candidature', display_name(auth.uid()) || ' postule à « ' || left(o.title, 60) || ' ».', jsonb_build_object('opportunity', p_id, 'application', v_id));
  return v_id;
end $$;
revoke all on function opp_apply(uuid, text, text) from public, anon;
grant execute on function opp_apply(uuid, text, text) to authenticated;

-- Offres recommandées : les offres IUT ne sont proposées qu'aux étudiants d'un établissement IUT vérifié.
create or replace function opps_recommended(p_limit integer default 10) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_iut boolean; v_lim integer := least(greatest(coalesce(p_limit, 10), 1), 30);
begin
  if uid is null then return '[]'::jsonb; end if;
  v_iut := _is_verified_iut_student(uid);
  return coalesce((
    select jsonb_agg(y.c order by y.s desc, y.created desc) from (
      select x.c, coalesce((x.c->'match'->>'score')::int, 0) s, x.c->>'created_at' created from (
        select _opp_card(o, uid) || jsonb_build_object('match', _opp_match(o, uid)) c
        from opportunities o
        where o.status = 'published' and (o.deadline is null or o.deadline >= current_date) and o.poster_id <> uid
          and (not o.iut_only or v_iut)
          and not exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = uid)
        order by o.created_at desc limit 200) x
      order by 2 desc, 3 desc limit v_lim) y), '[]'::jsonb);
end $$;
revoke all on function opps_recommended(integer) from public, anon;
grant execute on function opps_recommended(integer) to authenticated;

-- Fiche d'une offre : indique si la personne connectée peut postuler à une offre réservée IUT (établissement vérifié).
create or replace function opp_detail(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; uid uuid := auth.uid();
begin
  select * into o from opportunities where id = p_id;
  if not found or (o.status <> 'published' and o.poster_id is distinct from uid and coalesce(current_role_name()::text, '') not in ('admin', 'dept')) then raise exception 'Offre introuvable'; end if;
  return _opp_card(o, uid) || jsonb_build_object('description', o.description, 'missions', to_jsonb(o.missions), 'profile_wanted', o.profile_wanted, 'level', o.level, 'gains', to_jsonb(o.gains),
    'apply_whatsapp', o.apply_whatsapp, 'apply_in_app', o.apply_in_app, 'about_org', o.about_org, 'mine', o.poster_id = uid, 'review_note', o.review_note,
    'iut_eligible', case when uid is null then false else _is_verified_iut_student(uid) end,
    'my_application', (select to_jsonb(a) - 'opportunity_id' - 'applicant_id' - 'message' from (select id, status, created_at from opportunity_applications where opportunity_id = p_id and applicant_id = uid) a),
    'reminder', exists (select 1 from opportunity_reminders r where r.opportunity_id = p_id and r.user_id = uid),
    'other_offers', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'title', x.title, 'kind', x.kind)) from (select id, title, kind from opportunities where poster_id = o.poster_id and id <> p_id and status in ('published', 'closed') order by created_at desc limit 5) x), '[]'::jsonb));
end $$;
revoke all on function opp_detail(uuid) from public;
grant execute on function opp_detail(uuid) to anon, authenticated;

-- ============================================================ 2. Visibilité auprès des recruteurs (S8-2)
-- Par défaut l'étudiant est proposable (comportement existant) ; il peut se retirer des suggestions et des invitations.
create table if not exists student_talent_prefs (
  user_id uuid primary key references profiles(id) on delete cascade,
  visible_to_recruiters boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table student_talent_prefs enable row level security;
revoke all on student_talent_prefs from anon, authenticated;

-- Vrai tant que l'étudiant n'a pas retiré sa visibilité (utilisable par les autres RPC de talents).
create or replace function _talent_visible(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select t.visible_to_recruiters from student_talent_prefs t where t.user_id = p_user), true)
$$;
revoke all on function _talent_visible(uuid) from public, anon, authenticated;

create or replace function talent_visibility_get() returns boolean
language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then true else _talent_visible(auth.uid()) end
$$;

create or replace function talent_visibility_set(p_visible boolean) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_visible is null then raise exception 'Choix incomplet'; end if;
  insert into student_talent_prefs (user_id, visible_to_recruiters) values (auth.uid(), p_visible)
  on conflict (user_id) do update set visible_to_recruiters = excluded.visible_to_recruiters, updated_at = now();
  return p_visible;
end $$;
revoke all on function talent_visibility_get(), talent_visibility_set(boolean) from public, anon;
grant execute on function talent_visibility_get(), talent_visibility_set(boolean) to authenticated;

-- Suggestions : les étudiants vérifiés (lot S1) qui ont retiré leur visibilité ne sont plus proposés.
create or replace function opp_suggested_students(p_id uuid, p_limit integer default 10) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o opportunities%rowtype;
begin
  select * into o from opportunities where id = p_id and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  return coalesce((
    select jsonb_agg(t.j order by (t.j->'match'->>'score')::int desc, t.j->>'name')
    from (select x.j
          from (select jsonb_build_object('id', pr.id, 'name', display_name(pr.id), 'department', pr.department, 'avatar_url', pr.avatar_url, 'match', _opp_match(o, pr.id),
                       'invited', exists (select 1 from opportunity_invites iv where iv.opportunity_id = p_id and iv.student_id = pr.id)) j
                from profiles pr
                where pr.role = 'student' and not pr.suspended and pr.id <> o.poster_id and is_verified_student(pr.id)
                  and _talent_visible(pr.id)
                  and (btrim(coalesce(pr.skills, '')) <> '' or btrim(coalesce(pr.bio, '')) <> '')
                  and not exists (select 1 from opportunity_applications a where a.opportunity_id = p_id and a.applicant_id = pr.id)
                limit 500) x
          where (x.j->'match'->>'score')::int >= 30
          order by (x.j->'match'->>'score')::int desc, x.j->>'name'
          limit greatest(1, least(coalesce(p_limit, 10), 30))) t), '[]'::jsonb);
end $$;
revoke all on function opp_suggested_students(uuid, integer) from public, anon;
grant execute on function opp_suggested_students(uuid, integer) to authenticated;

-- Invitation : refusée pour un étudiant qui ne souhaite pas être proposé ; l'étudiant invité est toujours notifié (notification « opportunity_invite »).
create or replace function opp_invite(p_opp uuid, p_student uuid, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_msg text := left(btrim(coalesce(p_message, '')), 300);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  if o.status <> 'published' then raise exception 'Publiez l''offre avant d''inviter des étudiants'; end if;
  if not is_verified_student(p_student) or not _talent_visible(p_student) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_opp and applicant_id = p_student) then raise exception 'Cet étudiant a déjà postulé'; end if;
  if exists (select 1 from opportunity_invites where opportunity_id = p_opp and student_id = p_student) then raise exception 'Cet étudiant est déjà invité'; end if;
  if (select count(*) from opportunity_invites where opportunity_id = p_opp) >= 30 then raise exception '30 invitations au plus par offre'; end if;
  if (select count(*) from opportunity_invites where invited_by = auth.uid() and created_at > now() - interval '1 day') >= 100 then raise exception '100 invitations au plus par jour'; end if;
  insert into opportunity_invites (opportunity_id, student_id, invited_by, message) values (p_opp, p_student, auth.uid(), v_msg);
  perform notify_user(p_student, 'opportunity_invite', o.org_name || ' vous invite à postuler', o.title || case when v_msg <> '' then ' : ' || v_msg else '' end || ' · Ouvrez l''offre dans Opportunités.',
                      jsonb_build_object('opportunity', p_opp));
  return 'invited';
end $$;
revoke all on function opp_invite(uuid, uuid, text) from public, anon;
grant execute on function opp_invite(uuid, uuid, text) to authenticated;

-- Vivier et demandes de contact (dernières définitions : 20261117010000_s1_etudiant_verifie) : un étudiant qui s'est retiré n'est plus ajouté ni contacté.
create or replace function talent_list_add(p_list uuid, p_student uuid, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  if not exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid()) then raise exception 'Liste introuvable'; end if;
  if not is_verified_student(p_student) or not _talent_visible(p_student) then raise exception 'Étudiant introuvable'; end if;
  if (select count(*) from talent_list_members where list_id = p_list) >= 500 then raise exception '500 étudiants au plus par liste'; end if;
  insert into talent_list_members (list_id, student_id, note) values (p_list, p_student, left(btrim(coalesce(p_note, '')), 200))
  on conflict (list_id, student_id) do update set note = excluded.note;
end $$;
revoke all on function talent_list_add(uuid, uuid, text) from public, anon;
grant execute on function talent_list_add(uuid, uuid, text) to authenticated;

create or replace function talent_contact_request(p_user uuid, p_kind text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare v_msg text := left(btrim(coalesce(p_message, '')), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('company', 'client', 'other', 'dept', 'admin') then raise exception 'Cette demande est réservée aux entreprises, aux clients et au département'; end if;
  if p_kind not in ('internship_offer', 'contact') then raise exception 'Type de demande inconnu'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not is_verified_student(p_user) or not _talent_visible(p_user) then raise exception 'Talent introuvable'; end if;
  if not exists (select 1 from cv_links where owner_id = p_user and revoked_at is null and (expires_at is null or expires_at > now())) then raise exception 'Ce talent n''a pas publié son CV'; end if;
  if (select count(*) from talent_contacts where sender_id = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix demandes par jour au plus'; end if;
  begin
    insert into talent_contacts (sender_id, target_id, kind, message) values (auth.uid(), p_user, p_kind, v_msg);
  exception when unique_violation then
    raise exception 'Vous avez déjà adressé cette demande à ce talent aujourd''hui';
  end;
  perform notify_user(p_user, 'talent_contact', case p_kind when 'internship_offer' then 'Proposition de stage' else 'Demande de contact' end,
    left(display_name(auth.uid()) || case p_kind when 'internship_offer' then ' vous propose un stage' else ' souhaite vous contacter' end || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
    jsonb_build_object('from', auth.uid(), 'kind', p_kind));
  return 'sent';
end $$;
revoke all on function talent_contact_request(uuid, text, text) from public, anon;
grant execute on function talent_contact_request(uuid, text, text) to authenticated;

-- Mes invitations (propositions reçues de recruteurs) : l'étudiant concerné seulement.
create or replace function opp_my_invites() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('opportunity_id', o.id, 'title', o.title, 'org', o.org_name, 'status', iv.status, 'message', iv.message, 'created_at', iv.created_at,
      'deadline', o.deadline, 'offer_status', o.status, 'open', o.status = 'published' and (o.deadline is null or o.deadline >= current_date)) order by iv.created_at desc), '[]'::jsonb)
  from opportunity_invites iv join opportunities o on o.id = iv.opportunity_id where iv.student_id = auth.uid()
$$;
revoke all on function opp_my_invites() from public, anon;
grant execute on function opp_my_invites() to authenticated;

-- ============================================================ 3. « Partager mon recrutement » (S8-3)
-- La signature change : le partage exige désormais une confirmation explicite (p_confirm = true).
drop function if exists opp_hire_publish(uuid);
create or replace function opp_hire_publish(p_application uuid, p_confirm boolean default false) returns void
language plpgsql security definer set search_path = public as $$
declare a opportunity_applications%rowtype; o opportunities%rowtype; v_dept text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if current_role_name() is null then raise exception 'Compte suspendu : action impossible'; end if;
  if not coalesce(p_confirm, false) then raise exception 'Confirmez le partage : votre prénom, votre filière, l''organisation et le poste seront visibles de tous, visiteurs compris'; end if;
  select * into a from opportunity_applications where id = p_application and applicant_id = auth.uid();
  if not found then raise exception 'Candidature introuvable'; end if;
  if a.status <> 'hired' then raise exception 'Vous pourrez partager votre recrutement une fois retenu(e) par l''organisation'; end if;
  select * into o from opportunities where id = a.opportunity_id;
  select coalesce(department, '') into v_dept from profiles where id = auth.uid();
  insert into opportunity_hires (application_id, student_id, org_name, role_title, department) values (p_application, auth.uid(), o.org_name, o.title, v_dept) on conflict do nothing;
end $$;

-- Retrait du partage : l'annonce disparaît de « Ils ont été recrutés ».
create or replace function opp_hire_unpublish(p_application uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from opportunity_hires where application_id = p_application and student_id = auth.uid();
  if not found then raise exception 'Aucun partage à retirer'; end if;
end $$;

-- Liste publique : un visiteur ne voit que le prénom ; une personne connectée voit « Prénom N. ».
create or replace function opp_hired_list(p_limit integer default 10) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'name', case when auth.uid() is null then coalesce(nullif(split_part(btrim((select name from profiles where id = h.student_id)), ' ', 1), ''), 'Un étudiant') else display_name(h.student_id) end,
      'department', h.department, 'org', h.org_name, 'role', h.role_title, 'created_at', h.created_at) order by h.created_at desc), '[]'::jsonb)
  from (select * from opportunity_hires order by created_at desc limit least(greatest(coalesce(p_limit, 10), 1), 30)) h
$$;

revoke all on function opp_hire_publish(uuid, boolean), opp_hire_unpublish(uuid) from public, anon;
grant execute on function opp_hire_publish(uuid, boolean), opp_hire_unpublish(uuid) to authenticated;
revoke all on function opp_hired_list(integer) from public;
grant execute on function opp_hired_list(integer) to anon, authenticated;

-- Retour arrière :
--   drop function opp_hire_unpublish(uuid), opp_my_invites(), talent_visibility_get(), talent_visibility_set(boolean), _talent_visible(uuid), _is_verified_iut_student(uuid);
--   drop function opp_hire_publish(uuid, boolean) ; recréer opp_hire_publish(uuid) et opp_hired_list depuis 20261114001300 ;
--   recréer opp_apply (20261114001300), opp_withdraw_application et opps_recommended (20261115180000), opp_detail (20261114001300),
--   opp_suggested_students, opp_invite, talent_list_add, talent_contact_request (20261117010000_s1_etudiant_verifie) ;
--   drop table opportunity_withdrawals, student_talent_prefs;
-- À FAIRE PAR LE CHEF (objet réservé) : talents_list doit ajouter « and _talent_visible(id) » à son filtre d'étudiants (réglage « Me proposer aux recruteurs »).
