-- Lot K1 (4/4) : isolation entre équipes internes (suite de H4). Il restait des LECTURES ouvertes à tout compte de rôle « support » (ou finance) sans permission :
-- politiques de lecture directe (profils, demandes de certification, rattachements de réclamation, engagements, annonces, boutiques, publications, commentaires,
-- compétences, devis, lignes de commande, motifs d'annulation, retraits en borne) et fonctions de lecture (accès à une publication, fiche d'organisation vue par le personnel,
-- fil d'un devis, liste des réussites, classe « personnel » de la recherche de talents). Un agent sans permission n'a donc plus accès à ces données.
-- Méthode : chaque politique / fonction est relue depuis sa DERNIÈRE définition et seul le test de rôle « admin / support / finance » est remplacé par
-- has_any_admin_permission(<permissions de l'équipe concernée>) : l'administrateur global garde tout, les rôles département / direction et les branches « propriétaire »,
-- « acheteur » ou « public » sont conservés. Idempotent.
-- Retour arrière : réappliquer les politiques / fonctions d'origine (migrations d'origine citées par pg_policies / les en-têtes des fonctions) ; drop function _staff_perm(text[]).

-- Les politiques de lecture sont évaluées aussi pour l'anonyme (annonces, boutiques, publications publiques) : le test de permission passe donc par un point d'entrée
-- exécutable par anon et authenticated ; sans session (auth.uid() nul) il renvoie faux, sinon il applique la même règle que has_any_admin_permission.
create or replace function _staff_perm(p_perms text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select _admin_perm_check(auth.uid(), p_perms)
$$;
revoke all on function _staff_perm(text[]) from public;
grant execute on function _staff_perm(text[]) to anon, authenticated;

create or replace function _k1_patch_policies(p_table text, p_perms text[]) returns integer
language plpgsql set search_path = public as $$
declare
  r record; v_new text; n integer := 0;
  v_has text := '_staff_perm(array[' || (select string_agg('''' || x || '''', ', ') from unnest(p_perms) x) || '])';
  c_re constant text := '(?:COALESCE\(\(current_role_name\(\)\)::text, ''''::text\)|current_role_name\(\))\s*=\s*ANY\s*\(ARRAY\[(?:''(?:admin|support|finance)''::(?:text|app_role)(?:,\s*)?)+\]\)';
begin
  for r in select policyname, qual from pg_policies where schemaname = 'public' and tablename = p_table and qual is not null loop
    v_new := regexp_replace(r.qual, c_re, v_has, 'g');
    if v_new <> r.qual then
      execute format('alter policy %I on public.%I using (%s)', r.policyname, p_table, v_new);
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

create or replace function _k1_patch_fn(p_name text, p_perms text[], p_custom text[] default '{}') returns integer
language plpgsql set search_path = public as $$
declare
  r record; v_def text; v_new text; n integer := 0; i integer;
  v_has text := '_staff_perm(array[' || (select string_agg('''' || x || '''', ', ') from unnest(p_perms) x) || '])';
  c_re constant text := 'coalesce\(current_role_name\(\)::text,\s*''''\)\s+in\s*\(\s*''admin''\s*,\s*''support''\s*\)';
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name and p.prokind = 'f' loop
    v_def := pg_get_functiondef(r.oid);
    v_new := regexp_replace(v_def, c_re, v_has, 'g');
    if cardinality(p_custom) >= 2 then
      for i in 1..cardinality(p_custom) / 2 loop
        v_new := replace(v_new, p_custom[2 * i - 1], replace(p_custom[2 * i], '{HAS}', v_has));
      end loop;
    end if;
    if v_new <> v_def then execute v_new; n := n + 1; end if;
  end loop;
  return n;
end $$;

do $$
begin
  perform _k1_patch_policies('profiles', array['support.requests', 'support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'security.accounts', 'security.moderation', 'security.reports']);
  perform _k1_patch_policies('certification_requests', array['support.requests']);
  perform _k1_patch_policies('claim_sellers', array['support.claims']);
  perform _k1_patch_policies('engagements', array['security.moderation', 'security.reports']);
  perform _k1_patch_policies('listings', array['security.moderation', 'security.reports']);
  perform _k1_patch_policies('shops', array['security.moderation', 'security.reports']);
  perform _k1_patch_policies('posts', array['security.moderation', 'security.reports']);
  perform _k1_patch_policies('post_comments', array['security.moderation', 'security.reports']);
  perform _k1_patch_policies('talent_skills', array['support.requests', 'security.moderation']);
  perform _k1_patch_policies('quote_requests', array['support.disputes', 'support.claims']);
  perform _k1_patch_policies('quote_messages', array['support.disputes', 'support.claims']);
  perform _k1_patch_policies('order_lines', array['finance.read', 'finance.payments', 'finance.refunds', 'finance.payouts', 'support.orders', 'support.claims', 'support.disputes', 'support.refunds', 'support.tickets']);
  perform _k1_patch_policies('order_cancellations', array['finance.read', 'finance.refunds', 'support.orders', 'support.claims', 'support.refunds']);
  perform _k1_patch_policies('pickups', array['support.orders']);

  perform _k1_patch_fn('_post_accessible', array['security.moderation', 'security.reports']);
  perform _k1_patch_fn('_company_page', array['support.requests']);
  perform _k1_patch_fn('quote_thread', array['support.disputes', 'support.claims']);
  perform _k1_patch_fn('victories_list', array['security.moderation']);
  perform _k1_patch_fn('_viewer_class', array['support.requests'], array[
    'if v_role in (''dept'', ''direction'', ''admin'', ''support'') then return ''staff''; end if;',
    'if v_role in (''dept'', ''direction'', ''admin'') or (v_role = ''support'' and _staff_perm(array[''support.requests'', ''security.accounts'', ''security.moderation''])) then return ''staff''; end if;']);
end $$;

drop function if exists _k1_patch_policies(text, text[]);
drop function if exists _k1_patch_fn(text, text[], text[]);
