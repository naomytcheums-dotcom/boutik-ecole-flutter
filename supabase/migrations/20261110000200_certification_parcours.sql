-- Certification du compte : parcours complet (demande motivée + justificatifs du dossier, décision motivée, notification, badge)
-- et blocage de la publication tant que le compte n'est pas certifié. Additive : aucune donnée supprimée.

create table if not exists certification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  motive text not null check (char_length(motive) between 20 and 1000),
  links text not null default '' check (char_length(links) <= 600),
  documents jsonb not null default '[]',           -- justificatifs du dossier au moment de la demande (type, nom, statut)
  status text not null default 'pending' check (status in ('pending', 'review', 'approved', 'rejected', 'revoked')),
  decision_note text,
  decided_by uuid references profiles(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists certification_requests_user on certification_requests (user_id, created_at desc);
alter table certification_requests enable row level security;
revoke all on certification_requests from anon, authenticated;
grant select on certification_requests to authenticated;
drop policy if exists "certification : titulaire ou équipe" on certification_requests;
create policy "certification : titulaire ou équipe" on certification_requests for select
  using (user_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support'));

-- Demande : motif + au moins un justificatif déposé dans le dossier ; l'ancienne demande sans justificatif n'est plus utilisable
create or replace function submit_certification_request(p_motive text, p_links text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c certification_status; docs jsonb; nm text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select certification, name into c, nm from profiles where id = auth.uid();
  if not found then raise exception 'Profil introuvable'; end if;
  if c not in ('none', 'rejected') then raise exception 'Une demande est déjà en cours ou le compte est déjà certifié'; end if;
  if char_length(trim(coalesce(p_motive, ''))) < 20 then raise exception 'Expliquez votre demande en 20 caractères au moins'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'name', name, 'status', status) order by created_at desc), '[]')
    into docs from user_documents where owner_id = auth.uid();
  if jsonb_array_length(docs) = 0 then
    raise exception 'Ajoutez d''abord au moins un justificatif (carte d''étudiant, certificat de scolarité, diplôme…) dans votre dossier';
  end if;
  insert into certification_requests (user_id, motive, links, documents) values (auth.uid(), trim(p_motive), trim(coalesce(p_links, '')), docs);
  perform set_config('app.cert_rpc', '1', true);
  update profiles set certification = 'pending', certification_decided_by = null, certification_decided_at = null where id = auth.uid();
  perform set_config('app.cert_rpc', '', true);
  insert into notifications (user_id, kind, title, body, data)
    select p.id, 'certification', 'Nouvelle demande de certification', coalesce(nm, 'Un compte') || ' demande la certification.', jsonb_build_object('user', auth.uid())
    from profiles p where p.role::text in ('dept', 'admin');
  return 'pending';
end $$;
revoke all on function submit_certification_request(text, text) from public, anon;
grant execute on function submit_certification_request(text, text) to authenticated;
-- l'ancienne demande directe contournait motif et justificatifs : elle n'est plus appelable par les clients
revoke execute on function request_certification() from authenticated;

-- Décision (département ou administrateur) : refus motivé, notification du titulaire, trace d'audit
drop function if exists decide_certification(uuid, text);
create or replace function decide_certification(p_user uuid, p_status text, p_note text default null) returns text
language plpgsql security definer set search_path = public as $$
declare c certification_status; who text; target text; ttl text; msg text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('dept', 'admin') then raise exception 'Réservé au département ou à l''administrateur'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas décider de votre propre certification'; end if;
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

-- Peut publier : compte certifié, ou équipe de la plateforme. Utilisée par l'application ET par le déclencheur ci-dessous.
create or replace function can_publish() returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from profiles p where p.id = auth.uid() and (p.certification::text = 'approved' or p.role::text in ('dept', 'direction', 'finance', 'support', 'admin')))
  )
$$;
revoke all on function can_publish() from public, anon;
grant execute on function can_publish() to authenticated;

-- Annonces : l'envoi en validation (statut « pending ») exige un compte certifié ; le brouillon reste libre.
-- Ne s'applique qu'aux actions d'un utilisateur connecté sur sa propre annonce (pas aux scripts ni aux produits de la plateforme).
create or replace function require_certified_listing() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and new.seller_id = auth.uid() and new.status::text = 'pending'
     and (tg_op = 'INSERT' or old.status::text is distinct from 'pending') and not can_publish() then
    raise exception 'Publication réservée aux comptes certifiés : demandez la certification de votre compte (Profil → Certification)';
  end if;
  return new;
end $$;
drop trigger if exists trg_require_certified_listing on listings;
create trigger trg_require_certified_listing before insert or update of status on listings for each row execute function require_certified_listing();
