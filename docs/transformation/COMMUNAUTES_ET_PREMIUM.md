# Communautés et offres premium

État : **conception uniquement, plus la logique des droits premium** (`lib/core/domain/abonnements_campagnes.dart`, testée, non branchée). Aucune table, aucune migration, aucun écran de communauté ou d'abonnement n'est livré dans ce lot.

## Communautés (réutilisation, pas de second système)

Une communauté **réutilise** `profiles` (membres), `posts` (publications, via `community_id`), `notifications` et la recherche existante. Tables à créer : `communities` (nom, description, catégorie, règles, logo, couverture, `privacy`), `community_members` (rôle et statut : membre, modérateur, administrateur, propriétaire ; en attente, banni), `community_events` si les événements existants ne suffisent pas (à vérifier : les concours et événements ont déjà des tables).

Trois types : **publique** (rejoindre directement), **privée sur approbation** (demande, acceptation ou refus par un modérateur), **privée sur invitation**. Les permissions (publier, modérer, bannir, changer les rôles) sont des politiques RLS et des fonctions `security definer`, jamais seulement des boutons. Écrans existants à rattacher : section « communauté » AD et AM (116 écrans à données fictives selon l'inventaire de lancement).

## Offres premium

Plans visés : gratuit, créateur ou professionnel, vendeur professionnel, entreprise, administrateur de communauté. **Les prix ne sont pas décidés** : la table `plans` les porte (`price_fcfa` nul tant qu'il n'est pas fixé).

Modèle : `plans`, `plan_features`, `subscriptions` (statut, période, renouvellement, annulation en fin de période, historique), factures reliées à `payment_transactions`. Un droit n'est accordé que si l'abonnement est en vigueur **et** son paiement validé par le serveur (`Entitlements.allows`). Testé : sans abonnement aucun droit ; paiement non validé aucun droit ; annulé en fin de période, droits jusqu'à l'échéance ; expiré ou suspendu, aucun droit.

Fonctionnalités candidates (à confirmer, sans copier LinkedIn) : badge vérifié (déjà lié à la certification par le département : ne pas le vendre), statistiques avancées, portfolio enrichi, outils vendeur, boost de campagnes, outils de gestion de communauté. Les « visiteurs du profil » ne doivent être exposés qu'avec un consentement explicite des visiteurs.

## Décisions nécessaires

Grille des plans et des droits ; tarifs ; sort du badge vérifié ; politique de confidentialité des visiteurs de profil.
