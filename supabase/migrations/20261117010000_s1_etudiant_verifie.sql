-- Lot S1 (profil étudiant-vendeur) — partie 1 : « étudiant vérifié », décisions sur les pièces et le référentiel, certification par périmètre.
--   S1-4 / S1-87 : le rôle « student » reste choisi à l'inscription, mais l'annuaire des talents, les invitations et le vivier d'entreprises,
--                  les contacts de talents et les chiffres publics des départements ne comptent que les étudiants VÉRIFIÉS.
--                  Étudiant vérifié = rôle student, compte actif, ET (certification « approved » OU une carte d'étudiant / un certificat
--                  de scolarité dont la pièce a été validée par l'équipe). Fonction interne is_verified_student(uuid) : le lot S8 peut s'en servir
--                  pour les offres « réservées IUT » (opp_apply, liste d'offres).
--   S1-82 / S1-83 / S1-84 : decide_certification limité au périmètre (département ou établissement) du responsable ; l'administrateur décide pour tous.
--                  submit_certification_request exige un profil éligible et un justificatif valable ; file de demandes (certification_queue) ouverte au département.
--   S1-19 / S1-24 / S1-25 / S1-27 : décisions sur les pièces (liste, validation, refus motivé, notification de l'étudiant) et sur les propositions
--                  d'établissements/départements ; la validation d'une pièce a désormais un effet réel (statut « étudiant vérifié »).
--   S1-80 : matricule unique par établissement (contrôle dans profile_set_academic ; pas d'index unique : des doublons existants feraient échouer la migration).
--   S1-81 : le fichier d'une pièce enregistrée ne se supprime plus directement dans le stockage (passer par document_delete).
-- Additive et rejouable. Retour arrière : voir la fin du fichier.

-- ============================================================ 1. Aides internes
-- Étudiant vérifié (jamais appelable par l'application : les fonctions SECURITY DEFINER l'utilisent, le client lit my_student_status()).
create or replace function is_verified_student(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select p.role::text = 'student' and not coalesce(p.suspended, false)
       and (p.certification::text = 'approved'
            or exists (select 1 from user_documents d where d.owner_id = p.id and d.kind in ('student_card', 'enrollment_certificate') and d.status = 'verified'))
    from profiles p where p.id = p_user), false)
$$;
revoke all on function is_verified_student(uuid) from public, anon, authenticated;

-- Le responsable connecté peut-il décider pour cette personne ? administrateur : tout le monde ; support (si p_support) : tout le monde ;
-- département : les comptes de SON département (ou, sans département renseigné, de son établissement).
create or replace function _review_scope_ok(p_target uuid, p_support boolean default false) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, ''); me profiles%rowtype; t profiles%rowtype;
begin
  if auth.uid() is null then return false; end if;
  if r = 'admin' or (p_support and r = 'support') then return true; end if;
  if r <> 'dept' then return false; end if;
  select * into me from profiles where id = auth.uid();
  select * into t from profiles where id = p_target;
  if t.id is null then return false; end if;
  if me.department_id is not null then return t.department_id = me.department_id; end if;
  return me.institution_id is not null and t.institution_id = me.institution_id;
end $$;
revoke all on function _review_scope_ok(uuid, boolean) from public, anon, authenticated;

-- Destinataires d'une demande concernant cette personne : administrateurs, (support) et responsables de son département / établissement.
create or replace function _scope_recipients(p_target uuid, p_support boolean default false) returns setof uuid
language sql stable security definer set search_path = public as $$
  select a.id from profiles a, profiles t
  where t.id = p_target and not coalesce(a.suspended, false)
    and (a.role::text = 'admin' or (p_support and a.role::text = 'support')
         or (a.role::text = 'dept' and ((a.department_id is not null and a.department_id = t.department_id)
                                      or (a.department_id is null and a.institution_id is not null and a.institution_id = t.institution_id))))
$$;
revoke all on function _scope_recipients(uuid, boolean) from public, anon, authenticated;

-- Fichier d'une pièce enregistrée (stockage) : utilisé par les politiques ci-dessous (une sous-requête y confondrait « name »).
create or replace function _profile_doc_registered(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from user_documents d where d.path = p_path)
$$;
create or replace function _profile_doc_reviewable(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from user_documents d where d.path = p_path and _review_scope_ok(d.owner_id, false))
$$;
revoke all on function _profile_doc_registered(text), _profile_doc_reviewable(text) from public, anon;
grant execute on function _profile_doc_registered(text), _profile_doc_reviewable(text) to authenticated;

-- ============================================================ 2. Stockage des pièces (S1-81, ouverture par le département)
drop policy if exists "documents profil : suppression par le propriétaire" on storage.objects;
create policy "documents profil : suppression par le propriétaire" on storage.objects for delete to authenticated
  using (bucket_id = 'profile-documents' and (storage.foldername(name))[1] = auth.uid()::text and not _profile_doc_registered(name));
drop policy if exists "documents profil : lecture par le département" on storage.objects;
create policy "documents profil : lecture par le département" on storage.objects for select to authenticated
  using (bucket_id = 'profile-documents' and coalesce(current_role_name()::text, '') = 'dept' and _profile_doc_reviewable(name));

-- ============================================================ 3. Pièces : dépôt, soumission, décision
-- Prévient l'équipe concernée (administration, support, responsable du département de l'étudiant) : une notification par étudiant et par 12 h.
create or replace function _notify_verification_team(p_user uuid, p_doc uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  select coalesce(name, 'Un compte') into v_name from profiles where id = p_user;
  insert into notifications (user_id, kind, title, body, data)
    select r, 'verification', 'Pièce justificative à examiner', coalesce(v_name, 'Un compte') || ' a déposé une pièce justificative en attente de validation.',
           jsonb_build_object('user', p_user, 'document', p_doc)
    from _scope_recipients(p_user, true) r
    where not exists (select 1 from notifications n where n.user_id = r and n.kind = 'verification' and n.data ->> 'user' = p_user::text
                        and n.created_at > now() - interval '12 hours');
end $$;
revoke all on function _notify_verification_team(uuid, uuid) from public, anon, authenticated;

create or replace function document_register(p_kind text, p_path text, p_name text, p_mime text, p_size int) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_meta jsonb; v_mime text := p_mime; v_size int := p_size;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if (storage.foldername(p_path))[1] is distinct from auth.uid()::text then raise exception 'Chemin de fichier non autorisé'; end if;
  select metadata into v_meta from storage.objects where bucket_id = 'profile-documents' and name = p_path;
  if not found then raise exception 'Fichier absent du stockage'; end if;
  if p_kind is null or p_kind not in ('student_card', 'enrollment_certificate', 'diploma', 'certificate', 'cv', 'other') then raise exception 'Type de pièce inconnu'; end if;
  if v_meta is not null then
    v_mime := coalesce(nullif(v_meta ->> 'mimetype', ''), v_mime);
    begin
      v_size := coalesce((v_meta ->> 'size')::int, v_size);
    exception when others then
      v_size := p_size;
    end;
  end if;
  if v_mime is null or v_mime not in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf') then raise exception 'Format non accepté (PDF, JPG, PNG ou WebP)'; end if;
  if v_size is null or v_size < 1 or v_size > 10485760 then raise exception 'Fichier trop lourd (10 Mo au maximum)'; end if;
  if exists (select 1 from user_documents where path = p_path) then raise exception 'Ce fichier est déjà enregistré'; end if;
  if (select count(*) from user_documents where owner_id = auth.uid()) >= 30 then raise exception 'Trop de documents : supprimez-en avant d''en ajouter'; end if;
  insert into user_documents (owner_id, kind, name, path, mime, size_bytes) values (auth.uid(), p_kind, left(coalesce(nullif(btrim(p_name), ''), 'document'), 160), p_path, v_mime, v_size) returning id into v_id;
  insert into user_document_history (document_id, status, actor_id) values (v_id, 'pending', auth.uid());
  perform _notify_verification_team(auth.uid(), v_id);
  return v_id;
end $$;
revoke all on function document_register(text, text, text, text, int) from public, anon;
grant execute on function document_register(text, text, text, text, int) to authenticated;

-- « Envoyer pour validation » (écran 18c) : l'équipe concernée est prévenue qu'un dossier est prêt. Retourne le nombre de pièces en attente.
create or replace function verification_submit() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select count(*) into n from user_documents where owner_id = auth.uid() and status = 'pending';
  if n = 0 then raise exception 'Déposez d''abord une pièce justificative (carte d''étudiant ou certificat de scolarité)'; end if;
  perform _notify_verification_team(auth.uid(), null);
  return n;
end $$;
revoke all on function verification_submit() from public, anon;
grant execute on function verification_submit() to authenticated;

-- Décision sur une pièce : administration et support (toutes), responsable de département (étudiants de son département).
-- Refus : motif obligatoire. L'étudiant est notifié ; une pièce « carte d'étudiant / certificat de scolarité » validée le rend « étudiant vérifié ».
-- Nouvelle fonction (et non une redéfinition de document_review, que d'autres lots modifient aussi) : c'est elle que l'écran d'équipe appelle.
create or replace function document_decide(p_id uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare d user_documents%rowtype; v_note text := nullif(btrim(coalesce(p_note, '')), ''); who text; v_label text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into d from user_documents where id = p_id;
  if d.id is null then raise exception 'Document introuvable'; end if;
  if not _review_scope_ok(d.owner_id, true) then raise exception 'Action non autorisée'; end if;
  if d.owner_id = auth.uid() then raise exception 'Vous ne pouvez pas valider vos propres pièces'; end if;
  if p_status not in ('verified', 'rejected') then raise exception 'Statut invalide'; end if;
  if p_status = 'rejected' and char_length(coalesce(v_note, '')) < 5 then raise exception 'Indiquez le motif du refus (5 caractères au moins)'; end if;
  if d.status = p_status then raise exception 'Cette pièce a déjà reçu cette décision'; end if;
  update user_documents set status = p_status, review_note = left(v_note, 500), reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  insert into user_document_history (document_id, status, note, actor_id) values (p_id, p_status, left(v_note, 500), auth.uid());
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
    values (coalesce(who, 'Valideur'), 'Pièce ' || case p_status when 'verified' then 'validée' else 'refusée' end || ' (' || d.kind || ')', d.owner_id::text, 'Vérification', 'Sensible');
  if p_status = 'verified' and to_regprocedure('_mentor_auto_verify(uuid)') is not null then execute 'select _mentor_auto_verify($1)' using d.owner_id; end if;
  v_label := case d.kind when 'student_card' then 'carte d''étudiant' when 'enrollment_certificate' then 'certificat de scolarité' when 'diploma' then 'diplôme'
                         when 'certificate' then 'certificat' when 'cv' then 'CV' else 'document' end;
  insert into notifications (user_id, kind, title, body, data)
    values (d.owner_id, 'verification',
            case p_status when 'verified' then 'Pièce validée' else 'Pièce refusée' end,
            case p_status when 'verified' then 'Votre ' || v_label || ' (' || d.name || ') a été validée.' || case when is_verified_student(d.owner_id) then ' Votre compte est désormais « étudiant vérifié ».' else '' end
                          else 'Votre ' || v_label || ' (' || d.name || ') a été refusée. Motif : ' || v_note || '. Déposez une nouvelle pièce depuis « Mes documents ».' end,
            jsonb_build_object('document', p_id, 'status', p_status));
end $$;
revoke all on function document_decide(uuid, text, text) from public, anon;
grant execute on function document_decide(uuid, text, text) to authenticated;

-- Pièces à examiner (statut p_status : 'pending' par défaut ; null = toutes), dans le périmètre du responsable.
create or replace function documents_to_review(p_status text default 'pending', p_limit int default 100) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text := coalesce(current_role_name()::text, '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if r not in ('admin', 'support', 'dept') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', d.id, 'owner_id', d.owner_id, 'owner_name', p.name, 'matricule', coalesce(p.matricule, ''), 'institution', coalesce(p.institution, ''),
                                        'department', coalesce(p.department, ''), 'kind', d.kind, 'name', d.name, 'path', d.path, 'mime', d.mime, 'size', d.size_bytes,
                                        'status', d.status, 'review_note', d.review_note, 'created_at', d.created_at, 'verified_student', is_verified_student(d.owner_id))
                     order by d.created_at)
    from (select * from user_documents x where (p_status is null or x.status = p_status) and _review_scope_ok(x.owner_id, true)
          order by x.created_at limit least(greatest(p_limit, 1), 200)) d
    join profiles p on p.id = d.owner_id), '[]'::jsonb);
end $$;
revoke all on function documents_to_review(text, int) from public, anon;
grant execute on function documents_to_review(text, int) to authenticated;

-- État de vérification de la personne connectée (écrans 18, 18c, 154).
create or replace function my_student_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from profiles where id = auth.uid();
  if p.id is null then return null; end if;
  return jsonb_build_object(
    'role', p.role::text, 'certification', p.certification::text, 'verified', is_verified_student(p.id),
    'can_request_certification', p.role::text in ('student', 'company', 'other') and p.certification::text in ('none', 'rejected'),
    'has_identity_document', exists (select 1 from user_documents d where d.owner_id = p.id and d.kind in ('student_card', 'enrollment_certificate') and d.status <> 'rejected'),
    'documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'status', d.status, 'review_note', d.review_note) order by d.created_at desc)
                           from user_documents d where d.owner_id = p.id), '[]'::jsonb));
end $$;
revoke all on function my_student_status() from public, anon;
grant execute on function my_student_status() to authenticated;

-- ============================================================ 4. Référentiel : propositions relues par l'équipe (S1-19)
create or replace function institution_propose(p_name text, p_city text default '', p_kind text default 'autre') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_name) < 3 or char_length(v_name) > 160 then raise exception 'Nom d''établissement invalide'; end if;
  if p_kind not in ('universite_etat', 'institut', 'ecole', 'prive', 'autre') then p_kind := 'autre'; end if;
  select id into v_id from institutions where lower(name) = lower(v_name);
  if v_id is not null then return v_id; end if;
  if (select count(*) from institutions where proposed_by = auth.uid() and status = 'proposed') >= 5 then raise exception 'Trop de propositions en attente'; end if;
  insert into institutions (name, kind, city, status, proposed_by, source) values (v_name, p_kind, nullif(left(trim(coalesce(p_city, '')), 80), ''), 'proposed', auth.uid(), 'Proposition d''un utilisateur') returning id into v_id;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'reference', 'Établissement proposé', 'Nouvel établissement à relire : ' || v_name || '.', jsonb_build_object('kind', 'institution', 'id', v_id)
    from profiles a where a.role::text in ('admin', 'support');
  return v_id;
end $$;

create or replace function department_propose(p_institution uuid, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text := regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if char_length(v_name) < 2 or char_length(v_name) > 120 then raise exception 'Nom de département invalide'; end if;
  if not exists (select 1 from institutions where id = p_institution and (status = 'verified' or proposed_by = auth.uid())) then raise exception 'Établissement introuvable'; end if;
  select id into v_id from departments where institution_id = p_institution and lower(name) = lower(v_name);
  if v_id is not null then return v_id; end if;
  if (select count(*) from departments where proposed_by = auth.uid() and status = 'proposed') >= 10 then raise exception 'Trop de propositions en attente'; end if;
  insert into departments (institution_id, name, status, proposed_by) values (p_institution, v_name, 'proposed', auth.uid()) returning id into v_id;
  insert into notifications (user_id, kind, title, body, data)
    select a.id, 'reference', 'Département proposé', 'Nouveau département à relire : ' || v_name || '.', jsonb_build_object('kind', 'department', 'id', v_id)
    from profiles a where a.role::text in ('admin', 'support');
  return v_id;
end $$;

-- Relecture : l'auteur de la proposition est prévenu ; une proposition déjà traitée ou inconnue est signalée.
create or replace function reference_review(p_kind text, p_id uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_status text := case when p_approve then 'verified' else 'rejected' end; v_by uuid; v_name text; v_label text;
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  if p_kind = 'institution' then
    update institutions set status = v_status, reviewed_by = auth.uid(), reviewed_at = now() where id = p_id and status = 'proposed' returning proposed_by, name into v_by, v_name;
    v_label := 'Établissement';
  elsif p_kind = 'department' then
    update departments set status = v_status, reviewed_by = auth.uid(), reviewed_at = now() where id = p_id and status = 'proposed' returning proposed_by, name into v_by, v_name;
    v_label := 'Département';
  else
    raise exception 'Type inconnu';
  end if;
  if v_name is null then raise exception 'Proposition introuvable ou déjà traitée'; end if;
  if v_by is not null then
    insert into notifications (user_id, kind, title, body, data)
      values (v_by, 'reference', v_label || case when p_approve then ' publié' else ' refusé' end,
              '« ' || v_name || ' » ' || case when p_approve then 'est désormais dans le référentiel : vous pouvez le choisir dans votre profil.' else 'n''a pas été retenu. Choisissez un élément existant ou refaites une proposition.' end,
              jsonb_build_object('kind', p_kind, 'id', p_id, 'approved', p_approve));
  end if;
end $$;

create or replace function references_to_review() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_staff() then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(x.j order by x.created_at) from (
      select i.created_at, jsonb_build_object('kind', 'institution', 'id', i.id, 'name', i.name, 'parent', '', 'city', coalesce(i.city, ''), 'proposed_by', coalesce(p.name, ''), 'created_at', i.created_at) j
      from institutions i left join profiles p on p.id = i.proposed_by where i.status = 'proposed'
      union all
      select d.created_at, jsonb_build_object('kind', 'department', 'id', d.id, 'name', d.name, 'parent', coalesce(i.name, ''), 'city', coalesce(i.city, ''), 'proposed_by', coalesce(p.name, ''), 'created_at', d.created_at)
      from departments d join institutions i on i.id = d.institution_id left join profiles p on p.id = d.proposed_by where d.status = 'proposed'
    ) x), '[]'::jsonb);
end $$;
revoke all on function institution_propose(text, text, text), department_propose(uuid, text), reference_review(text, uuid, boolean), references_to_review() from public, anon;
grant execute on function institution_propose(text, text, text), department_propose(uuid, text), reference_review(text, uuid, boolean), references_to_review() to authenticated;

-- Informations académiques : un matricule ne peut être déclaré que par un seul compte pour un même établissement (S1-80).
create or replace function profile_set_academic(p_institution uuid, p_department uuid, p_matricule text default null, p_level text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_inst institutions; v_dept departments; v_mat text := nullif(regexp_replace(trim(coalesce(p_matricule, '')), '\s+', '', 'g'), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_institution is not null then
    select * into v_inst from institutions where id = p_institution and (status = 'verified' or proposed_by = auth.uid());
    if v_inst.id is null then raise exception 'Établissement introuvable'; end if;
  end if;
  if p_department is not null then
    select * into v_dept from departments where id = p_department and (status = 'verified' or proposed_by = auth.uid());
    if v_dept.id is null or v_dept.institution_id is distinct from p_institution then raise exception 'Département introuvable pour cet établissement'; end if;
  end if;
  if v_mat is not null and (char_length(v_mat) < 3 or char_length(v_mat) > 40 or v_mat !~ '^[A-Za-z0-9/_.-]+$') then raise exception 'Matricule invalide'; end if;
  if v_mat is not null and exists (select 1 from profiles o where o.id <> auth.uid() and lower(o.matricule) = lower(v_mat)
                                   and o.institution_id is not distinct from p_institution) then
    raise exception 'Ce matricule est déjà enregistré par un autre compte : vérifiez votre saisie ou contactez le support';
  end if;
  update profiles set
    institution_id = p_institution, institution = coalesce(v_inst.name, ''),
    department_id = p_department, department = coalesce(v_dept.name, ''),
    matricule = v_mat, study_level = nullif(left(trim(coalesce(p_level, '')), 40), '')
  where id = auth.uid();
end $$;
revoke all on function profile_set_academic(uuid, uuid, text, text) from public, anon;
grant execute on function profile_set_academic(uuid, uuid, text, text) to authenticated;

-- ============================================================ 5. Certification : qui peut demander, qui peut décider (S1-82, 83, 84)
create or replace function submit_certification_request(p_motive text, p_links text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c certification_status; docs jsonb; nm text; r text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select certification, name, role::text into c, nm, r from profiles where id = auth.uid();
  if not found then raise exception 'Profil introuvable'; end if;
  if r not in ('student', 'company', 'other') then
    raise exception 'La certification est réservée aux étudiants-vendeurs et aux comptes professionnels : un compte Client peut acheter sans certification';
  end if;
  if c not in ('none', 'rejected') then raise exception 'Une demande est déjà en cours ou le compte est déjà certifié'; end if;
  if char_length(trim(coalesce(p_motive, ''))) < 20 then raise exception 'Expliquez votre demande en 20 caractères au moins'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'name', name, 'status', status) order by created_at desc), '[]')
    into docs from user_documents where owner_id = auth.uid() and status <> 'rejected';
  if r = 'student' and not exists (select 1 from user_documents where owner_id = auth.uid() and status <> 'rejected' and kind in ('student_card', 'enrollment_certificate')) then
    raise exception 'Ajoutez d''abord un justificatif d''étudiant (carte d''étudiant ou certificat de scolarité, non refusé) dans votre dossier';
  end if;
  if jsonb_array_length(docs) = 0 then
    raise exception 'Ajoutez d''abord au moins un justificatif (diplôme, certificat, CV…) non refusé dans votre dossier';
  end if;
  insert into certification_requests (user_id, motive, links, documents) values (auth.uid(), trim(p_motive), trim(coalesce(p_links, '')), docs);
  perform set_config('app.cert_rpc', '1', true);
  update profiles set certification = 'pending', certification_decided_by = null, certification_decided_at = null where id = auth.uid();
  perform set_config('app.cert_rpc', '', true);
  insert into notifications (user_id, kind, title, body, data)
    select s, 'certification', 'Nouvelle demande de certification', coalesce(nm, 'Un compte') || ' demande la certification.', jsonb_build_object('user', auth.uid())
    from (select distinct s from _scope_recipients(auth.uid(), false) s) x(s);
  return 'pending';
end $$;
revoke all on function submit_certification_request(text, text) from public, anon;
grant execute on function submit_certification_request(text, text) to authenticated;

create or replace function decide_certification(p_user uuid, p_status text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare c certification_status; who text; target text; ttl text; msg text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas décider de votre propre certification'; end if;
  if not _review_scope_ok(p_user, false) then raise exception 'Ce compte n''appartient pas à votre département : seul son département ou l''administration peut décider'; end if;
  if p_status not in ('review', 'approved', 'rejected', 'revoked') then raise exception 'Statut invalide'; end if;
  if p_status in ('rejected', 'revoked') and char_length(trim(coalesce(p_note, ''))) < 5 then raise exception 'Indiquez le motif de la décision'; end if;
  select certification, name into c, target from profiles where id = p_user;
  if c is null then raise exception 'Profil introuvable'; end if;
  if not ((p_status = 'review' and c = 'pending')
       or (p_status in ('approved', 'rejected') and c in ('pending', 'review'))
       or (p_status = 'revoked' and c = 'approved')) then
    raise exception 'Transition impossible de % vers %', c, p_status;
  end if;
  perform set_config('app.cert_rpc', '1', true);
  update profiles set certification = p_status::certification_status, certification_decided_by = auth.uid(), certification_decided_at = now() where id = p_user;
  perform set_config('app.cert_rpc', '', true);
  update certification_requests set status = p_status, decision_note = nullif(trim(coalesce(p_note, '')), ''), decided_by = auth.uid(), decided_at = now()
    where id = (select id from certification_requests where user_id = p_user order by created_at desc limit 1);
  select name into who from profiles where id = auth.uid();
  insert into audit_log (actor, action, target, category, level)
  values (coalesce(who, 'Valideur'), 'Certification : ' || p_status, coalesce(target, p_user::text), 'Certification', 'Sensible');
  ttl := case p_status when 'approved' then 'Votre compte est certifié' when 'rejected' then 'Certification refusée'
                       when 'revoked' then 'Badge de certification retiré' else 'Demande de certification en cours d''examen' end;
  msg := case p_status when 'approved' then 'Le badge bleu apparaît sur votre profil et vous pouvez publier.'
                       when 'review' then 'Votre dossier est examiné par l''équipe.'
                       else 'Motif : ' || trim(p_note) || '. Vous pouvez compléter votre dossier et refaire une demande.' end;
  insert into notifications (user_id, kind, title, body, data) values (p_user, 'certification', ttl, msg, jsonb_build_object('status', p_status));
  return p_status;
end $$;
revoke all on function decide_certification(uuid, text, text) from public, anon;
grant execute on function decide_certification(uuid, text, text) to authenticated;

-- File des demandes de certification (administration : toutes ; département : celles de son périmètre) avec motif, liens et pièces du dossier.
create or replace function certification_queue() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', p.id, 'name', p.name, 'role', p.role::text, 'department', coalesce(p.department, ''), 'institution', coalesce(p.institution, ''),
      'certification', p.certification::text,
      'motive', q.motive, 'links', q.links, 'requested_at', q.created_at,
      'documents', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'kind', d.kind, 'name', d.name, 'status', d.status) order by d.created_at desc)
                             from user_documents d where d.owner_id = p.id), '[]'::jsonb)
    ) order by q.created_at nulls last)
    from profiles p
    left join lateral (select * from certification_requests r where r.user_id = p.id order by r.created_at desc limit 1) q on true
    where p.certification::text in ('pending', 'review', 'approved') and p.id <> auth.uid() and _review_scope_ok(p.id, false)
  ), '[]'::jsonb);
end $$;
revoke all on function certification_queue() from public, anon;
grant execute on function certification_queue() to authenticated;

-- ============================================================ 6. Surfaces réservées aux étudiants vérifiés (S1-4, S1-87)
-- Annuaire des talents (dernière définition : 20261112000000_couverture_profil).
create or replace function talents_list(p_query text default '', p_limit int default 20) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'department', coalesce(t.department, ''), 'institution', coalesce(t.institution, ''),
                                        'skills', coalesce(t.skills, ''), 'city', coalesce(t.city, ''), 'avatar_url', t.avatar_url, 'certified', t.certification::text = 'approved',
                                        'cover_path', t.cover_path, 'cover_kind', t.cover_kind))
    from (
      select * from profiles
      where role::text = 'student' and not suspended and nullif(trim(coalesce(skills, '')), '') is not null and is_verified_student(id)
        and (coalesce(trim(p_query), '') = '' or name ilike '%' || trim(p_query) || '%' or skills ilike '%' || trim(p_query) || '%' or coalesce(department, '') ilike '%' || trim(p_query) || '%')
      order by (certification::text = 'approved') desc, created_at desc
      limit least(greatest(p_limit, 1), 50)
    ) t
  ), '[]'::jsonb);
end $$;
revoke all on function talents_list(text, int) from public, anon;
grant execute on function talents_list(text, int) to authenticated;

-- Invitations d'entreprises (dernière définition : 20261114003800_invitations_offres).
create or replace function opp_invite(p_opp uuid, p_student uuid, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_msg text := left(btrim(coalesce(p_message, '')), 300);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  if o.status <> 'published' then raise exception 'Publiez l''offre avant d''inviter des étudiants'; end if;
  if not is_verified_student(p_student) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_opp and applicant_id = p_student) then raise exception 'Cet étudiant a déjà postulé'; end if;
  if exists (select 1 from opportunity_invites where opportunity_id = p_opp and student_id = p_student) then raise exception 'Cet étudiant est déjà invité'; end if;
  if (select count(*) from opportunity_invites where opportunity_id = p_opp) >= 30 then raise exception '30 invitations au plus par offre'; end if;
  if (select count(*) from opportunity_invites where invited_by = auth.uid() and created_at > now() - interval '1 day') >= 100 then raise exception '100 invitations au plus par jour'; end if;
  insert into opportunity_invites (opportunity_id, student_id, invited_by, message) values (p_opp, p_student, auth.uid(), v_msg);
  perform notify_user(p_student, 'opportunity_invite', o.org_name || ' vous invite à postuler', o.title || case when v_msg <> '' then ' : ' || v_msg else '' end || ' · Ouvrez l''offre dans Opportunités.',
                      jsonb_build_object('opportunity', p_opp));
  return 'invited';
end $$;

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
                  and (btrim(coalesce(pr.skills, '')) <> '' or btrim(coalesce(pr.bio, '')) <> '')
                  and not exists (select 1 from opportunity_applications a where a.opportunity_id = p_id and a.applicant_id = pr.id)
                limit 500) x
          where (x.j->'match'->>'score')::int >= 30
          order by (x.j->'match'->>'score')::int desc, x.j->>'name'
          limit greatest(1, least(coalesce(p_limit, 10), 30))) t), '[]'::jsonb);
end $$;
revoke all on function opp_invite(uuid, uuid, text), opp_suggested_students(uuid, integer) from public, anon;
grant execute on function opp_invite(uuid, uuid, text), opp_suggested_students(uuid, integer) to authenticated;

-- Vivier de talents (dernière définition : 20261114003900_vivier_talents).
create or replace function talent_list_add(p_list uuid, p_student uuid, p_note text default '') returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _talent_guard();
  if not exists (select 1 from talent_lists where id = p_list and owner_id = auth.uid()) then raise exception 'Liste introuvable'; end if;
  if not is_verified_student(p_student) then raise exception 'Étudiant introuvable'; end if;
  if (select count(*) from talent_list_members where list_id = p_list) >= 500 then raise exception '500 étudiants au plus par liste'; end if;
  insert into talent_list_members (list_id, student_id, note) values (p_list, p_student, left(btrim(coalesce(p_note, '')), 200))
  on conflict (list_id, student_id) do update set note = excluded.note;
end $$;
revoke all on function talent_list_add(uuid, uuid, text) from public, anon;
grant execute on function talent_list_add(uuid, uuid, text) to authenticated;

-- Demande de contact à un talent (dernière définition : 20261115200300_l10_cv_vivant).
create or replace function talent_contact_request(p_user uuid, p_kind text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare v_msg text := left(btrim(coalesce(p_message, '')), 500);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('company', 'client', 'other', 'dept', 'admin') then raise exception 'Cette demande est réservée aux entreprises, aux clients et au département'; end if;
  if p_kind not in ('internship_offer', 'contact') then raise exception 'Type de demande inconnu'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous adresser cette demande'; end if;
  if not is_verified_student(p_user) then raise exception 'Talent introuvable'; end if;
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

-- Chiffres : la fiche publique d'un département ne compte et ne met en avant que les étudiants vérifiés ; la console de l'administration
-- affiche les étudiants vérifiés (« students ») et rappelle le total déclaré (« students_declared »).
create or replace function department_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare d departments; i institutions;
begin
  select * into d from departments where id = p_id and status = 'verified';
  if d.id is null then return null; end if;
  select * into i from institutions where id = d.institution_id;
  return jsonb_build_object(
    'id', d.id, 'name', d.name, 'institution', coalesce(i.name, ''), 'institution_short', coalesce(i.short_name, ''), 'city', coalesce(i.city, ''),
    'students', (select count(*)::int from profiles p where p.department_id = d.id and is_verified_student(p.id)),
    'listings', (select count(*)::int from listings l join profiles p on p.id = l.seller_id where p.department_id = d.id and l.status = 'approved'),
    'projects', (select count(*)::int from projects pr join profiles p on p.id = pr.owner_id where p.department_id = d.id and pr.status = 'approved' and pr.visibility = 'public'),
    'featured', case when auth.uid() is null then '[]'::jsonb else coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'skills', coalesce(s.skills, ''), 'avatar_url', s.avatar_url, 'certified', s.certification::text = 'approved'))
      from (select * from profiles p where p.department_id = d.id and is_verified_student(p.id)
                and nullif(trim(coalesce(p.skills, '')), '') is not null
            order by (p.certification::text = 'approved') desc, p.created_at desc limit 4) s), '[]'::jsonb) end
  );
end $$;
revoke all on function department_detail(uuid) from public;
grant execute on function department_detail(uuid) to anon, authenticated;

create or replace function platform_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin', 'direction', 'support', 'finance') then raise exception 'Action non autorisée'; end if;
  return jsonb_build_object(
    'students', (select count(*)::int from profiles where is_verified_student(id)),
    'students_declared', (select count(*)::int from profiles where role::text = 'student'),
    'sellers', (select count(distinct seller_id)::int from listings where seller_id is not null and status = 'approved'),
    'listings_approved', (select count(*)::int from listings where status = 'approved'),
    'listings_pending', (select count(*)::int from listings where status = 'pending'),
    'orders', (select count(*)::int from orders),
    'orders_paid', (select count(*)::int from orders where paid and cancelled_at is null),
    'paid_revenue', (select coalesce(sum(subtotal + fee), 0)::bigint from orders where paid and cancelled_at is null)
  );
end $$;
revoke all on function platform_overview() from public, anon;
grant execute on function platform_overview() to authenticated;

create or replace function admin_departments() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'direction', 'admin', 'support') then raise exception 'Action non autorisée'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'name', d.name, 'institution', i.name, 'status', d.status,
      'students', (select count(*)::int from profiles p where p.department_id = d.id and is_verified_student(p.id)),
      'students_declared', (select count(*)::int from profiles p where p.department_id = d.id and p.role::text = 'student'),
      'head', (select string_agg(p.name, ', ' order by p.name) from profiles p where p.department_id = d.id and p.role::text = 'dept')
    ) order by i.name, d.name)
    from departments d join institutions i on i.id = d.institution_id
  ), '[]'::jsonb);
end $$;
revoke all on function admin_departments() from public, anon;
grant execute on function admin_departments() to authenticated;

-- Retour arrière :
--   réappliquer les définitions précédentes : document_register (20261115110000), reference_review/institution_propose/department_propose/
--   profile_set_academic (20261104000100), drop function document_decide(uuid, text, text), submit_certification_request/decide_certification (20261110000200), talents_list (20261112000000),
--   opp_invite/opp_suggested_students (20261114003800), talent_list_add (20261114003900), talent_contact_request (20261115200300),
--   department_detail (20261115160000), platform_overview (20261104000000), admin_departments (20261105000200) ;
--   recréer la politique storage « documents profil : suppression par le propriétaire » de 20261104000100 et supprimer « documents profil : lecture par le département » ;
--   drop function if exists is_verified_student(uuid), _review_scope_ok(uuid, boolean), _scope_recipients(uuid, boolean), _profile_doc_registered(text), _profile_doc_reviewable(text),
--     _notify_verification_team(uuid, uuid), verification_submit(), documents_to_review(text, int), my_student_status(), references_to_review(), certification_queue();
