| Écran | Titre | Module (lib/features) | Format | Route | Rôles autorisés (client) | Profondeur depuis 01 | Liens entrants | Exemples d'écrans appelants | Catégorie |
|---|---|---|---|---|---|---|---|---|---|
| 01 | Bienvenue | `a_demarrage` | mobile | `/s/01` | tous | 0 | 0 | — | 1 · direct (démarrage/accueil) |
| 02 | Bienvenue (variante) | `a_demarrage` | mobile | `/s/02` | tous | 1 | 1 | 01 | 1 · direct (démarrage/accueil) |
| 03 | Accueil | `a_demarrage` | mobile | `/s/03` | tous | 2 | 93 | 02 04 06 07 08 09 | 1 · direct (démarrage/accueil) |
| 04 | Explorer | `a_demarrage` | mobile | `/s/04` | tous | 3 | 2 | 03 05 | 1 · direct (démarrage/accueil) |
| 05 | Fiche produit | `a_demarrage` | mobile | `/s/05` | tous | 3 | 6 | 03 04 06 22 25 26 | 1 · direct (démarrage/accueil) |
| 06 | Mon panier | `a_demarrage` | mobile | `/s/06` | tous | 2 | 6 | 05 07 32 35 36 40 | 2 · indirect |
| 07 | Livraison | `a_demarrage` | mobile | `/s/07` | tous | 1 | 314 | 01 02 03 04 05 06 | 1 · direct (démarrage/accueil) |
| 08 | Paiement | `a_demarrage` | mobile | `/s/08` | tous | 2 | 4 | 07 09 171 42 | 2 · indirect |
| 09 | Ma commande | `a_demarrage` | mobile | `/s/09` | tous | 3 | 5 | 08 261 28 44 45 | 2 · indirect |
| 10 | Profil étudiant | `a_demarrage` | mobile | `/s/10` | tous | 2 | 95 | 03 04 06 07 08 09 | 1 · direct (démarrage/accueil) |
| 11 | Connexion | `b_auth` | mobile | `/s/11` | tous | 3 | 34 | 10 101 108 110 111 12 | 2 · indirect |
| 12 | Créer un compte | `b_auth` | mobile | `/s/12` | tous | 3 | 32 | 10 101 108 11 110 111 | 2 · indirect |
| 13 | Choix du profil | `b_auth` | mobile | `/s/13` | tous | 5 | 1 | 14 | 2 · indirect |
| 14 | Vérification du compte | `b_auth` | mobile | `/s/14` | tous | 4 | 1 | 12 | 2 · indirect |
| 15 | Mot de passe oublié | `b_auth` | mobile | `/s/15` | tous | 4 | 1 | 11 | 2 · indirect |
| 16 | Nouveau mot de passe | `b_auth` | mobile | `/s/16` | tous | 5 | 1 | 15 | 2 · indirect |
| 17 | Conditions et confidentialité | `b_auth` | mobile | `/s/17` | tous | 4 | 1 | 12 | 2 · indirect |
| 18 | État de validation | `b_auth` | mobile | `/s/18` | tous | 4 | 1 | 50 | 2 · indirect |
| 18b | Compléter mon profil | `b_auth` | mobile | `/s/18b` | tous | 6 | 1 | 13 | 2 · indirect |
| 18c | Vérification étudiant | `b_auth` | mobile | `/s/18c` | tous | 4 | 3 | 154 18b 69 | 2 · indirect |
| 19 | Découvrir | `b_auth` | mobile | `/s/19` | tous | 2 | 154 | 03 04 06 07 08 09 | 1 · direct (démarrage/accueil) |
| 20 | Résultats de recherche | `b_auth` | mobile | `/s/20` | tous | 3 | 1 | 19 | 2 · indirect |
| 21 | Recherche avancée | `c_decouverte` | mobile | `/s/21` | tous | 3 | 1 | 19 | 2 · indirect |
| 22 | Catalogue de produits | `c_decouverte` | mobile | `/s/22` | tous | 3 | 4 | 03 10 19 21 | 1 · direct (démarrage/accueil) |
| 22b | Services et prestations | `c_decouverte` | mobile | `/s/22b` | tous | 3 | 2 | 03 10 | 1 · direct (démarrage/accueil) |
| 22c | Tendances et nouveautés | `c_decouverte` | mobile | `/s/22c` | tous | 5 | 2 | 102 251 | 2 · indirect |
| 22d | Pour vous | `c_decouverte` | mobile | `/s/22d` | tous | 4 | 1 | 151 | 2 · indirect |
| 23 | Filtres | `c_decouverte` | mobile | `/s/23` | tous | 4 | 1 | 20 | 2 · indirect |
| 24 | Profil vendeur | `c_decouverte` | mobile | `/s/24` | tous | 5 | 1 | 172 | 2 · indirect |
| 25 | Mes favoris | `c_decouverte` | mobile | `/s/25` | tous | 3 | 2 | 10 50 | 2 · indirect |
| 25b | Mes collections | `c_decouverte` | mobile | `/s/25b` | tous | 3 | 1 | 10 | 2 · indirect |
| 26 | Comparer des offres | `c_decouverte` | mobile | `/s/26` | tous | 3 | 1 | 10 | 2 · indirect |
| 27 | Mes adresses | `c_decouverte` | mobile | `/s/27` | tous | 3 | 2 | 10 148_1 | 2 · indirect |
| 28 | Mes commandes | `c_decouverte` | mobile | `/s/28` | tous | 4 | 1 | 50 | 2 · indirect |
| 29 | Détail de la commande | `c_decouverte` | mobile | `/s/29` | tous | 5 | 2 | 146_1 30 | 2 · indirect |
| 30 | Commande reçue | `c_decouverte` | mobile | `/s/30` | tous | 4 | 2 | 261 50 | 2 · indirect |
| 31 | Avis et évaluations | `c_decouverte` | mobile | `/s/31` | tous | 5 | 1 | 36 | 2 · indirect |
| 32 | Détail du produit | `d_fiches` | mobile | `/s/32` | tous | 4 | 1 | 05 | 2 · indirect |
| 33 | Histoire du produit | `d_fiches` | mobile | `/s/33` | tous | 4 | 1 | 05 | 2 · indirect |
| 34 | Galerie | `d_fiches` | mobile | `/s/34` | tous | 5 | 1 | 211 | 2 · indirect |
| 35 | Disponibilité | `d_fiches` | mobile | `/s/35` | tous | 4 | 1 | 05 | 2 · indirect |
| 36 | Détail du service | `d_fiches` | mobile | `/s/36` | tous | 4 | 1 | 22b | 2 · indirect |
| 38 | Réputation | `d_fiches` | mobile | `/s/38` | tous | 5 | 2 | 172 32 | 2 · indirect |
| 39 | Demande de renseignements | `d_fiches` | mobile | `/s/39` | tous | 5 | 1 | 35 | 2 · indirect |
| 40 | Demande de devis | `d_fiches` | mobile | `/s/40` | tous | 3 | 1 | 10 | 2 · indirect |
| 41 | Adresse de livraison | `e_commandes` | mobile | `/s/41` | tous | 2 | 1 | 07 | 2 · indirect |
| 42 | Récapitulatif | `e_commandes` | mobile | `/s/42` | tous | 3 | 2 | 41 44 | 2 · indirect |
| 43 | Instructions de paiement | `e_commandes` | mobile | `/s/43` | tous | 3 | 1 | 41 | 2 · indirect |
| 44 | Commande confirmée | `e_commandes` | mobile | `/s/44` | tous | 5 | 1 | 260 | 2 · indirect |
| 45 | Mes commandes | `e_commandes` | mobile | `/s/45` | tous | 3 | 2 | 10 261 | 2 · indirect |
| 46 | Suivi de livraison | `e_commandes` | mobile | `/s/46` | tous | 5 | 2 | 29 51 | 2 · indirect |
| 47 | Annuler la commande | `e_commandes` | mobile | `/s/47` | tous | 6 | 1 | 29 | 2 · indirect |
| 48 | Réclamation | `e_commandes` | mobile | `/s/48` | tous | 5 | 1 | 30 | 2 · indirect |
| 49 | Aide et support | `e_commandes` | mobile | `/s/49` | tous | 3 | 4 | 10 148_1 170 18 | 2 · indirect |
| 50 | Notifications | `f_communication` | mobile | `/s/50` | tous | 3 | 1 | 10 | 2 · indirect |
| 51 | Détail d’une notification | `f_communication` | mobile | `/s/51` | tous | 4 | 1 | 50 | 2 · indirect |
| 52 | Messages | `f_communication` | mobile | `/s/52` | tous | 3 | 2 | 10 50 | 2 · indirect |
| 53 | Conversation | `f_communication` | mobile | `/s/53` | tous | 2 | 111 | 03 04 06 07 08 09 | 1 · direct (démarrage/accueil) |
| 54 | Conversation commande | `f_communication` | mobile | `/s/54` | tous | 4 | 4 | 29 46 50 51 | 2 · indirect |
| 55 | Conversation entreprise | `f_communication` | mobile | `/s/55` | tous | 6 | 1 | 76 | 2 · indirect |
| 56 | Notifications et confidentialité | `f_communication` | mobile | `/s/56` | tous | 4 | 1 | 148_1 | 2 · indirect |
| 57 | Tableau de bord vendeur | `g_espace_etudiant` | mobile | `/s/57` | admin,dept,student | 3 | 2 | 10 175 | 3 · conditionnel (rôle) |
| 58 | Nouveau produit | `g_espace_etudiant` | mobile | `/s/58` | admin,dept,student | 3 | 5 | 10 275 287 288 61 | 3 · conditionnel (rôle) |
| 59 | Nouveau service | `g_espace_etudiant` | mobile | `/s/59` | admin,dept,student | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 60 | Modifier l’annonce | `g_espace_etudiant` | mobile | `/s/60` | admin,dept,student | 4 | 1 | 61 | 3 · conditionnel (rôle) |
| 61 | Mon catalogue | `g_espace_etudiant` | mobile | `/s/61` | admin,dept,student | 3 | 32 | 10 101 108 110 111 128 | 3 · conditionnel (rôle) |
| 62 | Stocks | `g_espace_etudiant` | mobile | `/s/62` | admin,dept,student | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 63 | Commandes reçues | `g_espace_etudiant` | mobile | `/s/63` | admin,dept,student | 3 | 4 | 10 57 64 65 | 3 · conditionnel (rôle) |
| 64 | Préparer une commande | `g_espace_etudiant` | mobile | `/s/64` | admin,dept,student | 4 | 1 | 63 | 3 · conditionnel (rôle) |
| 65 | Détail d’une vente | `g_espace_etudiant` | mobile | `/s/65` | admin,dept,student | 5 | 1 | 51 | 3 · conditionnel (rôle) |
| 66 | Revenus | `g_espace_etudiant` | mobile | `/s/66` | admin,dept,student | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 67 | Statistiques | `g_espace_etudiant` | mobile | `/s/67` | admin,dept,student | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 69 | Validations | `g_espace_etudiant` | mobile | `/s/69` | admin,dept,student | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 70 | Talents étudiants | `h_talents` | mobile | `/s/70` | tous | 3 | 1 | 03 | 1 · direct (démarrage/accueil) |
| 72 | Ajouter à mon profil | `h_talents` | mobile | `/s/72` | tous | 4 | 1 | 75 | 2 · indirect |
| 73 | Mes documents | `h_talents` | mobile | `/s/73` | tous | 3 | 1 | 10 | 2 · indirect |
| 74 | Talent Passport | `nouveaux` | mobile | `/s/74` | tous | 3 | 1 | 10 | 2 · indirect |
| 75 | Opportunités | `h_talents` | mobile | `/s/75` | tous | 3 | 1 | 10 | 2 · indirect |
| 76 | Ma candidature | `h_talents` | mobile | `/s/76` | tous | 5 | 1 | 159 | 2 · indirect |
| 77 | Profil de mentor | `h_talents` | mobile | `/s/77` | tous | 5 | 1 | 114 | 2 · indirect |
| 78 | Projets innovants | `i_projets` | mobile | `/s/78` | tous | 3 | 3 | 03 10 80 | 1 · direct (démarrage/accueil) |
| 79 | Projet | `i_projets` | mobile | `/s/79` | tous | 4 | 1 | 78 | 2 · indirect |
| 80 | Soumettre un projet | `i_projets` | mobile | `/s/80` | tous | 4 | 1 | 78 | 2 · indirect |
| 81 | Équipe du projet | `i_projets` | mobile | `/s/81` | tous | 5 | 1 | 80 | 2 · indirect |
| 82 | Journal du projet | `i_projets` | mobile | `/s/82` | tous | 3 | 2 | 10 80 | 2 · indirect |
| 83 | Médias et preuves | `i_projets` | mobile | `/s/83` | tous | 5 | 1 | 80 | 2 · indirect |
| 84 | Nouvelle campagne | `i_projets` | mobile | `/s/84` | tous | 3 | 1 | 10 | 2 · indirect |
| 84b | Financement | `i_projets` | mobile | `/s/84b` | tous | 5 | 1 | 138 | 2 · indirect |
| 85 | Objectifs et jalons | `i_projets` | mobile | `/s/85` | tous | 5 | 1 | 79 | 2 · indirect |
| 86 | Résultats de campagne | `i_projets` | mobile | `/s/86` | tous | 5 | 1 | 168 | 2 · indirect |
| 87 | Registre des innovations | `i_projets` | mobile | `/s/87` | tous | 3 | 2 | 10 23 | 2 · indirect |
| 88 | Espace entreprise | `j_entreprises` | mobile | `/s/88` | admin,company | 4 | 1 | 177 | 3 · conditionnel (rôle) |
| 89 | Profil de l’entreprise | `j_entreprises` | mobile | `/s/89` | admin,company | 5 | 1 | 162 | 3 · conditionnel (rôle) |
| 90 | Publier un besoin | `j_entreprises` | mobile | `/s/90` | admin,company | 3 | 3 | 10 202 215 | 3 · conditionnel (rôle) |
| 91 | Rechercher des talents | `j_entreprises` | mobile | `/s/91` | admin,company | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 93 | Propositions reçues | `j_entreprises` | mobile | `/s/93` | admin,company | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 93b | Proposition | `j_entreprises` | mobile | `/s/93b` | admin,company | 5 | 1 | 94 | 3 · conditionnel (rôle) |
| 94 | Comparer les propositions | `j_entreprises` | mobile | `/s/94` | admin,company | 4 | 3 | 189 89 93 | 3 · conditionnel (rôle) |
| 95 | Devis et négociations | `j_entreprises` | mobile | `/s/95` | admin,company | 4 | 1 | 187 | 3 · conditionnel (rôle) |
| 95b | Demande de devis | `j_entreprises` | mobile | `/s/95b` | admin,client,company,dept,other,student | 5 | 1 | 36 | 3 · conditionnel (rôle) |
| 96 | Défis d’innovation | `j_entreprises` | mobile | `/s/96` | admin,company | 3 | 2 | 10 187 | 3 · conditionnel (rôle) |
| 97 | Recrutement | `j_entreprises` | mobile | `/s/97` | admin,company | 4 | 1 | 187 | 3 · conditionnel (rôle) |
| 98 | Collaborations | `j_entreprises` | mobile | `/s/98` | admin,company | 6 | 1 | 89 | 3 · conditionnel (rôle) |
| 99 | Historique | `j_entreprises` | mobile | `/s/99` | admin,company | 3 | 2 | 10 187 | 3 · conditionnel (rôle) |
| 100 | Événements | `k_evenements` | mobile | `/s/100` | tous | 3 | 1 | 10 | 2 · indirect |
| 101 | Événement | `k_evenements` | mobile | `/s/101` | tous | 4 | 1 | 50 | 2 · indirect |
| 102 | Vitrine | `k_evenements` | mobile | `/s/102` | tous | 6 | 1 | 22c | 2 · indirect |
| 103 | Communauté | `k_evenements` | mobile | `/s/103` | tous | 3 | 1 | 10 | 2 · indirect |
| 104 | Carte de l’innovation | `k_evenements` | mobile | `/s/104` | tous | 5 | 1 | 138 | 2 · indirect |
| 105 | Inter-établissements | `k_evenements` | mobile | `/s/105` | tous | 4 | 1 | 103 | 2 · indirect |
| 106 | Économie circulaire | `k_evenements` | mobile | `/s/106` | tous | 4 | 1 | 05 | 2 · indirect |
| 107 | Mon impact | `k_evenements` | mobile | `/s/107` | tous | 10 | 1 | 237 | 2 · indirect |
| 108 | Tableau de bord du département | `l_departement` | web | `/s/108` | admin,dept,direction | 3 | 9 | 10 109 110 111 112 113 | 3 · conditionnel (rôle) |
| 109 | Étudiants et vendeurs | `l_departement` | web | `/s/109` | admin,dept,direction | 4 | 8 | 108 110 111 112 113 114 | 3 · conditionnel (rôle) |
| 110 | Validation des annonces | `l_departement` | web | `/s/110` | admin,dept,direction | 4 | 8 | 108 109 111 112 113 114 | 3 · conditionnel (rôle) |
| 111 | Validation des projets | `l_departement` | web | `/s/111` | admin,dept,direction | 4 | 9 | 09 108 109 110 112 113 | 3 · conditionnel (rôle) |
| 112 | Statistiques du département | `l_departement` | web | `/s/112` | admin,dept,direction | 4 | 8 | 108 109 110 111 113 114 | 3 · conditionnel (rôle) |
| 113 | Suivi des productions | `l_departement` | web | `/s/113` | admin,dept,direction | 4 | 8 | 108 109 110 111 112 114 | 3 · conditionnel (rôle) |
| 114 | Mentors et encadreurs | `l_departement` | web | `/s/114` | admin,dept,direction | 4 | 8 | 108 109 110 111 112 113 | 3 · conditionnel (rôle) |
| 115 | Événements et initiatives | `l_departement` | web | `/s/115` | admin,dept,direction | 4 | 8 | 108 109 110 111 112 113 | 3 · conditionnel (rôle) |
| 116 | Rapports et exports | `l_departement` | web | `/s/116` | admin,dept,direction | 4 | 8 | 108 109 110 111 112 113 | 3 · conditionnel (rôle) |
| 117 | Tableau de bord institutionnel | `m_admin_institution` | web | `/s/117` | admin,direction | 3 | 10 | 10 118 119 120 121 122 | 3 · conditionnel (rôle) |
| 118 | Établissement et identité visuelle | `m_admin_institution` | web | `/s/118` | admin,direction | 3 | 10 | 10 117 119 120 121 122 | 3 · conditionnel (rôle) |
| 119 | Départements et filières | `m_admin_institution` | web | `/s/119` | admin,direction | 4 | 9 | 117 118 120 121 122 123 | 3 · conditionnel (rôle) |
| 120 | Utilisateurs et affectations | `m_admin_institution` | web | `/s/120` | admin,direction | 4 | 9 | 117 118 119 121 122 123 | 3 · conditionnel (rôle) |
| 121 | Responsables et encadreurs | `m_admin_institution` | web | `/s/121` | admin,direction | 4 | 9 | 117 118 119 120 122 123 | 3 · conditionnel (rôle) |
| 122 | Circuits de validation | `m_admin_institution` | web | `/s/122` | admin,direction | 4 | 10 | 117 118 119 120 121 123 | 3 · conditionnel (rôle) |
| 123 | Ventes et activité | `m_admin_institution` | web | `/s/123` | admin,direction | 4 | 9 | 117 118 119 120 121 122 | 3 · conditionnel (rôle) |
| 124 | Événements et campagnes | `m_admin_institution` | web | `/s/124` | admin,direction | 4 | 9 | 117 118 119 120 121 122 | 3 · conditionnel (rôle) |
| 125 | Rapports consolidés | `m_admin_institution` | web | `/s/125` | admin,direction | 4 | 9 | 117 118 119 120 121 122 | 3 · conditionnel (rôle) |
| 126 | Journal d’audit | `m_admin_institution` | web | `/s/126` | admin,direction | 4 | 9 | 117 118 119 120 121 122 | 3 · conditionnel (rôle) |
| 127 | Tableau de bord de la plateforme | `n_admin_globale` | web | `/s/127` | admin | 3 | 12 | 10 128 129 130 131 132 | 3 · conditionnel (rôle) |
| 128 | Comptes, rôles et permissions | `n_admin_globale` | web | `/s/128` | admin | 4 | 11 | 127 129 130 131 132 133 | 3 · conditionnel (rôle) |
| 129 | Institutions | `n_admin_globale` | web | `/s/129` | admin | 4 | 11 | 127 128 130 131 132 133 | 3 · conditionnel (rôle) |
| 130 | Modération | `n_admin_globale` | web | `/s/130` | admin | 4 | 11 | 127 128 129 131 132 133 | 3 · conditionnel (rôle) |
| 131 | Signalements | `n_admin_globale` | web | `/s/131` | admin,support | 5 | 10 | 128 129 130 132 133 134 | 3 · conditionnel (rôle) |
| 132 | Commandes et incidents | `n_admin_globale` | web | `/s/132` | admin,support | 5 | 10 | 128 129 130 131 133 134 | 3 · conditionnel (rôle) |
| 133 | Litiges et remboursements | `n_admin_globale` | web | `/s/133` | admin,support | 5 | 10 | 128 129 130 131 132 134 | 3 · conditionnel (rôle) |
| 134 | Transactions et rapprochements | `n_admin_globale` | web | `/s/134` | admin,finance | 5 | 10 | 128 129 130 131 132 133 | 3 · conditionnel (rôle) |
| 135 | Commissions et règles économiques | `n_admin_globale` | web | `/s/135` | admin,finance | 5 | 10 | 128 129 130 131 132 133 | 3 · conditionnel (rôle) |
| 136 | Sécurité et accès | `n_admin_globale` | web | `/s/136` | admin | 4 | 11 | 127 128 129 130 131 132 | 3 · conditionnel (rôle) |
| 137 | Journal d’audit global | `n_admin_globale` | web | `/s/137` | admin | 5 | 10 | 128 129 130 131 132 133 | 3 · conditionnel (rôle) |
| 138 | Configuration générale | `n_admin_globale` | web | `/s/138` | admin | 4 | 11 | 127 128 129 130 131 132 | 3 · conditionnel (rôle) |
| 139 | Tableau de bord financier | `o_finance` | web | `/s/139` | admin,direction,finance | 3 | 11 | 10 127 140 141 142 143 | 3 · conditionnel (rôle) |
| 140 | Paiements déclarés | `o_finance` | web | `/s/140` | admin,direction,finance | 4 | 9 | 139 141 142 143 144 145 | 3 · conditionnel (rôle) |
| 141 | Journal financier | `o_finance` | web | `/s/141` | admin,direction,finance | 4 | 9 | 139 140 142 143 144 145 | 3 · conditionnel (rôle) |
| 142 | Rapports financiers | `o_finance` | web | `/s/142` | admin,direction,finance | 4 | 9 | 139 140 141 143 144 145 | 3 · conditionnel (rôle) |
| 143 | Versements et montants dus | `o_finance` | web | `/s/143` | admin,direction,finance | 4 | 1 | 139 | 3 · conditionnel (rôle) |
| 144 | Moyens de paiement et règles | `o_finance` | web | `/s/144` | admin,direction,finance | 4 | 1 | 148_1 | 3 · conditionnel (rôle) |
| 145 | Points de retrait et kiosques | `p_exploitation` | web | `/s/145` | admin,support | 3 | 11 | 10 127 139 140 141 142 | 3 · conditionnel (rôle) |
| 146-1 | Kiosque (gestionnaire) | `p_exploitation` | mobile | `/s/146-1` | admin,support | 4 | 1 | 145 | 3 · conditionnel (rôle) |
| 146-2 | Remise d’une commande | `p_exploitation` | mobile | `/s/146-2` | admin,support | 5 | 1 | 146_1 | 3 · conditionnel (rôle) |
| 147-1 | Incidents et maintenance | `p_exploitation` | web | `/s/147-1` | admin,support | 4 | 9 | 139 140 141 142 143 144 | 3 · conditionnel (rôle) |
| 147-2 | Tickets de support | `p_exploitation` | web | `/s/147-2` | admin,support | 4 | 9 | 139 140 141 142 143 144 | 3 · conditionnel (rôle) |
| 147-3 | Interventions et résolutions | `p_exploitation` | web | `/s/147-3` | admin,support | 4 | 9 | 139 140 141 142 143 144 | 3 · conditionnel (rôle) |
| 148-1 | Paramètres | `q_parametres` | mobile | `/s/148-1` | tous | 3 | 2 | 10 139 | 2 · indirect |
| 148-2 | Centre de sécurité | `q_parametres` | mobile | `/s/148-2` | tous | 3 | 1 | 10 | 2 · indirect |
| 149 | Langue et affichage | `q_parametres` | mobile | `/s/149` | tous | 4 | 1 | 148_1 | 2 · indirect |
| 150-1 | Synchronisation | `q_parametres` | mobile | `/s/150-1` | tous | — | 0 | — | 4 · route sans point d'entrée actif (seul lien : widget mort lib/features/q_parametres/s150_connexion_impossible) |
| 150-2 | Session expirée | `q_parametres` | mobile | `/s/150-2` | tous | — | 0 | system_states.dart | 3 · conditionnel (état système : session expirée, ouvert par lib/figma/live/system_states.dart:99) |
| 150-3 | Connexion impossible | `q_parametres` | mobile | `/s/150-3` | tous | — | 0 | system_states.dart | 3 · conditionnel (état système : hors connexion, system_states.dart:28/75) |
| 150-4 | Mes commandes (vide) | `q_parametres` | mobile | `/s/150-4` | tous | — | 0 | — | 5 · réellement orphelin (aucune référence ; état « Mes commandes vide ») |
| 151 | Opportunités | `s_opportunites` | mobile | `/s/151` | tous | 3 | 2 | 10 155 | 2 · indirect |
| 152 | Kéla te recommande | `s_opportunites` | mobile | `/s/152` | tous | 4 | 2 | 151 159 | 2 · indirect |
| 153 | Pourquoi cette offre ? | `s_opportunites` | mobile | `/s/153` | tous | 4 | 1 | 155 | 2 · indirect |
| 154 | Mon dossier | `s_opportunites` | mobile | `/s/154` | tous | 4 | 2 | 151 155 | 2 · indirect |
| 155 | Alertes | `s_opportunites` | mobile | `/s/155` | tous | 3 | 1 | 10 | 2 · indirect |
| 156 | Préférences d’alertes | `s_opportunites` | mobile | `/s/156` | tous | 3 | 1 | 10 | 2 · indirect |
| 157 | Résumé de Kéla | `s_opportunites` | mobile | `/s/157` | tous | 4 | 1 | 151 | 2 · indirect |
| 158 | Candidatures classées | `s_opportunites` | mobile | `/s/158` | tous | 5 | 1 | 97 | 2 · indirect |
| 159 | Candidature envoyée | `s_opportunites` | mobile | `/s/159` | tous | 4 | 2 | 153 155 | 2 · indirect |
| 160 | Hackathons et concours | `t_concours` | mobile | `/s/160` | tous | 3 | 2 | 10 178 | 2 · indirect |
| 161 | Hackathon | `t_concours` | mobile | `/s/161` | tous | 4 | 1 | 160 | 2 · indirect |
| 162 | Inscription | `t_concours` | mobile | `/s/162` | tous | 4 | 2 | 100 161 | 2 · indirect |
| 163 | Trouver des coéquipiers | `t_concours` | mobile | `/s/163` | tous | 4 | 1 | 160 | 2 · indirect |
| 164 | Espace d’équipe | `t_concours` | mobile | `/s/164` | tous | 3 | 31 | 10 101 108 110 111 128 | 2 · indirect |
| 165 | Dépôt du projet | `t_concours` | mobile | `/s/165` | tous | 4 | 1 | 164 | 2 · indirect |
| 166 | Résultats | `t_concours` | mobile | `/s/166` | tous | 5 | 2 | 161 167 | 2 · indirect |
| 167 | Noter un projet | `t_concours` | mobile | `/s/167` | admin,dept | 4 | 1 | 178 | 3 · conditionnel (rôle) |
| 168 | Publier un concours | `t_concours` | web | `/s/168` | admin,dept | 4 | 1 | 160 | 3 · conditionnel (rôle) |
| 169 | Modération des concours | `t_concours` | web | `/s/169` | admin,dept | 5 | 1 | 168 | 3 · conditionnel (rôle) |
| 170 | Signaler une annonce | `u_confiance` | mobile | `/s/170` | tous | 4 | 1 | 05 | 2 · indirect |
| 171 | Paiement sécurisé | `u_confiance` | mobile | `/s/171` | tous | 5 | 1 | 36 | 2 · indirect |
| 172 | Confiance du vendeur | `u_confiance` | mobile | `/s/172` | tous | 4 | 1 | 05 | 2 · indirect |
| 173 | Partager | `u_confiance` | mobile | `/s/173` | tous | 4 | 1 | 240 | 2 · indirect |
| 174 | Centre de confiance | `u_confiance` | mobile | `/s/174` | tous | 3 | 1 | 10 | 2 · indirect |
| 175 | Bienvenue, étudiant | `v_onboarding` | mobile | `/s/175` | tous | 5 | 1 | 172 | 2 · indirect |
| 176 | Bienvenue | `v_onboarding` | mobile | `/s/176` | tous | — | 0 | — | 5 · réellement orphelin (aucune référence ; accueil « client » de l'onboarding, 177 « entreprise » est relié) |
| 177 | Bienvenue, entreprise | `v_onboarding` | mobile | `/s/177` | tous | 3 | 1 | 03 | 1 · direct (démarrage/accueil) |
| 178 | Bienvenue, jury | `v_onboarding` | mobile | `/s/178` | tous | 3 | 1 | 10 | 2 · indirect |
| 179 | Guide d’utilisation | `v_onboarding` | mobile | `/s/179` | tous | 3 | 1 | 10 | 2 · indirect |
| 180 | Rôles et permissions | `v_onboarding` | web | `/s/180` | admin | 3 | 2 | 10 128 | 3 · conditionnel (rôle) |
| 181 | Matrice des permissions | `v_onboarding` | web | `/s/181` | admin | 5 | 1 | 128 | 3 · conditionnel (rôle) |
| 182 | Explorer (chargement) | `w_connexion` | mobile | `/s/182` | tous | — | 1 | 150_3 system_states.dart, g_150_3 | 3 · conditionnel (état système : chargement hors connexion, system_states.dart:28 ; lien depuis 150-3) |
| 183 | Mes commandes (hors ligne) | `w_connexion` | mobile | `/s/183` | tous | — | 0 | system_states.dart | 3 · conditionnel (état système : commandes hors connexion, system_states.dart:75/89) |
| 184 | Économie de données | `w_connexion` | mobile | `/s/184` | tous | 3 | 1 | 10 | 2 · indirect |
| 185 | Language | `w_connexion` | mobile | `/s/185` | tous | 5 | 1 | 149 | 2 · indirect |
| 186 | Accessibilité | `w_connexion` | mobile | `/s/186` | tous | 5 | 1 | 149 | 2 · indirect |
| 187 | Tableau de bord entreprise | `x_web_entreprise` | web | `/s/187` | admin,company | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 188 | Recherche de talents et d’équipes | `x_web_entreprise` | web | `/s/188` | admin,company | 4 | 1 | 187 | 3 · conditionnel (rôle) |
| 189 | Propositions reçues | `x_web_entreprise` | web | `/s/189` | admin,company | 4 | 2 | 187 233 | 3 · conditionnel (rôle) |
| 190 | Devis et négociations | `x_web_entreprise` | web | `/s/190` | admin,company | 5 | 1 | 192 | 3 · conditionnel (rôle) |
| 191 | Votre besoin | `y_missions` | mobile | `/s/191` | tous | 3 | 2 | 10 207 | 2 · indirect |
| 192 | Votre devis | `y_missions` | mobile | `/s/192` | tous | 4 | 2 | 191 261 | 2 · indirect |
| 193 | Paiement sécurisé | `y_missions` | mobile | `/s/193` | tous | 5 | 2 | 192 197 | 2 · indirect |
| 194 | Ma mission | `y_missions` | mobile | `/s/194` | tous | 3 | 32 | 10 101 108 110 111 128 | 2 · indirect |
| 195 | Ajouter une preuve | `y_missions` | mobile | `/s/195` | tous | 6 | 2 | 201 83 | 2 · indirect |
| 196 | Dossier | `y_missions` | mobile | `/s/196` | tous | 4 | 2 | 194 233 | 2 · indirect |
| 197 | Valider le jalon | `y_missions` | mobile | `/s/197` | tous | 4 | 1 | 194 | 2 · indirect |
| 198 | Briefs reçus | `y_missions` | web | `/s/198` | admin,dept | 6 | 1 | 213 | 3 · conditionnel (rôle) |
| 199 | Attribuer | `y_missions` | web | `/s/199` | admin,dept | 7 | 1 | 198 | 3 · conditionnel (rôle) |
| 200 | Missions et encaissement | `y_missions` | web | `/s/200` | admin,dept | 7 | 1 | 198 | 3 · conditionnel (rôle) |
| 201 | Mes missions | `y_missions` | mobile | `/s/201` | tous | 7 | 2 | 195 200 | 2 · indirect |
| 202 | Pack Lancement de marque | `y_missions` | mobile | `/s/202` | tous | 8 | 1 | 200 | 2 · indirect |
| 203 | Mes compétences | `y_missions` | mobile | `/s/203` | tous | 4 | 1 | 227 | 2 · indirect |
| 204 | Coup de pouce startup | `y_missions` | mobile | `/s/204` | tous | 5 | 1 | 215 | 2 · indirect |
| 205 | Soumettre mon projet | `y_missions` | mobile | `/s/205` | tous | 3 | 2 | 04 10 | 2 · indirect |
| 206 | Borne · Accueil | `aa_borne` | borne | `/s/206` | tous | 7 | 1 | 212 | 2 · indirect |
| 207 | Borne · Explorer | `aa_borne` | borne | `/s/207` | tous | 5 | 3 | 206 209 276 | 2 · indirect |
| 208 | Borne · Fiche article | `aa_borne` | borne | `/s/208` | tous | 6 | 1 | 207 | 2 · indirect |
| 209 | Borne · QR téléphone | `aa_borne` | borne | `/s/209` | tous | 7 | 1 | 208 | 2 · indirect |
| 210 | Borne · C’est envoyé | `aa_borne` | borne | `/s/210` | tous | 8 | 1 | 209 | 2 · indirect |
| 211 | Passeport du produit | `u_confiance` | mobile | `/s/211` | tous | 4 | 2 | 05 283 | 2 · indirect |
| 212 | Vérifier un certificat | `u_confiance` | mobile | `/s/212` | tous | 6 | 1 | 213 | 2 · indirect |
| 213 | Registre des certificats | `u_confiance` | web | `/s/213` | admin,dept | 5 | 1 | 111 | 3 · conditionnel (rôle) |
| 214 | Départements | `l_departement` | mobile | `/s/214` | tous | 3 | 1 | 10 | 2 · indirect |
| 215 | Fiche département | `l_departement` | mobile | `/s/215` | tous | 4 | 1 | 117 | 2 · indirect |
| 216 | Marché des vœux | `ad_innovations` | mobile | `/s/216` | tous | 3 | 1 | 10 | 2 · indirect |
| 217 | Fiche d’un vœu | `ad_innovations` | mobile | `/s/217` | tous | 4 | 1 | 216 | 2 · indirect |
| 218 | Publier un vœu | `ad_innovations` | mobile | `/s/218` | tous | 3 | 1 | 10 | 2 · indirect |
| 219 | Nouveau duel | `ad_innovations` | mobile | `/s/219` | tous | 8 | 1 | 201 | 2 · indirect |
| 220 | Duel de talents | `ad_innovations` | mobile | `/s/220` | tous | 9 | 1 | 219 | 2 · indirect |
| 221 | Résultat du duel | `ad_innovations` | mobile | `/s/221` | tous | 10 | 1 | 220 | 2 · indirect |
| 222 | Atelier en direct | `ad_innovations` | mobile | `/s/222` | tous | 4 | 4 | 223 244 244b 246 | 2 · indirect |
| 223 | Ateliers en direct | `ad_innovations` | mobile | `/s/223` | tous | 3 | 1 | 10 | 2 · indirect |
| 224 | Validation des vœux | `ad_innovations` | mobile | `/s/224` | tous | 3 | 2 | 10 246 | 2 · indirect |
| 225 | Jumeau 3D | `ad_innovations` | mobile | `/s/225` | tous | 5 | 1 | 32 | 2 · indirect |
| 226 | Modération des duels | `ad_innovations` | mobile | `/s/226` | tous | 6 | 1 | 225 | 2 · indirect |
| 227 | Régie des ateliers en direct | `ad_innovations` | mobile | `/s/227` | tous | 3 | 1 | 10 | 2 · indirect |
| 228 | Partager mon CV | `ad_innovations` | mobile | `/s/228` | tous | 5 | 1 | 173 | 2 · indirect |
| 229 | CV vivant | `ad_innovations` | mobile | `/s/229` | tous | 4 | 1 | 227 | 2 · indirect |
| 230 | Assistante vocale Kéla | `ai_kela` | mobile | `/s/230` | tous | 2 | 101 | 03 04 06 07 08 09 | 1 · direct (démarrage/accueil) |
| 231 | Accueil Kéla | `ai_kela` | mobile | `/s/231` | tous | 3 | 4 | 230 232 a1 a3 | 2 · indirect |
| 232 | Voix en texte | `ai_kela` | mobile | `/s/232` | tous | 3 | 2 | 230 a1 | 2 · indirect |
| 233 | WhatsApp · suivi de mission | `ai_kela` | mobile | `/s/233` | tous | 4 | 1 | 194 | 2 · indirect |
| 234 | WhatsApp · validation de jalon | `ai_kela` | mobile | `/s/234` | tous | 6 | 1 | 193 | 2 · indirect |
| 235 | WhatsApp · paiement sécurisé | `ai_kela` | mobile | `/s/235` | tous | 6 | 1 | 193 | 2 · indirect |
| 236 | Canaux et notifications | `ai_kela` | mobile | `/s/236` | tous | 3 | 1 | 10 | 2 · indirect |
| 237 | Impact par territoire | `k_evenements` | web | `/s/237` | tous | 9 | 1 | 210 | 2 · indirect |
| 238 | Impact de Boutik-École | `k_evenements` | mobile | `/s/238` | tous | 3 | 2 | 10 237 | 2 · indirect |
| 239 | Rapport sponsors | `k_evenements` | web | `/s/239` | admin,dept,direction | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 240 | Parrainer et gagner | `am_cercle` | mobile | `/s/240` | tous | 3 | 1 | 10 | 2 · indirect |
| 241 | Mes contacts | `am_cercle` | mobile | `/s/241` | tous | 4 | 1 | 240 | 2 · indirect |
| 242 | Kit à partager | `am_cercle` | mobile | `/s/242` | tous | 3 | 1 | 10 | 2 · indirect |
| 243 | Mes gains | `am_cercle` | mobile | `/s/243` | tous | 4 | 1 | 240 | 2 · indirect |
| 244 | Cercle | `am_cercle` | mobile | `/s/244` | tous | 4 | 12 | 244b 245 246 247 248 249 | 2 · indirect |
| 244b | Cercle · publication aimée | `am_cercle` | mobile | `/s/244b` | tous | 5 | 1 | 244 | 2 · indirect |
| 245 | Reels | `am_cercle` | mobile | `/s/245` | tous | 3 | 3 | 10 249 251 | 2 · indirect |
| 246 | Lives | `am_cercle` | mobile | `/s/246` | tous | 6 | 1 | 254 | 2 · indirect |
| 247 | Profil créateur | `am_cercle` | mobile | `/s/247` | tous | 4 | 10 | 244 244b 245 246 248 249 | 2 · indirect |
| 248 | Boutique du créateur | `am_cercle` | mobile | `/s/248` | tous | 4 | 5 | 244 244b 245 247 249 | 2 · indirect |
| 249 | Créer | `am_cercle` | mobile | `/s/249` | tous | 5 | 3 | 244 244b 248 | 2 · indirect |
| 250 | Nouvelle publication | `am_cercle` | mobile | `/s/250` | tous | 6 | 2 | 249 254 | 2 · indirect |
| 250b | Nouvelle publication | `nouveaux` | mobile | `/s/250b` | tous | — | 0 | — | 6 · variante/doublon potentiel de 250 et P4 « Nouvelle publication » |
| 251 | Découvrir | `am_cercle` | mobile | `/s/251` | tous | 4 | 10 | 244 244b 245 246 247 248 | 2 · indirect |
| 252 | Commentaires et avis | `am_cercle` | mobile | `/s/252` | tous | 4 | 6 | 244 244b 245 247 254 261 | 2 · indirect |
| 253 | Défis et récompenses | `am_cercle` | mobile | `/s/253` | tous | 3 | 2 | 10 254 | 2 · indirect |
| 253b | Défis · récompense récupérée | `am_cercle` | mobile | `/s/253b` | tous | 4 | 1 | 253 | 2 · indirect |
| 254 | Activité | `am_cercle` | mobile | `/s/254` | tous | 5 | 3 | 244 244b 246 | 2 · indirect |
| 255 | Suivi de publication | `nouveaux` | mobile | `/s/255` | tous | 6 | 2 | 249 256 | 2 · indirect |
| 256 | Contrôles de la fiche | `nouveaux` | mobile | `/s/256` | tous | 7 | 1 | 255 | 2 · indirect |
| 257 | Paiement en attente de confirmation | `nouveaux` | mobile | `/s/257` | tous | 3 | 32 | 08 10 101 108 110 111 | 2 · indirect |
| 258 | Paiement échoué | `nouveaux` | mobile | `/s/258` | tous | 4 | 1 | 257 | 2 · indirect |
| 259 | Reçu | `nouveaux` | mobile | `/s/259` | tous | 3 | 30 | 10 101 108 110 111 128 | 2 · indirect |
| 260 | Facture | `nouveaux` | mobile | `/s/260` | tous | 4 | 1 | 259 | 2 · indirect |
| 261 | Mon espace client | `nouveaux` | mobile | `/s/261` | tous | 3 | 1 | 10 | 2 · indirect |
| 262 | Accueil B2B | `nouveaux` | web | `/s/262` | admin,company | 3 | 2 | 10 138 | 3 · conditionnel (rôle) |
| 263 | Médiathèque | `nouveaux` | web | `/s/263` | admin,dept | 4 | 1 | 288 | 3 · conditionnel (rôle) |
| 264 | Pages éditoriales | `nouveaux` | web | `/s/264` | admin | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 265 | Modèles de notifications | `nouveaux` | web | `/s/265` | admin | 3 | 2 | 10 138 | 3 · conditionnel (rôle) |
| 266 | État technique | `nouveaux` | web | `/s/266` | admin | 6 | 1 | 81 | 3 · conditionnel (rôle) |
| 267 | Boutik-École Network | `nouveaux` | web | `/s/267` | admin | 4 | 1 | 127 | 3 · conditionnel (rôle) |
| 268 | Analytics de la borne | `nouveaux` | web | `/s/268` | admin,support | 4 | 1 | 145 | 3 · conditionnel (rôle) |
| 269 | Innovation Radar | `nouveaux` | web | `/s/269` | admin | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 270 | Showroom national | `nouveaux` | mobile | `/s/270` | tous | 5 | 1 | 267 | 2 · indirect |
| 271 | Mes liens et réseaux | `nouveaux` | mobile | `/s/271` | tous | 3 | 1 | 10 | 2 · indirect |
| 272 | Vérification en 2 étapes | `nouveaux` | mobile | `/s/272` | tous | 3 | 1 | 10 | 2 · indirect |
| 273 | Mes données | `nouveaux` | mobile | `/s/273` | tous | 3 | 2 | 10 148_1 | 2 · indirect |
| 274 | Conditions générales | `nouveaux` | mobile | `/s/274` | tous | 3 | 1 | 10 | 2 · indirect |
| 275 | Déposer un produit (erreurs) | `nouveaux` | mobile | `/s/275` | tous | — | 0 | — | 4 · route sans point d'entrée actif (seuls liens : widgets morts s287/s288 de lib/features) |
| 276 | Borne hors ligne | `nouveaux` | mobile | `/s/276` | tous | 4 | 1 | 145 | 2 · indirect |
| 277 | Supervision des bornes | `nouveaux` | mobile | `/s/277` | admin,support | 3 | 2 | 10 145 | 3 · conditionnel (rôle) |
| 278 | Fiche projet · liens et PI | `nouveaux` | mobile | `/s/278` | tous | 4 | 1 | 87 | 2 · indirect |
| 279 | Ajouter des fichiers | `nouveaux` | mobile | `/s/279` | tous | 4 | 1 | 58 | 2 · indirect |
| 280 | Intégrations | `nouveaux` | mobile | `/s/280` | admin | 3 | 2 | 10 266 | 3 · conditionnel (rôle) |
| 281 | Rôles et périmètres | `nouveaux` | mobile | `/s/281` | admin | 3 | 2 | 10 180 | 3 · conditionnel (rôle) |
| 282 | QR de transfert | `nouveaux` | mobile | `/s/282` | tous | 6 | 1 | 207 | 2 · indirect |
| 283 | Registre des certificats | `nouveaux` | mobile | `/s/283` | admin,dept | 3 | 2 | 10 213 | 3 · conditionnel (rôle) |
| 284 | Registre financier | `nouveaux` | mobile | `/s/284` | admin,direction,finance | 3 | 2 | 10 141 | 3 · conditionnel (rôle) |
| 285 | Espace projet | `nouveaux` | mobile | `/s/285` | admin,company | 3 | 1 | 10 | 3 · conditionnel (rôle) |
| 286 | Soumissions et équipe | `nouveaux` | mobile | `/s/286` | admin,dept | 5 | 1 | 162 | 3 · conditionnel (rôle) |
| 287 | Catalogue département (tablette) | `nouveaux` | tablette | `/s/287` | admin,dept | 6 | 1 | 286 | 3 · conditionnel (rôle) |
| 288 | Catalogue département (web) | `nouveaux` | web | `/s/288` | admin,dept | 3 | 2 | 10 287 | 3 · conditionnel (rôle) |
| A1 | Assistante vocale Kéla | `ref_echantillons` | mobile | `/s/A1` | tous | 4 | 3 | 108 231 a2 | 2 · indirect |
| A2 | Accueil Kéla | `ref_echantillons` | mobile | `/s/A2` | tous | — | 0 | — | 6 · doublon potentiel de 231 « Accueil Kéla » (même classe AccueilKelaScreen, section « échantillons de référence ») |
| A3 | Voix en texte | `ref_echantillons` | mobile | `/s/A3` | tous | 4 | 1 | 231 | 2 · indirect |
| D1 | Tableau de bord du studio | `ref_echantillons` | web | `/s/D1` | tous | 3 | 2 | 10 248 | 2 · indirect |
| L1 | Aller en direct | `ref_echantillons` | mobile | `/s/L1` | tous | 3 | 2 | 10 249 | 2 · indirect |
| P1 | Profil talent | `ref_echantillons` | mobile | `/s/P1` | tous | 4 | 1 | 91 | 2 · indirect |
| P2 | Profil talent · abonnement | `ref_echantillons` | mobile | `/s/P2` | tous | 5 | 1 | p1 | 2 · indirect |
| P3 | Avis et outils connectés | `ref_echantillons` | mobile | `/s/P3` | tous | 5 | 4 | 109 221 p1 p2 | 2 · indirect |
| P4 | Nouvelle publication | `ref_echantillons` | mobile | `/s/P4` | tous | — | 0 | — | 6 · doublon potentiel de 250b « Nouvelle publication » (même classe NouvellePublicationScreen) |
| P5 | Connecter mes outils | `ref_echantillons` | mobile | `/s/P5` | tous | 3 | 2 | 10 p3 | 2 · indirect |
| S1 | Démarrage animé | `ref_echantillons` | mobile | `/s/S1` | tous | — | 0 | — | 5 · réellement orphelin (écran de démarrage animé ; seul lien sortant dans un widget mort) |
| V1 | Vitrine | `ref_echantillons` | mobile | `/s/V1` | tous | 7 | 1 | 246 | 2 · indirect |
