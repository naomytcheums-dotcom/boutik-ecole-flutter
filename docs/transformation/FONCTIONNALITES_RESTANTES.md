# Fonctionnalités restantes et état par domaine (03/11/2026, fin du lot 1)

Légende : **non implémenté** · **conception** (document seulement) · **logique pure testée, non branchée** · **partiel** · **corrigé et testé** (tests automatisés ; **non vérifié dans un navigateur** dans ce lot).

| Domaine | État | Détail |
|---|---|---|
| D-011 montants 42 / 43 | corrigé et testé | `coherence_commande_test.dart` NR-001 à NR-003, NR-006 |
| D-082 / D-083 détail, suivi et annulation de commande | corrigé et testé (partiel) | 46 et 47 liés à la commande, chronologie partagée, redirection sans commande ; **09 et 29 non revus** : leurs textes d'étapes (« Confirmée », « En préparation », « Livrée » dans la maquette) n'ont pas été contrôlés écran par écran |
| D-005 onglet Messages | corrigé et testé | 93 fichiers + générateur ; test NR-022 sur l'accueil seulement |
| D-024 erreur visiteur | corrigé et testé | message nettoyé ; invite à se connecter (`requireLogin`, existant) ; test sur la fonction de nettoyage ; **le clic réel n'est pas testé** |
| D-042 Talents coupé | **non revérifié** | la composition plein écran des téléphones (déjà présente) le traite probablement ; à confirmer dans un navigateur à 360, 375, 390, 430 |
| D-084 contrastes | non implémenté | demande la régénération de 315 rendus de référence |
| D-085 clavier | non implémenté | |
| D-086, D-087 | non implémenté / en attente de décision | |
| D-038 parcours par rôle | non implémenté | règle à décider |
| Profils dynamiques (avatars, couverture, visibilité) | non implémenté | `profileAccountProvider` et un avatar de démonstration conditionné à `demoContent` existent ; audit des avatars de maquette non fait |
| Publications, commentaires, partages, enregistrements | non implémenté | voir IMPLEMENTATION_RESEAU_SOCIAL.md |
| Abonnements sociaux (listes, suggestions) | non implémenté | `follow` existe dans `engagements` |
| Messagerie : blocage, signalement, accusés | non implémenté | |
| Communautés | conception | |
| Offres premium | logique pure testée, non branchée | |
| Campagnes sponsorisées | logique pure testée, non branchée | |
| Moteur de recommandation | logique pure testée, non branchée | |
| Tara Money / Dikalo | bloqué | documentation officielle introuvable |
| Multi-prestataires de paiement | conception | |
| Notifications : générateurs d'événements, push, e-mail, SMS | non implémenté | architecture de canaux locale, aucun envoi réel |
| Responsive tablette et ordinateur | non implémenté | voir RESPONSIVE_PWA.md |
| PWA | partiel | manifeste et service worker présents ; `orientation` à lever ; rien vérifié |
| 315 écrans : état par écran | non fait | la matrice du dossier de lancement (`00_INVENTAIRE_ECRANS_315.md`) reste la référence : 23 connectés et testés, 37 partiels, 126 non vérifiés, 116 à données fictives, 5 non fonctionnels, 8 bloqués. Ce lot ne l'a pas mise à jour. |

## Ce qui bloque

Base de test isolée et autorisation d'écrire des migrations non appliquées ; décisions de la phase 7 (Q-01 à Q-12) ; documentation officielle de Tara Money ; disque libre de 3 à 4 Go (aucune compilation web ou Android).

## Prochains lots proposés (dans l'ordre)

1. Terminer la chaîne de commande : 09 et 29, puis régénérer les rendus de référence de 42, 43, 46, 47.
2. Écrans de profil : supprimer les avatars de maquette et brancher les données du compte (audit des 315 écrans pour les images de maquette).
3. Migration `posts` étendue + commentaires + abonnés, testée sur réplique locale (sans appliquer).
4. Fil classé branché sur `FeedRanker` pour l'écran 245.
5. Communautés, puis plans et abonnements, puis campagnes, chacun avec ses tests de permissions.
