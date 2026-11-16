-- Communautés : le nom d'une communauté refusée redevient disponible (S7-60).
-- Jusqu'ici le nom restait réservé pour toujours (index unique et contrôle sur tous les statuts) : l'étudiant refusé devait inventer un autre nom.
-- L'unicité ne vaut plus que pour les communautés en attente ou actives (les refusées sont ignorées).
-- Retour arrière : recréer l'index communities_name_unique sans condition (peut échouer s'il existe des doublons) et create_community depuis 20261114004100.

drop index if exists communities_name_unique;
create unique index if not exists communities_name_unique on communities (lower(btrim(name))) where status <> 'rejected';

create or replace function create_community(p_name text, p_description text default '', p_category text default '', p_privacy text default 'public', p_rules text default '', p_department uuid default null,
  p_kind text default 'interest', p_promo text default null, p_interest text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_words integer; r record; v_promo text := nullif(btrim(coalesce(p_promo, '')), ''); v_interest text := nullif(btrim(coalesce(p_interest, '')), '');
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from profiles where id = auth.uid() and coalesce(suspended, false) = false) then raise exception 'Compte suspendu : création de communauté impossible'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 3 and 60 then raise exception 'Le nom doit contenir entre 3 et 60 caractères'; end if;
  if p_privacy not in ('public', 'approval', 'invite') then raise exception 'Confidentialité inconnue'; end if;
  if p_kind not in ('filiere', 'promo', 'interest', 'alumni', 'project') then raise exception 'Type de communauté inconnu'; end if;
  if p_kind = 'promo' and v_promo is null then raise exception 'Indiquez la promotion (ex. Promo 2026)'; end if;
  if p_kind = 'interest' and v_interest is null then raise exception 'Indiquez le centre d''intérêt (ex. Dev Flutter)'; end if;
  if p_kind = 'filiere' and p_department is null then raise exception 'Choisissez la filière'; end if;
  v_words := case when btrim(coalesce(p_description, '')) = '' then 0 else cardinality(regexp_split_to_array(btrim(p_description), '\s+')) end;
  if v_words > 500 then raise exception 'La description ne doit pas dépasser 500 mots (% mots saisis)', v_words; end if;
  if p_department is not null and not exists (select 1 from departments where id = p_department and status = 'verified') then raise exception 'Département inconnu'; end if;
  if (select count(*) from communities where owner_id = auth.uid() and status in ('pending', 'active')) >= 5 then raise exception 'Vous ne pouvez pas avoir plus de 5 communautés'; end if;
  if exists (select 1 from communities where lower(btrim(name)) = lower(btrim(p_name)) and status <> 'rejected') then raise exception 'Une communauté porte déjà ce nom'; end if;
  insert into communities (name, description, category, rules, privacy, owner_id, department_id, status, kind, promo_year, interest)
    values (btrim(p_name), btrim(coalesce(p_description, '')), coalesce(p_category, ''), coalesce(p_rules, ''), p_privacy, auth.uid(), p_department, 'pending', p_kind, left(v_promo, 20), left(v_interest, 60)) returning id into v_id;
  insert into community_members (community_id, user_id, role, status) values (v_id, auth.uid(), 'owner', 'active');
  for r in select id from profiles where role::text in ('admin', 'support') loop
    perform notify_user(r.id, 'community_validation', 'Communauté à valider', display_name(auth.uid()) || ' propose la communauté « ' || btrim(p_name) || ' ».', jsonb_build_object('community', v_id));
  end loop;
  return v_id;
end $$;
revoke all on function create_community(text, text, text, text, text, uuid, text, text, text) from public, anon;
grant execute on function create_community(text, text, text, text, text, uuid, text, text, text) to authenticated;
