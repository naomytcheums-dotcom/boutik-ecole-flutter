-- Messagerie directe entre coéquipiers : une fois l'invitation acceptée, les deux étudiants s'écrivent dans l'application.
-- Retour arrière : drop function teammate_message_send(uuid, text), teammate_messages_list(uuid, timestamptz); drop table teammate_messages ; recréer mates_search depuis 20261114001500.

create table if not exists teammate_messages (
  id bigint generated always as identity primary key,
  invite_id uuid not null references teammate_invites(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists teammate_messages_invite on teammate_messages (invite_id, created_at);
alter table teammate_messages enable row level security;
revoke all on teammate_messages from anon, authenticated;

create or replace function teammate_message_send(p_invite uuid, p_body text) returns bigint
language plpgsql security definer set search_path = public as $$
declare i teammate_invites%rowtype; v_other uuid; v_id bigint; v_body text := btrim(coalesce(p_body, ''));
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into i from teammate_invites where id = p_invite and status = 'accepted' and auth.uid() in (from_user, to_user);
  if not found then raise exception 'Conversation introuvable : l''invitation doit être acceptée'; end if;
  if char_length(v_body) not between 1 and 1000 then raise exception 'Le message doit contenir entre 1 et 1000 caractères'; end if;
  if (select count(*) from teammate_messages where sender_id = auth.uid() and created_at > now() - interval '1 minute') >= 20 then raise exception 'Trop de messages en peu de temps. Réessayez dans une minute.'; end if;
  insert into teammate_messages (invite_id, sender_id, body) values (i.id, auth.uid(), v_body) returning id into v_id;
  v_other := case when i.from_user = auth.uid() then i.to_user else i.from_user end;
  -- une seule notification non lue par conversation et par dizaine de minutes : pas de rafale
  if not exists (select 1 from notifications where user_id = v_other and kind = 'teammate_message' and read_at is null and (data->>'invite') = i.id::text and created_at > now() - interval '10 minutes') then
    insert into notifications (user_id, kind, title, body, data)
      values (v_other, 'teammate_message', 'Message de ' || display_name(auth.uid()), left(v_body, 120), jsonb_build_object('invite', i.id));
  end if;
  return v_id;
end $$;

create or replace function teammate_messages_list(p_invite uuid, p_after timestamptz default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from teammate_invites where id = p_invite and status = 'accepted' and auth.uid() in (from_user, to_user)) then raise exception 'Conversation introuvable : l''invitation doit être acceptée'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'body', m.body, 'created_at', m.created_at, 'mine', m.sender_id = auth.uid(), 'author', display_name(m.sender_id)) order by m.created_at, m.id)
    from (select * from teammate_messages where invite_id = p_invite and (p_after is null or created_at > p_after) order by created_at desc, id desc limit 100) m), '[]'::jsonb);
end $$;

revoke all on function teammate_message_send(uuid, text), teammate_messages_list(uuid, timestamptz) from public, anon;
grant execute on function teammate_message_send(uuid, text), teammate_messages_list(uuid, timestamptz) to authenticated;

-- La recherche indique aussi l'identifiant de l'invitation (pour ouvrir la conversation d'un coéquipier accepté).
create or replace function mates_search(p_query text default '', p_category uuid default null, p_department text default '', p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_kw text[];
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if p_category is not null then select keywords into v_kw from mate_categories where id = p_category and active; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', display_name(t.id), 'department', coalesce(t.department, ''), 'skills', coalesce(t.skills, ''), 'avatar_url', t.avatar_url,
      'certified', t.certification::text = 'approved',
      'invite', (select i.status from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1),
      'invite_id', (select i.id from teammate_invites i where (i.from_user = auth.uid() and i.to_user = t.id) or (i.to_user = auth.uid() and i.from_user = t.id and i.status = 'accepted') order by i.created_at desc limit 1)) order by (t.certification::text = 'approved') desc, t.created_at desc)
    from (select * from profiles
          where role::text = 'student' and not coalesce(suspended, false) and id <> auth.uid() and nullif(btrim(coalesce(skills, '')), '') is not null
            and (nullif(btrim(coalesce(p_query, '')), '') is null or name ilike '%' || btrim(p_query) || '%' or skills ilike '%' || btrim(p_query) || '%' or coalesce(department, '') ilike '%' || btrim(p_query) || '%')
            and (nullif(btrim(coalesce(p_department, '')), '') is null or coalesce(department, '') ilike '%' || btrim(p_department) || '%')
            and (v_kw is null or exists (select 1 from unnest(v_kw) k where lower(skills || ' ' || coalesce(department, '')) ~ ('(^|[^a-zà-ÿ0-9])' || regexp_replace(k, '([.*+?^$()\[\]{}|\\])', '\\\1', 'g'))))
          order by created_at desc limit least(greatest(coalesce(p_limit, 30), 1), 60)) t), '[]'::jsonb);
end $$;
