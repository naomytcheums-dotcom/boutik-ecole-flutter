-- Invitations directes : l'auteur d'une offre publiée invite un étudiant à postuler. L'étudiant reçoit une notification et voit un bandeau
-- sur l'offre ; la candidature passe l'invitation à « envoyée ». Limites : 30 invitations par offre, 100 par jour et par auteur.
create table if not exists opportunity_invites (
  opportunity_id uuid not null references opportunities(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  invited_by uuid not null references profiles(id) on delete cascade,
  message text not null default '' check (char_length(message) <= 300),
  status text not null default 'invited' check (status in ('invited', 'applied', 'declined')),
  created_at timestamptz not null default now(),
  primary key (opportunity_id, student_id)
);
create index if not exists opportunity_invites_by on opportunity_invites (invited_by, created_at desc);
alter table opportunity_invites enable row level security;
revoke all on opportunity_invites from anon, authenticated;

create or replace function opp_invite(p_opp uuid, p_student uuid, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare o opportunities%rowtype; v_msg text := left(btrim(coalesce(p_message, '')), 300);
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into o from opportunities where id = p_opp and poster_id = auth.uid();
  if not found then raise exception 'Offre introuvable'; end if;
  if o.status <> 'published' then raise exception 'Publiez l''offre avant d''inviter des étudiants'; end if;
  if not exists (select 1 from profiles where id = p_student and role = 'student' and not suspended) then raise exception 'Étudiant introuvable'; end if;
  if exists (select 1 from opportunity_applications where opportunity_id = p_opp and applicant_id = p_student) then raise exception 'Cet étudiant a déjà postulé'; end if;
  if exists (select 1 from opportunity_invites where opportunity_id = p_opp and student_id = p_student) then raise exception 'Cet étudiant est déjà invité'; end if;
  if (select count(*) from opportunity_invites where opportunity_id = p_opp) >= 30 then raise exception '30 invitations au plus par offre'; end if;
  if (select count(*) from opportunity_invites where invited_by = auth.uid() and created_at > now() - interval '1 day') >= 100 then raise exception '100 invitations au plus par jour'; end if;
  insert into opportunity_invites (opportunity_id, student_id, invited_by, message) values (p_opp, p_student, auth.uid(), v_msg);
  perform notify_user(p_student, 'opportunity_invite', o.org_name || ' vous invite à postuler', o.title || case when v_msg <> '' then ' : ' || v_msg else '' end || ' · Ouvrez l''offre dans Opportunités.',
                      jsonb_build_object('opportunity', p_opp));
  return 'invited';
end $$;

-- L'invitation reçue pour une offre (l'étudiant concerné seulement).
create or replace function opp_my_invite(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select case when iv.opportunity_id is null then null
              else jsonb_build_object('status', iv.status, 'message', iv.message, 'org', o.org_name, 'created_at', iv.created_at) end
  from (select 1) d left join opportunity_invites iv on iv.opportunity_id = p_id and iv.student_id = auth.uid() left join opportunities o on o.id = p_id
$$;

create or replace function opp_invite_decline(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  update opportunity_invites set status = 'declined' where opportunity_id = p_id and student_id = auth.uid() and status = 'invited';
end $$;

create or replace function trg_invite_applied() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update opportunity_invites set status = 'applied' where opportunity_id = new.opportunity_id and student_id = new.applicant_id and status <> 'applied';
  return new;
end $$;
drop trigger if exists opportunity_applications_invite on opportunity_applications;
create trigger opportunity_applications_invite after insert on opportunity_applications for each row execute function trg_invite_applied();

-- Suggestions : indique aussi qui est déjà invité.
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
                where pr.role = 'student' and not pr.suspended and pr.id <> o.poster_id
                  and (btrim(coalesce(pr.skills, '')) <> '' or btrim(coalesce(pr.bio, '')) <> '')
                  and not exists (select 1 from opportunity_applications a where a.opportunity_id = p_id and a.applicant_id = pr.id)
                limit 500) x
          where (x.j->'match'->>'score')::int >= 30
          order by (x.j->'match'->>'score')::int desc, x.j->>'name'
          limit greatest(1, least(coalesce(p_limit, 10), 30))) t), '[]'::jsonb);
end $$;

revoke all on function opp_invite(uuid, uuid, text), opp_my_invite(uuid), opp_invite_decline(uuid), trg_invite_applied() from public, anon;
grant execute on function opp_invite(uuid, uuid, text), opp_my_invite(uuid), opp_invite_decline(uuid) to authenticated;
revoke all on function opp_suggested_students(uuid, integer) from public, anon;
grant execute on function opp_suggested_students(uuid, integer) to authenticated;
