-- Lot H3 (Direction) : la direction est l'autorité institutionnelle de l'établissement, distincte de l'administrateur global.
-- Cette migration retire à la direction les pouvoirs techniques / d'administration qu'elle avait par héritage :
--   * lecture des réglages de la plateforme (settings_all : double authentification, restriction IP, passerelles de paiement…) ;
--   * écriture et suppression des contenus éditoriaux (cms_save, cms_delete) et lecture des contenus masqués ;
--   * modération des campagnes publicitaires (ad_campaign_review) et lecture de toutes les campagnes, abonnements et forfaits masqués ;
--   * liste complète des comptes (admin_users : e-mails, dernières connexions, état de suspension) ;
--   * journaux de paiement individuels (paiements, fils de paiement, lots de reversement, reçus d'événement) : la finance les tient ;
--   * liste des retraits en borne (pickups) ;
--   * lecture du journal d'audit (audit_log) et de TOUS les profils (profiles : e-mails, téléphones…) : c'est la gestion des comptes et la surveillance, donc l'administrateur global ;
--   * écriture des mentors et productions (le suivi reste en lecture : c'est le ressort du département).
-- La direction GARDE : identité de l'établissement, lecture des chiffres consolidés (vue d'ensemble, départements, finance consolidée
-- par _finance_read_consolidated), événements officiels, certificats, missions et compétences en lecture, et les nouvelles RPC direction_*.
-- Méthode : la DERNIÈRE définition en base fait foi ; elle est relue (pg_get_functiondef / pg_policies) puis réécrite sans le rôle
-- « direction », ce qui conserve tous les garde-fous existants (suspension, audit, quotas) et les définitions posées par d'autres lots.
-- Idempotent : rejouable sans effet (rien à retirer la seconde fois).
-- Retour arrière : réappliquer les définitions d'origine (schema.sql pour audit_log et profiles, 20261031000100, 20261105000500, 20261105000700, 20261105001000, 20261105001200,
-- 20261105000200, 20261106000000, 20261116100000) ; drop function _finance_read_consolidated().

create or replace function _h3_strip_role_in_fn(p_name text, p_role text default 'direction') returns int
language plpgsql set search_path = public as $$
declare r record; v_def text; v_new text; v_n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = p_name and p.prokind = 'f' loop
    v_def := pg_get_functiondef(r.oid);
    v_new := regexp_replace(v_def, ',\s*''' || p_role || '''(?![A-Za-z_])', '', 'g');
    v_new := regexp_replace(v_new, '''' || p_role || '''\s*,\s*', '', 'g');
    if v_new <> v_def then execute v_new; v_n := v_n + 1; end if;
  end loop;
  return v_n;
end $$;

create or replace function _h3_replace_in_fn(p_name text, p_from text, p_to text) returns int
language plpgsql set search_path = public as $$
declare r record; v_def text; v_new text; v_n int := 0;
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = p_name and p.prokind = 'f' loop
    v_def := pg_get_functiondef(r.oid);
    v_new := replace(v_def, p_from, p_to);
    if v_new <> v_def then execute v_new; v_n := v_n + 1; end if;
  end loop;
  return v_n;
end $$;

create or replace function _h3_strip_role_in_policies(p_tables text[], p_role text default 'direction') returns int
language plpgsql set search_path = public as $$
declare r record; v_q text; v_w text; v_n int := 0; v_sql text;
begin
  for r in select * from pg_policies
           where schemaname = 'public' and tablename = any (p_tables)
             and (coalesce(qual, '') like '%''' || p_role || '''%' or coalesce(with_check, '') like '%''' || p_role || '''%') loop
    v_q := r.qual; v_w := r.with_check;
    if v_q is not null then
      v_q := regexp_replace(v_q, ',\s*''' || p_role || '''::\w+', '', 'g');
      v_q := regexp_replace(v_q, '''' || p_role || '''::\w+\s*,\s*', '', 'g');
    end if;
    if v_w is not null then
      v_w := regexp_replace(v_w, ',\s*''' || p_role || '''::\w+', '', 'g');
      v_w := regexp_replace(v_w, '''' || p_role || '''::\w+\s*,\s*', '', 'g');
    end if;
    v_sql := format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    if v_q is not null then v_sql := v_sql || ' using (' || v_q || ')'; end if;
    if v_w is not null then v_sql := v_sql || ' with check (' || v_w || ')'; end if;
    execute v_sql;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ============================================================ 1. Finance : lecture consolidée seulement pour la direction
-- La finance, l'administration et le support gardent _finance_read (paiements, journal, versements). La direction passe par
-- _finance_read_consolidated, appelée uniquement par les deux fonctions de chiffres agrégés (vue d'ensemble et par département).
create or replace function _finance_read_consolidated() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  if coalesce(current_role_name()::text, '') not in ('finance', 'admin', 'direction', 'support') then raise exception 'Action non autorisée'; end if;
end $$;
revoke all on function _finance_read_consolidated() from public, anon, authenticated;

do $$
begin
  if to_regprocedure('_finance_read()') is not null then
    perform _h3_replace_in_fn('finance_overview', 'perform _finance_read();', 'perform _finance_read_consolidated();');
    perform _h3_replace_in_fn('finance_by_department', 'perform _finance_read();', 'perform _finance_read_consolidated();');
    perform _h3_strip_role_in_fn('_finance_read');
  end if;
end $$;

-- ============================================================ 2. Fonctions techniques / d'administration
do $$
declare f text;
begin
  foreach f in array array['settings_all', 'cms_save', 'cms_delete', 'ad_campaign_review', 'pickups_list', 'admin_users', 'payment_thread'] loop
    perform _h3_strip_role_in_fn(f);
  end loop;
  -- Mentors et productions : écriture réservée au département et à l'administration ; la direction suit en lecture.
  perform _h3_replace_in_fn('_staff_check', 'p_write and r not in (''admin'', ''direction'', ''dept'')', 'p_write and r not in (''admin'', ''dept'')');
end $$;

-- ============================================================ 3. Politiques de lecture
do $$
begin
  perform _h3_strip_role_in_policies(array['plans', 'subscriptions', 'ad_campaigns', 'payout_batches', 'payment_transactions', 'payment_messages', 'event_receipts', 'cms_items', 'pickups', 'audit_log', 'profiles']);
  if exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'payout_batches' and policyname = 'lots : finance, administrateur, direction ou bénéficiaire') then
    alter policy "lots : finance, administrateur, direction ou bénéficiaire" on payout_batches rename to "lots : finance, administrateur ou bénéficiaire";
  end if;
end $$;

drop function if exists _h3_strip_role_in_fn(text, text);
drop function if exists _h3_replace_in_fn(text, text, text);
drop function if exists _h3_strip_role_in_policies(text[], text);
