# Campagnes sponsorisées

État : **cycle de vie et règles budgétaires implémentés en logique pure et testés** (`Campaign`, `indicateurs` dans `lib/core/domain/abonnements_campagnes.dart`), **non branchés**. Aucune table, aucun écran, aucun paiement.

## Ce qui existe déjà et ne doit pas être confondu

`post_boosts` = visibilité **gratuite** (série de 6 jours), jamais convertible en argent. L'action « Propulser » payante est indiquée « indisponible » (migration reels). La campagne payante est un autre objet : elle **réfère** à un `post` ou à un `listing` existant, elle ne crée pas de second catalogue.

## Cycle (testé)

brouillon → attente de validation → approuvée → active ↔ suspendue → terminée ; refusée → brouillon. Toute autre transition lève une erreur. La soumission exige un budget total positif, un budget quotidien positif et inférieur ou égal au total, une fin postérieure au début. Passer à « active » exige **paiement validé par le serveur et confirmation du propriétaire**.

## Budget

La dépense est refusée au-delà du budget total ou du budget du jour ; atteindre le budget termine la campagne. Aucun débit sans paiement validé.

## Indicateurs

Impressions, clics, taux de clic, coût par clic : calculés seulement depuis des compteurs réels ; `null` si le dénominateur est nul. Portée, interactions, conversions : à définir avec le serveur (comptage dédoublonné) ; aucune statistique n'est inventée.

## Modération et transparence

Validation avant diffusion (qui valide et sous quel délai : décision à prendre). Tout contenu diffusé est marqué « Sponsorisé » ; aucune visibilité trompeuse.

## À construire

`campaigns`, `campaign_daily_spend`, `campaign_events` (impressions, clics dédoublonnés), liaison avec `payment_transactions` (type `campagne`), écrans de création et de suivi (rattachés aux écrans de promotion existants à identifier dans l'inventaire), insertion des contenus sponsorisés dans le fil.
