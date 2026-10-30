-- Nettoyage contrôlé des comptes de test « zz-test-…@example.com » (créés par les tests REST et navigateur).
-- À exécuter par le propriétaire de la base (éditeur SQL Supabase, rôle postgres). Jamais par l'application.
--
-- Pourquoi pas « delete from auth.users where … » : listings, orders, missions, certificats, journaux de bornes et plusieurs
-- colonnes « reviewed_by / decided_by » référencent les profils SANS cascade ; la suppression directe échoue (ou laisserait
-- des données orphelines si l'on forçait). L'ordre ci-dessous respecte ces dépendances.
--
-- Sécurité :
--  * le domaine example.com est réservé (RFC 2606) : aucune vraie adresse ne peut y appartenir ;
--  * le script S'ARRÊTE (exception, tout est annulé) si une donnée d'un compte réel dépend d'un compte de test
--    (ex. commande d'un vrai client contenant une annonce de test) — à examiner au cas par cas ;
--  * tout se passe dans une transaction terminée par ROLLBACK : relire les totaux, puis relancer en remplaçant
--    la dernière ligne par COMMIT ;
--  * les fichiers du stockage (photos d'annonces, pièces jointes) ne sont pas supprimés par SQL : voir la fin du fichier.
--  * Les tables de la migration 20261031a sont traitées seulement si elles existent (le script marche avant et après).

-- ======================================================== 1. INVENTAIRE (lecture seule ; à exécuter seul d'abord)
select u.id, u.email, u.created_at, p.role, p.name
from auth.users u left join public.profiles p on p.id = u.id
where u.email like 'zz-test-%@example.com'
order by u.created_at;

-- ======================================================== 2. SUPPRESSION EN TRANSACTION
begin;

create temporary table zz on commit drop as
  select id from auth.users where email ~ '^zz-test-[a-z0-9-]+@example\.com$';
create temporary table zz_listings on commit drop as select id from public.listings where seller_id in (select id from zz);
create temporary table zz_orders on commit drop as select id from public.orders where buyer_id in (select id from zz);
create temporary table zz_avant on commit drop as select
  (select count(*) from auth.users where id not in (select id from zz)) as comptes_reels,
  (select count(*) from public.listings where id not in (select id from zz_listings)) as annonces_reelles,
  (select count(*) from public.orders where id not in (select id from zz_orders)) as commandes_reelles,
  (select count(*) from zz) as comptes_test;

do $$
declare n integer;
begin
  -- garde-fous : aucune donnée d'un compte réel ne doit dépendre d'un compte de test
  select count(*) into n from public.order_lines ol where ol.listing_id in (select id from zz_listings) and ol.order_id not in (select id from zz_orders);
  if n > 0 then raise exception 'ARRÊT : % ligne(s) de commande de comptes réels portent sur des annonces de test', n; end if;
  if to_regclass('public.certificates') is not null then
    execute 'select count(*) from public.certificates where issued_by in (select id from zz) and (holder_id is null or holder_id not in (select id from zz))' into n;
    if n > 0 then raise exception 'ARRÊT : % certificat(s) d''un titulaire hors test émis par un compte de test', n; end if;
  end if;

  -- références sans cascade : auteur d'une décision effacé, données propres aux comptes de test supprimées
  update public.listings set reviewed_by = null where reviewed_by in (select id from zz);
  update public.profiles set certification_decided_by = null where certification_decided_by in (select id from zz);
  if to_regclass('public.wishes') is not null then
    execute 'update public.missions set assigned_by = null where assigned_by in (select id from zz)';
    execute 'update public.wishes set reviewed_by = null where reviewed_by in (select id from zz)';
    execute 'update public.campaigns set reviewed_by = null where reviewed_by in (select id from zz)';
    execute 'delete from public.certificates where issued_by in (select id from zz)';
    execute 'delete from public.kiosk_incidents where reported_by in (select id from zz)';
    execute 'delete from public.kiosk_events where created_by in (select id from zz)';
  end if;
  delete from public.hackathon_teams where owner_id in (select id from zz);
  delete from public.missions where client_id in (select id from zz);            -- propositions et jalons en cascade
  delete from public.orders where id in (select id from zz_orders);              -- lignes, avis, réclamations, motifs en cascade
  delete from public.kiosk_sessions where listing_id in (select id from zz_listings);
  delete from public.listings where id in (select id from zz_listings);          -- historique, stock, avis, signalements, devis en cascade
  delete from auth.users where id in (select id from zz);                        -- profils, favoris, messages, notifications… en cascade

  -- contrôle : les données des comptes réels sont intactes
  if (select comptes_reels from zz_avant) <> (select count(*) from auth.users)
     or (select annonces_reelles from zz_avant) <> (select count(*) from public.listings)
     or (select commandes_reelles from zz_avant) <> (select count(*) from public.orders) then
    raise exception 'ARRÊT : des données hors test auraient été modifiées';
  end if;
  raise notice 'Comptes de test supprimés : %. Comptes réels : % (inchangé), annonces : % (inchangé), commandes : % (inchangé).',
    (select comptes_test from zz_avant), (select comptes_reels from zz_avant), (select annonces_reelles from zz_avant), (select commandes_reelles from zz_avant);
end $$;

select (select comptes_test from zz_avant) as comptes_test_supprimes, (select count(*) from auth.users where email like 'zz-test-%@example.com') as comptes_test_restants,
       (select comptes_reels from zz_avant) as comptes_reels_avant, (select count(*) from auth.users) as comptes_reels_apres;

-- Relire le résultat ci-dessus (comptes_test_restants = 0, comptes réels avant = après), puis remplacer ROLLBACK par COMMIT.
rollback;

-- ======================================================== 3. FICHIERS DU STOCKAGE (après le COMMIT)
-- Les objets des buckets « listing-images » et « chat-files » des comptes supprimés n'ont plus de propriétaire :
-- select bucket_id, name, created_at from storage.objects where owner is null order by created_at desc;
-- à retirer depuis le tableau de bord (Storage) ou l'API Storage (la suppression SQL ne retire pas le fichier physique).
