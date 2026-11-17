-- Lot F1 (2/6) — porte de publication des entreprises et organisations (E1-3, E1-4, E1-19, E1-22, E5-2, E5-8, E5-14, E5-19 en partie).
--   · colonnes de traçabilité : missions.created_by / published_at, opportunities.posted_by, contest_announcements.posted_by
--     (la publication au nom d'une entreprise par un membre de l'équipe reste attribuée à son auteur) ;
--   · _publish_check(kind, ignore, owner) : renvoie le message de refus (ou null). Rôles de publication par type, puis, pour les rôles company ET other :
--     fiche approuvée (ou compte de test) + quotas du forfait ; besoins : au plus 5 publications par 24 h (les besoins annulés comptent) et 10 brouillons ;
--   · company_gate(kind, ignore, owner) : lève le message de _publish_check (les rôles client, étudiant, département, administration restent hors porte
--     pour leurs besoins — décision 3 — mais jamais pour les offres ni les concours des organisations) ;
--   · company_publish_status(p_owner) : ce que l'appelant peut publier MAINTENANT (vérification, forfait, quotas restants, raisons), pour avertir AVANT la saisie.
-- Retour arrière : recréer company_gate(text, uuid) depuis 20261114003100 ; drop function company_publish_status(uuid), _publish_check(text, uuid, uuid), company_gate(text, uuid, uuid) ;
--   alter table missions drop column created_by, drop column published_at ; alter table opportunities drop column posted_by ; alter table contest_announcements drop column posted_by.

alter table missions add column if not exists created_by uuid references profiles(id) on delete set null;
alter table missions add column if not exists published_at timestamptz;
update missions set published_at = created_at where published_at is null and status <> 'draft';
create index if not exists missions_owner_published on missions (client_id, published_at desc);
alter table opportunities add column if not exists posted_by uuid references profiles(id) on delete set null;
alter table contest_announcements add column if not exists posted_by uuid references profiles(id) on delete set null;

create or replace function _publish_check(p_kind text, p_ignore uuid default null, p_owner uuid default null) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_actor uuid := auth.uid(); v_owner uuid := coalesce(p_owner, auth.uid()); v_role text; v_test boolean; v_status text;
        pl company_plans%rowtype; v_used integer; v_max integer; v_label text; v_next timestamptz;
begin
  if v_actor is null then return 'Connexion requise'; end if;
  select role::text, coalesce(is_test, false) into v_role, v_test from profiles where id = v_owner and not coalesce(suspended, false);
  if v_role is null or current_role_name() is null then return 'Compte suspendu : publication impossible'; end if;
  if v_owner <> v_actor then
    if v_role not in ('company', 'other') then return 'Action non autorisée'; end if;
    if company_role_of(v_owner) is distinct from 'admin' then return 'Réservé au propriétaire et aux administrateurs de l''entreprise'; end if;
  end if;
  if p_kind in ('need', 'need_edit', 'draft') then
    if v_role not in ('client', 'company', 'other', 'student', 'dept', 'admin') then return 'Action non autorisée'; end if;
  elsif p_kind = 'offer' then
    if v_role not in ('company', 'other', 'dept', 'direction', 'finance', 'support', 'admin') then return 'Réservé aux entreprises, ONG, startups et à l''équipe de l''IUT'; end if;
  elsif p_kind = 'contest' then
    if v_role not in ('admin', 'dept', 'direction', 'support', 'finance', 'company', 'other') then return 'Réservé à l''équipe, aux départements, aux entreprises et aux ONG'; end if;
  else
    return 'Type de publication inconnu';
  end if;

  if p_kind = 'draft' then
    if (select count(*) from missions where client_id = v_owner and status = 'draft' and id is distinct from p_ignore) >= 10 then
      return 'Dix brouillons au plus : annulez un brouillon (« Mes besoins ») ou publiez-le avant d''en créer un autre.';
    end if;
    return null;
  end if;

  if v_role in ('company', 'other') and not v_test then
    select status into v_status from company_profiles where owner_id = v_owner;
    if v_status is distinct from 'approved' then
      return case when v_role = 'other' then 'Votre organisation' else 'Votre entreprise' end
        || ' doit être vérifiée par l''administrateur avant de publier : complétez votre fiche entreprise et envoyez vos pièces justificatives.';
    end if;
    select * into pl from company_current_plan(v_owner);
    if p_kind in ('need', 'need_edit') then
      select count(*) into v_used from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress') and (p_ignore is null or id <> p_ignore);
      v_max := pl.max_needs; v_label := 'besoins';
    elsif p_kind = 'offer' then
      select count(*) into v_used from opportunities where poster_id = v_owner and status in ('pending', 'published') and (p_ignore is null or id <> p_ignore);
      v_max := pl.max_offers; v_label := 'offres';
    else
      select count(*) into v_used from contest_announcements where poster_id = v_owner and status in ('pending', 'published') and (p_ignore is null or id <> p_ignore);
      v_max := pl.max_contests; v_label := 'concours';
    end if;
    if v_used >= v_max then
      return format('Votre forfait « %s » est atteint : %s %s actifs sur %s. Clôturez une publication active ou passez à un forfait supérieur.', pl.name, v_used, v_label, v_max);
    end if;
  end if;

  if p_kind = 'need' and v_role not in ('dept', 'admin') and not v_test then
    select published_at into v_next from missions where client_id = v_owner and published_at > now() - interval '24 hours' and id is distinct from p_ignore
      order by published_at desc offset 4 limit 1;
    if v_next is not null then
      return 'Limite atteinte : 5 besoins publiés par jour (les besoins annulés comptent). Prochaine publication possible vers '
        || to_char((v_next at time zone 'UTC') + interval '25 hours', 'DD/MM "à" HH24"h"MI') || ' (heure du Cameroun).';
    end if;
  end if;
  return null;
end $$;
revoke all on function _publish_check(text, uuid, uuid) from public, anon, authenticated;

drop function if exists company_gate(text, uuid);
create or replace function company_gate(p_kind text, p_ignore uuid default null, p_owner uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_msg text := _publish_check(p_kind, p_ignore, p_owner);
begin
  if v_msg is not null then raise exception '%', v_msg; end if;
end $$;
revoke all on function company_gate(text, uuid, uuid) from public, anon, authenticated;

-- Ce que l'appelant (ou l'entreprise dont il est administrateur) peut publier maintenant. Les rôles hors organisation (client, étudiant…) n'ont ni forfait ni quota d'organisation.
create or replace function company_publish_status(p_owner uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid; v_arg uuid; v_role text; v_test boolean; v_org boolean; v_status text; pl company_plans%rowtype; v_end timestamptz;
        n_need int; n_offer int; n_contest int; n_draft int; d_used int; d_next timestamptz; r_need text; r_offer text; r_contest text; r_draft text;
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  v_owner := company_effective_owner(p_owner);
  v_arg := case when v_owner = auth.uid() then null else v_owner end;
  select role::text, coalesce(is_test, false) into v_role, v_test from profiles where id = v_owner;
  v_org := v_role in ('company', 'other');
  select status into v_status from company_profiles where owner_id = v_owner;
  if v_org then
    select * into pl from company_current_plan(v_owner);
    select max(ends_at) into v_end from company_subscriptions where owner_id = v_owner and status = 'active' and ends_at > now();
  end if;
  select count(*)::int into n_need from missions where client_id = v_owner and status in ('published', 'assigned', 'in_progress');
  select count(*)::int into n_offer from opportunities where poster_id = v_owner and status in ('pending', 'published');
  select count(*)::int into n_contest from contest_announcements where poster_id = v_owner and status in ('pending', 'published');
  select count(*)::int into n_draft from missions where client_id = v_owner and status = 'draft';
  select count(*)::int into d_used from missions where client_id = v_owner and published_at > now() - interval '24 hours';
  select published_at + interval '24 hours' into d_next from missions where client_id = v_owner and published_at > now() - interval '24 hours' order by published_at desc offset 4 limit 1;
  r_need := _publish_check('need', null, v_arg);
  r_offer := _publish_check('offer', null, v_arg);
  r_contest := _publish_check('contest', null, v_arg);
  r_draft := _publish_check('draft', null, v_arg);
  return jsonb_build_object(
    'role', v_role, 'is_org', v_org, 'verified', case when v_org then v_status = 'approved' or v_test else null end, 'company_status', v_status,
    'team_role', company_role_of(v_owner),
    'plan', case when v_org then jsonb_build_object('code', pl.code, 'name', pl.name, 'price_fcfa', pl.price_fcfa) end, 'plan_ends_at', v_end,
    'needs', jsonb_build_object('used', n_need, 'max', case when v_org then pl.max_needs end, 'remaining', case when v_org then greatest(pl.max_needs - n_need, 0) end,
                                'drafts', n_draft, 'drafts_max', 10),
    'offers', jsonb_build_object('used', n_offer, 'max', case when v_org then pl.max_offers end, 'remaining', case when v_org then greatest(pl.max_offers - n_offer, 0) end),
    'contests', jsonb_build_object('used', n_contest, 'max', case when v_org then pl.max_contests end, 'remaining', case when v_org then greatest(pl.max_contests - n_contest, 0) end),
    'daily', jsonb_build_object('used', d_used, 'max', 5, 'next_at', d_next),
    'can', jsonb_build_object('need', r_need is null, 'offer', r_offer is null, 'contest', r_contest is null, 'draft', r_draft is null),
    'reasons', jsonb_build_object('need', r_need, 'offer', r_offer, 'contest', r_contest, 'draft', r_draft),
    'can_publish', r_need is null or r_offer is null or r_contest is null);
end $$;
revoke all on function company_publish_status(uuid) from public, anon;
grant execute on function company_publish_status(uuid) to authenticated;
