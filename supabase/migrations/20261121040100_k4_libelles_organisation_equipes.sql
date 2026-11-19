-- Lot K4 (Partenariats et Organisation) 2/2 — libellés : dernières occurrences de l'ancienne classification dans les messages émis par le serveur.
--   « Entreprise » (acteur) devient « Organisation » ; « Finance » et « Support » ne sont plus présentés comme des acteurs autonomes mais comme des équipes de l'administration.
-- Même méthode que 20261120010400 (H1) : les fonctions dont le texte contient encore ces formulations sont recréées À L'IDENTIQUE (définition en vigueur lue dans pg_proc,
-- donc garde-fous 2FA, suspension, permissions d'équipe, cloisonnement et audit conservés ; CREATE OR REPLACE garde les privilèges) avec le seul libellé changé.
-- Conservés volontairement : « entreprise commerciale » (type d'organisation), « entreprise_commerciale » / company_* / valeurs d'enum (other, finance, support),
-- le code de forfait « entreprise », et les lignes d'audit déjà écrites (historique). Idempotente : une fonction déjà à jour est ignorée.
-- Retour arrière : recréer les fonctions concernées depuis leurs migrations d'origine (voir 20261114002900, 20261118040100, 20261118010300, 20261115210000, 20261117030100, 20261121*) ;
--   update plans set audience = 'Entreprises et partenaires' where code = 'entreprise'.

do $$
declare r record; v_def text; v_new text; n integer := 0;
begin
  for r in
    select p.oid, p.proname from pg_proc p join pg_language l on l.oid = p.prolang
    where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and l.lanname in ('plpgsql', 'sql')
      and (p.prosrc ilike '%entreprise%' or p.prosrc ilike '%Réservé à la finance%' or p.prosrc ilike '%Réservé au support%' or p.prosrc ilike '%réservés à la finance%'
           or p.prosrc ilike '%administration et à la finance%' or p.prosrc ilike '%Réservé au support et à la finance%')
  loop
    v_def := pg_get_functiondef(r.oid);
    v_new := v_def;
    -- le corps d'une fonction double ses apostrophes : « l'accueil » s'y écrit l''accueil, donc l''''accueil dans les littéraux ci-dessous
    v_new := replace(v_new, 'Accès refusé à cette entreprise', 'Accès refusé à cette organisation');
    v_new := replace(v_new, 'Cette entreprise n''''a pas de fiche', 'Cette organisation n''''a pas de fiche');
    v_new := replace(v_new, 'Réservé aux entreprises', 'Réservé aux organisations');
    v_new := replace(v_new, 'réservée aux entreprises vérifiées, aux organisations et au département', 'réservée aux organisations vérifiées et au département');
    v_new := replace(v_new, 'Vendeur professionnel et Entreprise', 'Vendeur professionnel et Organisation');
    v_new := replace(v_new, 'depuis l''''accueil entreprise', 'depuis l''''accueil de l''''organisation');
    v_new := replace(v_new, '''Entreprise''', '''Organisation''');
    v_new := replace(v_new, 'Les virements Mobile Money sont réservés à la finance', 'Les virements Mobile Money sont réservés à l''''équipe Finance de l''''administration');
    v_new := replace(v_new, 'Réservé au support et à la finance', 'Réservé aux équipes Support et Finance de l''''administration');
    v_new := replace(v_new, 'Réservé à l''''administration et à la finance', 'Réservé à l''''administration et à son équipe Finance');
    v_new := replace(v_new, 'Réservé au support, au département ou à l''''administration', 'Réservé à l''''équipe Support, au département ou à l''''administration');
    v_new := replace(v_new, 'Réservé au support ou à l''''administrateur', 'Réservé à l''''équipe Support ou à l''''administrateur');
    v_new := replace(v_new, 'Réservé à la finance', 'Réservé à l''''équipe Finance de l''''administration');
    if v_new is distinct from v_def then
      execute v_new;
      n := n + 1;
    end if;
  end loop;
  raise notice 'K4 libellés : % fonctions mises à jour', n;
end $$;

update plans set audience = 'Organisations et partenaires' where code = 'entreprise' and audience = 'Entreprises et partenaires';
