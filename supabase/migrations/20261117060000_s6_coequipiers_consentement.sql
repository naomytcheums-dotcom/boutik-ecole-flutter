-- Lot S6 (1/4) : annuaire de coéquipiers sur consentement explicite (S6-15, S6-16).
-- Avant : tout étudiant ayant renseigné ses compétences apparaissait dans mates_search pour tous les autres étudiants (nom, filière, compétences, photo).
-- Désormais : un étudiant n'est listé que s'il a ACTIVÉ « Apparaître dans l'annuaire des coéquipiers » (écran 163) ; il peut se retirer à tout moment.
-- Le consentement est stocké dans une table à part (aucune colonne de profiles n'est ajoutée ni modifiée) et n'est lisible que par RPC.
-- Les étudiants déjà visibles avant cette migration ne le sont plus tant qu'ils n'ont pas donné leur accord (choix volontaire : respect de la vie privée).
-- Retour arrière : voir le bas du fichier.

create table if not exists mate_consents (
  user_id uuid primary key references profiles(id) on delete cascade,
  visible boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table mate_consents enable row level security;
revoke all on mate_consents from anon, authenticated;

-- Lecture de mon réglage : visible, compétences renseignées (condition pour être listé), rôle concerné.
create or replace function mates_visibility_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p profiles%rowtype; v boolean;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from profiles where id = auth.uid();
  select visible into v from mate_consents where user_id = auth.uid();
  return jsonb_build_object(
    'eligible', p.role::text = 'student' and not coalesce(p.suspended, false),
    'visible', coalesce(v, false),
    'has_skills', nullif(btrim(coalesce(p.skills, '')), '') is not null,
    'verified', p.certification::text = 'approved');
end $$;

create or replace function mates_visibility_set(p_visible boolean) returns boolean
language plpgsql security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into p from profiles where id = auth.uid();
  if p.role::text <> 'student' or coalesce(p.suspended, false) then raise exception 'L''annuaire des coéquipiers est réservé aux étudiants'; end if;
  if coalesce(p_visible, false) and nullif(btrim(coalesce(p.skills, '')), '') is null then
    raise exception 'Renseignez vos compétences dans votre profil avant d''apparaître dans l''annuaire';
  end if;
  insert into mate_consents (user_id, visible, updated_at) values (auth.uid(), coalesce(p_visible, false), now())
    on conflict (user_id) do update set visible = excluded.visible, updated_at = now();
  return coalesce(p_visible, false);
end $$;

-- Recherche : même contrat qu'avant (20261115200400), mais seuls les étudiants consentants (et avec compétences) sont listés.
create or replace function mates_search(p_query text default '', p_category uuid default null, p_department text default '', p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_kw text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'La recherche de coéquipiers est réservée aux étudiants'; end if;
  if p_category is not null then select keywords into v_kw from mate_categories where id = p_category and active; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', display_name(t.id), 'department', coalesce(t.department, ''), 'skills', coalesce(t.skills, ''), 'avatar_url', t.avatar_url,
      'certified', t.certification::text = 'approved',
      'invite', (select i.status from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1),
      'invite_id', (select i.id from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1)) order by (t.certification::text = 'approved') desc, t.created_at desc)
    from (select * from profiles pr
          where pr.role::text = 'student' and not coalesce(pr.suspended, false) and pr.id <> auth.uid() and nullif(btrim(coalesce(pr.skills, '')), '') is not null
            and exists (select 1 from mate_consents mc where mc.user_id = pr.id and mc.visible)
            and (nullif(btrim(coalesce(p_query, '')), '') is null or pr.name ilike '%' || btrim(p_query) || '%' or pr.skills ilike '%' || btrim(p_query) || '%' or coalesce(pr.department, '') ilike '%' || btrim(p_query) || '%')
            and (nullif(btrim(coalesce(p_department, '')), '') is null or coalesce(pr.department, '') ilike '%' || btrim(p_department) || '%')
            and (v_kw is null or exists (select 1 from unnest(v_kw) k where lower(pr.skills || ' ' || coalesce(pr.department, '')) ~ ('(^|[^a-zà-ÿ0-9])' || regexp_replace(k, '([.*+?^$()\[\]{}|\\])', '\\\1', 'g'))))
          order by pr.created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) t), '[]'::jsonb);
end $$;

-- Invitation : seulement vers un étudiant qui a accepté d'apparaître dans l'annuaire, ou qui m'a lui-même invité (pour lui répondre).
create or replace function teammate_invite(p_user uuid, p_message text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'dept', 'admin') then raise exception 'Les invitations d''équipe sont réservées aux étudiants'; end if;
  if p_user = auth.uid() then raise exception 'Vous ne pouvez pas vous inviter vous-même'; end if;
  if not exists (select 1 from profiles where id = p_user and role::text = 'student' and not coalesce(suspended, false)) then raise exception 'Étudiant introuvable'; end if;
  if not exists (select 1 from mate_consents where user_id = p_user and visible)
     and not exists (select 1 from teammate_invites where from_user = p_user and to_user = auth.uid()) then
    raise exception 'Cet étudiant n''est pas dans l''annuaire des coéquipiers';
  end if;
  if exists (select 1 from teammate_invites where from_user = auth.uid() and to_user = p_user and status = 'pending') then raise exception 'Une invitation est déjà en attente pour cet étudiant'; end if;
  if (select count(*) from teammate_invites where from_user = auth.uid() and created_at > now() - interval '1 day') >= 10 then raise exception 'Dix invitations par jour au plus'; end if;
  insert into teammate_invites (from_user, to_user, message) values (auth.uid(), p_user, left(btrim(coalesce(p_message, '')), 500)) returning id into v_id;
  perform notify_user(p_user, 'teammate_invite', 'Invitation d''équipe', display_name(auth.uid()) || ' vous invite à rejoindre son équipe.', jsonb_build_object('invite', v_id));
  return v_id;
end $$;

revoke all on function mates_visibility_get(), mates_visibility_set(boolean) from public, anon;
grant execute on function mates_visibility_get(), mates_visibility_set(boolean) to authenticated;
revoke all on function mates_search(text, uuid, text, integer), teammate_invite(uuid, text) from public, anon;
grant execute on function mates_search(text, uuid, text, integer), teammate_invite(uuid, text) to authenticated;

-- Retour arrière : recréer mates_search et teammate_invite depuis 20261115200400_l10_concours_hackathons.sql ;
--   drop function mates_visibility_get(), mates_visibility_set(boolean) ; drop table mate_consents.
