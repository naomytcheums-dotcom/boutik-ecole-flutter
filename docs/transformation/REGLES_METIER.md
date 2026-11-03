# Règles métier appliquées et propositions (lot 1)

Légende : **appliquée** = implémentée et testée dans ce lot ; **proposée** = argumentée, à valider par une personne ; **existante** = déjà dans le code ou les migrations.

## Commande

| Règle | Statut | Argument |
|---|---|---|
| Le retrait sur campus est **gratuit** ; la livraison à domicile coûte 5 000 FCFA (réglage administrateur, désactivée par défaut) | existante (`deliveryFee`, migration 20261101000300), **appliquée** aux écrans 42 et 43 | la maquette affichait 5 000 FCFA avec retrait campus (question 13 de `docs/QUESTIONS.md`, jamais tranchée) ; les écrans 06, 07, 08 et la règle proposée du dossier de lancement disent gratuit. **À valider** par le responsable (Q-01 de la phase 7). |
| Un seul total par panier : sous-total + frais, identique de 06 à 44 | **appliquée** (42 et 43 lisent `totalsProvider` / la commande créée) | cas NR-001 à NR-006 |
| Aucune référence de commande inventée : « Attribuée à la validation » tant qu'aucune commande n'existe | **appliquée** (43) | l'ancienne référence `BE-2026-0142` était une constante de maquette |
| Un seul statut par commande, lu sur la commande : Confirmée, En préparation, Expédiée, Livrée, Annulée | **appliquée** (46, 47 ; 09 et 29 le lisaient déjà) | libellés de `statusLabel` ; la liste officielle reste à valider (Q-05) |
| Un compte connecté sans commande n'ouvre jamais le détail, le suivi ou l'annulation d'une commande d'exemple | **appliquée** (redirection vers « Mes commandes » avec message) | D-082 et D-083 |
| Le trajet Douala → Yaoundé du suivi est retiré (retrait sur campus) | **appliquée** (46) | il contredisait le point de retrait « Kiosque IUT » |

## Navigation

| L'onglet Messages ouvre la **liste des conversations (52)** ; une conversation s'ouvre depuis la liste ou depuis « Contacter le vendeur » | **appliquée** (93 écrans + générateur) | **proposée** : aucun document ne fixait la cible (Q-04). Une liste est la convention d'une messagerie ; l'ancien comportement ouvrait une conversation vide. |

## Erreurs

| Une erreur technique du serveur (permission, fonction, JWT, SQL) n'est jamais affichée ; un visiteur qui demande la certification est invité à se connecter | **appliquée** (`Backend.userMessage`, `requireLogin`) | D-024 |

## Réseau social, communautés, premium, campagnes, paiements : règles proposées (non implémentées en base)

| Règle | Statut |
|---|---|
| Visibilité d'une publication : publique, abonnés, communauté ; modération avant publication pour un compte non certifié (comme les reels) | **proposée** |
| Un abonnement (follow) est unique par couple (abonné, suivi) ; on ne se suit pas soi-même ; un blocage supprime les abonnements croisés | **proposée** (le `follow` existant est dans `engagements` avec unicité `(user_id, kind, ref)`) |
| Communautés : publique, privée sur approbation, privée sur invitation ; rôles propriétaire, administrateur, modérateur, membre ; toute permission est vérifiée côté serveur | **proposée** |
| Droits premium accordés par un abonnement **en vigueur et dont le paiement est validé**, jamais par l'affichage d'un bouton | **implémentée en logique pure** (`Entitlements`), non branchée |
| Tarifs : **aucun montant n'est fixé** ; ce sont des données modifiables | **règle** (décision du propriétaire attendue) |
| Campagne : brouillon → attente de validation → approuvée → active → suspendue → terminée, ou refusée ; jamais de diffusion ni de débit sans paiement validé par le serveur et confirmation du propriétaire ; dépense plafonnée par budget total et quotidien ; contenu toujours marqué « Sponsorisé » | **implémentée en logique pure** (`Campaign`), non branchée |
| Statistiques de campagne : uniquement à partir de compteurs réels ; `null` si le dénominateur est nul | **implémentée en logique pure** |
| Commission, reversement et remboursement : paramètres configurables, explicites | **proposée** |

## Décisions humaines nécessaires

Q-01 frais du retrait campus ; Q-02 et Q-03 parcours et vérification par rôle ; Q-04 cible de l'onglet Messages ; Q-05 liste officielle des statuts ; tarifs des offres ; commission et reversements ; modération des campagnes (qui valide, sous quel délai) ; périmètre de Tara Money.
