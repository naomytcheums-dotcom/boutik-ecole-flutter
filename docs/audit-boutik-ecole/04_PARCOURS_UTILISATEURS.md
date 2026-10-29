# 04 — Parcours utilisateurs de bout en bout

Aucun parcours n'a été exécuté contre les données de production (règle de l'audit). Les parcours ci-dessous sont reconstitués d'après le code et les tests automatisés ; le « premier point de rupture » est le premier endroit où l'enchaînement cesse d'être réel (persistance serveur, autre utilisateur, ou réseau).

## A. Parcours client
Accueil (03) → recherche (19) → fiche produit (05) → panier (06) → livraison (07) → paiement (08) → attente (257) → reçu (259) → facture (260) → commandes (45) → suivi (09).
- **Préconditions** : compte connecté (`Backend.ready` et session Supabase requises pour payer).
- **Vérifié (T)** : `purchase_flow_test.dart` et le parcours de démonstration (24 écrans) enchaînent ces écrans en mémoire.
- **Premier point de rupture** : le catalogue est local (aucune annonce serveur) ; le prix vient du client (AN-003). Le paiement réel est NON VÉRIFIABLE (clé absente, AN-014). Le stock n'est pas décrémenté (AN-008).
- **Autres écrans touchés** : mes commandes, tableaux de bord vendeur/admin lisent des états différents qui ne se synchronisent pas entre appareils.
- **Test de non-régression proposé** : créer une commande avec un faux montant (doit être refusée), payer avec les numéros de test Notch Pay, vérifier `orders.paid`, stock −1, reçu avec le bon montant.

## B. Parcours vendeur
Compte étudiant → espace vendeur (57–69) → création d'annonce → envoi en validation → décision du département (110) → publication → stock → commandes reçues (63).
- **Vérifié (T)** : `seller_test.dart`, `review_finance_test.dart` en mémoire.
- **Premier point de rupture** : l'annonce créée n'est écrite nulle part sur le serveur ; un autre utilisateur ne la voit jamais (AN-007). La validation par le département est locale.
- **Test proposé** : créer une annonce avec le compte A, la valider avec le compte département B sur un autre navigateur, vérifier la visibilité côté client C.

## C. Parcours de gestion (département, direction, finance, support, admin)
Connexion du responsable → file « à valider » (110) → décision → mise à jour de statut → visibilité pour les intéressés.
- **Premier point de rupture** : états locaux ; l'administrateur ne voit que ce qui a été fait dans sa propre session (AN-012, AN-013).

## D. Cohérence achat / vente
Produit commandé ↔ vendeur ↔ quantités ↔ montants ↔ commande ↔ tableaux de bord : **non cohérents** car aucun lien serveur ne relie la commande d'un client aux « commandes reçues » du vendeur (états distincts : `ordersProvider` côté client, `sellerOrdersProvider` côté vendeur, `seller.dart:119`).

## E. Autres parcours
- **Missions** (191–201) : brief → devis → séquestre par jalons → preuve → libération : enchaînement cohérent en mémoire (T), aucun argent réel, pas de persistance.
- **Hackathons** (160–169) : équipe → règlement → dépôt → jury : en mémoire (T).
- **Borne** (206–210) : QR de 5 minutes à usage unique, vérifié en mémoire seulement (T, AN-023).
- **Messagerie / Kéla** : texte vérifié localement (N) ; photo/fichier/vocal/voix non vérifiés.
- **Démarrage** : splash → bienvenue → connexion → accueil : codé et testé par le parcours automatique (compte administrateur injecté) ; non rejoué manuellement après la dernière correction.

## Ruptures transversales
1. **Aucune synchronisation entre utilisateurs** (cause racine : absence de source de vérité serveur, voir 05).
2. **222 écrans sans lien entrant** : de nombreux écrans ne sont atteignables que par l'adresse (AN-015).
3. **Succès affiché sans confirmation serveur** (AN-010).
