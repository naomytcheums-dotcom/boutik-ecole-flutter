-- Image ou vidéo d'une offre : une illustration (photo du lieu, vidéo de présentation) visible dans la liste et dans le détail.
-- Aucune fonction existante n'est réécrite sauf la carte d'offre (_opp_card), qui gagne deux champs.
alter table opportunities add column if not exists media_path text check (media_path is null or char_length(media_path) between 5 and 300);
alter table opportunities add column if not exists media_kind text check (media_kind is null or media_kind in ('image', 'video'));

-- Rattache (ou retire, avec un chemin vide) le média d'une offre : seul son auteur ; le fichier doit être dans son dossier.
create or replace function opp_media_set(p_id uuid, p_path text, p_kind text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if not exists (select 1 from opportunities where id = p_id and poster_id = auth.uid()) then raise exception 'Offre introuvable'; end if;
  if nullif(p_path, '') is null then
    update opportunities set media_path = null, media_kind = null where id = p_id;
    return;
  end if;
  if p_kind not in ('image', 'video') then raise exception 'Format inconnu'; end if;
  if split_part(p_path, '/', 1) <> auth.uid()::text then raise exception 'Fichier invalide : déposez-le d''abord dans votre dossier'; end if;
  update opportunities set media_path = p_path, media_kind = p_kind where id = p_id;
end $$;
revoke all on function opp_media_set(uuid, text, text) from public, anon;
grant execute on function opp_media_set(uuid, text, text) to authenticated;

create or replace function _opp_card(o opportunities, p_user uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', o.id, 'org', o.org_name, 'verified', o.verified, 'kind', o.kind, 'contract', o.contract, 'title', o.title, 'location', o.location, 'mode', o.mode, 'duration', o.duration,
    'pay_kind', o.pay_kind, 'pay_amount', o.pay_amount, 'pay_note', o.pay_note, 'deadline', o.deadline, 'skills', to_jsonb(o.skills), 'department_target', o.department_target, 'iut_only', o.iut_only,
    'status', o.status, 'created_at', o.created_at, 'logo', (select pr.avatar_url from profiles pr where pr.id = o.poster_id),
    'media_path', o.media_path, 'media_kind', o.media_kind,
    'saved', exists (select 1 from opportunity_saves s where s.opportunity_id = o.id and s.user_id = p_user),
    'applied', exists (select 1 from opportunity_applications a where a.opportunity_id = o.id and a.applicant_id = p_user))
$$;
revoke all on function _opp_card(opportunities, uuid) from public, anon, authenticated;
