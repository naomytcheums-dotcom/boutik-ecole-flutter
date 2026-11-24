-- H10 TRUST (1/3) : certificats vérifiables (CDC 17.2, matrice A-411 à A-416, A-428, C-155).
--  * empreinte DÉTERMINISTE recalculable : SHA-256 d'un contenu canonique « BE-CERT/1|code|intitulé|titulaire|émetteur|date UTC »
--    (barre verticale, antislash et saut de ligne échappés), fixée à l'émission par un déclencheur (issue_certificate, patchée par H2/H4, n'est pas redéfinie) ;
--  * signature serveur HMAC-SHA256 du contenu canonique ; la clé vient du réglage `app.trust_signing_key` ou de la table privée trust_signing_keys,
--    jamais du dépôt. Sans clé : le certificat reste « non signé », dit honnêtement comme tel ;
--  * verify_certificate_public(code, titulaire?) : vérification par un tiers anonyme (valide / révoqué / inconnu), nom du titulaire SEULEMENT s'il a consenti
--    (sinon initiales), limite de tentatives infructueuses (anti-énumération) ; verify_certificate devient un enrobage compatible ;
--  * qr_resolve_public(jeton) : un QR de certificat se vérifie sans connexion ; certificate_document(code) : données du document partageable (PDF côté application).
-- Rien n'est supprimé : les colonnes `fingerprint` et tous les certificats existants sont conservés ; l'empreinte canonique des anciens certificats est calculée
-- une fois à partir de leurs champs stockés (deterministe, recalculable), sans signature tant qu'aucune clé n'est configurée.
-- Retour arrière : drop trigger trg_certificates_seal / trg_certificates_frozen on certificates ; drop function verify_certificate_public(text, text), qr_resolve_public(text),
--   certificate_document(text), certificate_set_public_name(text, boolean), trust_* ; rejouer verify_certificate depuis 20261117020000_s2_securite_cv_couvertures.sql.

create extension if not exists pgcrypto;

alter table certificates
  add column if not exists issuer_label text,
  add column if not exists hash_version smallint,
  add column if not exists content_hash text,
  add column if not exists signature text,
  add column if not exists signature_alg text,
  add column if not exists signature_key_id text,
  add column if not exists signed_at timestamptz,
  add column if not exists public_name_consent boolean not null default false;

-- ------------------------------------------------------------ clés de signature (table privée : aucun droit, lecture par fonctions définies seulement)
create table if not exists trust_signing_keys (
  key_id text primary key,
  secret text not null check (char_length(secret) >= 32),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid
);
alter table trust_signing_keys enable row level security;
revoke all on trust_signing_keys from public, anon, authenticated;

-- ------------------------------------------------------------ contenu canonique et empreinte
create or replace function _trust_esc(p_text text) returns text
language sql immutable set search_path = public as $$
  select replace(replace(replace(coalesce(p_text, ''), '\', '\\'), '|', '\|'), E'\n', '\n')
$$;

create or replace function certificate_canonical(p_code text, p_title text, p_holder text, p_issuer text, p_issued timestamptz) returns text
language sql immutable set search_path = public as $$
  select 'BE-CERT/1|' || _trust_esc(p_code) || '|' || _trust_esc(p_title) || '|' || _trust_esc(p_holder) || '|' || _trust_esc(p_issuer) || '|'
         || to_char(p_issued at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
$$;

create or replace function certificate_content_hash(p_code text, p_title text, p_holder text, p_issuer text, p_issued timestamptz) returns text
language sql immutable set search_path = public, extensions as $$
  select encode(digest(convert_to(certificate_canonical(p_code, p_title, p_holder, p_issuer, p_issued), 'UTF8'), 'sha256'), 'hex')
$$;
revoke all on function _trust_esc(text), certificate_canonical(text, text, text, text, timestamptz), certificate_content_hash(text, text, text, text, timestamptz) from public;
grant execute on function certificate_canonical(text, text, text, text, timestamptz), certificate_content_hash(text, text, text, text, timestamptz) to anon, authenticated;

-- ------------------------------------------------------------ clé de signature : réglage de base, sinon table privée ; jamais de valeur par défaut
create or replace function _trust_key_id(p_secret text) returns text
language sql immutable set search_path = public, extensions as $$
  select left(encode(digest(convert_to(p_secret, 'UTF8'), 'sha256'), 'hex'), 12)
$$;

create or replace function _trust_setting_key() returns text
language plpgsql stable set search_path = public as $$
declare v text;
begin
  begin v := nullif(current_setting('app.trust_signing_key', true), ''); exception when others then v := null; end;
  return case when v is not null and char_length(v) >= 32 then v else null end;
end $$;

-- Clé active : (identifiant, secret) ; aucune ligne tant que rien n'est configuré.
create or replace function _trust_active_key(out key_id text, out secret text) returns record
language plpgsql stable security definer set search_path = public, extensions as $$
declare v text := _trust_setting_key();
begin
  if v is not null then key_id := _trust_key_id(v); secret := v; return; end if;
  select k.key_id, k.secret into key_id, secret from trust_signing_keys k where k.active order by k.created_at desc limit 1;
end $$;

create or replace function _trust_key_secret(p_key_id text) returns text
language plpgsql stable security definer set search_path = public, extensions as $$
declare v text := _trust_setting_key(); s text;
begin
  if v is not null and _trust_key_id(v) = p_key_id then return v; end if;
  select secret into s from trust_signing_keys where key_id = p_key_id;
  return s;
end $$;

create or replace function _trust_sign(p_canonical text, p_secret text) returns text
language sql immutable set search_path = public, extensions as $$
  select encode(hmac(convert_to(p_canonical, 'UTF8'), convert_to(p_secret, 'UTF8'), 'sha256'), 'hex')
$$;
revoke all on function _trust_key_id(text), _trust_setting_key(), _trust_active_key(), _trust_key_secret(text), _trust_sign(text, text) from public, anon, authenticated;

-- ------------------------------------------------------------ déclencheur d'émission : empreinte canonique et signature
create or replace function _certificates_seal() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare k record;
begin
  new.issued_at := date_trunc('second', coalesce(new.issued_at, now()));
  new.issuer_label := coalesce(nullif(trim(coalesce(new.issuer_label, '')), ''),
                               'Boutik-École' || case when nullif(trim(coalesce(new.department, '')), '') is not null then ' — ' || trim(new.department) else '' end);
  new.hash_version := 1;
  new.content_hash := certificate_content_hash(new.code, new.subject_title, new.holder_name, new.issuer_label, new.issued_at);
  new.fingerprint := new.content_hash;
  select * into k from _trust_active_key();
  if k.secret is not null then
    new.signature := _trust_sign(certificate_canonical(new.code, new.subject_title, new.holder_name, new.issuer_label, new.issued_at), k.secret);
    new.signature_alg := 'HMAC-SHA256';
    new.signature_key_id := k.key_id;
    new.signed_at := now();
  else
    new.signature := null; new.signature_alg := null; new.signature_key_id := null; new.signed_at := null;
  end if;
  return new;
end $$;
revoke all on function _certificates_seal() from public, anon, authenticated;
drop trigger if exists trg_certificates_seal on certificates;
create trigger trg_certificates_seal before insert on certificates for each row execute function _certificates_seal();

-- Anciens certificats : empreinte canonique calculée une fois à partir des champs stockés, dans content_hash. La colonne fingerprint d'origine reste TELLE QUELLE (valeur conservée ;
-- la vérification publique lit coalesce(content_hash, fingerprint)).
update certificates set
  issuer_label = 'Boutik-École' || case when nullif(trim(coalesce(department, '')), '') is not null then ' — ' || trim(department) else '' end
where issuer_label is null;
update certificates set hash_version = 1, content_hash = certificate_content_hash(code, subject_title, holder_name, issuer_label, date_trunc('second', issued_at))
where content_hash is null;

-- ------------------------------------------------------------ contenu figé : seules la révocation, le consentement et la signature tardive sont modifiables
create or replace function _certificates_frozen() returns trigger
language plpgsql set search_path = public as $$
begin
  if (old.code, old.subject_kind, old.subject_title, old.holder_name, old.issuer_label, old.issued_at, old.content_hash, old.hash_version)
     is distinct from (new.code, new.subject_kind, new.subject_title, new.holder_name, new.issuer_label, new.issued_at, new.content_hash, new.hash_version) then
    raise exception 'Un certificat émis ne se modifie pas : révoquez-le et émettez-en un nouveau';
  end if;
  if old.revoked and not new.revoked then raise exception 'Un certificat révoqué ne peut pas être rétabli'; end if;
  if old.signature is not null and (old.signature, old.signature_alg, old.signature_key_id) is distinct from (new.signature, new.signature_alg, new.signature_key_id) then
    raise exception 'La signature d''un certificat ne se modifie pas';
  end if;
  return new;
end $$;
revoke all on function _certificates_frozen() from public, anon, authenticated;
drop trigger if exists trg_certificates_frozen on certificates;
create trigger trg_certificates_frozen before update on certificates for each row execute function _certificates_frozen();

-- ------------------------------------------------------------ administration de la clé (administrateur seulement)
create or replace function trust_signing_status() returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare k record;
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into k from _trust_active_key();
  return jsonb_build_object('configured', k.secret is not null, 'key_id', k.key_id, 'source', case when _trust_setting_key() is not null then 'setting' when k.secret is not null then 'table' else null end,
    'unsigned', (select count(*)::int from certificates where signature is null and not revoked), 'algorithm', 'HMAC-SHA256');
end $$;

-- Enregistre une nouvelle clé (32 caractères minimum, jamais renvoyée). Les anciennes clés restent lisibles par le serveur pour vérifier les signatures déjà émises.
create or replace function trust_signing_key_set(p_secret text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare v_id text;
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  if p_secret is null or char_length(p_secret) < 32 then raise exception 'La clé de signature doit contenir au moins 32 caractères'; end if;
  v_id := _trust_key_id(p_secret);
  update trust_signing_keys set active = false where active;
  insert into trust_signing_keys (key_id, secret, active, created_by) values (v_id, p_secret, true, auth.uid())
    on conflict (key_id) do update set active = true;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Clé de signature des certificats enregistrée', v_id, 'Certificats', 'Sensible');
  return v_id;
end $$;

-- Signe les certificats émis avant la configuration de la clé (le contenu canonique ne change pas).
create or replace function trust_sign_pending() returns integer
language plpgsql security definer set search_path = public, extensions as $$
declare k record; n integer;
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  select * into k from _trust_active_key();
  if k.secret is null then raise exception 'Aucune clé de signature configurée : les certificats restent non signés'; end if;
  update certificates set signature = _trust_sign(certificate_canonical(code, subject_title, holder_name, issuer_label, issued_at), k.secret),
         signature_alg = 'HMAC-SHA256', signature_key_id = k.key_id, signed_at = now()
   where signature is null and not revoked and hash_version = 1;
  get diagnostics n = row_count;
  insert into audit_log (actor, action, target, category, level) values (auth.uid()::text, 'Certificats signés a posteriori : ' || n, k.key_id, 'Certificats', 'Sensible');
  return n;
end $$;
revoke all on function trust_signing_status(), trust_signing_key_set(text), trust_sign_pending() from public, anon;
grant execute on function trust_signing_status(), trust_signing_key_set(text), trust_sign_pending() to authenticated;

-- ------------------------------------------------------------ consentement du titulaire à l'affichage public de son nom
create or replace function certificate_set_public_name(p_code text, p_consent boolean) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update certificates set public_name_consent = coalesce(p_consent, false) where code = upper(trim(coalesce(p_code, ''))) and holder_id = auth.uid();
  if not found then raise exception 'Certificat introuvable'; end if;
  return coalesce(p_consent, false);
end $$;
revoke all on function certificate_set_public_name(text, boolean) from public, anon;
grant execute on function certificate_set_public_name(text, boolean) to authenticated;

-- ------------------------------------------------------------ vérification publique
create or replace function _trust_initials(p_name text) returns text
language sql immutable set search_path = public as $$
  select coalesce(nullif((select string_agg(upper(left(w, 1)) || '.', ' ') from regexp_split_to_table(btrim(coalesce(p_name, '')), '\s+') w where w <> ''), ''), '—')
$$;

-- Appelant pour la limite de débit : compte connecté, sinon adresse transmise par la passerelle (la plus proche du serveur d'abord).
create or replace function _trust_caller() returns text
language plpgsql stable set search_path = public as $$
declare v_headers jsonb; v_ip text;
begin
  begin v_headers := nullif(current_setting('request.headers', true), '')::jsonb; exception when others then v_headers := null; end;
  v_ip := coalesce(nullif(trim(v_headers ->> 'cf-connecting-ip'), ''), nullif(trim(v_headers ->> 'x-real-ip'), ''),
                   nullif(trim((regexp_split_to_array(coalesce(v_headers ->> 'x-forwarded-for', ''), '\s*,\s*'))[array_length(regexp_split_to_array(coalesce(v_headers ->> 'x-forwarded-for', ''), '\s*,\s*'), 1)]), ''));
  return coalesce(auth.uid()::text, v_ip, 'inconnu');
end $$;
revoke all on function _trust_initials(text), _trust_caller() from public, anon, authenticated;

create or replace function verify_certificate_public(p_code text, p_holder text default null) returns jsonb
language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  v_code text := upper(left(regexp_replace(coalesce(p_code, ''), '\s+', '', 'g'), 40));
  v_caller text := _trust_caller();
  c certificates%rowtype; v_secret text; v_sig text; v_full boolean; v_res jsonb; v_claim boolean;
begin
  if (select count(*) from certificate_checks where caller = v_caller and at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('code', v_code, 'statut', 'limite', 'valide', false, 'limite', true);
  end if;
  select * into c from certificates where code = v_code;
  if not found then
    insert into certificate_checks (caller) values (v_caller);
    delete from certificate_checks where at < now() - interval '1 day';
    return jsonb_build_object('code', v_code, 'statut', 'inconnu', 'valide', false, 'introuvable', true);
  end if;
  v_full := auth.uid() is not null and (c.holder_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'direction'));
  if c.signature is null then v_sig := 'non_signe';
  else
    v_secret := _trust_key_secret(c.signature_key_id);
    if v_secret is null then v_sig := 'cle_indisponible';
    elsif _trust_sign(certificate_canonical(c.code, c.subject_title, c.holder_name, c.issuer_label, c.issued_at), v_secret) = c.signature then v_sig := 'valide';
    else v_sig := 'invalide'; end if;
  end if;
  if p_holder is not null then
    v_claim := c.hash_version = 1 and certificate_content_hash(c.code, c.subject_title, btrim(p_holder), c.issuer_label, c.issued_at) = c.content_hash;
    if not v_claim then insert into certificate_checks (caller) values (v_caller); end if;
  end if;
  v_res := jsonb_build_object(
    'code', c.code, 'statut', case when c.revoked then 'revoque' else 'valide' end, 'valide', not c.revoked,
    'objet', c.subject_title, 'type', c.subject_kind, 'emetteur', c.issuer_label, 'departement', c.department,
    'delivre_le', to_char(c.issued_at at time zone 'UTC', 'DD/MM/YYYY'), 'delivre_le_iso', to_char(c.issued_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'titulaire', case when c.public_name_consent or v_full then c.holder_name else _trust_initials(c.holder_name) end,
    'titulaire_nom_public', c.public_name_consent,
    'motif_revocation', c.revoked_reason, 'revoque_le', c.revoked_at,
    'empreinte', coalesce(c.content_hash, c.fingerprint), 'empreinte_algo', 'SHA-256', 'empreinte_recalculable', c.hash_version = 1,
    'format_empreinte', 'BE-CERT/1|code|intitule|titulaire|emetteur|date UTC (AAAA-MM-JJTHH:MM:SSZ) ; \, | et saut de ligne échappés par \',
    'signature', v_sig, 'signature_algo', c.signature_alg, 'cle_id', c.signature_key_id);
  if p_holder is not null then v_res := v_res || jsonb_build_object('titulaire_concordant', v_claim); end if;
  return v_res;
end $$;
revoke all on function verify_certificate_public(text, text) from public;
grant execute on function verify_certificate_public(text, text) to anon, authenticated;

-- Ancienne fonction conservée (écran 212, bouton « Voir le certificat ») : mêmes clés, mais le nom du titulaire suit désormais son consentement.
create or replace function verify_certificate(p_code text) returns jsonb
language sql volatile security definer set search_path = public, extensions as $$
  select verify_certificate_public(p_code, null)
$$;
revoke all on function verify_certificate(text) from public;
grant execute on function verify_certificate(text) to anon, authenticated;

-- ------------------------------------------------------------ QR de certificat : résolu sans connexion (les autres QR demandent toujours un compte)
create or replace function qr_resolve_public(p_token text) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare r qr_codes%rowtype; v_caller text := _trust_caller();
begin
  if (select count(*) from certificate_checks where caller = v_caller and at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('valid', false, 'reason', 'limit');
  end if;
  select * into r from qr_codes where token = coalesce(p_token, '');
  if not found then
    insert into certificate_checks (caller) values (v_caller);
    return jsonb_build_object('valid', false, 'reason', 'login_required');
  end if;
  if r.kind <> 'certificate' then return jsonb_build_object('valid', false, 'reason', 'login_required'); end if;
  if r.revoked or (r.expires_at is not null and r.expires_at < now()) then return jsonb_build_object('valid', false, 'reason', 'expired', 'kind', 'certificate'); end if;
  return jsonb_build_object('valid', true, 'kind', 'certificate', 'code', r.target_id);
end $$;
revoke all on function qr_resolve_public(text) from public;
grant execute on function qr_resolve_public(text) to anon, authenticated;

-- ------------------------------------------------------------ données du document partageable (titulaire ou équipe dans son périmètre, selon la RLS de certificates)
-- Ne renvoie que l'état de la signature (jamais la clé) : fonction définie séparément pour que certificate_document reste soumise à la RLS.
create or replace function _trust_signature_status(p_code text) returns text
language plpgsql stable security definer set search_path = public, extensions as $$
declare c certificates%rowtype; v_secret text;
begin
  select * into c from certificates where code = p_code;
  if not found or c.signature is null then return 'non_signe'; end if;
  v_secret := _trust_key_secret(c.signature_key_id);
  if v_secret is null then return 'cle_indisponible'; end if;
  return case when _trust_sign(certificate_canonical(c.code, c.subject_title, c.holder_name, c.issuer_label, c.issued_at), v_secret) = c.signature then 'valide' else 'invalide' end;
end $$;
revoke all on function _trust_signature_status(text) from public, anon;
grant execute on function _trust_signature_status(text) to authenticated;

create or replace function certificate_document(p_code text) returns jsonb
language plpgsql stable security invoker set search_path = public, extensions as $$
declare c certificates%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from certificates where code = upper(trim(coalesce(p_code, '')));
  if not found then return null; end if;
  return jsonb_build_object('code', c.code, 'objet', c.subject_title, 'titulaire', c.holder_name, 'emetteur', c.issuer_label,
    'delivre_le', to_char(c.issued_at at time zone 'UTC', 'DD/MM/YYYY'), 'delivre_le_iso', to_char(c.issued_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'valide', not c.revoked, 'empreinte', coalesce(c.content_hash, c.fingerprint), 'empreinte_algo', 'SHA-256', 'signature', _trust_signature_status(c.code),
    'public_name_consent', c.public_name_consent);
end $$;
revoke all on function certificate_document(text) from public, anon;
grant execute on function certificate_document(text) to authenticated;
