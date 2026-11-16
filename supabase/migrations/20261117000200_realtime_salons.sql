-- Salons vocaux (S7-62) : le canal Realtime d'un salon était public (n'importe qui pouvait écouter la signalisation et le tableau blanc en
-- connaissant l'identifiant du salon). Le client ouvre désormais un canal PRIVÉ `study-room:<id>` ; ces politiques sur realtime.messages
-- n'autorisent à le lire et à y écrire que les membres de la communauté propriétaire d'un salon OUVERT.
-- Réglage externe complémentaire (tableau de bord Supabase > Realtime > Settings) : désactiver « Allow public access ».
-- Retour arrière : drop policy "salons vocaux : lecture" on realtime.messages ; drop policy "salons vocaux : écriture" on realtime.messages ; drop function study_room_topic_allowed(text).

create or replace function study_room_topic_allowed(p_topic text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null or coalesce(current_role_name()::text, '') = '' then return false; end if;
  begin
    v_id := substring(coalesce(p_topic, '') from '^study-room:([0-9a-f-]{36})$')::uuid;
  exception when others then
    return false;
  end;
  if v_id is null then return false; end if;
  return exists (select 1 from study_rooms r where r.id = v_id and r.status = 'open' and is_community_member(r.community_id));
end $$;
revoke all on function study_room_topic_allowed(text) from public, anon;
grant execute on function study_room_topic_allowed(text) to authenticated;

do $$ begin
  drop policy if exists "salons vocaux : lecture" on realtime.messages;
  drop policy if exists "salons vocaux : écriture" on realtime.messages;
  create policy "salons vocaux : lecture" on realtime.messages for select to authenticated using (public.study_room_topic_allowed(realtime.topic()));
  create policy "salons vocaux : écriture" on realtime.messages for insert to authenticated with check (public.study_room_topic_allowed(realtime.topic()));
exception when others then
  raise notice 'Politiques realtime.messages non créées (%). Les salons vocaux ne doivent pas être mis en canal privé tant qu''elles n''existent pas.', sqlerrm;
end $$;
