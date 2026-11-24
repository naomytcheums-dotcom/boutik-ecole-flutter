-- H10 TRUST (3/3) : registre de preuves d'innovation horodaté et versionné (CDC 12.3, matrice C-146/C-148/C-155/C-157, A-419).
--  * project_versions : une VERSION IMMUABLE d'un projet (titre, résumé, liens, étapes, auteur et contributeurs acceptés au moment de la preuve), chaînée à la précédente
--    par son empreinte (prev_hash) : SHA-256 d'un contenu canonique « BE-PROOF/1|projet|version|date UTC|empreinte précédente|instantané », signée HMAC-SHA256 si la clé
--    de la plateforme est configurée (même clé que les certificats), sinon marquée « non signée » ;
--  * l'horodatage est celui du serveur de Boutik-École : ce n'est PAS un horodatage d'un tiers de confiance, ni un brevet, ni une reconnaissance de propriété intellectuelle ;
--  * project_proof_register (porteur) crée la version suivante (refus s'il n'y a aucun changement) ; project_proof_list (porteur, département, administrateur) ;
--    project_proof_verify (tiers anonyme, projets APPROUVÉS seulement) recalcule les empreintes et la chaîne, sans le contenu privé ; nom de l'auteur en initiales.
-- Les versions ne se modifient ni ne se suppriment (la suppression du projet par son porteur supprime ses preuves). Additive et rejouable.
-- Retour arrière : drop function project_proof_register(uuid, text), project_proof_list(uuid), project_proof_verify(uuid) ; drop table project_versions.

create extension if not exists pgcrypto;

create table if not exists project_versions (
  id bigint generated always as identity primary key,
  project_id uuid not null references projects (id) on delete cascade,
  version integer not null check (version >= 1),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  note text not null default '' check (char_length(note) <= 300),
  prev_hash text check (prev_hash is null or prev_hash ~ '^[0-9a-f]{64}$'),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  signature text,
  signature_alg text,
  signature_key_id text,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null,
  unique (project_id, version)
);
alter table project_versions enable row level security;
revoke all on project_versions from public, anon, authenticated;

create or replace function _proof_canonical(p_project uuid, p_version integer, p_at timestamptz, p_prev text, p_snapshot jsonb) returns text
language sql immutable set search_path = public as $$
  select 'BE-PROOF/1|' || p_project::text || '|' || p_version::text || '|' || to_char(p_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '|' || coalesce(p_prev, '') || '|' || _trust_esc(p_snapshot::text)
$$;
revoke all on function _proof_canonical(uuid, integer, timestamptz, text, jsonb) from public, anon, authenticated;

create or replace function _project_versions_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then raise exception 'Une version de preuve ne se modifie pas'; end if;
  if exists (select 1 from projects where id = old.project_id) then raise exception 'Une version de preuve ne se supprime pas'; end if;
  return old;
end $$;
revoke all on function _project_versions_guard() from public, anon, authenticated;
drop trigger if exists trg_project_versions_guard on project_versions;
create trigger trg_project_versions_guard before update or delete on project_versions for each row execute function _project_versions_guard();

create or replace function project_proof_register(p_project uuid, p_note text default '') returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  p projects%rowtype; v_snap jsonb; v_last project_versions%rowtype; v_ver integer; v_at timestamptz := date_trunc('second', now()); v_hash text; k record; v_sig text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from projects where id = p_project and owner_id = auth.uid() for update;
  if not found then raise exception 'Projet introuvable'; end if;
  v_snap := jsonb_build_object('title', p.title, 'summary', coalesce(p.summary, ''), 'department', coalesce(p.department, ''), 'links', p.links,
    'author', (select name from profiles where id = p.owner_id),
    'members', coalesce((select jsonb_agg(jsonb_build_object('name', pr.name, 'role', m.role) order by pr.name, m.user_id) from project_members m join profiles pr on pr.id = m.user_id
                         where m.project_id = p.id and m.status = 'accepted'), '[]'::jsonb),
    'steps', coalesce((select jsonb_agg(jsonb_build_object('title', s.title, 'on', s.happened_on) order by s.happened_on, s.id) from project_steps s where s.project_id = p.id), '[]'::jsonb));
  select * into v_last from project_versions where project_id = p.id order by version desc limit 1;
  if found and v_last.snapshot = v_snap then raise exception 'Aucun changement depuis la version %', v_last.version; end if;
  v_ver := coalesce(v_last.version, 0) + 1;
  if v_ver > 50 then raise exception 'Cinquante versions au plus par projet'; end if;
  v_hash := encode(digest(convert_to(_proof_canonical(p.id, v_ver, v_at, v_last.content_hash, v_snap), 'UTF8'), 'sha256'), 'hex');
  select * into k from _trust_active_key();
  if k.secret is not null then v_sig := _trust_sign(_proof_canonical(p.id, v_ver, v_at, v_last.content_hash, v_snap), k.secret); end if;
  insert into project_versions (project_id, version, snapshot, note, prev_hash, content_hash, signature, signature_alg, signature_key_id, created_by, created_at)
    values (p.id, v_ver, v_snap, left(_clean_text(p_note), 300), v_last.content_hash, v_hash, v_sig, case when v_sig is not null then 'HMAC-SHA256' end, case when v_sig is not null then k.key_id end, auth.uid(), v_at);
  return jsonb_build_object('project_id', p.id, 'version', v_ver, 'empreinte', v_hash, 'precedente', v_last.content_hash, 'horodatage', v_at, 'signature', case when v_sig is null then 'non_signe' else 'valide' end,
    'mention', 'Horodatage interne de Boutik-École : ce n''est ni un brevet ni une reconnaissance de propriété intellectuelle.');
end $$;

-- Intégrité d'une version : empreinte recalculée, chaîne, signature.
create or replace function _proof_check(v project_versions, p_prev text) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare v_canon text := _proof_canonical(v.project_id, v.version, v.created_at, v.prev_hash, v.snapshot); v_secret text; v_sig text;
begin
  if v.signature is null then v_sig := 'non_signe';
  else
    v_secret := _trust_key_secret(v.signature_key_id);
    v_sig := case when v_secret is null then 'cle_indisponible' when _trust_sign(v_canon, v_secret) = v.signature then 'valide' else 'invalide' end;
  end if;
  return jsonb_build_object('version', v.version, 'horodatage', v.created_at, 'empreinte', v.content_hash, 'precedente', v.prev_hash,
    'integre', encode(digest(convert_to(v_canon, 'UTF8'), 'sha256'), 'hex') = v.content_hash and v.prev_hash is not distinct from p_prev, 'signature', v_sig);
end $$;
revoke all on function _proof_check(project_versions, text) from public, anon, authenticated;

create or replace function project_proof_list(p_project uuid) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare v project_versions%rowtype; v_prev text; v_out jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from projects p where p.id = p_project and (p.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin'))) then return '[]'::jsonb; end if;
  for v in select * from project_versions where project_id = p_project order by version loop
    v_out := v_out || (_proof_check(v, v_prev) || jsonb_build_object('note', v.note, 'titre', v.snapshot ->> 'title', 'contributeurs', jsonb_array_length(v.snapshot -> 'members')));
    v_prev := v.content_hash;
  end loop;
  return (select coalesce(jsonb_agg(x order by (x ->> 'version')::int desc), '[]'::jsonb) from jsonb_array_elements(v_out) x);
end $$;

create or replace function project_proof_verify(p_project uuid) returns jsonb
language plpgsql volatile security definer set search_path = public, extensions as $$
declare
  v_caller text := _trust_caller(); p projects%rowtype; v project_versions%rowtype; v_prev text; v_out jsonb := '[]'::jsonb; v_author text;
begin
  if (select count(*) from certificate_checks where caller = v_caller and at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('statut', 'limite', 'valide', false);
  end if;
  select * into p from projects where id = p_project and status = 'approved';
  if not found or not exists (select 1 from project_versions where project_id = p.id) then
    insert into certificate_checks (caller) values (v_caller);
    return jsonb_build_object('statut', 'inconnu', 'valide', false);
  end if;
  for v in select * from project_versions where project_id = p.id order by version loop
    v_out := v_out || (_proof_check(v, v_prev) || jsonb_build_object('note', v.note));
    v_prev := v.content_hash;
    v_author := v.snapshot ->> 'author';
  end loop;
  return jsonb_build_object('statut', 'enregistre', 'valide', not exists (select 1 from jsonb_array_elements(v_out) x where not (x ->> 'integre')::boolean),
    'projet', p.title, 'auteur', _trust_initials(v_author), 'versions', (select jsonb_agg(x order by (x ->> 'version')::int desc) from jsonb_array_elements(v_out) x),
    'mention', 'Horodatage interne de Boutik-École : ce n''est ni un brevet ni une reconnaissance de propriété intellectuelle.');
end $$;

revoke all on function project_proof_register(uuid, text), project_proof_list(uuid) from public, anon;
grant execute on function project_proof_register(uuid, text), project_proof_list(uuid) to authenticated;
revoke all on function project_proof_verify(uuid) from public;
grant execute on function project_proof_verify(uuid) to anon, authenticated;
