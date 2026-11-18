-- Lot H1 (Organisation) 5/5 — libellés : « Entreprise » devient « Organisation » dans les messages et notifications du serveur.
-- Les fonctions dont le texte parle encore de « l'entreprise », « votre entreprise », « fiche entreprise » ou « Entreprise vérifiée » sont recréées à
-- l'identique avec le nouveau libellé (aucun changement de logique ni de droits : CREATE OR REPLACE conserve les privilèges). Les identifiants techniques
-- (company_*, code de forfait « entreprise ») restent. Idempotente : une fonction déjà à jour est ignorée.
-- Retour arrière : recréer les fonctions concernées depuis leurs migrations d'origine (20261114002500 à 20261119070000).

do $$
declare r record; v_def text; v_new text; n integer := 0;
begin
  for r in
    select p.oid, p.proname from pg_proc p join pg_language l on l.oid = p.prolang
    where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and l.lanname in ('plpgsql', 'sql')
      and (p.prosrc ilike '%entreprise%')
  loop
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;
    -- le texte d'une fonction double ses apostrophes : « l''entreprise » s'écrit l''''entreprise dans ces littéraux
    v_new := replace(v_new, 'l''''entreprise', 'l''''organisation');
    v_new := replace(v_new, 'Votre entreprise', 'Votre organisation');
    v_new := replace(v_new, 'votre entreprise', 'votre organisation');
    v_new := replace(v_new, 'fiche entreprise', 'fiche d''''organisation');
    v_new := replace(v_new, 'Entreprise non vérifiée', 'Organisation non vérifiée');
    v_new := replace(v_new, 'Entreprise à revérifier', 'Organisation à revérifier');
    v_new := replace(v_new, 'Entreprise à vérifier', 'Organisation à vérifier');
    v_new := replace(v_new, 'Entreprise vérifiée', 'Organisation vérifiée');
    v_new := replace(v_new, 'Entreprise déjà vérifiée', 'Organisation déjà vérifiée');
    v_new := replace(v_new, 'entreprise inconnue', 'organisation inconnue');
    v_new := replace(v_new, 'Réservé aux entreprises, ONG, startups et à l''''équipe de l''''IUT', 'Réservé aux organisations et à l''''équipe de l''''IUT');
    v_new := replace(v_new, 'aux entreprises et aux ONG', 'aux organisations');
    v_new := replace(v_new, 'aux entreprises, aux organisations,', 'aux organisations,');
    v_new := replace(v_new, 'offre Entreprise', 'offre Organisation');
    v_new := replace(v_new, 'forfait d''''entreprise', 'forfait d''''organisation');
    if v_new is distinct from v_def then
      execute v_new;
      n := n + 1;
    end if;
  end loop;
  raise notice 'H1 libellés : % fonctions mises à jour', n;
end $$;

update plans set name = 'Organisation' where code = 'entreprise' and name = 'Entreprise';
