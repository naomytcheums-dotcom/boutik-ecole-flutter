-- Lot S2 (1/5) : sécurité du profil étudiant.
--  1. S2-55 : send_cv_to_recruiter ne révèle plus si une adresse correspond à un compte entreprise (réponse identique) et limite les
--     TENTATIVES (réussies ou non) par utilisateur ; une table dédiée compte les tentatives.
--  2. S2-5  : profile_cover_set / profile_cover_clear / set_my_cover renvoient le chemin de l'ancien média devenu orphelin (aucune autre
--     couverture ni publication ne l'utilise) ; l'application le supprime du bucket public post-media (politique de suppression dans son dossier).
--  3. S2-66 : verify_certificate retire les espaces du code saisi (les codes actuels ont 24 caractères, les anciens 16).
-- Retour arrière : voir le bas du fichier.

-- ============================================================ 1. S2-55 : envoi du CV à une entreprise
create table if not exists cv_send_attempts (
  sender_id uuid not null references profiles(id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists cv_send_attempts_sender on cv_send_attempts (sender_id, at desc);
alter table cv_send_attempts enable row level security;
revoke all on cv_send_attempts from public, anon, authenticated;

create or replace function send_cv_to_recruiter(p_email text, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare c cv_links%rowtype; r profiles%rowtype; v_mail text := lower(btrim(coalesce(p_email, ''))); v_msg text := left(btrim(coalesce(p_message, '')), 500);
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
  select * into r from profiles where lower(email) = v_mail and role::text = 'company' and not coalesce(suspended, false);
  if found and not exists (select 1 from cv_sends where sender_id = auth.uid() and recipient_id = r.id and created_at > now() - interval '1 day') then
    insert into cv_sends (sender_id, recipient_id, token, message) values (auth.uid(), r.id, c.token, v_msg);
    perform notify_user(r.id, 'cv_shared', 'CV reçu', left(display_name(auth.uid()) || ' vous envoie son CV' || case when v_msg <> '' then ' : ' || v_msg else '.' end, 500),
      jsonb_build_object('cv_token', c.token, 'from', auth.uid()));
  end if;
  return 'sent';
end $$;
revoke all on function send_cv_to_recruiter(text, text) from public, anon;
grant execute on function send_cv_to_recruiter(text, text) to authenticated;

-- ============================================================ 2. S2-5 : médias de couverture remplacés ou supprimés
-- Chemin encore utilisé par une couverture, une couverture de carte ou une publication ?
create or replace function _post_media_in_use(p_path text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profile_covers where path = p_path)
      or exists (select 1 from profiles where cover_path = p_path)
      or exists (select 1 from posts where media_path = p_path)
$$;
revoke all on function _post_media_in_use(text) from public, anon, authenticated;

drop function if exists profile_cover_set(integer, text, text);
create or replace function profile_cover_set(p_slot integer, p_path text, p_kind text) returns text
language plpgsql security definer set search_path = public as $$
declare v_old text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_slot not between 0 and 2 then raise exception 'Emplacement inconnu'; end if;
  if p_kind not in ('image', 'video') then raise exception 'Format inconnu'; end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  select path into v_old from profile_covers where user_id = auth.uid() and slot = p_slot;
  insert into profile_covers (user_id, slot, path, kind) values (auth.uid(), p_slot, p_path, p_kind)
  on conflict (user_id, slot) do update set path = excluded.path, kind = excluded.kind, updated_at = now();
  -- Chemin de l'ancien fichier à supprimer du stockage public (vide : rien à supprimer).
  return case when v_old is not null and v_old <> p_path and not _post_media_in_use(v_old) then v_old else '' end;
end $$;

drop function if exists profile_cover_clear(integer);
create or replace function profile_cover_clear(p_slot integer) returns text
language plpgsql security definer set search_path = public as $$
declare v_old text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  delete from profile_covers where user_id = auth.uid() and slot = p_slot returning path into v_old;
  return case when v_old is not null and not _post_media_in_use(v_old) then v_old else '' end;
end $$;

create or replace function set_my_cover(p_path text, p_kind text) returns text
language plpgsql security definer set search_path = public as $$
declare v_old text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_kind not in ('image', 'video') then raise exception 'Type de couverture invalide'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  select cover_path into v_old from profiles where id = auth.uid();
  update profiles set cover_path = p_path, cover_kind = p_kind where id = auth.uid();
  return case when v_old is not null and v_old <> p_path and not _post_media_in_use(v_old) then v_old else '' end;
end $$;

revoke all on function profile_cover_set(integer, text, text), profile_cover_clear(integer), set_my_cover(text, text) from public, anon;
grant execute on function profile_cover_set(integer, text, text), profile_cover_clear(integer), set_my_cover(text, text) to authenticated;

-- ============================================================ 3. S2-66 : vérification d'un certificat
create or replace function verify_certificate(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_code text := upper(left(regexp_replace(coalesce(p_code, ''), '\s+', '', 'g'), 40)); v_headers jsonb; v_caller text; v_res jsonb;
begin
  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := null;
  end;
  v_caller := coalesce(auth.uid()::text, nullif(trim(split_part(coalesce(v_headers ->> 'x-forwarded-for', v_headers ->> 'cf-connecting-ip', ''), ',', 1)), ''), 'inconnu');
  if (select count(*) from certificate_checks where caller = v_caller and at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('code', v_code, 'valide', false, 'limite', true);
  end if;
  select jsonb_build_object('code', code, 'objet', subject_title, 'type', subject_kind, 'titulaire', holder_name, 'departement', department,
           'delivre_le', to_char(issued_at, 'DD/MM/YYYY'), 'valide', not revoked, 'motif_revocation', revoked_reason, 'empreinte', fingerprint)
    into v_res from certificates where code = v_code;
  if v_res is null then
    insert into certificate_checks (caller) values (v_caller);
    delete from certificate_checks where at < now() - interval '1 day';
    return jsonb_build_object('code', v_code, 'valide', false, 'introuvable', true);
  end if;
  return v_res;
end $$;
revoke all on function verify_certificate(text) from public;
grant execute on function verify_certificate(text) to anon, authenticated;

-- Retour arrière : rejouer send_cv_to_recruiter depuis 20261115200300_l10_cv_vivant.sql et verify_certificate depuis 20261115140000 ;
--   drop function _post_media_in_use(text) ; drop function profile_cover_set(integer, text, text), profile_cover_clear(integer) puis les recréer en « returns void »
--   depuis 20261114003400 ; rejouer set_my_cover depuis 20261112000000 ; drop table cv_send_attempts.
