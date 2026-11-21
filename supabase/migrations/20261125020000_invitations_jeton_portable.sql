-- Correctif de 20261125010000 : sur Supabase, pgcrypto est dans le schéma « extensions » et gen_random_bytes() n'est pas trouvée avec search_path = public
-- (« function gen_random_bytes(integer) does not exist » à la création d'un lien). Le jeton vient maintenant de deux UUID v4 aléatoires (fonction du noyau
-- PostgreSQL, 64 caractères hexadécimaux, 244 bits) ; seule son empreinte SHA-256 est conservée, comme avant.
-- Retour arrière : recréer la fonction depuis 20261125010000.

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
  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  v_exp := now() + make_interval(days => p_days);
  insert into dept_leader_invitations (token_hash, department_id, email, title, created_by, expires_at)
  values (_dept_invite_hash(v_token), d.id, v_mail, v_title, auth.uid(), v_exp) returning id into v_id;
  insert into audit_log (actor, actor_id, action, target, category, level)
  values (coalesce((select name from profiles where id = auth.uid()), 'Administrateur'), auth.uid(), 'Invitation d''un responsable de département', left(d.name || coalesce(' -> ' || v_mail, ''), 200), 'Départements', 'Sensible');
  return jsonb_build_object('id', v_id, 'token', v_token, 'department', d.name, 'expires_at', v_exp);
end $$;

revoke all on function dept_invite_create(uuid, text, text, integer) from public, anon;
grant execute on function dept_invite_create(uuid, text, text, integer) to authenticated;
