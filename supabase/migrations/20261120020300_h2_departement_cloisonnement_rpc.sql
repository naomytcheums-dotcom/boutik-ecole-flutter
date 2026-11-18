-- Lot H2 « Département » (4/6) : cloisonnement par département de toutes les fonctions lisibles ou utilisables par le rôle `dept`.
-- Audit : chaque fonction ci-dessous autorisait le rôle dept sur TOUS les départements (annonces de concours, offres, projets, campagnes, accompagnement, vœux, mentors,
-- boutiques, annonces, réclamations, devis, retraits, missions, certificats, QR, modération du réseau). Chacune est modifiée SUR PLACE à partir de sa définition en vigueur
-- (garde-fous conservés : suspension, audit, quotas, libellés du lot H1) avec UN contrôle de plus : le rôle dept ne voit/modifie que les éléments dont le propriétaire est dans SON département
-- (_dept_sees / _dept_visible / _dept_sees_opp / _can_review_project), l'administrateur et le support gardent leur périmètre, la direction garde sa lecture.
-- Ce qui n'a pas de département (offre sans cible, annonce d'un organisme extérieur, boutique d'un compte sans département) n'est décidé que par l'administration.
-- Retour arrière : recréer chaque fonction depuis la migration indiquée dans le commentaire qui la précède (ou : select _h2_patch_fn(nom, '', array[nouveau, ancien]) avec les motifs inversés) ; drop function _listing_staff_ok(uuid), _dept_account_covers(uuid, uuid),
--   _claim_dept_sees(uuid), _order_dept_sees(uuid), _mission_dept_sees(uuid), _can_review_project(uuid).

-- Modification sur place : la définition EN VIGUEUR (après toutes les migrations précédentes, dont les libellés et fusions de rôles du lot H1) est relue,
-- les motifs sont remplacés (première occurrence), puis la fonction est recréée à l'identique ailleurs : privilèges, 2FA, audit et quotas restent ceux de la fonction.
create or replace function _h2_patch_fn(p_name text, p_sig text, p_pairs text[]) returns integer
language plpgsql set search_path = public as $$
declare r record; v_def text; v_new text; i integer; pos integer; n integer := 0; v_done integer := 0;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name and p.prokind = 'f'
             and (p_sig = '' or pg_get_function_identity_arguments(p.oid) ilike '%' || p_sig || '%') loop
    v_def := replace(pg_get_functiondef(r.oid), E'\r\n', E'\n');
    if position(p_pairs[1] in v_def) = 0 then
      if position(p_pairs[2] in v_def) > 0 then v_done := v_done + 1; end if;   -- déjà modifiée : rien à faire
      continue;
    end if;
    v_new := v_def;
    i := 1;
    while i < array_length(p_pairs, 1) loop
      pos := position(p_pairs[i] in v_new);
      if pos = 0 then raise exception 'H2 : motif absent dans % (%)', p_name, left(p_pairs[i], 80); end if;
      v_new := overlay(v_new placing p_pairs[i + 1] from pos for char_length(p_pairs[i]));
      i := i + 2;
    end loop;
    execute v_new;
    n := n + 1;
  end loop;
  if n = 0 and v_done = 0 then raise exception 'H2 : fonction ou motif introuvable : %', p_name; end if;
  return n;
end $$;
create or replace function _dept_account_covers(p_account uuid, p_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from department_accounts da join profiles t on t.id = p_owner where da.user_id = p_account and t.department_id is not null and da.department_id = t.department_id)
$$;

create or replace function _listing_staff_ok(p_seller uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(p_seller))
$$;

-- Destinataires des validations d'un porteur : l'administration et les comptes Département de SON département (jamais un libellé libre).
create or replace function _owner_reviewers(p_owner uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from profiles where role::text = 'admin' and not coalesce(suspended, false)
  union
  select a.user_id from department_accounts a join profiles x on x.id = a.user_id join profiles t on t.id = p_owner
  where x.role::text = 'dept' and not coalesce(x.suspended, false) and t.department_id is not null and a.department_id = t.department_id
$$;
revoke all on function _owner_reviewers(uuid) from public, anon, authenticated;
create or replace function _claim_dept_sees(p_claim uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from claims c where c.id = p_claim and (_dept_sees(c.seller_id) or exists (select 1 from claim_sellers s where s.claim_id = c.id and _dept_sees(s.seller_id))))
$$;

create or replace function _order_dept_sees(p_order uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = p_order and _dept_sees(l.seller_id))
$$;

-- Besoin client : un responsable le voit s'il est ouvert (publié, déjà visible des étudiants) ou si un étudiant de son département y est engagé.
create or replace function _mission_dept_sees(p_mission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from missions m where m.id = p_mission
    and (m.status = 'published' or exists (select 1 from mission_proposals p where p.mission_id = m.id and _dept_sees(p.author_id))))
$$;

revoke all on function _dept_account_covers(uuid, uuid), _listing_staff_ok(uuid), _claim_dept_sees(uuid), _order_dept_sees(uuid), _mission_dept_sees(uuid) from public, anon, authenticated;
grant execute on function _dept_account_covers(uuid, uuid), _listing_staff_ok(uuid), _claim_dept_sees(uuid), _order_dept_sees(uuid), _mission_dept_sees(uuid) to anon, authenticated;

-- Aides des politiques RLS (lignes liées à un propriétaire par une autre table).
create or replace function _listing_dept_sees(p_listing uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from listings l where l.id = p_listing and _dept_sees(l.seller_id))
$$;
create or replace function _post_dept_sees(p_post uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from posts p where p.id = p_post and _dept_sees(p.author_id))
$$;
create or replace function _shop_dept_sees(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from shops s where s.id = p_shop and _dept_sees(s.owner_id))
$$;
create or replace function _dept_sees_mission_provider(p_mission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from mission_proposals p where p.mission_id = p_mission and p.status = 'accepted' and _dept_sees(p.author_id))
$$;

-- Concours : un responsable gère les concours créés par son département ; l'administrateur gère tout.
create or replace function _contest_staff_for(p_contest uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (coalesce(current_role_name()::text, '') = 'admin'
    or (coalesce(current_role_name()::text, '') = 'dept' and exists (select 1 from contests c where c.id = p_contest and c.created_by is not null and _dept_sees(c.created_by))))
$$;
create or replace function _contest_staff_for_team(p_team uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from contest_teams t where t.id = p_team and _contest_staff_for(t.contest_id))
$$;
create or replace function _contest_staff_for_submission(p_submission uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from contest_submissions s where s.id = p_submission and _contest_staff_for_team(s.team_id))
$$;

revoke all on function _listing_dept_sees(uuid), _post_dept_sees(uuid), _shop_dept_sees(uuid), _dept_sees_mission_provider(uuid),
  _contest_staff_for(uuid), _contest_staff_for_team(uuid), _contest_staff_for_submission(uuid) from public, anon, authenticated;
grant execute on function _listing_dept_sees(uuid), _post_dept_sees(uuid), _shop_dept_sees(uuid), _dept_sees_mission_provider(uuid),
  _contest_staff_for(uuid), _contest_staff_for_team(uuid), _contest_staff_for_submission(uuid) to anon, authenticated;


-- ann_decide(p_id uuid, p_approve boolean, p_verified boolean default false, p_note) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001400_annonces_concours.sql)
select _h2_patch_fn('ann_decide', '', array[
  $h2$if not found then raise exception 'Annonce introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Annonce introuvable'; end if;
  if not _dept_visible(a.poster_id) then raise exception 'Cette annonce ne relève pas de votre département : seule l''administration peut la décider'; end if;$h2$
]);

-- ann_close(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001400_annonces_concours.sql)
select _h2_patch_fn('ann_close', '', array[
  $h2$coalesce(current_role_name()::text, '') in ('admin', 'dept'));$h2$,
  $h2$coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(poster_id));$h2$
]);

-- ann_detail(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114004100_correctifs_profil_visiteur.sql)
select _h2_patch_fn('ann_detail', '', array[
  $h2$v_staff boolean := coalesce(current_role_name()::text, '') in ('admin', 'dept'); v_n integer;$h2$,
  $h2$v_staff boolean := false; v_n integer;$h2$,
  $h2$select * into a from contest_announcements where id = p_id;$h2$,
  $h2$select * into a from contest_announcements where id = p_id;
  v_staff := coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(a.poster_id);$h2$
]);

-- ann_my_posted() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001400_annonces_concours.sql)
select _h2_patch_fn('ann_my_posted', '', array[
  $h2$(v_staff and a.status = 'pending')$h2$,
  $h2$(v_staff and a.status = 'pending' and _dept_visible(a.poster_id))$h2$
]);

-- ann_win_decide(p_id uuid, p_approve boolean) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001400_annonces_concours.sql)
select _h2_patch_fn('ann_win_decide', '', array[
  $h2$if not found then raise exception 'Déclaration introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Déclaration introuvable'; end if;
  if not _dept_visible(w.student_id) then raise exception 'Cette déclaration relève d''un autre département'; end if;$h2$
]);

-- ann_wins_list(p_limit integer default 10, p_pending boolean default false) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001400_annonces_concours.sql)
select _h2_patch_fn('ann_wins_list', '', array[
  $h2$where status = case when coalesce(p_pending, false) then 'pending' else 'published' end order by created_at desc$h2$,
  $h2$where status = case when coalesce(p_pending, false) then 'pending' else 'published' end and (not coalesce(p_pending, false) or _dept_visible(student_id)) order by created_at desc$h2$
]);

-- opp_decide(p_id uuid, p_approve boolean, p_verified boolean default false, p_note) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001300_opportunites.sql)
select _h2_patch_fn('opp_decide', '', array[
  $h2$if not found then raise exception 'Offre introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Offre introuvable'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and not _dept_sees_opp(o.department_target, o.poster_id) then raise exception 'Cette offre ne cible pas votre département : seule l''administration peut la décider'; end if;$h2$
]);

-- opp_close(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001300_opportunites.sql)
select _h2_patch_fn('opp_close', '', array[
  $h2$coalesce(current_role_name()::text, '') in ('admin', 'dept'));$h2$,
  $h2$coalesce(current_role_name()::text, '') = 'admin' or _dept_sees_opp(department_target, poster_id));$h2$
]);

-- opp_detail(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261118010400_f1_etiquettes_besoins.sql)
select _h2_patch_fn('opp_detail', '', array[
  $h2$coalesce(current_role_name()::text, '') not in ('admin', 'dept')) then raise exception 'Offre introuvable'$h2$,
  $h2$not (coalesce(current_role_name()::text, '') = 'admin' or _dept_sees_opp(o.department_target, o.poster_id))) then raise exception 'Offre introuvable'$h2$
]);

-- opp_my_posted() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261114001300_opportunites.sql)
select _h2_patch_fn('opp_my_posted', '', array[
  $h2$(v_staff and o.status = 'pending')$h2$,
  $h2$(v_staff and o.status = 'pending' and (coalesce(current_role_name()::text, '') = 'admin' or _dept_sees_opp(o.department_target, o.poster_id)))$h2$
]);

-- opp_save(p_org text, p_kind text, p_contract text, p_title text, p_location tex) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261118010200_f1_publication.sql)
select _h2_patch_fn('opp_save', '', array[
  $h2$for r in select id from profiles where role::text in ('admin', 'dept') loop$h2$,
  $h2$for r in select id from profiles where not coalesce(suspended, false) and (role::text = 'admin' or id in (select da.user_id from department_accounts da where da.department_id in (select d.id from departments d where lower(btrim(d.name)) = lower(btrim(coalesce(p_department, ''))) union select po.department_id from profiles po where po.id = v_owner))) loop$h2$
]);

-- review_project(p_id uuid, p_approve boolean, p_note text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050200_s5_projets_equipe.sql)
select _h2_patch_fn('review_project', '', array[
  $h2$if not _can_review_dept(p.department) then$h2$,
  $h2$if not _can_review_project(p.id) then$h2$
]);

-- campaign_milestone_review(p_id uuid, p_approve boolean, p_note text default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('campaign_milestone_review', '', array[
  $h2$if not _can_review_dept(v_dept) then$h2$,
  $h2$if not _can_review_project(c.project_id) then$h2$
]);

-- review_campaign(p_id uuid, p_approve boolean, p_note text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('review_campaign', '', array[
  $h2$if not _can_review_dept(v_dept) then$h2$,
  $h2$if not _can_review_project(c.project_id) then$h2$
]);

-- campaign_milestones_to_review() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('campaign_milestones_to_review', '', array[
  $h2$_can_review_dept(p.department)$h2$,
  $h2$_can_review_project(p.id)$h2$
]);

-- support_requests_to_handle() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050500_s5_accompagnement.sql)
select _h2_patch_fn('support_requests_to_handle', '', array[
  $h2$_can_review_dept(p.department)$h2$,
  $h2$_can_review_project(p.id)$h2$
]);

-- support_request_handle(p_id uuid, p_status text, p_response text default '') : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050500_s5_accompagnement.sql)
select _h2_patch_fn('support_request_handle', '', array[
  $h2$if not _can_review_dept(p.department) then$h2$,
  $h2$if not _can_review_project(p.id) then$h2$
]);

-- campaign_backers(p_campaign uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('campaign_backers', '', array[
  $h2$(c.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'finance'))$h2$,
  $h2$(c.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance') or _dept_sees(c.owner_id))$h2$
]);

-- campaigns_overview(p_mine boolean default false, p_id uuid default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('campaigns_overview', '', array[
  $h2$c.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'finance') then$h2$,
  $h2$c.owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('admin', 'finance') or _dept_sees(c.owner_id) then$h2$
]);

-- project_files_list(p_project uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050200_s5_projets_equipe.sql)
select _h2_patch_fn('project_files_list', '', array[
  $h2$(owner_id = auth.uid() or coalesce(current_role_name()::text, '') in ('dept', 'admin'))$h2$,
  $h2$(owner_id = auth.uid() or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(owner_id))$h2$
]);

-- project_members_list(p_project uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115190000_l9_projets_innovations.sql)
select _h2_patch_fn('project_members_list', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin')) then$h2$,
  $h2$or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(p.owner_id)) then$h2$
]);

-- public_project_get(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119060100_g6_portfolio_projets_concours.sql)
select _h2_patch_fn('public_project_get', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin');$h2$,
  $h2$or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(p.owner_id);$h2$
]);

-- storage_file_allowed(p_name text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050200_s5_projets_equipe.sql)
select _h2_patch_fn('storage_file_allowed', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin')$h2$,
  $h2$or coalesce(current_role_name()::text, '') = 'admin' or exists (select 1 from profiles t where t.id::text = (storage.foldername(p_name))[1] and _dept_sees(t.id))$h2$
]);

-- wishes_to_review() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117060200_s6_voeux_precommandes.sql)
select _h2_patch_fn('wishes_to_review', '', array[
  $h2$(me.role::text = 'admin' or w.institution_id is null or me.institution_id is null or w.institution_id = me.institution_id)$h2$,
  $h2$(me.role::text = 'admin' or ((w.department_id is not null and _dept_sees_dept(w.department_id)) or (w.department_id is null and _dept_sees(w.author_id))))$h2$
]);

-- review_wish(p_id uuid, p_decision text, p_note text, p_scheduled_for text default ) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115200000_l10_voeux_precommandes.sql)
select _h2_patch_fn('review_wish', '', array[
  $h2$if me.role::text = 'dept' and w.institution_id is not null and me.institution_id is not null and w.institution_id <> me.institution_id then raise exception 'Ce vœu relève d''un autre établissement'; end if;$h2$,
  $h2$if me.role::text = 'dept' and not ((w.department_id is not null and _dept_sees_dept(w.department_id)) or (w.department_id is null and _dept_sees(w.author_id))) then raise exception 'Ce vœu relève d''un autre département'; end if;$h2$
]);

-- wish_get(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115200000_l10_voeux_precommandes.sql)
select _h2_patch_fn('wish_get', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin')) then return null;$h2$,
  $h2$or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(w.author_id)) then return null;$h2$
]);

-- wish_preorderers(p_wish uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117060200_s6_voeux_precommandes.sql)
select _h2_patch_fn('wish_preorderers', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin')) then raise$h2$,
  $h2$or coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(w.author_id)) then raise$h2$
]);

-- save_wish(p_id uuid, p_title text, p_description text, p_price integer, p_thresh) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115200000_l10_voeux_precommandes.sql)
select _h2_patch_fn('save_wish', '', array[
  $h2$    if v_to is null and me.institution_id is not null then
      select array_agg(id) into v_to from profiles where role::text = 'dept' and not coalesce(suspended, false) and institution_id = me.institution_id;
    end if;
$h2$,
  $h2$$h2$
]);

-- mentors_pending() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117080200_s8_mentors_verification.sql)
select _h2_patch_fn('mentors_pending', '', array[
  $h2$where m.status = 'pending'), '[]'::jsonb);$h2$,
  $h2$where m.status = 'pending' and (is_platform_staff() or _dept_sees(m.user_id))), '[]'::jsonb);$h2$
]);

-- mentor_validate(p_user uuid, p_approve boolean, p_note text default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117080200_s8_mentors_verification.sql)
select _h2_patch_fn('mentor_validate', '', array[
  $h2$if p_approve is null then raise exception 'Décision manquante'; end if;$h2$,
  $h2$if p_approve is null then raise exception 'Décision manquante'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and not _dept_sees(p_user) then raise exception 'Ce mentor relève d''un autre département'; end if;$h2$
]);

-- skills_radar() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261105001000_modules_restants.sql)
select _h2_patch_fn('skills_radar', '', array[
  $h2$where trim(x) <> '' group by$h2$,
  $h2$where trim(x) <> '' and _dept_visible(profiles.id) group by$h2$,
  $h2$'students', (select count(*)::int from profiles where role = 'student')$h2$,
  $h2$'students', (select count(*)::int from profiles where role = 'student' and _dept_visible(id))$h2$
]);

-- marketplace_moderation() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261107000000_marketplace.sql)
select _h2_patch_fn('marketplace_moderation', '', array[
  $h2$from shops s where s.status = 'pending'$h2$,
  $h2$from shops s where s.status = 'pending' and _dept_visible(s.owner_id)$h2$,
  $h2$from shops s where s.status in ('active', 'suspended')$h2$,
  $h2$from shops s where s.status in ('active', 'suspended') and _dept_visible(s.owner_id)$h2$,
  $h2$where r.status <> 'closed'$h2$,
  $h2$where r.status <> 'closed' and _dept_visible(s.owner_id)$h2$,
  $h2$from claims c where c.status <> 'closed'$h2$,
  $h2$from claims c where c.status <> 'closed' and (coalesce(current_role_name()::text, '') <> 'dept' or _claim_dept_sees(c.id))$h2$
]);

-- shop_decide(p_shop uuid, p_action text, p_note text default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261107000000_marketplace.sql)
select _h2_patch_fn('shop_decide', '', array[
  $h2$if not found then raise exception 'Boutique introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Boutique introuvable'; end if;
  if not _dept_visible(s.owner_id) then raise exception 'Cette boutique relève d''un autre département'; end if;$h2$
]);

-- shop_report_set_status(p_id uuid, p_status text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261107000000_marketplace.sql)
select _h2_patch_fn('shop_report_set_status', '', array[
  $h2$update shop_reports set status = p_status where id = p_id;$h2$,
  $h2$update shop_reports set status = p_status where id = p_id and (coalesce(current_role_name()::text, '') <> 'dept' or exists (select 1 from shops s where s.id = shop_reports.shop_id and _dept_sees(s.owner_id)));$h2$
]);

-- shop_public(p_slug text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261107000000_marketplace.sql)
select _h2_patch_fn('shop_public', '', array[
  $h2$and coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support')) then$h2$,
  $h2$and (coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') or not _dept_visible(s.owner_id))) then$h2$
]);

-- product_detail(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117030000_s3_annonces_boutique_stock.sql)
select _h2_patch_fn('product_detail', '', array[
  $h2$and coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support')
$h2$,
  $h2$and (coalesce(current_role_name()::text, '') not in ('admin', 'dept', 'support') or not _dept_visible(l.seller_id))
$h2$
]);

-- set_listing_showcase(p_listing uuid, p_showcase boolean) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261101000800_produits_exemple.sql)
select _h2_patch_fn('set_listing_showcase', '', array[
  $h2$update listings set showcase = p_showcase where id = p_listing;$h2$,
  $h2$update listings set showcase = p_showcase where id = p_listing and _dept_visible(seller_id);$h2$
]);

-- listing_review_queue() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119020000_g2_annonces_moderation.sql)
select _h2_patch_fn('listing_review_queue', '', array[
  $h2$and _listing_staff_scope(l.department)$h2$,
  $h2$and (coalesce(current_role_name()::text, '') = 'admin' or _dept_sees(l.seller_id))$h2$
]);

-- protect_listing_status() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119020000_g2_annonces_moderation.sql)
select _h2_patch_fn('protect_listing_status', '', array[
  $h2$if not _listing_staff_scope(old.department) then$h2$,
  $h2$if not _listing_staff_ok(old.seller_id) then$h2$,
  $h2$(p.role::text = 'dept' and lower(coalesce(p.department, '')) = lower(coalesce(new.department, '')))$h2$,
  $h2$(p.role::text = 'dept' and _dept_account_covers(p.id, new.seller_id))$h2$
]);

-- set_report_status(p_report uuid, p_status text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115140000_l4_produit_service_devis_confiance.sql)
select _h2_patch_fn('set_report_status', '', array[
  $h2$from listing_reports r join listings l on l.id = r.listing_id where r.id = p_report for update of r;$h2$,
  $h2$from listing_reports r join listings l on l.id = r.listing_id where r.id = p_report and _dept_visible(l.seller_id) for update of r;$h2$
]);

-- _notify_shop_validators(p_shop shops, p_title text, p_body text, p_dedupe boolean default fals) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117030200_s3_boutique_postmoderation.sql)
select _h2_patch_fn('_notify_shop_validators', '', array[
  $h2$where role::text in ('admin', 'dept', 'support') and not coalesce(suspended, false) limit 100$h2$,
  $h2$where (role::text in ('admin', 'support') or (role::text = 'dept' and _dept_account_covers(profiles.id, p_shop.owner_id))) and not coalesce(suspended, false) limit 100$h2$
]);

-- answer_claim(p_claim uuid, p_message text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117040200_money_reclamations.sql)
select _h2_patch_fn('answer_claim', '', array[
  $h2$elsif coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then v_role := 'staff';$h2$,
  $h2$elsif coalesce(current_role_name()::text, '') in ('admin', 'support') or (coalesce(current_role_name()::text, '') = 'dept' and _claim_dept_sees(c.id)) then v_role := 'staff';$h2$
]);

-- claim_thread(p_claim uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117040200_money_reclamations.sql)
select _h2_patch_fn('claim_thread', '', array[
  $h2$elsif coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support') then v_role := 'staff';$h2$,
  $h2$elsif coalesce(current_role_name()::text, '') in ('admin', 'support') or (coalesce(current_role_name()::text, '') = 'dept' and _claim_dept_sees(c.id)) then v_role := 'staff';$h2$
]);

-- submit_claim(p_order text, p_reason text, p_details text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117040200_money_reclamations.sql)
select _h2_patch_fn('submit_claim', '', array[
  $h2$(p.role::text = 'dept' and p.department is not null and p.department in (select sp.department from order_lines ol join listings l on l.id = ol.listing_id join profiles sp on sp.id = l.seller_id where ol.order_id = o.id and sp.department is not null))$h2$,
  $h2$(p.role::text = 'dept' and exists (select 1 from order_lines ol join listings l on l.id = ol.listing_id where ol.order_id = o.id and _dept_account_covers(p.id, l.seller_id)))$h2$
]);

-- quote_thread(p_quote uuid, p_limit integer default 200) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261118040200_f4_negociation_devis.sql)
select _h2_patch_fn('quote_thread', '', array[
  $h2$select * into q from quote_requests where id = p_quote and (requester_id = v_me or provider_id = v_me or v_staff);$h2$,
  $h2$select * into q from quote_requests where id = p_quote and (requester_id = v_me or provider_id = v_me or (v_staff and (coalesce(current_role_name()::text, '') <> 'dept' or _dept_sees(provider_id) or _dept_sees(requester_id))));$h2$
]);

-- pickups_list(p_limit int default 100) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261105001000_modules_restants.sql)
select _h2_patch_fn('pickups_list', '', array[
  $h2$from (select * from pickups order by ready_at desc limit$h2$,
  $h2$from (select * from pickups where (coalesce(current_role_name()::text, '') <> 'dept' or _order_dept_sees(order_id)) order by ready_at desc limit$h2$
]);

-- pickup_register(p_order text, p_kiosk text, p_locker text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261105001000_modules_restants.sql)
select _h2_patch_fn('pickup_register', '', array[
  $h2$if not found or not o.paid or o.cancelled_at is not null then raise exception 'Commande introuvable ou non payée'; end if;$h2$,
  $h2$if not found or not o.paid or o.cancelled_at is not null then raise exception 'Commande introuvable ou non payée'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and not _order_dept_sees(o.id) then raise exception 'Cette commande ne concerne pas votre département'; end if;$h2$
]);

-- pickup_collect(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261105001000_modules_restants.sql)
select _h2_patch_fn('pickup_collect', '', array[
  $h2$update pickups set status = 'collected', collected_at = now() where id = p_id and status = 'ready';$h2$,
  $h2$update pickups set status = 'collected', collected_at = now() where id = p_id and status = 'ready' and (coalesce(current_role_name()::text, '') <> 'dept' or _order_dept_sees(order_id));$h2$
]);

-- staff_missions() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261105000600_console_missions.sql)
select _h2_patch_fn('staff_missions', '', array[
  $h2$from missions m left join profiles c on c.id = m.client_id where m.status <> 'draft'$h2$,
  $h2$from missions m left join profiles c on c.id = m.client_id where m.status <> 'draft' and (coalesce(current_role_name()::text, '') <> 'dept' or _mission_dept_sees(m.id))$h2$
]);

-- staff_mission_proposals(p_mission uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261105000600_console_missions.sql)
select _h2_patch_fn('staff_mission_proposals', '', array[
  $h2$where p.mission_id = p_mission
$h2$,
  $h2$where p.mission_id = p_mission and (coalesce(current_role_name()::text, '') <> 'dept' or _dept_sees(p.author_id))
$h2$
]);

-- assign_mission(p_mission uuid, p_team text default null, p_proposal uuid default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117045100_missions_prestataire.sql)
select _h2_patch_fn('assign_mission', 'p_proposal', array[
  $h2$  perform _mission_accept(p.id, p_team, true);$h2$,
  $h2$  if coalesce(current_role_name()::text, '') = 'dept' and not _dept_sees(p.author_id) then raise exception 'Ce talent relève d''un autre département'; end if;
  perform _mission_accept(p.id, p_team, true);$h2$
]);

-- is_mission_participant(p_mission uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261031000100_parametres_fichiers_dossiers_cv_retrait.sql)
select _h2_patch_fn('is_mission_participant', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin');$h2$,
  $h2$or coalesce(current_role_name()::text, '') = 'admin' or (coalesce(current_role_name()::text, '') = 'dept' and _mission_dept_sees(p_mission));$h2$
]);

-- issue_certificate(p_kind text, p_subject text, p_holder_email text, p_holder_name text, ) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261031000200_correctifs_securite_audit.sql)
select _h2_patch_fn('issue_certificate', '', array[
  $h2$if coalesce(h.name, trim(coalesce(p_holder_name, ''))) = '' then raise exception 'Nom du titulaire obligatoire'; end if;$h2$,
  $h2$if coalesce(current_role_name()::text, '') = 'dept' then
    if h.id is null or not _dept_sees(h.id) then raise exception 'Le titulaire doit être un compte étudiant de votre département'; end if;
    if p_kind = 'product' and not _dept_sees(l.seller_id) then raise exception 'Ce produit relève d''un autre département'; end if;
  end if;
  if coalesce(h.name, trim(coalesce(p_holder_name, ''))) = '' then raise exception 'Nom du titulaire obligatoire'; end if;$h2$,
  $h2$nullif(left(trim(coalesce(p_department, '')), 120), ''), l.id, auth.uid(), fp);$h2$,
  $h2$case when coalesce(current_role_name()::text, '') = 'dept' then (select d.name from departments d where d.id = _dept_id()) else nullif(left(trim(coalesce(p_department, '')), 120), '') end, l.id, auth.uid(), fp);$h2$
]);

-- revoke_certificate(p_code text, p_reason text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261031000000_missions_voeux_campagnes_certificats_bornes.sql)
select _h2_patch_fn('revoke_certificate', '', array[
  $h2$where code = upper(trim(p_code)) and not revoked;$h2$,
  $h2$where code = upper(trim(p_code)) and not revoked and (coalesce(current_role_name()::text, '') = 'admin' or (holder_id is not null and _dept_sees(holder_id)) or _dept_sees_name(department));$h2$
]);

-- qr_issue(p_kind text, p_target_id text, p_label text default '', p_ttl_seconds ) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119030000_g3_commande_machine_etats.sql)
select _h2_patch_fn('qr_issue', '', array[
  $h2$if p_ttl_seconds is not null and (p_ttl_seconds < 30 or p_ttl_seconds > 86400) then raise exception 'Durée de validité invalide'; end if;$h2$,
  $h2$if coalesce(current_role_name()::text, '') = 'dept' and p_kind = 'certificate' and not exists (select 1 from certificates c where c.code = upper(p_target_id) and (_dept_sees_name(c.department) or (c.holder_id is not null and _dept_sees(c.holder_id)))) then
    raise exception 'Ce certificat relève d''un autre département';
  end if;
  if coalesce(current_role_name()::text, '') = 'dept' and p_kind = 'event' and not exists (select 1 from events e where e.id::text = p_target_id and e.created_by = auth.uid()) then
    raise exception 'Cet événement n''est pas le vôtre';
  end if;
  if p_ttl_seconds is not null and (p_ttl_seconds < 30 or p_ttl_seconds > 86400) then raise exception 'Durée de validité invalide'; end if;$h2$
]);

-- moderate_post(p_post uuid, p_publish boolean, p_note text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('moderate_post', '', array[
  $h2$if not found then raise exception 'Publication introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Publication introuvable'; end if;
  if not _dept_visible(p.author_id) then raise exception 'Cette publication relève d''un autre département'; end if;$h2$
]);

-- moderate_story(p_story uuid, p_hide boolean, p_note text default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('moderate_story', '', array[
  $h2$if not found then raise exception 'Histoire introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Histoire introuvable'; end if;
  if not _dept_visible(s.author_id) then raise exception 'Cette histoire relève d''un autre département'; end if;$h2$
]);

-- moderation_posts_list(p_status text default 'pending', p_limit integer default 50) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('moderation_posts_list', '', array[
  $h2$else p.status = 'published' and exists (select 1 from post_reports r where r.post_id = p.id and r.status = 'open') end$h2$,
  $h2$else p.status = 'published' and exists (select 1 from post_reports r where r.post_id = p.id and r.status = 'open') end and _dept_visible(p.author_id)$h2$
]);

-- moderation_stories_list(p_limit integer default 60) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('moderation_stories_list', '', array[
  $h2$from stories s where s.expires_at > now() and$h2$,
  $h2$from stories s where s.expires_at > now() and _dept_visible(s.author_id) and$h2$
]);

-- comment_reports_list(p_limit integer default 100) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115170000_l7_parrainage_social_lives_defis.sql)
select _h2_patch_fn('comment_reports_list', '', array[
  $h2$join post_comments c on c.id = x.comment_id)$h2$,
  $h2$join post_comments c on c.id = x.comment_id where _dept_visible(c.author_id))$h2$
]);

-- comment_report_close(p_id uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115170000_l7_parrainage_social_lives_defis.sql)
select _h2_patch_fn('comment_report_close', '', array[
  $h2$update comment_reports set status = 'closed' where id = p_id;$h2$,
  $h2$update comment_reports set status = 'closed' where id = p_id and (coalesce(current_role_name()::text, '') <> 'dept' or exists (select 1 from post_comments c where c.id = comment_reports.comment_id and _dept_sees(c.author_id)));$h2$
]);

-- post_reports_dismiss(p_post uuid, p_note text default null) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('post_reports_dismiss', '', array[
  $h2$if not exists (select 1 from posts where id = p_post) then$h2$,
  $h2$if not exists (select 1 from posts where id = p_post and _dept_visible(author_id)) then$h2$
]);

-- delete_post_comment(p_comment uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119060000_g6_reseau_visibilite.sql)
select _h2_patch_fn('delete_post_comment', '', array[
  $h2$update post_comments set status = 'hidden' where id = p_comment;$h2$,
  $h2$update post_comments set status = 'hidden' where id = p_comment and _dept_visible(author_id);$h2$
]);

-- hide_story(p_story uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119060000_g6_reseau_visibilite.sql)
select _h2_patch_fn('hide_story', '', array[
  $h2$update stories set status = 'hidden' where id = p_story;$h2$,
  $h2$update stories set status = 'hidden' where id = p_story and _dept_visible(author_id);$h2$
]);

-- _post_accessible(p_post uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117070000_gardes_publications_communautes.sql)
select _h2_patch_fn('_post_accessible', '', array[
  $h2$or coalesce(current_role_name()::text, '') in ('dept', 'admin', 'support')))$h2$,
  $h2$or coalesce(current_role_name()::text, '') in ('admin', 'support') or (coalesce(current_role_name()::text, '') = 'dept' and _dept_sees(p.author_id))))$h2$
]);

-- report_post(p_post uuid, p_reason text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261119060000_g6_reseau_visibilite.sql)
select _h2_patch_fn('report_post', '', array[
  $h2$where p.role::text in ('dept', 'admin', 'support') and not p.suspended$h2$,
  $h2$where (p.role::text in ('admin', 'support') or (p.role::text = 'dept' and exists (select 1 from posts q where q.id = p_post and _dept_account_covers(p.id, q.author_id)))) and not p.suspended$h2$
]);

-- report_comment(p_comment uuid, p_reason text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117070000_gardes_publications_communautes.sql)
select _h2_patch_fn('report_comment', '', array[
  $h2$where p.role::text in ('dept', 'admin', 'support') and not p.suspended$h2$,
  $h2$where (p.role::text in ('admin', 'support') or (p.role::text = 'dept' and _dept_account_covers(p.id, c.author_id))) and not p.suspended$h2$
]);

-- report_story(p_story uuid, p_reason text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('report_story', '', array[
  $h2$where p.role::text in ('dept', 'admin', 'support') and not p.suspended$h2$,
  $h2$where (p.role::text in ('admin', 'support') or (p.role::text = 'dept' and exists (select 1 from stories q where q.id = p_story and _dept_account_covers(p.id, q.author_id)))) and not p.suspended$h2$
]);

-- trg_notify_pending_post() : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117071000_moderation_reseau.sql)
select _h2_patch_fn('trg_notify_pending_post', '', array[
  $h2$where p.role::text in ('dept', 'admin', 'support') and not p.suspended$h2$,
  $h2$where (p.role::text in ('admin', 'support') or (p.role::text = 'dept' and _dept_account_covers(p.id, new.author_id))) and not p.suspended$h2$
]);

-- project_save_full(p_id uuid, p_kind text, p_title text, p_summary text, p_department tex) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050200_s5_projets_equipe.sql)
select _h2_patch_fn('project_save_full', '', array[
  $h2$from _project_reviewers(v_dept) r where r <> auth.uid();$h2$,
  $h2$from _owner_reviewers(auth.uid()) r where r <> auth.uid();$h2$
]);

-- save_project(p_id uuid, p_title text, p_summary text, p_department text, p_links js) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050200_s5_projets_equipe.sql)
select _h2_patch_fn('save_project', 'p_submit', array[
  $h2$from _project_reviewers(p.department) r where$h2$,
  $h2$from _owner_reviewers(p.owner_id) r where$h2$
]);

-- save_campaign(p_id uuid, p_kind text, p_project text, p_goal integer, p_duration_day) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('save_campaign', '', array[
  $h2$from _project_reviewers(v_dept) r where r <> auth.uid();$h2$,
  $h2$from _owner_reviewers(auth.uid()) r where r <> auth.uid();$h2$
]);

-- campaign_milestone_done(p_id uuid, p_done boolean default true, p_proof text default null, p_p) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050300_s5_campagnes_cloture.sql)
select _h2_patch_fn('campaign_milestone_done', 'p_proof', array[
  $h2$from _project_reviewers(v_dept) r where r <> auth.uid();$h2$,
  $h2$from _owner_reviewers(coalesce((select pr.owner_id from projects pr where pr.id = c.project_id), c.owner_id)) r where r <> auth.uid();$h2$
]);

-- support_request_create(p_project uuid, p_kind text, p_message text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117050500_s5_accompagnement.sql)
select _h2_patch_fn('support_request_create', '', array[
  $h2$from _project_reviewers(p.department) r where r <> auth.uid();$h2$,
  $h2$from _owner_reviewers(p.owner_id) r where r <> auth.uid();$h2$
]);

-- talents_search(p_query text default '', p_filiere text default '', p_skills text[] de) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261118010000_f1_talents_search.sql)
select _h2_patch_fn('talents_search', '', array[
  $h2$where p.role::text = 'student' and not coalesce(p.suspended, false) and nullif(trim(coalesce(p.skills, '')), '') is not null$h2$,
  $h2$where p.role::text = 'student' and not coalesce(p.suspended, false) and nullif(trim(coalesce(p.skills, '')), '') is not null and (coalesce(current_role_name()::text, '') <> 'dept' or _dept_sees(p.id))$h2$
]);

-- save_contest(p_id uuid, p_title text, p_description text, p_theme text, p_rules tex) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261117060100_s6_concours.sql)
select _h2_patch_fn('save_contest', '', array[
  $h2$if not is_contest_staff() then raise exception 'Publication réservée au département ou à l''administrateur'; end if;$h2$,
  $h2$if not is_contest_staff() then raise exception 'Publication réservée au département ou à l''administrateur'; end if;
  if coalesce(current_role_name()::text, '') = 'dept' and _dept_id() is null then raise exception 'Votre compte n''est rattaché à aucun département : contactez l''administration'; end if;$h2$,
  $h2$if not found then raise exception 'Concours introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Concours introuvable'; end if;
    if not _contest_staff_for(c.id) then raise exception 'Ce concours relève d''un autre département'; end if;$h2$
]);

-- set_contest_status(p_contest uuid, p_status text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261115200400_l10_concours_hackathons.sql)
select _h2_patch_fn('set_contest_status', 'p_status', array[
  $h2$if not found then raise exception 'Concours introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Concours introuvable'; end if;
  if not _contest_staff_for(c.id) then raise exception 'Ce concours relève d''un autre département'; end if;$h2$
]);

-- assign_contest_juror(p_contest uuid, p_email text, p_add boolean) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261101000200_concours.sql)
select _h2_patch_fn('assign_contest_juror', '', array[
  $h2$if not exists (select 1 from contests where id = p_contest and status in ('draft', 'published', 'judging')) then$h2$,
  $h2$if not exists (select 1 from contests where id = p_contest and status in ('draft', 'published', 'judging') and _contest_staff_for(id)) then$h2$
]);

-- moderate_contest_team(p_team uuid, p_hidden boolean, p_reason text) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261101000200_concours.sql)
select _h2_patch_fn('moderate_contest_team', '', array[
  $h2$if not found then raise exception 'Équipe introuvable'; end if;$h2$,
  $h2$if not found then raise exception 'Équipe introuvable'; end if;
  if not _contest_staff_for(t.contest_id) then raise exception 'Cette équipe relève d''un autre département'; end if;$h2$
]);

-- contest_ranking(p_contest uuid) : cloisonnée par département (modification sur place de la définition en vigueur, issue de 20261101000200_concours.sql)
select _h2_patch_fn('contest_ranking', '', array[
  $h2$is_contest_staff() or is_contest_juror(c.id)$h2$,
  $h2$_contest_staff_for(c.id) or is_contest_juror(c.id)$h2$
]);

drop function _h2_patch_fn(text, text, text[]);
