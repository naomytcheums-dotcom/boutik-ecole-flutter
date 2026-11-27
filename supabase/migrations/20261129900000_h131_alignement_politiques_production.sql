-- H13.1 · Alignement des politiques RLS de la PRODUCTION sur celles du dépôt.
-- Constat (comparaison pg_policies production / base reconstruite par toutes les migrations, 27/11/2026) : dix politiques existent en production sous un nom ASCII
-- (« profil cree a l inscription », « annonces approuvees visibles par tous »…) alors que les migrations les suppriment/recréent sous le nom accentué
-- (« profil créé à l'inscription »…). Conséquence : `drop policy if exists "<nom accentué>"` n'a RIEN supprimé en production. Les politiques RLS permissives s'ADDITIONNENT :
--   * listings / profiles : la politique ASCII (définition d'AVANT H1 et H2) coexiste avec la politique accentuée à jour et l'emporte : un compte Département voyait les annonces
--     non approuvées de tous les établissements (cloisonnement H2 inopérant sur cette lecture) ; l'inscription acceptait encore le rôle « other » (H1) ;
--   * kiosk_sessions : « sessions borne lisibles/créées par les connectés » (fermeture H13 20261128070100) sont restées : codes de borne lisibles par tout compte connecté ;
--   * six autres politiques ASCII n'ont pas leur homologue accentué : mêmes définitions que le dépôt, seulement le nom diffère.
-- Cette migration : (1) supprime les deux politiques de borne ; (2) pour chaque politique ASCII : si son homologue du dépôt existe déjà (listings, profiles) elle est SUPPRIMÉE
-- (doublon à l'ancienne définition), sinon elle est RENOMMÉE au nom du dépôt (définition inchangée) pour que les futures migrations la retrouvent.
-- Idempotente et sans effet sur une base où les noms ASCII n'existent pas (banc, copies). Aucune donnée touchée. Retour arrière : recréer les anciennes politiques
-- (définitions dans la sauvegarde du 27/11/2026, `prod_structure_complete_*.json`).
do $$
declare r record;
begin
  drop policy if exists "sessions borne lisibles par les connectes" on public.kiosk_sessions;
  drop policy if exists "sessions borne creees par les connectes" on public.kiosk_sessions;

  for r in
    select * from (values
      ('audit_log', 'journal lisible par l administration', 'journal lisible par l''administration'),
      ('hackathon_teams', 'equipes visibles par tous', 'équipes visibles par tous'),
      ('hackathon_teams', 'un etudiant cree son equipe', 'un étudiant crée son équipe'),
      ('listings', 'un vendeur cree ses annonces', 'un vendeur crée ses annonces'),
      ('listings', 'annonces approuvees visibles par tous', 'annonces approuvées visibles par tous'),
      ('orders', 'commandes de l acheteur ou de l administration', 'commandes de l''acheteur ou de l''administration'),
      ('profiles', 'profil cree a l inscription', 'profil créé à l''inscription'),
      ('profiles', 'profil visible par soi et l administration', 'profil visible par soi et l''administration')
    ) v(t, old_name, new_name)
  loop
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = r.t and policyname = r.old_name) then continue; end if;
    if exists (select 1 from pg_policies where schemaname = 'public' and tablename = r.t and policyname = r.new_name) then
      execute format('drop policy %I on public.%I', r.old_name, r.t);
    else
      execute format('alter policy %I on public.%I rename to %I', r.old_name, r.t, r.new_name);
    end if;
  end loop;
end $$;
