# Reste à faire (tâches réellement non terminées ou bloquées — 2ᵉ reprise, 30/10/2026 nuit)

Ce document ne liste que ce qui n'est **pas** fait. Bilan détaillé : `REPRISE.md`. Marche à suivre du propriétaire : `INTERVENTIONS_PROPRIETAIRE.md`.

## Bloqué par une action du propriétaire (procédures prêtes et vérifiées sur base isolée)
1. **Appliquer la migration `20261031a`** (INTERVENTIONS §1) : 28 actions (missions, vœux, campagnes, projets, lives, liens, certificats, incidents et événements de bornes, motif d'annulation) attendent ces fonctions en production ; elles l'annoncent clairement d'ici là.
2. **Nettoyer les comptes de test** avec `supabase/maintenance/cleanup_test_accounts.sql` (INTERVENTIONS §2) — pas avec un `delete from auth.users`, qui échouerait.
3. **MCP** : déployer le code corrigé de `notchpay-mcp`, désactiver « Verify JWT » pour cette seule fonction, créer `MCP_ACCESS_KEY` (INTERVENTIONS §3). Production : 401 tant que ce n'est pas fait.
4. **Renouveler la clé API et le Hash Key Notch Pay** (exposés) et mettre à jour `NOTCHPAY_KEY` / `NOTCHPAY_HASH` (INTERVENTIONS §4).
5. **Webhook** : déclencher un paiement sandbox et vérifier `payment_events` (INTERVENTIONS §5). Aucun événement authentique accepté à ce jour.
6. Rejouer `devis.spec.ts` en production après approbation d'un service de test (INTERVENTIONS §6) — déjà 5/5 sur base isolée.
7. Passage en production Notch Pay et Orange Money ; réactiver « Confirm email » avec un vrai code (e-mail ou SMS) : décisions du propriétaire.

## Dépendances externes qui bloquent des actions précises (expliquées à l'utilisateur, rien n'est simulé)
Paiement du devis accepté, contribution à une campagne (84b), retrait des gains (243), séquestre du duel (219), versement des jalons (234, 285 : la validation est réelle, le versement suit l'activation des paiements), mise en avant payante (250, 250b), diffusion vidéo en direct (L1).

## À développer (16 actions « Démonstration » restantes)
- Administration : identité de l'établissement (118), modèles de notifications (265), aperçu des pages éditoriales (264), clés d'intégration (280), invitation d'un membre (286) — tables et règles de gestion à définir.
- Téléversements : médiathèque (263), médias et preuves (83), fichiers de projet (279), fichiers du dossier de mission (196) — compartiment de stockage dédié, contrôles de type/taille et analyse antivirus à prévoir.
- Messagerie du dossier de mission (196 « Envoyer ») ; vérification en 2 étapes (272, MFA TOTP de Supabase à activer puis intégrer) ; régénération du lien du CV (228) ; code de retrait (46, absent du modèle de commande) ; comparaison de candidatures (158) ; filtre « Innovations » (23) ; « Continuer » de la variante d'erreur 275.
- Tableaux de bord vendeur calculés (57, 62, 66, 67), photo de profil, certification complète (justificatifs, décision).
- Séparation des environnements de production et de démonstration (une seule base aujourd'hui ; la base isolée Docker sert aux tests).
- Navigateur : messagerie avec pièces jointes et vocaux, commande payée (sandbox), parcours validateur/administrateur en production (comptes de rôle à créer par le propriétaire, INTERVENTIONS §7), précommande, suivi et alerte de stock ; accessibilité, performance (bundle ≈ 9 Mo), builds Android et iOS.

## Écrans : 303/315 atteignables par un parcours métier
Les 12 autres apparaissent par état ou sont des variantes de maquette (détail dans `REPRISE.md` §7) : 150-2 (session expirée), 150-3 (coupure réseau), 183 (commandes hors ligne) et 182 sont affichés par l'état réel ; 150-1 (synchronisation) n'est pas affiché faute de synchronisation réelle à montrer ; 150-4, S1, A2, P4, 250B, 176, 275 sont des variantes.

## Critères de finition
Terminé lorsque : la migration `20261031a` est appliquée et vérifiée ; le MCP répond en HTTPS avec la clé ; le webhook a accepté un événement authentique ; les 16 actions restantes sont traitées ou explicitement retirées du périmètre ; les parcours du personnel sont testés en production. Ce n'est pas encore le cas.
