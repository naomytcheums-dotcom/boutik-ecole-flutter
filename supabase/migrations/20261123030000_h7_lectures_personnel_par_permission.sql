-- Lot ORG (H7) : lectures directes du personnel sur des données personnelles, ramenées aux permissions de l'équipe concernée.
-- Constat (scénario supabase/tests/marketplace_pglite/h7_cloisonnement.mjs) : is_platform_staff() (support, sécurité OU maintenance technique) ouvrait la lecture directe de
-- pièces justificatives (documents d'identité et leur stockage privé), de leur historique, des demandes d'aide, des demandes de suppression de compte, des conditions acceptées,
-- des inscriptions aux événements et des sponsors à TOUT agent ayant une seule de ces permissions. Un agent « Technique » (tech.maintenance, tech.logs) lisait ainsi les pièces
-- d'identité de tous les étudiants et organisations ; un agent « demandes d'aide » aussi.
-- Correctif : (1) la maintenance technique n'est plus « équipe de la plateforme » au sens de is_platform_staff() (ses accès aux bornes passent par des permissions explicites) ;
-- (2) chaque lecture sensible exige LA permission qui la justifie (catalogue admin_permissions) : l'administrateur global garde tout, le propriétaire garde ses lignes.
--   pièces et historique des pièces, stockage « profile-documents » : support.requests, security.accounts
--   demandes d'aide : support.tickets ; suppressions de compte et conditions acceptées : support.requests, security.accounts
--   inscriptions aux événements : support.tickets, support.orders ; sponsors et contributions : finance.read
-- Retour arrière : recréer ces politiques depuis 20261104000100 / 20261105000000 / 20261105000100 / 20261115160000 / 20261117010100 / 20261119010000 / 20261115110000 (avec is_platform_staff()),
--   et is_platform_staff() depuis 20261120040000 (liste avec 'tech.maintenance').

create or replace function is_platform_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select _admin_perm_check(auth.uid(), array['support.tickets', 'support.claims', 'support.disputes', 'support.orders', 'support.requests', 'support.refunds',
                                             'security.moderation', 'security.reports', 'security.accounts'])
$$;

do $$
declare
  r record;
  v_docs text := '_staff_perm(array[''support.requests'', ''security.accounts''])';
  v_tickets text := '_staff_perm(array[''support.tickets''])';
begin
  -- pièces justificatives
  for r in select * from (values
    ('public', 'user_documents', 'documents : propriétaire ou équipe', '(owner_id = auth.uid()) or ' || v_docs),
    ('public', 'user_document_history', 'historique documents : propriétaire ou équipe', v_docs || ' or (exists (select 1 from user_documents d where d.id = user_document_history.document_id and d.owner_id = auth.uid()))'),
    ('storage', 'objects', 'documents profil : lecture', '(bucket_id = ''profile-documents'' and (((storage.foldername(name))[1] = (auth.uid())::text) or ' || v_docs || '))'),
    ('public', 'support_tickets', 'demandes d''aide : les miennes et le support', '(user_id = auth.uid()) or ' || v_tickets),
    ('public', 'account_deletion_requests', 'suppression de compte : titulaire et administration', '(user_id = auth.uid()) or ' || v_docs),
    ('public', 'terms_acceptances', 'conditions acceptées : titulaire et équipe', '(user_id = auth.uid()) or ' || v_docs),
    ('public', 'event_registrations', 'inscriptions : les miennes ou l''équipe', '(user_id = auth.uid()) or _staff_perm(array[''support.tickets'', ''support.orders''])'),
    ('public', 'sponsors', 'sponsors : propriétaire ou gestion', '(owner_id = auth.uid()) or _staff_perm(array[''finance.read'']) or _sponsor_dept_sees(id)')
  ) as t(sch, tbl, pol, expr) loop
    if exists (select 1 from pg_policies where schemaname = r.sch and tablename = r.tbl and policyname = r.pol) then
      execute format('alter policy %I on %I.%I using (%s)', r.pol, r.sch, r.tbl, r.expr);
    else
      raise notice 'H7 : politique absente (%.% : %), non modifiée', r.sch, r.tbl, r.pol;
    end if;
  end loop;
end $$;

-- Contributions : propriétaire du sponsor, département concerné, finance ou administration.
do $$
begin
  if exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'sponsorships' and policyname = 'contributions : propriétaire du sponsor ou gestion') then
    alter policy "contributions : propriétaire du sponsor ou gestion" on public.sponsorships
      using (_staff_perm(array['finance.read']) or _dept_sees_name(department) or (exists (select 1 from sponsors s where s.id = sponsorships.sponsor_id and s.owner_id = auth.uid())));
  else
    raise notice 'H7 : politique des contributions absente, non modifiée';
  end if;
end $$;
