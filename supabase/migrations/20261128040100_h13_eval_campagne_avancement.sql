-- H13 · Évaluations : avancement d'une campagne pour l'organisation (comptes SEULEMENT, jamais de nom ni de contenu) et état du fournisseur de la campagne.
--  assessment_campaign_progress(p_campaign) : mêmes droits que assessment_campaign_results (propriétaire et administrateurs de l'organisation) ;
--  ne compte que les demandes que le candidat a accepté de partager avec l'organisation (share_with_org), réparties en « en attente », « en cours », « terminées », « en erreur » ;
--  « provider_ready » : un fournisseur actif, configuré et couvrant la famille et le mode de la campagne existe (booléen, aucun secret).
-- Aucune donnée insérée. Additive et rejouable. Retour arrière : drop function assessment_campaign_progress(uuid).

create or replace function assessment_campaign_progress(p_campaign uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare c assessment_campaigns;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  select * into c from assessment_campaigns where id = p_campaign;
  if c.id is null or not _assessment_org_can(c.org_id, true) then raise exception 'Campagne introuvable'; end if;
  perform _assessment_org_owner(c.org_id, true);
  return jsonb_build_object(
    'campaign_id', c.id, 'status', c.status,
    'invited', (select count(*)::int from assessment_campaign_invites i where i.campaign_id = c.id),
    'waiting', (select count(*)::int from assessment_requests q where q.campaign_id = c.id and q.share_with_org and q.reuse_of is null and q.status = 'envoyee'),
    'running', (select count(*)::int from assessment_requests q where q.campaign_id = c.id and q.share_with_org and q.reuse_of is null and q.status in ('acceptee', 'en_cours')),
    'done', (select count(*)::int from assessment_requests q where q.campaign_id = c.id and q.share_with_org and q.reuse_of is null and q.status = 'terminee'),
    'error', (select count(*)::int from assessment_requests q where q.campaign_id = c.id and q.share_with_org and q.reuse_of is null and q.status in ('refusee', 'echouee')),
    'reused', (select count(*)::int from assessment_requests q where q.campaign_id = c.id and q.share_with_org and q.reuse_of is not null and q.reuse_consent and q.status <> 'annulee'),
    'provider_ready', exists (select 1 from assessment_providers p join assessment_provider_health h on h.provider_code = p.code
                              where p.status = 'actif' and h.configured and h.checked_at > now() - interval '3 hours'
                                and c.family_code = any (p.family_codes) and c.mode = any (p.modes)));
end $$;
revoke all on function assessment_campaign_progress(uuid) from public, anon;
grant execute on function assessment_campaign_progress(uuid) to authenticated;
