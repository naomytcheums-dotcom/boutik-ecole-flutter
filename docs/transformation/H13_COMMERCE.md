# H13 · Commerce : variantes complètes, panier multi-boutiques, suivi des commandes

Migrations (additives, rejouables, à appliquer en production seulement après validation) :
- `20261128030000_h13_commerce_variantes_prix.sql` : prix propre OPTIONNEL et image par variante (`variant_upsert`, `variant_details_save`), `marketplace_checkout` qui lit le prix de la variante (le client n'envoie jamais de prix), `promo_preview` alignée, `cart_check` (contrôle ligne par ligne sans écriture, avec la boutique), double envoi simultané de la même clé d'idempotence = commande déjà créée rejouée.
- `20261128030100_h13_commerce_etats_suivi.sql` : `order_events` (historique horodaté par déclencheurs), matrice d'états unique (`_order_state`, `_order_state_seller`, `_order_payment`), `order_tracking(p_number)` (acheteur : toutes les boutiques ; vendeur : la sienne ; administrateur : tout), `admin_orders` alignée.

Flutter : `lib/figma/live/order_tracking.dart` (liste et détail `/commandes/suivi`, `/commandes/suivi/:number`, entrée « Suivi détaillé de mes commandes » du menu compte, lien « Historique et suivi » côté vendeur), `commerce_logic.dart` (`cartIssuesMessage`), `marche/variant_stock.dart` (prix, image, réservé), `marche_screens.dart` (prix de la variante choisie), `Backend.createOrder` (`cart_check` avant la commande).

## Décisions de conception (aucune règle financière décidée)
- Un panier multi-boutiques = **une commande, un paiement**, lignes par boutique, séquestre et répartition par vendeur inchangés (`money_order_paid`) ; l'acheteur voit l'état par boutique, le vendeur seulement ses lignes. Modèle « plusieurs boutiques par compte » (A-002) : hors lot, décision propriétaire.
- Le prix d'une variante est un choix du vendeur dans les bornes déjà en vigueur pour une annonce (500 à 100 000 000 FCFA) ; sans prix propre, prix de l'annonce. Aucune commission, aucun barème, aucun prix imposé par la plateforme.
- Une ligne à prix propre n'est pas soumise à la vente flash de l'annonce.
- Réservation temporaire du stock = stock décrémenté à la commande impayée, restitué une seule fois à l'annulation, à l'expiration (règle existante de `expire_unpaid_orders` : 2 h, 48 h si une demande de paiement est ouverte) ou au remboursement complet.
- Reçu de paiement : justificatif non fiscal, jamais présenté comme facture.

## Décision du propriétaire en attente : remboursement partiel
Comportement actuel, inchangé et testé : un remboursement **complet** retire l'accès aux ressources numériques de la commande et restitue le stock ; un remboursement **partiel** conserve l'accès, laisse la commande ouverte (paiement « payée, remboursée en partie ») et n'agit pas sur le stock (`_order_refund_partial_apply` ne le touche pas ; lecture du code, non couvert par un test dédié). Ce choix n'a pas été décidé par le propriétaire (décision 6 de `H8_DECISIONS_PROPRIETAIRE_SEPAREES.md` : « intégral sans retenue » seulement). À trancher : l'accès numérique après un remboursement partiel (conservé / retiré au-delà d'un seuil / décision au cas par cas), la restitution partielle du stock, le délai maximal de demande. Tant que non décidé, aucun changement.

## Preuves locales
Voir `H9_MATRICE_A_COMMERCE_FINANCE_CONFIANCE.md` (A-018, A-050, A-051, A-109, A-653) : `h13_commerce.mjs` 145 OK / 0 ECHEC ; `h12_stock_concurrence.mjs` sur PostgreSQL réel 30 OK / 0 ECHEC ; `h13_commerce_test.dart`.
