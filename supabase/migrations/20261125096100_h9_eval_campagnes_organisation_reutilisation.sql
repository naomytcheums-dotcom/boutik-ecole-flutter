-- Lot H9 / EVAL-SQL (2/3) : campagnes d'évaluation d'une organisation et réutilisation d'une évaluation récente (CDC 8.4).
--  1. campagnes : création, liste, invitation de candidats, clôture par l'équipe de l'organisation (company_members : propriétaire et administrateurs ; finance et lecteur lisent les campagnes) ;
--     AUCUN paiement, AUCUN débit : une campagne naît « en_attente_financement » et le reste tant que le propriétaire n'a pas décidé un mécanisme de financement (aucune RPC ne l'ouvre) ;
--     personne ne peut passer d'évaluation sur une campagne non ouverte ; l'organisation ne voit que ses campagnes et les résultats que les candidats ont accepté de partager ;
--  2. candidat : liste de ses invitations, retrait ou rétablissement du partage d'un résultat de campagne ;
--  3. réutilisation d'une évaluation récente avec l'accord explicite du candidat, révocable ; durée de validité lue dans platform_settings 'assessment.reuse_days'
--     (ABSENTE par défaut : réutilisation indisponible, aucune valeur inventée) ; une réutilisation ne consomme ni quota ni financement.
-- Aucune donnée insérée. Additive et rejouable. Retour arrière :
--   drop function _assessment_reuse_days(), _assessment_org_owner(uuid, boolean), assessment_campaign_create(text, text, text, uuid), assessment_campaigns_list(uuid), assessment_campaign_invite(uuid, text),
--     assessment_campaign_close(uuid), assessment_campaign_results(uuid), assessment_my_invitations(), assessment_share_set(uuid, boolean), assessment_reuse_options(uuid),
--     assessment_reuse_grant(uuid, uuid, boolean), assessment_reuse_revoke(uuid);

-- Durée de validité d'une évaluation réutilisable : null tant que le propriétaire ne l'a pas décidée (réglage absent ou invalide).
create or replace function _assessment_reuse_days() returns integer
language plpgsql stable security definer set search_path = public as $$
declare v jsonb; n numeric;
begin
  select value into v from platform_settings where key = 'assessment.reuse_days';
  if v is null then return null; end if;
  begin
    n := case jsonb_typeof(v) when 'number' then (v #>> '{}')::numeric when 'object' then (v ->> 'days')::numeric else null end;
  exception when others then
    return null;
  end;
  return case when n is not null and n >= 1 and n = floor(n) and n <= 3650 then n::integer end;
end $$;
revoke all on function _assessment_reuse_days() from public, anon, authenticated;

-- Organisation visée (la sienne, ou celle dont on est membre actif) ; compte d'organisation et droit de l'équipe exigés.
create or replace function _assessment_org_owner(p_org uuid, p_write boolean) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu'; end if;
  v_owner := company_effective_owner(p_org);
  if coalesce((select role::text from profiles where id = v_owner), '') not in ('company', 'other') then raise exception 'Accès refusé : réservé aux comptes d''organisation'; end if;
  if not _assessment_org_can(v_owner, p_write) then raise exception 'Accès refusé : réservé au propriétaire et aux administrateurs de l''organisation'; end if;
  return v_owner;
end $$;
revoke all on function _assessment_org_owner(uuid, boolean) from public, anon, authenticated;

-- ============================================================ 1. Campagnes (organisation)
create or replace function assessment_campaign_create(p_title text, p_family text, p_mode text, p_org uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_owner uuid := _assessment_org_owner(p_org, true); v_title text := btrim(coalesce(p_title, '')); v_id uuid;
begin
  if char_length(v_title) < 2 or char_length(v_title) > 160 then raise exception 'Donnez un titre de campagne (2 à 160 caractères)'; end if;
  if p_mode is null or not (p_mode = any (_assessment_modes())) then raise exception 'Mode d''évaluation inconnu'; end if;
  if not exists (select 1 from assessment_families where code = p_family and active) then raise exception 'Famille de métiers inconnue ou désactivée'; end if;
  insert into assessment_campaigns (org_id, title, family_code, mode, status, created_by) values (v_owner, v_title, p_family, p_mode, 'en_attente_financement', auth.uid()) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id, 'status', 'en_attente_financement',
    'message', 'Campagne enregistrée « en attente de financement » : aucun paiement n''est demandé ni prélevé. Elle ne s''ouvrira aux candidats que lorsque le financement des campagnes sera en service.');
end $$;

create or replace function assessment_campaigns_list(p_org uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := _assessment_org_owner(p_org, false); v_write boolean;
begin
  v_write := _assessment_org_can(v_owner, true);
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'family_code', c.family_code, 'family_label', f.label, 'mode', c.mode, 'status', c.status, 'created_at', c.created_at,
      'invited', (select count(*)::int from assessment_campaign_invites i where i.campaign_id = c.id),
      'shared_results', case when v_write then (select count(*)::int from assessment_requests q join assessment_results r on r.request_id = coalesce(q.reuse_of, q.id)
                                                where q.campaign_id = c.id and q.share_with_org and q.status <> 'annulee' and (q.reuse_of is null or q.reuse_consent)) end,
      'note', case c.status when 'en_attente_financement' then 'Financement non décidé : aucun paiement n''est demandé, la campagne n''est pas ouverte aux candidats.' end)
      order by c.created_at desc)
    from assessment_campaigns c join assessment_families f on f.code = c.family_code where c.org_id = v_owner), '[]'::jsonb);
end $$;

create or replace function assessment_campaign_invite(p_campaign uuid, p_email text) returns text
language plpgsql security definer set search_path = public as $$
declare c assessment_campaigns; v_email text := lower(btrim(coalesce(p_email, ''))); v_target uuid; v_name text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from assessment_campaigns where id = p_campaign;
  if c.id is null or not _assessment_org_can(c.org_id, true) then raise exception 'Campagne introuvable'; end if;
  perform _assessment_org_owner(c.org_id, true);
  if c.status = 'close' then raise exception 'Cette campagne est close'; end if;
  if v_email = '' or v_email !~ '^[^@ ]+@[^@ ]+$' then raise exception 'Saisissez l''e-mail du candidat'; end if;
  select id into v_target from profiles where lower(email) = v_email and not coalesce(suspended, false) and role::text in ('student', 'client');
  -- compte inconnu ou inéligible : même réponse, sans invitation ni notification (pas d'énumération de comptes)
  if v_target is null or v_target = c.org_id then return 'invited'; end if;
  insert into assessment_campaign_invites (campaign_id, candidate_id) values (c.id, v_target) on conflict do nothing;
  if found then
    select coalesce((select company_name from company_profiles where owner_id = c.org_id), (select name from profiles where id = c.org_id), 'Une organisation') into v_name;
    perform notify_user(v_target, 'assessment', 'Invitation à une évaluation',
      v_name || ' vous invite à la campagne « ' || left(c.title, 80) || ' ». Vous restez libre de la passer ou non ; aucun résultat n''est partagé sans votre accord.',
      jsonb_build_object('campaign', c.id));
  end if;
  return 'invited';
end $$;

create or replace function assessment_campaign_close(p_campaign uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c assessment_campaigns;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from assessment_campaigns where id = p_campaign;
  if c.id is null or not _assessment_org_can(c.org_id, true) then raise exception 'Campagne introuvable'; end if;
  perform _assessment_org_owner(c.org_id, true);
  update assessment_campaigns set status = 'close' where id = c.id;
end $$;

-- Résultats partagés par les candidats avec cette campagne (accord explicite) : propriétaire et administrateurs de l'organisation seulement.
create or replace function assessment_campaign_results(p_campaign uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c assessment_campaigns;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from assessment_campaigns where id = p_campaign;
  if c.id is null or not _assessment_org_can(c.org_id, true) then raise exception 'Campagne introuvable'; end if;
  perform _assessment_org_owner(c.org_id, true);
  return jsonb_build_object(
    'campaign', jsonb_build_object('id', c.id, 'title', c.title, 'status', c.status, 'family_code', c.family_code, 'mode', c.mode),
    'invited', (select count(*)::int from assessment_campaign_invites i where i.campaign_id = c.id),
    'results', coalesce((select jsonb_agg(jsonb_build_object(
        'request_id', q.id, 'reused', q.reuse_of is not null, 'candidate', display_name(q.candidate_id), 'result_id', r.id,
        'competences', r.competences, 'criteria', r.criteria, 'evidence', r.evidence, 'limits', r.limits, 'recommendations', r.recommendations,
        'validation_status', r.validation_status, 'created_at', r.created_at) order by r.created_at desc)
      from assessment_requests q join assessment_results r on r.request_id = coalesce(q.reuse_of, q.id)
      where q.campaign_id = c.id and q.share_with_org and q.status <> 'annulee' and (q.reuse_of is null or q.reuse_consent)), '[]'::jsonb));
end $$;

-- ============================================================ 2. Candidat : invitations et partage
create or replace function assessment_my_invitations() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'campaign_id', c.id, 'title', c.title, 'family_code', c.family_code, 'family_label', f.label, 'mode', c.mode, 'status', c.status, 'invited_at', i.created_at,
      'organization', coalesce((select company_name from company_profiles where owner_id = c.org_id), (select name from profiles where id = c.org_id), 'Une organisation'),
      'requested', exists (select 1 from assessment_requests q where q.campaign_id = c.id and q.candidate_id = auth.uid() and q.status <> 'annulee')) order by i.created_at desc)
    from assessment_campaign_invites i join assessment_campaigns c on c.id = i.campaign_id join assessment_families f on f.code = c.family_code
    where i.candidate_id = auth.uid()), '[]'::jsonb);
end $$;

-- Le candidat accepte ou retire le partage du résultat d'une demande de campagne avec l'organisation (une réutilisation se révoque avec assessment_reuse_revoke).
create or replace function assessment_share_set(p_request uuid, p_share boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare q assessment_requests;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') = '' then raise exception 'Compte suspendu'; end if;
  select * into q from assessment_requests where id = p_request and candidate_id = auth.uid() for update;
  if q.id is null or q.campaign_id is null or q.reuse_of is not null then raise exception 'Demande de campagne introuvable'; end if;
  if q.status = 'annulee' then raise exception 'Cette demande est annulée'; end if;
  update assessment_requests set share_with_org = coalesce(p_share, false), updated_at = now() where id = q.id;
  return jsonb_build_object('ok', true, 'share_with_org', coalesce(p_share, false));
end $$;

-- ============================================================ 3. Réutilisation avec accord du candidat
create or replace function assessment_reuse_options(p_campaign uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c assessment_campaigns; v_days integer := _assessment_reuse_days();
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from assessment_campaigns where id = p_campaign and _assessment_invited(id);
  if c.id is null then raise exception 'Campagne introuvable'; end if;
  if v_days is null then
    return jsonb_build_object('available', false, 'reuse_days', null, 'options', '[]'::jsonb,
      'message', 'La réutilisation d''une évaluation récente n''est pas disponible : sa durée de validité n''a pas encore été décidée.');
  end if;
  return jsonb_build_object('available', c.status = 'ouverte', 'reuse_days', v_days,
    'options', coalesce((select jsonb_agg(jsonb_build_object('result_id', r.id, 'request_id', q.id, 'created_at', r.created_at, 'validation_status', r.validation_status) order by r.created_at desc)
      from assessment_results r join assessment_requests q on q.id = r.request_id
      where r.candidate_id = auth.uid() and q.status = 'terminee' and q.reuse_of is null and q.family_code = c.family_code and q.mode = c.mode
        and r.created_at >= now() - make_interval(days => v_days)
        and not exists (select 1 from assessment_requests x where x.reuse_of = q.id and x.campaign_id = c.id and x.status <> 'annulee')), '[]'::jsonb),
    'message', case when c.status = 'ouverte' then 'Vous pouvez partager une évaluation récente avec cette campagne, avec votre accord, sans en repasser une.'
                    else 'Cette campagne n''est pas encore ouverte.' end);
end $$;

create or replace function assessment_reuse_grant(p_result uuid, p_campaign uuid, p_consent boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_days integer := _assessment_reuse_days(); r assessment_results; q assessment_requests; c assessment_campaigns; v_id uuid;
begin
  if v_uid is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('student', 'client') then raise exception 'Accès refusé : les évaluations sont réservées aux candidats (étudiants et clients).'; end if;
  if coalesce(p_consent, false) is not true then
    return jsonb_build_object('ok', false, 'code', 'consent_required', 'message', 'Votre accord explicite est nécessaire pour partager une évaluation existante.');
  end if;
  if v_days is null then
    return jsonb_build_object('ok', false, 'code', 'reuse_unavailable', 'message', 'La réutilisation d''une évaluation récente n''est pas disponible : sa durée de validité n''a pas encore été décidée.');
  end if;
  select * into r from assessment_results where id = p_result and candidate_id = v_uid;
  if r.id is null then raise exception 'Résultat introuvable'; end if;
  select * into q from assessment_requests where id = r.request_id;
  select * into c from assessment_campaigns where id = p_campaign and status = 'ouverte' and _assessment_invited(id);
  if c.id is null then return jsonb_build_object('ok', false, 'code', 'campaign_invalid', 'message', 'Aucune campagne ouverte ne vous invite.'); end if;
  if q.status <> 'terminee' or q.family_code <> c.family_code or q.mode <> c.mode then
    return jsonb_build_object('ok', false, 'code', 'mismatch', 'message', 'Cette évaluation ne correspond pas à la famille et au mode de la campagne.');
  end if;
  if r.created_at < now() - make_interval(days => v_days) then
    return jsonb_build_object('ok', false, 'code', 'too_old', 'message', 'Cette évaluation est trop ancienne pour être réutilisée.', 'reuse_days', v_days);
  end if;
  if exists (select 1 from assessment_requests x where x.reuse_of = q.id and x.campaign_id = c.id and x.status <> 'annulee') then
    return jsonb_build_object('ok', false, 'code', 'already_shared', 'message', 'Cette évaluation est déjà partagée avec cette campagne.');
  end if;
  insert into assessment_requests (candidate_id, family_code, mode, provider_code, status, funding, campaign_id, consent, share_with_org, reuse_of, reuse_consent, status_note, accepted_at)
  values (v_uid, q.family_code, q.mode, q.provider_code, 'terminee', 'financee_organisation', c.id, true, true, q.id, true, 'Évaluation existante partagée avec l''accord du candidat', null)
  returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

create or replace function assessment_reuse_revoke(p_request uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare q assessment_requests;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into q from assessment_requests where id = p_request and candidate_id = auth.uid() and reuse_of is not null for update;
  if q.id is null then raise exception 'Partage introuvable'; end if;
  update assessment_requests set share_with_org = false, reuse_consent = false, status = 'annulee', status_note = 'Partage retiré par le candidat', updated_at = now() where id = q.id;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function assessment_campaign_create(text, text, text, uuid), assessment_campaigns_list(uuid), assessment_campaign_invite(uuid, text), assessment_campaign_close(uuid),
  assessment_campaign_results(uuid), assessment_my_invitations(), assessment_share_set(uuid, boolean), assessment_reuse_options(uuid), assessment_reuse_grant(uuid, uuid, boolean),
  assessment_reuse_revoke(uuid) from public, anon;
grant execute on function assessment_campaign_create(text, text, text, uuid), assessment_campaigns_list(uuid), assessment_campaign_invite(uuid, text), assessment_campaign_close(uuid),
  assessment_campaign_results(uuid), assessment_my_invitations(), assessment_share_set(uuid, boolean), assessment_reuse_options(uuid), assessment_reuse_grant(uuid, uuid, boolean),
  assessment_reuse_revoke(uuid) to authenticated;
