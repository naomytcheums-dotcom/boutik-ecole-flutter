# Lot 5 — Livraison (écrans 07, 27, 41, 46)

Date : 01/11/2026. Commits locaux **`842cd01`** (migration) et **`5b10843`** (client), non poussés. Migration locale **`20261101000300_livraison.sql`**, **non appliquée en production**. Règles : `REGLES_METIER_PROPOSEES.md` § 5.

## A. Constat initial
- La livraison à domicile était **facturée 5 000 FCFA sans adresse** : `create_order(p_home = true)` n'en demandait aucune.
- Il n'existait aucune table d'adresses. L'écran 41 affichait une adresse d'exemple pré-remplie, et son bouton passait à l'étape suivante sans rien enregistrer.

## B. Serveur
- **Réglage** `home_delivery_enabled`, **désactivé par défaut**. Seul l'administrateur l'active (`set_home_delivery`, action journalisée), avec la ville desservie (Douala) et les frais (5 000 FCFA).
- **Carnet** `addresses` : 5 adresses au plus. Lecture réservée au titulaire. Écriture par `save_address` et `delete_address` uniquement.
- **`create_order(…, p_address)`** : la livraison à domicile exige que le service soit activé, qu'une adresse du titulaire soit fournie, et que la ville soit desservie. L'adresse est figée sur la commande.
- L'ancienne signature reste valable pour le retrait sur campus. Avec `p_home = true`, elle est désormais refusée, au lieu de facturer sans adresse.
- **Circuit logistique** (rôle `support`) :
  - `start_delivery` : seulement pour une commande payée et prête ;
  - `delivery_failed` : motif obligatoire ; après 2 échecs, retour au kiosque ;
  - la remise se fait avec le code à 6 chiffres existant (31c).
- **Réplique : 22/22** (transaction annulée). Un cas réussissait d'abord pour une mauvaise raison (adresse refusée parce que le carnet était plein) ; je l'ai corrigé pour qu'il vérifie vraiment la validation.

## C. Client
| Écran | Avec le serveur |
|---|---|
| 07 | « Livraison à domicile » est refusée, avec explication, tant qu'elle n'est pas activée. Sinon, les frais du réglage s'appliquent et l'adresse est demandée. |
| 41 | La saisie est validée (erreurs sous les champs), enregistrée dans le carnet, puis retenue pour la commande. Aucune adresse d'exemple. |
| Panier et paiement | Les frais affichés valent **0** tant que la livraison à domicile n'est pas proposée |
| 27 | **Reste** : la liste affichée vient de la maquette, alors que le carnet existe côté serveur |
| 46 | **Reste** : l'état « en livraison » n'est pas encore affiché |

## D. Tests
- 4 nouveaux tests Flutter.
- **Suite complète : 457/457.**
- Golden images inchangées.

## E. Déploiement
Ordre obligatoire, après votre autorisation :
1. appliquer la migration ;
2. redéployer le site.

L'ancien client reste compatible pour le retrait sur campus.
