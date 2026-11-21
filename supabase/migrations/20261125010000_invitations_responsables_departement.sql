-- Invitations privées des responsables de département : l'administrateur choisit un département (et, s'il le souhaite, une adresse e-mail),
-- obtient un LIEN À USAGE UNIQUE qu'il envoie à la personne. Celle-ci ouvre le lien, crée son compte ou se connecte, accepte : son compte devient
-- « Département » et est rattaché à ce département (même effet qu'admin_dept_assign, avec historique, notification et journal d'audit).
-- Sécurité : le jeton (192 bits) n'est jamais stocké, seulement son empreinte SHA-256 ; il n'est renvoyé qu'une fois, à la création. Le lien expire
-- (7 jours par défaut, 30 au plus), ne sert qu'une fois, peut être révoqué, et peut être réservé à une adresse e-mail. Seuls un compte Client (ou déjà
-- Département) peut l'accepter : un étudiant, une organisation ou un compte du personnel ne change jamais de rôle par ce lien.
-- Retour arrière : drop function dept_invite_create(uuid, text, text, integer), dept_invite_info(text), dept_invite_accept(text), dept_invites_list(), dept_invite_revoke(uuid); drop table dept_leader_invitations.

create table if not exists dept_leader_invitations (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  department_id uuid not null references departments(id) on delete cascade,
  email text check (email is null or email ~ '^[^@ ]+@[^@ ]+$'),
  title text not null default 'Responsable' check (char_length(title) between 1 and 80),
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references profiles(id) on delete set null,
  revoked_at timestamptz
);
alter table dept_leader_invitations enable row level security;
revoke all on dept_leader_invitations from anon, authenticated;

create or replace function _dept_invite_hash(p_token text) returns text
language sql immutable as $$ select encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex') $$;
revoke all on function _dept_invite_hash(text) from public, anon, authenticated;

-- Création (administrateur, session sécurisée si le compte a une double authentification).
create or replace function dept_invite_create(p_department uuid, p_email text default null, p_title text default 'Responsable', p_days integer default 7) returns jsonb
language plpgsql security definer set search_path = public as $$
declare d departments; v_token text; v_id uuid; v_exp timestamptz; v_mail text := nullif(lower(btrim(coalesce(p_email, ''))), '');
        v_title text := coalesce(nullif(btrim(coalesce(p_title, '')), ''), 'Responsable');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  perform _require_staff_aal2();
  if p_days is null or p_days < 1 or p_days > 30 then raise exception 'Durée du lien : de 1 à 30 jours'; end if;
  if char_length(v_title) > 80 then raise exception 'Fonction : 80 caractères au plus'; end if;
  if v_mail is not null and v_mail !~ '^[^@ ]+@[^@ ]+$' then raise exception 'Adresse e-mail invalide'; end if;
  select * into d from departments where id = p_department and status = 'verified';
  if d.id is null then raise exception 'Département introuvable ou non vérifié'; end if;
  if (select count(*) from dept_leader_invitations where created_by = auth.uid() and created_at > now() - interval '1 day') >= 50 then
    raise exception '50 invitations par jour au plus';
  end if;
  v_token := encode(gen_random_bytes(24), 'hex');
  v_exp := now() + make_interval(days => p_days);
  insert into dept_leader_invitations (token_hash, department_id, email, title, created_by, expires_at)
  values (_dept_invite_hash(v_token), d.id, v_mail, v_title, auth.uid(), v_exp) returning id into v_id;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Invitation d''un responsable de département', left(d.name || coalesce(' -> ' || v_mail, ''), 200), 'Départements', 'Sensible');
  return jsonb_build_object('id', v_id, 'token', v_token, 'department', d.name, 'expires_at', v_exp);
end $$;

-- Lecture publique d'un lien (pour la page d'invitation, avant la connexion) : ne révèle que le nom du département et l'état du lien.
create or replace function dept_invite_info(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare i dept_leader_invitations; d departments; v_inst text; v_state text;
begin
  select * into i from dept_leader_invitations where token_hash = _dept_invite_hash(p_token);
  if i.id is null then return jsonb_build_object('valid', false, 'state', 'unknown'); end if;
  select * into d from departments where id = i.department_id;
  select name into v_inst from institutions where id = d.institution_id;
  v_state := case when i.revoked_at is not null then 'revoked' when i.used_at is not null then 'used' when i.expires_at <= now() then 'expired' else 'valid' end;
  return jsonb_build_object('valid', v_state = 'valid', 'state', v_state, 'department', d.name, 'institution', v_inst, 'title', i.title,
    'email_hint', case when i.email is null then null else left(i.email, 2) || '***@' || split_part(i.email, '@', 2) end, 'expires_at', i.expires_at);
end $$;

-- Acceptation (compte connecté).
create or replace function dept_invite_accept(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare i dept_leader_invitations; d departments; me profiles; v_inst text; v_prev department_accounts; v_prev_name text; v_action text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into i from dept_leader_invitations where token_hash = _dept_invite_hash(p_token) for update;
  if i.id is null then raise exception 'Invitation introuvable'; end if;
  if i.revoked_at is not null then raise exception 'Cette invitation a été annulée'; end if;
  if i.used_at is not null then raise exception 'Cette invitation a déjà été utilisée'; end if;
  if i.expires_at <= now() then raise exception 'Cette invitation a expiré : demandez-en une nouvelle à l''administrateur'; end if;
  select * into me from profiles where id = auth.uid() and not suspended;
  if me.id is null then raise exception 'Compte introuvable ou suspendu'; end if;
  if i.email is not null and lower(coalesce(me.email, '')) <> i.email then
    raise exception 'Cette invitation est réservée à une autre adresse e-mail';
  end if;
  if me.role::text not in ('client', 'dept') then
    raise exception 'Ce compte ne peut pas devenir responsable de département : ouvrez le lien avec un compte Client ou créez-en un avec une autre adresse';
  end if;
  select * into d from departments where id = i.department_id and status = 'verified';
  if d.id is null then raise exception 'Département introuvable ou non vérifié'; end if;
  select name into v_inst from institutions where id = d.institution_id;
  if me.role::text <> 'dept' then
    perform set_config('app.dept_invite_rpc', '1', true);
    update profiles set role = 'dept' where id = me.id;
    perform set_config('app.dept_invite_rpc', '', true);
  end if;
  select * into v_prev from department_accounts where user_id = me.id for update;
  select name into v_prev_name from departments where id = v_prev.department_id;
  v_action := case when v_prev.user_id is null then 'assign' when v_prev.department_id = d.id then 'confirm' else 'change' end;
  insert into department_accounts (user_id, department_id, title, assigned_by) values (me.id, d.id, i.title, i.created_by)
  on conflict (user_id) do update set department_id = excluded.department_id, title = excluded.title, assigned_by = excluded.assigned_by, assigned_at = now();
  insert into department_assignment_history (user_id, action, department_id, department_name, institution_name, previous_department, title, actor_id)
  values (me.id, v_action, d.id, d.name, v_inst, v_prev_name, i.title, coalesce(i.created_by, me.id));
  update dept_leader_invitations set used_at = now(), used_by = me.id where id = i.id;
  perform notify_user(i.created_by, 'department', 'Invitation acceptée', me.name || ' gère désormais le département « ' || d.name || ' ».', jsonb_build_object('department', d.id, 'type', 'invite_accepted', 'user', me.id));
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce(me.name, 'Responsable'), me.id, 'Invitation de département acceptée', left(me.name || ' -> ' || d.name, 200), 'Départements', 'Sensible');
  return jsonb_build_object('department', d.name, 'institution', v_inst, 'title', i.title);
end $$;

-- Liste (administrateur) : état de chaque lien, jamais le jeton.
create or replace function dept_invites_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'department', d.name, 'email', i.email, 'title', i.title, 'created_at', i.created_at, 'expires_at', i.expires_at,
      'state', case when i.revoked_at is not null then 'revoked' when i.used_at is not null then 'used' when i.expires_at <= now() then 'expired' else 'valid' end,
      'used_by', (select name from profiles where id = i.used_by)) order by i.created_at desc)
    from (select * from dept_leader_invitations order by created_at desc limit 100) i join departments d on d.id = i.department_id), '[]'::jsonb);
end $$;

create or replace function dept_invite_revoke(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') <> 'admin' then raise exception 'Réservé à l''administrateur'; end if;
  perform _require_staff_aal2();
  update dept_leader_invitations set revoked_at = now() where id = p_id and used_at is null and revoked_at is null;
  if not found then raise exception 'Invitation introuvable ou déjà utilisée'; end if;
end $$;

revoke all on function dept_invite_create(uuid, text, text, integer), dept_invite_accept(text), dept_invites_list(), dept_invite_revoke(uuid) from public, anon;
grant execute on function dept_invite_create(uuid, text, text, integer), dept_invite_accept(text), dept_invites_list(), dept_invite_revoke(uuid) to authenticated;
revoke all on function dept_invite_info(text) from public;
grant execute on function dept_invite_info(text) to anon, authenticated;

-- Le déclencheur de protection laisse passer UNIQUEMENT ce changement de rôle (client -> dept), dans cette fonction (dernière définition : 20261117990100).
create or replace function protect_profile_authority() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
      new.certification := 'none';
      new.certification_decided_by := null;
      new.certification_decided_at := null;
      new.is_test := false;
      new.email := (select u.email from auth.users u where u.id = auth.uid());
      new.phone_verified := false;
    end if;
    return new;
  end if;
  if auth.uid() is not null and coalesce(current_setting('app.cert_rpc', true), '') <> '1'
     and (new.certification is distinct from old.certification
          or new.certification_decided_by is distinct from old.certification_decided_by
          or new.certification_decided_at is distinct from old.certification_decided_at) then
    raise exception 'La certification ne peut être modifiée que par la procédure de certification';
  end if;
  if auth.uid() is not null
     and (new.role is distinct from old.role or new.suspended is distinct from old.suspended or new.is_test is distinct from old.is_test)
     and coalesce(current_role_name()::text, '') <> 'admin'
     -- seule exception : l'acceptation d'une invitation de responsable de département (client -> dept), posée par dept_invite_accept
     and not (coalesce(current_setting('app.dept_invite_rpc', true), '') = '1' and old.role::text = 'client' and new.role::text = 'dept'
              and new.suspended is not distinct from old.suspended and new.is_test is not distinct from old.is_test) then
    raise exception 'Modification du rôle ou du statut réservée à l''administrateur';
  end if;
  if auth.uid() is not null and coalesce(current_role_name()::text, '') <> 'admin' then
    if new.email is distinct from old.email then
      raise exception 'L''adresse e-mail se change depuis la sécurité du compte';
    end if;
    if new.phone is distinct from old.phone and coalesce(old.phone, '') <> '' and coalesce(current_setting('app.phone_rpc', true), '') <> '1' then
      raise exception 'Pour changer de numéro, contactez le support';
    end if;
    -- Le drapeau « vérifié » ne se pose que par la procédure de vérification ; changer de numéro l'efface.
    if new.phone_verified is distinct from old.phone_verified and coalesce(current_setting('app.phone_verify_rpc', true), '') <> '1' then
      new.phone_verified := old.phone_verified;
    end if;
    if new.phone is distinct from old.phone and coalesce(current_setting('app.phone_verify_rpc', true), '') <> '1' then
      new.phone_verified := false;
    end if;
  end if;
  return new;
end $$;
