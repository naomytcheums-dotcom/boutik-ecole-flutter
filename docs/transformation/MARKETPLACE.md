# Marketplace multi-boutiques (migration 20261107000000)

Étend l'existant (profils, annonces `listings`, commandes, avis, réclamations, notifications, messagerie, paiement Tara Money / Notch Pay) sans second système.
Une boutique (`shops`) appartient à un profil ; ses annonces portent `listings.shop_id` (rattachement automatique à la création). Les annonces sans boutique
(plateforme, vendeurs historiques) continuent de fonctionner comme avant.

## Écrans (routes hors manifeste Figma, mobile d'abord)

| Route | Contenu |
|---|---|
| `/marche` | recherche, filtres prix/catégorie/lieu, tris (popularité, nouveautés, prix, notes), produits tendance, onglet Boutiques, comparaison |
| `/marche/boutique/:slug` | vitrine type Alibaba : bannière, carrousel de ventes flash, campagnes, packs, produits, livraison/conditions/réseaux, avis ; suivre ; écrire ; signaler |
| `/marche/produit/:id` | 3 photos à défilement automatique toutes les 3 s, vidéo, variantes, prix normal/promo/flash avec compte à rebours, stock, caractéristiques, alertes prix/stock, questions-réponses, avis |
| `/marche/ventes-flash` | ventes flash en cours et à venir, compte à rebours, jauge de stock |
| `/marche/panier` | panier regroupé par boutique (une commande par boutique), code promo |
| `/marche/ma-boutique` | création/personnalisation (logo, bannière, couleurs, catégories, livraison, conditions, réseaux, adresse publique unique), statut brouillon → validation → active/suspendue/fermée, suggestion Kéla (jamais publiée sans accord) |
| `/marche/vendeur` | tableau de bord (CA, commandes, vues, conversion, top produits, graphiques 7/30/90 j), commandes de la boutique, produits (médias, prix normal, variantes, caractéristiques), promotions |
| `/marche/moderation` | validation des boutiques, suspension, signalements, litiges, catégories (équipe : admin, département, support) |

Accès depuis l'existant : Explorer (04) et Vitrine (102) → Marketplace ; Tableau de bord (57) et Catalogue (61) → Ma boutique ; panier (06) → « Par boutique · code promo » ;
profil vendeur (24) → « Voir sa boutique » ; Boutique du créateur (248) → « Ma boutique marketplace ». Adresse publique : `https://boutik-ecole.vercel.app/#/marche/boutique/<adresse>`.

## Règles serveur

* Aucune écriture directe sur les tables de la marketplace (RLS + `revoke`) : tout passe par des fonctions `security definer`.
* Statut d'une boutique : seul le serveur le change (`shop_submit`, `shop_close`, `shop_decide` pour l'équipe). Les annonces d'une boutique non active disparaissent (politique restrictive sur `listings`).
* `marketplace_checkout` : prix recalculé et figé dans `order_lines.unit_price`, stock décrémenté atomiquement, stock flash réservé (le reste du stock ne peut pas être vendu en dessous du réservé),
  code promo (pourcentage ou montant, par boutique ou plateforme, minimum d'achat, plafond d'utilisations, une fois par client), packs au prorata, achat de son propre produit refusé,
  clé d'idempotence (même panier, même quart d'heure → même commande). L'annulation d'une commande non payée rend stock, unités flash et code promo.
* Commande multi-boutiques : un paiement, des lignes par boutique ; chaque vendeur ne voit et ne fait avancer que ses lignes (`seller_orders`, `set_seller_order_status` existants) ; `my_order_split` donne à l'acheteur la vue séparée.
* L'ancienne fonction `create_order` reste en place : le client y revient si `marketplace_checkout` n'est pas installée.

## Tests

* `flutter test -j 1 test/purchase/marketplace_test.dart` (interface : cadre de produit, défilement 3 s, vitrine, fiche, panier par boutique, tableau de bord, modération, formulaire).
* `supabase/tests/marketplace_pglite` : rejoue schéma + migrations sur Postgres embarqué (sans Docker) puis un scénario de 57 contrôles (RLS, stock, flash, promo, idempotence, annulation, modération).

## Reste à faire / limites

* Variantes : choisies à l'achat mais le stock reste global par produit (pas de stock par variante).
* Campagnes : bannière facultative non téléversée depuis l'interface ; packs ajoutés au panier par leur titre.
* Questions-réponses, avis et alertes : pas encore de modération dédiée des textes (signalement de boutique uniquement).
* Notifications push des alertes : enregistrées dans `notifications` (la distribution suit les canaux existants).
* Vidéo : lecture via `video_player` ; envoi limité à MP4/WebM de 30 Mo (compartiment `listing-videos`).
