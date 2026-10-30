# Matrice des écrans (315)

Générée par `tool/audit/gen_matrix.py` à partir du code (analyse statique). **Aucun écran n'est déclaré « terminé et testé »** : le seul test exécuté sur chaque écran est son rendu (test golden) ; le comportement n'a pas été vérifié écran par écran dans un navigateur.

- Écrans : **315**
- Atteignables depuis le démarrage par liens contextuels explicites : **60** ; les autres sont atteignables par **« Mes rubriques »** (écran `/espace`, filtré par rôle, ouvert depuis le profil et la page de bienvenue), pas par un lien propre à leur parcours.
- Actions « Démonstration » restantes : **175** sur **122** écrans.

| Statut | Écrans |
|---|---|
| NAVIGATION SEULE | 145 |
| PARTIEL | 122 |
| IMPLÉMENTÉ MAIS NON PERSISTÉ | 42 |
| IMPLÉMENTÉ | 5 |
| STATIQUE | 1 |

| Id | Titre | Route | Rôles autorisés | Rubrique | Éléments interactifs | Démos restantes | Lien contextuel | Données | Tests | Statut |
|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Bienvenue | `/s/01` | tous | A | 1 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 02 | Bienvenue (variante) | `/s/02` | tous | A | 2 | 0 | oui | serveur (Supabase) | golden (rendu) | IMPLÉMENTÉ — serveur ; comportement non vérifié en navigateur |
| 03 | Accueil | `/s/03` | tous | A | 16 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 04 | Explorer | `/s/04` | tous | A | 11 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 05 | Fiche produit | `/s/05` | tous | A | 5 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 06 | Mon panier | `/s/06` | tous | A | 8 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 07 | Livraison | `/s/07` | tous | A | 13 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 08 | Paiement | `/s/08` | tous | A | 13 | 0 | oui | serveur (Supabase) | golden (rendu) | IMPLÉMENTÉ — serveur ; comportement non vérifié en navigateur |
| 09 | Ma commande | `/s/09` | tous | A | 11 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 10 | Profil étudiant | `/s/10` | tous | A | 18 | 0 | oui | serveur (Supabase) | golden (rendu) | IMPLÉMENTÉ — serveur ; comportement non vérifié en navigateur |
| 11 | Connexion | `/s/11` | tous | B | 7 | 1 | oui | serveur (Supabase) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 12 | Créer un compte | `/s/12` | tous | B | 10 | 0 | oui | serveur (Supabase) | golden (rendu) | IMPLÉMENTÉ — serveur ; comportement non vérifié en navigateur |
| 13 | Choix du profil | `/s/13` | tous | B | 6 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 14 | Vérification du compte | `/s/14` | tous | B | 5 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 15 | Mot de passe oublié | `/s/15` | tous | B | 4 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 16 | Nouveau mot de passe | `/s/16` | tous | B | 5 | 1 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 17 | Conditions et confidentialité | `/s/17` | tous | B | 5 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 18 | État de validation | `/s/18` | tous | B | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 18b | Compléter mon profil | `/s/18b` | tous | B | 11 | 0 | oui | serveur (Supabase) | golden (rendu) | IMPLÉMENTÉ — serveur ; comportement non vérifié en navigateur |
| 18c | Vérification étudiant | `/s/18c` | tous | B | 6 | 2 | oui | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 19 | Découvrir | `/s/19` | tous | C | 9 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 20 | Résultats de recherche | `/s/20` | tous | C | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 21 | Recherche avancée | `/s/21` | tous | C | 10 | 1 | oui | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 22 | Catalogue de produits | `/s/22` | tous | C | 21 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 22b | Services et prestations | `/s/22b` | tous | C | 9 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 22c | Tendances et nouveautés | `/s/22c` | tous | C | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 22d | Pour vous | `/s/22d` | tous | C | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 23 | Filtres | `/s/23` | tous | C | 5 | 3 | non | statique | golden (rendu) | PARTIEL (3 action(s) de démonstration) |
| 24 | Profil vendeur | `/s/24` | tous | C | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 25 | Mes favoris | `/s/25` | tous | C | 13 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 25b | Mes collections | `/s/25b` | tous | C | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 26 | Comparer des offres | `/s/26` | tous | C | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 27 | Mes adresses | `/s/27` | tous | C | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 28 | Mes commandes | `/s/28` | tous | C | 11 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 29 | Détail de la commande | `/s/29` | tous | C | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 30 | Commande reçue | `/s/30` | tous | C | 4 | 3 | non | statique | golden (rendu) | PARTIEL (3 action(s) de démonstration) |
| 31 | Avis et évaluations | `/s/31` | tous | C | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 32 | Détail du produit | `/s/32` | tous | D | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 33 | Histoire du produit | `/s/33` | tous | D | 3 | 1 | oui | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 34 | Galerie | `/s/34` | tous | D | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 35 | Disponibilité | `/s/35` | tous | D | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 36 | Détail du service | `/s/36` | tous | D | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 38 | Réputation | `/s/38` | tous | D | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 39 | Demande de renseignements | `/s/39` | tous | D | 6 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 40 | Demande de devis | `/s/40` | tous | E | 6 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 41 | Adresse de livraison | `/s/41` | tous | E | 8 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 42 | Récapitulatif | `/s/42` | tous | E | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 43 | Instructions de paiement | `/s/43` | tous | E | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 44 | Commande confirmée | `/s/44` | tous | E | 3 | 1 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 45 | Mes commandes | `/s/45` | tous | E | 14 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 46 | Suivi de livraison | `/s/46` | tous | E | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 47 | Annuler la commande | `/s/47` | tous | E | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 48 | Réclamation | `/s/48` | tous | E | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 49 | Aide et support | `/s/49` | tous | E | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 50 | Notifications | `/s/50` | tous | F | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 51 | Détail d’une notification | `/s/51` | tous | F | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 52 | Messages | `/s/52` | tous | F | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 53 | Conversation | `/s/53` | tous | F | 2 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 54 | Conversation commande | `/s/54` | tous | F | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 55 | Conversation entreprise | `/s/55` | tous | F | 5 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 56 | Notifications et confidentialité | `/s/56` | tous | F | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 57 | Tableau de bord vendeur | `/s/57` | étudiant, dépt, admin | G | 8 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 58 | Nouveau produit | `/s/58` | étudiant, dépt, admin | G | 9 | 2 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 59 | Nouveau service | `/s/59` | étudiant, dépt, admin | G | 9 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 60 | Modifier l’annonce | `/s/60` | étudiant, dépt, admin | G | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 61 | Mon catalogue | `/s/61` | étudiant, dépt, admin | G | 10 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 62 | Stocks | `/s/62` | étudiant, dépt, admin | G | 13 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 63 | Commandes reçues | `/s/63` | étudiant, dépt, admin | G | 11 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 64 | Préparer une commande | `/s/64` | étudiant, dépt, admin | G | 5 | 2 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 65 | Détail d’une vente | `/s/65` | étudiant, dépt, admin | G | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 66 | Revenus | `/s/66` | étudiant, dépt, admin | G | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 67 | Statistiques | `/s/67` | étudiant, dépt, admin | G | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 69 | Validations | `/s/69` | étudiant, dépt, admin | G | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 70 | Talents étudiants | `/s/70` | tous | H | 16 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 72 | Ajouter à mon profil | `/s/72` | tous | H | 6 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 73 | Mes documents | `/s/73` | tous | H | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 74 | Talent Passport | `/s/74` | tous | H | 4 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 75 | Opportunités | `/s/75` | tous | H | 12 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 76 | Ma candidature | `/s/76` | tous | H | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 77 | Profil de mentor | `/s/77` | tous | H | 11 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 78 | Projets innovants | `/s/78` | tous | I | 14 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 79 | Projet | `/s/79` | tous | I | 3 | 1 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 80 | Soumettre un projet | `/s/80` | tous | I | 7 | 1 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 81 | Équipe du projet | `/s/81` | tous | I | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 82 | Journal du projet | `/s/82` | tous | I | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 83 | Médias et preuves | `/s/83` | tous | I | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 84 | Nouvelle campagne | `/s/84` | tous | I | 8 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 84b | Financement | `/s/84b` | tous | I | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 85 | Objectifs et jalons | `/s/85` | tous | I | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 86 | Résultats de campagne | `/s/86` | tous | I | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 87 | Registre des innovations | `/s/87` | tous | I | 4 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 88 | Espace entreprise | `/s/88` | entreprise, admin | J | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 89 | Profil de l’entreprise | `/s/89` | entreprise, admin | J | 11 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 90 | Publier un besoin | `/s/90` | entreprise, admin | J | 8 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 91 | Rechercher des talents | `/s/91` | entreprise, admin | J | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 93 | Propositions reçues | `/s/93` | entreprise, admin | J | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 93b | Proposition | `/s/93b` | entreprise, admin | J | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 94 | Comparer les propositions | `/s/94` | entreprise, admin | J | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 95 | Devis et négociations | `/s/95` | entreprise, admin | J | 8 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 95b | Demande de devis | `/s/95b` | entreprise, admin | J | 7 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 96 | Défis d’innovation | `/s/96` | entreprise, admin | J | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 97 | Recrutement | `/s/97` | entreprise, admin | J | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 98 | Collaborations | `/s/98` | entreprise, admin | J | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 99 | Historique | `/s/99` | entreprise, admin | J | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 100 | Événements | `/s/100` | tous | K | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 101 | Événement | `/s/101` | tous | K | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 102 | Vitrine | `/s/102` | tous | K | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 103 | Communauté | `/s/103` | tous | K | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 104 | Carte de l’innovation | `/s/104` | tous | K | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 105 | Inter-établissements | `/s/105` | tous | K | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 106 | Économie circulaire | `/s/106` | tous | K | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 107 | Mon impact | `/s/107` | tous | K | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 108 | Tableau de bord du département | `/s/108` | dépt, direction, admin | L | 12 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 109 | Étudiants et vendeurs | `/s/109` | dépt, direction, admin | L | 14 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 110 | Validation des annonces | `/s/110` | dépt, direction, admin | L | 19 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 111 | Validation des projets | `/s/111` | dépt, direction, admin | L | 16 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 112 | Statistiques du département | `/s/112` | dépt, direction, admin | L | 12 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 113 | Suivi des productions | `/s/113` | dépt, direction, admin | L | 11 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 114 | Mentors et encadreurs | `/s/114` | dépt, direction, admin | L | 13 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 115 | Événements et initiatives | `/s/115` | dépt, direction, admin | L | 12 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 116 | Rapports et exports | `/s/116` | dépt, direction, admin | L | 11 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 117 | Tableau de bord institutionnel | `/s/117` | direction, admin | M | 16 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 118 | Établissement et identité visuelle | `/s/118` | direction, admin | M | 13 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 119 | Départements et filières | `/s/119` | direction, admin | M | 14 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 120 | Utilisateurs et affectations | `/s/120` | direction, admin | M | 15 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 121 | Responsables et encadreurs | `/s/121` | direction, admin | M | 12 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 122 | Circuits de validation | `/s/122` | direction, admin | M | 15 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 123 | Ventes et activité | `/s/123` | direction, admin | M | 12 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 124 | Événements et campagnes | `/s/124` | direction, admin | M | 14 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 125 | Rapports consolidés | `/s/125` | direction, admin | M | 12 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 126 | Journal d’audit | `/s/126` | direction, admin | M | 15 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 127 | Tableau de bord de la plateforme | `/s/127` | admin | N | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 128 | Comptes, rôles et permissions | `/s/128` | admin | N | 23 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 129 | Institutions | `/s/129` | admin | N | 16 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 130 | Modération | `/s/130` | admin | N | 14 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 131 | Signalements | `/s/131` | support, admin | N | 18 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 132 | Commandes et incidents | `/s/132` | support, admin | N | 18 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 133 | Litiges et remboursements | `/s/133` | support, admin | N | 14 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 134 | Transactions et rapprochements | `/s/134` | finance, admin | N | 14 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 135 | Commissions et règles économiques | `/s/135` | finance, admin | N | 16 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 136 | Sécurité et accès | `/s/136` | admin | N | 18 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 137 | Journal d’audit global | `/s/137` | admin | N | 17 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 138 | Configuration générale | `/s/138` | admin | N | 18 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 139 | Tableau de bord financier | `/s/139` | finance, direction, admin | O | 12 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 140 | Paiements déclarés | `/s/140` | finance, direction, admin | O | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 141 | Journal financier | `/s/141` | finance, direction, admin | O | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 142 | Rapports financiers | `/s/142` | finance, direction, admin | O | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 143 | Versements et montants dus | `/s/143` | finance, direction, admin | O | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 144 | Moyens de paiement et règles | `/s/144` | finance, direction, admin | O | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 145 | Points de retrait et kiosques | `/s/145` | support, admin | P | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 146_1 | — | `/s/146_1` | support, admin | P | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 146_2 | — | `/s/146_2` | support, admin | P | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 147_1 | — | `/s/147_1` | support, admin | P | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 147_2 | — | `/s/147_2` | support, admin | P | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 147_3 | — | `/s/147_3` | support, admin | P | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 148_1 | — | `/s/148_1` | tous | Q | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 148_2 | — | `/s/148_2` | tous | Q | 9 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 149 | Langue et affichage | `/s/149` | tous | Q | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 150_1 | — | `/s/150_1` | tous | Q | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 150_2 | — | `/s/150_2` | tous | Q | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 150_3 | — | `/s/150_3` | tous | Q | 8 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 150_4 | — | `/s/150_4` | tous | Q | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 151 | Opportunités | `/s/151` | tous | S | 10 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 152 | Kéla te recommande | `/s/152` | tous | S | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 153 | Pourquoi cette offre ? | `/s/153` | tous | S | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 154 | Mon dossier | `/s/154` | tous | S | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 155 | Alertes | `/s/155` | tous | S | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 156 | Préférences d’alertes | `/s/156` | tous | S | 11 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 157 | Résumé de Kéla | `/s/157` | tous | S | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 158 | Candidatures classées | `/s/158` | tous | S | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 159 | Candidature envoyée | `/s/159` | tous | S | 2 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 160 | Hackathons et concours | `/s/160` | tous | T | 14 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 161 | Hackathon | `/s/161` | tous | T | 5 | 1 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 162 | Inscription | `/s/162` | tous | T | 10 | 1 | non | serveur (Supabase) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 163 | Trouver des coéquipiers | `/s/163` | tous | T | 8 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 164 | Espace d’équipe | `/s/164` | tous | T | 6 | 2 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 165 | Dépôt du projet | `/s/165` | tous | T | 8 | 2 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 166 | Résultats | `/s/166` | tous | T | 2 | 1 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 167 | Noter un projet | `/s/167` | dépt, admin | T | 10 | 2 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 168 | Publier un concours | `/s/168` | dépt, admin | T | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 169 | Modération des concours | `/s/169` | dépt, admin | T | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 170 | Signaler une annonce | `/s/170` | tous | U | 10 | 1 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 171 | Paiement sécurisé | `/s/171` | tous | U | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 172 | Confiance du vendeur | `/s/172` | tous | U | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 173 | Partager | `/s/173` | tous | U | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 174 | Centre de confiance | `/s/174` | tous | U | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 175 | Bienvenue, étudiant | `/s/175` | tous | V | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 176 | Bienvenue | `/s/176` | tous | V | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 177 | Bienvenue, entreprise | `/s/177` | tous | V | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 178 | Bienvenue, jury | `/s/178` | tous | V | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 179 | Guide d’utilisation | `/s/179` | tous | V | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 180 | Rôles et permissions | `/s/180` | tous | V | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 181 | Matrice des permissions | `/s/181` | tous | V | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 182 | Explorer (chargement) | `/s/182` | tous | W | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 183 | Mes commandes (hors ligne) | `/s/183` | tous | W | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 184 | Économie de données | `/s/184` | tous | W | 5 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 185 | Language | `/s/185` | tous | W | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 186 | Accessibilité | `/s/186` | tous | W | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 187 | Tableau de bord entreprise | `/s/187` | entreprise, admin | X | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 188 | Recherche de talents et d’équipes | `/s/188` | entreprise, admin | X | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 189 | Propositions reçues | `/s/189` | entreprise, admin | X | 6 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 190 | Devis et négociations | `/s/190` | entreprise, admin | X | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 191 | Votre besoin | `/s/191` | tous | Y | 12 | 1 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 192 | Votre devis | `/s/192` | tous | Y | 5 | 2 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 193 | Paiement sécurisé | `/s/193` | tous | Y | 3 | 1 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 194 | Ma mission | `/s/194` | tous | Y | 7 | 2 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 195 | Ajouter une preuve | `/s/195` | tous | Y | 6 | 2 | non | mémoire locale (non persistée) | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 196 | Dossier | `/s/196` | tous | Y | 7 | 5 | non | statique | golden (rendu) | PARTIEL (5 action(s) de démonstration) |
| 197 | Valider le jalon | `/s/197` | tous | Y | 4 | 1 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 198 | Briefs reçus | `/s/198` | dépt, admin | Y | 12 | 4 | non | statique | golden (rendu) | PARTIEL (4 action(s) de démonstration) |
| 199 | Attribuer | `/s/199` | dépt, admin | Y | 4 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 200 | Missions et encaissement | `/s/200` | dépt, admin | Y | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 201 | Mes missions | `/s/201` | tous | Y | 8 | 0 | non | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 202 | Pack Lancement de marque | `/s/202` | tous | Y | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 203 | Mes compétences | `/s/203` | tous | Y | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 204 | Coup de pouce startup | `/s/204` | tous | Y | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 205 | Soumettre mon projet | `/s/205` | tous | Y | 7 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 206 | Borne · Accueil | `/s/206` | tous | AA | 4 | 1 | oui | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 207 | Borne · Explorer | `/s/207` | tous | AA | 15 | 4 | oui | mémoire locale (non persistée) | golden (rendu) | PARTIEL (4 action(s) de démonstration) |
| 208 | Borne · Fiche article | `/s/208` | tous | AA | 7 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 209 | Borne · QR téléphone | `/s/209` | tous | AA | 4 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 210 | Borne · C’est envoyé | `/s/210` | tous | AA | 3 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 211 | Passeport du produit | `/s/211` | tous | AD | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 212 | Vérifier un certificat | `/s/212` | tous | AD | 1 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 213 | Registre des certificats | `/s/213` | dépt, admin | AD | 6 | 1 | oui | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 214 | Départements | `/s/214` | tous | AD | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 215 | Fiche département | `/s/215` | tous | AD | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 216 | Marché des vœux | `/s/216` | tous | AD | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 217 | Fiche d’un vœu | `/s/217` | tous | AD | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 218 | Publier un vœu | `/s/218` | tous | AD | 8 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 219 | Nouveau duel | `/s/219` | tous | AD | 6 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 220 | Duel de talents | `/s/220` | tous | AD | 11 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 221 | Résultat du duel | `/s/221` | tous | AD | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 222 | Atelier en direct | `/s/222` | tous | AD | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 223 | Ateliers en direct | `/s/223` | tous | AD | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 224 | Validation des vœux | `/s/224` | tous | AD | 6 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 225 | Jumeau 3D | `/s/225` | tous | AD | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 226 | Modération des duels | `/s/226` | tous | AD | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 227 | Régie des ateliers en direct | `/s/227` | tous | AD | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 228 | Partager mon CV | `/s/228` | tous | AD | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 229 | CV vivant | `/s/229` | tous | AD | 2 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 230 | Assistante vocale Kéla | `/s/230` | tous | AI | 4 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 231 | Accueil Kéla | `/s/231` | tous | AI | 9 | 1 | oui | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 232 | Voix en texte | `/s/232` | tous | AI | 12 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 233 | WhatsApp · suivi de mission | `/s/233` | tous | AI | 5 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 234 | WhatsApp · validation de jalon | `/s/234` | tous | AI | 5 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 235 | WhatsApp · paiement sécurisé | `/s/235` | tous | AI | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 236 | Canaux et notifications | `/s/236` | tous | AI | 5 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 237 | Impact par territoire | `/s/237` | tous | AI | 2 | 1 | oui | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 238 | Impact de Boutik-École | `/s/238` | tous | AM | 6 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 239 | Rapport sponsors | `/s/239` | direction, dépt, admin | AM | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 240 | Parrainer et gagner | `/s/240` | tous | AM | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 241 | Mes contacts | `/s/241` | tous | AM | 10 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 242 | Kit à partager | `/s/242` | tous | AM | 11 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 243 | Mes gains | `/s/243` | tous | AM | 10 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 244 | Cercle | `/s/244` | tous | AM | 22 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 244b | Cercle · publication aimée | `/s/244b` | tous | AM | 24 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 245 | Reels | `/s/245` | tous | AM | 12 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 246 | Lives | `/s/246` | tous | AM | 12 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 247 | Profil créateur | `/s/247` | tous | AM | 14 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 248 | Boutique du créateur | `/s/248` | tous | AM | 11 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 249 | Créer | `/s/249` | tous | AM | 13 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 250 | Nouvelle publication | `/s/250` | tous | AM | 9 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 250b | Nouvelle publication | `/s/250b` | tous | AM | 9 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 251 | Découvrir | `/s/251` | tous | AM | 18 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 252 | Commentaires et avis | `/s/252` | tous | AM | 5 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 253 | Défis et récompenses | `/s/253` | tous | AM | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 253b | Défis · récompense récupérée | `/s/253b` | tous | AM | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 254 | Activité | `/s/254` | tous | AM | 13 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 255 | Suivi de publication | `/s/255` | tous | AM | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 256 | Contrôles de la fiche | `/s/256` | tous | Z | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 257 | Paiement en attente de confirmation | `/s/257` | tous | Z | 5 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 258 | Paiement échoué | `/s/258` | tous | Z | 4 | 0 | oui | statique | golden (rendu) | NAVIGATION SEULE |
| 259 | Reçu | `/s/259` | tous | Z | 5 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 260 | Facture | `/s/260` | tous | Z | 4 | 0 | oui | mémoire locale (non persistée) | golden (rendu) | IMPLÉMENTÉ MAIS NON PERSISTÉ |
| 261 | Mon espace client | `/s/261` | tous | Z | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 262 | Accueil B2B | `/s/262` | entreprise, admin | Z | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 263 | Médiathèque | `/s/263` | dépt, admin | Z | 5 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 264 | Pages éditoriales | `/s/264` | admin | Z | 8 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 265 | Modèles de notifications | `/s/265` | admin | Z | 5 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 266 | État technique | `/s/266` | admin | Z | 4 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 267 | Boutik-École Network | `/s/267` | admin | Z | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 268 | Analytics de la borne | `/s/268` | support, admin | Z | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 269 | Innovation Radar | `/s/269` | admin | Z | 3 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 270 | Showroom national | `/s/270` | tous | Z | 1 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 271 | Mes liens et réseaux | `/s/271` | tous | Z | 13 | 2 | oui | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 272 | Vérification en 2 étapes | `/s/272` | tous | Z | 4 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 273 | Mes données | `/s/273` | tous | Z | 4 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| 274 | Conditions générales | `/s/274` | tous | Z | 5 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 275 | Déposer un produit (erreurs) | `/s/275` | tous | Z | 6 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 276 | Borne hors ligne | `/s/276` | tous | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 277 | Supervision des bornes | `/s/277` | support, admin | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 278 | Fiche projet · liens et PI | `/s/278` | tous | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 279 | Ajouter des fichiers | `/s/279` | tous | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 280 | Intégrations | `/s/280` | admin | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 281 | Rôles et périmètres | `/s/281` | admin | Z | 2 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| 282 | QR de transfert | `/s/282` | tous | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 283 | Registre des certificats | `/s/283` | dépt, admin | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 284 | Registre financier | `/s/284` | finance, direction, admin | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 285 | Espace projet | `/s/285` | entreprise, admin | Z | 3 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 286 | Soumissions et équipe | `/s/286` | dépt, admin | Z | 6 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 287 | Catalogue département (tablette) | `/s/287` | dépt, admin | Z | 2 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| 288 | Catalogue département (web) | `/s/288` | dépt, admin | Z | 3 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| a1 | — | `/s/a1` | tous | S+ | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| a2 | — | `/s/a2` | tous | S+ | 9 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| a3 | — | `/s/a3` | tous | S+ | 12 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| d1 | — | `/s/d1` | tous | S+ | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| l1 | — | `/s/l1` | tous | S+ | 6 | 2 | non | statique | golden (rendu) | PARTIEL (2 action(s) de démonstration) |
| p1 | — | `/s/p1` | tous | S+ | 8 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| p2 | — | `/s/p2` | tous | S+ | 9 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| p3 | — | `/s/p3` | tous | S+ | 5 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| p4 | — | `/s/p4` | tous | S+ | 7 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
| p5 | — | `/s/p5` | tous | S+ | 8 | 1 | non | statique | golden (rendu) | PARTIEL (1 action(s) de démonstration) |
| s1 | — | `/s/s1` | tous | S+ | 0 | 0 | non | statique | golden (rendu) | STATIQUE (aucune interaction) |
| v1 | — | `/s/v1` | tous | S+ | 10 | 0 | non | statique | golden (rendu) | NAVIGATION SEULE |
