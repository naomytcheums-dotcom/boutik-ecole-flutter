# Reste à faire (3ᵉ reprise, 31/10/2026 matin)

Bilan et preuves : `REPRISE.md`. Marche à suivre : `INTERVENTIONS_PROPRIETAIRE.md`.

## Code : rien d'ouvert
0 action « Démonstration » ; 303/315 écrans par parcours métier, 12 par état ou variante ; 403 tests Flutter ; 51/51 navigateur sur base isolée ; 27/27 navigateur en production.

## Bloqué par le propriétaire (le code est prêt, testé sur base isolée)
1. **Appliquer `20261031a` puis `20261031b` sur le projet `zxqcnmgwhtbxkdpjqtlr`** — constat du 31/10 : aucune des deux n'y est présente. Tant que ce n'est pas fait, 40 actions (28 + 12) affichent « fonction pas encore activée » en production.
2. Après application : relancer `production.spec.ts` (s'ignore), puis `lots.spec.ts` et `lots2.spec.ts` en production avec des comptes de personnel créés par le propriétaire (INTERVENTIONS §7) — ces deux specs refusent aujourd'hui toute base non locale ; une variante production est à écrire une fois les comptes de recette fournis.
3. MCP : vérifier l'appel authentifié (§9) ; redéployer `notchpay-mcp` si la clé dans l'URL est encore acceptée.
4. Webhook : renouveler les clés et déclencher un paiement sandbox (§4–5).
5. Nettoyage des comptes de test avec `cleanup_test_accounts.sql`.
6. Décisions : Notch Pay et Orange Money en production, « Confirm email » avec un vrai code.

## Hors périmètre fonctionnel actuel (à décider)
Paiements réels des jalons, du duel, des campagnes et de la mise en avant ; diffusion vidéo en direct ; antivirus des fichiers (aujourd'hui : liste blanche de types, tailles plafonnées, exécutables refusés) ; tableaux de bord vendeur calculés ; séparation des environnements ; builds Android et iOS.