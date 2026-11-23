| ID | Nom | Rôles | Entrées 31/10 | Interactions (serveur / navigation / locales / attente) | Champs | Données de maquette visibles | Sources serveur lues | Tests fonctionnels | Statut | Motif |
|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Bienvenue | tous | 0 | 1 (0 / 1 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 02 | Bienvenue (variante) | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 03 | Accueil | tous | 93 | 13 (0 / 11 / 2 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 04 | Explorer | tous | 2 | 11 (0 / 11 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 05 | Fiche produit | tous | 6 | 11 (0 / 10 / 1 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 06 | Mon panier | tous | 6 | 8 (0 / 8 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 07 | Livraison | tous | 314 | 13 (0 / 11 / 2 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | lot 5 : domicile seulement si activé (refus expliqué sinon), frais du réglage ; testé par la fonction, pas par l’écran |
| 08 | Paiement | tous | 4 | 12 (1 / 9 / 2 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 09 | Ma commande | tous | 5 | 11 (0 / 10 / 1 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 10 | Profil étudiant | tous | 95 | 15 (0 / 11 / 4 / 0) | 0 | 0 | listingsProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 100 | Événements | tous | 1 | 10 (0 / 10 / 0 / 0) | 0 | 12 | — | 0 | **DONNÉES FICTIVES** | 12 données de maquette visibles, aucune source serveur |
| 101 | Événement | tous | 1 | 2 (1 / 1 / 0 / 0) | 0 | 6 | — | 1 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 6 données de maquette visibles |
| 102 | Vitrine | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 103 | Communauté | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 104 | Carte de l’innovation | tous | 1 | 8 (0 / 8 / 0 / 0) | 1 | 2 | — | 0 | **NON VÉRIFIÉ** | lot 7 : recherche d’acteurs → annuaire des talents |
| 105 | Inter-établissements | tous | 1 | 8 (0 / 8 / 0 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 106 | Économie circulaire | tous | 1 | 8 (0 / 8 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 107 | Mon impact | tous | 1 | 8 (0 / 8 / 0 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 108 | Tableau de bord du département | admin,dept,direction | 9 | 18 (5 / 13 / 0 / 0) | 2 | 7 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 7 données de maquette visibles |
| 109 | Étudiants et vendeurs | admin,dept,direction | 8 | 11 (0 / 11 / 0 / 0) | 2 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 11 | Connexion | tous | 34 | 3 (1 / 2 / 0 / 0) | 2 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 110 | Validation des annonces | admin,dept,direction | 8 | 18 (6 / 9 / 3 / 0) | 1 | 2 | reviewDecisionsProvider | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 111 | Validation des projets | admin,dept,direction | 9 | 14 (4 / 10 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 112 | Statistiques du département | admin,dept,direction | 8 | 9 (0 / 9 / 0 / 0) | 1 | 11 | — | 0 | **DONNÉES FICTIVES** | 11 données de maquette visibles, aucune source serveur |
| 113 | Suivi des productions | admin,dept,direction | 8 | 9 (0 / 9 / 0 / 0) | 1 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 114 | Mentors et encadreurs | admin,dept,direction | 8 | 11 (0 / 11 / 0 / 0) | 2 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 115 | Événements et initiatives | admin,dept,direction | 8 | 10 (0 / 10 / 0 / 0) | 1 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| 116 | Rapports et exports | admin,dept,direction | 8 | 9 (0 / 9 / 0 / 0) | 1 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 117 | Tableau de bord institutionnel | admin,direction | 10 | 14 (0 / 14 / 0 / 0) | 2 | 19 | — | 0 | **DONNÉES FICTIVES** | 19 données de maquette visibles, aucune source serveur |
| 118 | Établissement et identité visuelle | admin,direction | 10 | 11 (1 / 10 / 0 / 0) | 1 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 119 | Départements et filières | admin,direction | 9 | 11 (0 / 11 / 0 / 0) | 2 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 12 | Créer un compte | tous | 32 | 6 (2 / 4 / 0 / 0) | 5 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 120 | Utilisateurs et affectations | admin,direction | 9 | 11 (0 / 11 / 0 / 0) | 2 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 121 | Responsables et encadreurs | admin,direction | 9 | 10 (0 / 10 / 0 / 0) | 1 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 122 | Circuits de validation | admin,direction | 10 | 10 (0 / 10 / 0 / 0) | 1 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 123 | Ventes et activité | admin,direction | 9 | 10 (0 / 10 / 0 / 0) | 1 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| 124 | Événements et campagnes | admin,direction | 9 | 11 (0 / 11 / 0 / 0) | 2 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 125 | Rapports consolidés | admin,direction | 9 | 10 (0 / 10 / 0 / 0) | 1 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 126 | Journal d’audit | admin,direction | 9 | 11 (0 / 11 / 0 / 0) | 2 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | phase 4 : recherche filtrant réellement le journal ; plus d’entrées fictives avec serveur ; preuve : tests locaux |
| 127 | Tableau de bord de la plateforme | admin | 12 | 13 (0 / 13 / 0 / 0) | 2 | 18 | — | 0 | **DONNÉES FICTIVES** | 18 données de maquette visibles, aucune source serveur |
| 128 | Comptes, rôles et permissions | admin | 11 | 19 (5 / 14 / 0 / 0) | 1 | 0 | adminUsersProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 129 | Institutions | admin | 11 | 13 (0 / 13 / 0 / 0) | 2 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 13 | Choix du profil | tous | 1 | 6 (1 / 1 / 4 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 130 | Modération | admin | 11 | 12 (0 / 12 / 0 / 0) | 1 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 131 | Signalements | admin,support | 10 | 16 (4 / 12 / 0 / 0) | 1 | 2 | allReportsProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 132 | Commandes et incidents | admin,support | 10 | 16 (4 / 12 / 0 / 0) | 1 | 0 | ordersProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 133 | Litiges et remboursements | admin,support | 10 | 12 (0 / 12 / 0 / 0) | 1 | 9 | — | 0 | **DONNÉES FICTIVES** | 9 données de maquette visibles, aucune source serveur |
| 134 | Transactions et rapprochements | admin,finance | 10 | 12 (0 / 12 / 0 / 0) | 1 | 16 | — | 0 | **DONNÉES FICTIVES** | 16 données de maquette visibles, aucune source serveur |
| 135 | Commissions et règles économiques | admin,finance | 10 | 14 (2 / 12 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 136 | Sécurité et accès | admin | 11 | 12 (0 / 12 / 0 / 0) | 1 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 137 | Journal d’audit global | admin | 10 | 13 (0 / 13 / 0 / 0) | 2 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | phase 4 : idem 126 ; preuve : tests locaux |
| 138 | Configuration générale | admin | 11 | 16 (0 / 16 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche d’en-tête reliée (pages autorisées + catalogue) ; aucun test n’ouvre l’écran |
| 139 | Tableau de bord financier | admin,direction,finance | 11 | 18 (5 / 13 / 0 / 0) | 2 | 7 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 7 données de maquette visibles |
| 14 | Vérification du compte | tous | 1 | 4 (2 / 2 / 0 / 0) | 1 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 140 | Paiements déclarés | admin,direction,finance | 9 | 8 (0 / 8 / 0 / 0) | 1 | 15 | — | 0 | **DONNÉES FICTIVES** | 15 données de maquette visibles, aucune source serveur |
| 141 | Journal financier | admin,direction,finance | 9 | 9 (0 / 9 / 0 / 0) | 1 | 13 | — | 0 | **DONNÉES FICTIVES** | 13 données de maquette visibles, aucune source serveur |
| 142 | Rapports financiers | admin,direction,finance | 9 | 8 (0 / 8 / 0 / 0) | 1 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| 143 | Versements et montants dus | admin,direction,finance | 1 | 9 (0 / 9 / 0 / 0) | 1 | 17 | — | 0 | **DONNÉES FICTIVES** | 17 données de maquette visibles, aucune source serveur |
| 144 | Moyens de paiement et règles | admin,direction,finance | 1 | 9 (0 / 9 / 0 / 0) | 1 | 2 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche d’en-tête reliée (pages autorisées + catalogue) ; aucun test n’ouvre l’écran |
| 145 | Points de retrait et kiosques | admin,support | 11 | 12 (0 / 12 / 0 / 0) | 1 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 146-1 | Kiosque (gestionnaire) | admin,support | 1 | 8 (0 / 8 / 0 / 0) | 0 | 10 | — | 0 | **DONNÉES FICTIVES** | 10 données de maquette visibles, aucune source serveur |
| 146-2 | Remise d’une commande | admin,support | 1 | 8 (1 / 7 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 147-1 | Incidents et maintenance | admin,support | 9 | 8 (0 / 8 / 0 / 0) | 1 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 147-2 | Tickets de support | admin,support | 9 | 8 (0 / 8 / 0 / 0) | 1 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 147-3 | Interventions et résolutions | admin,support | 9 | 8 (0 / 8 / 0 / 0) | 1 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 148-1 | Paramètres | tous | 2 | 14 (0 / 14 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 148-2 | Centre de sécurité | tous | 1 | 8 (1 / 7 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 149 | Langue et affichage | tous | 1 | 3 (0 / 3 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 15 | Mot de passe oublié | tous | 1 | 3 (1 / 2 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 150-1 | Synchronisation | tous | 0 | 2 (0 / 2 / 0 / 0) | 0 | 2 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | phase 3 : ouvert par « Réessayer » au retour du réseau, resynchronisation réelle ; preuve : tests locaux |
| 150-2 | Session expirée | tous | 0 | 2 (0 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 150-3 | Connexion impossible | tous | 0 | 8 (0 / 7 / 1 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 150-4 | Mes commandes (vide) | tous | 0 | 7 (0 / 7 / 0 / 0) | 0 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | phase 3 : remplace 45 quand le serveur confirme zéro commande ; preuve : tests locaux |
| 151 | Opportunités | tous | 2 | 13 (3 / 10 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 152 | Kéla te recommande | tous | 2 | 7 (0 / 7 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 153 | Pourquoi cette offre ? | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 6 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 6 données de maquette visibles |
| 154 | Mon dossier | tous | 2 | 2 (0 / 2 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 155 | Alertes | tous | 1 | 10 (0 / 10 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 156 | Préférences d’alertes | tous | 1 | 2 (1 / 1 / 0 / 0) | 1 | 1 | alertPrefsProvider | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 157 | Résumé de Kéla | tous | 1 | 6 (0 / 6 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 158 | Candidatures classées | tous | 1 | 2 (1 / 1 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 159 | Candidature envoyée | tous | 2 | 3 (0 / 3 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 16 | Nouveau mot de passe | tous | 1 | 2 (1 / 1 / 0 / 0) | 2 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 160 | Hackathons et concours | tous | 2 | 14 (0 / 10 / 4 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | lot 4 : concours lus sur le serveur (migration locale) ; testé par les fournisseurs, pas par l’écran |
| 161 | Hackathon | tous | 1 | 5 (0 / 3 / 2 / 0) | 0 | 3 | — | 0 | **NON VÉRIFIÉ** | lot 4 : fiche du concours réel ; testé par les fournisseurs |
| 162 | Inscription | tous | 2 | 9 (2 / 5 / 2 / 0) | 2 | 0 | teamMembersProvider | 0 | **NON VÉRIFIÉ** | lot 4 : inscription réelle (register_contest_team) |
| 163 | Trouver des coéquipiers | tous | 1 | 6 (4 / 2 / 0 / 0) | 1 | 0 | teamMembersProvider | 0 | **CONNECTÉ MAIS PARTIEL** | lot 4 : invitation réelle par e-mail ; l’annuaire de coéquipiers affiché reste celui de la maquette |
| 164 | Espace d’équipe | tous | 31 | 4 (0 / 2 / 0 / 2) | 0 | 3 | — | 1 | **CONNECTÉ MAIS PARTIEL** | lot 4 : équipe réelle côté serveur ; membres affichés encore issus de la maquette |
| 165 | Dépôt du projet | tous | 1 | 3 (2 / 1 / 0 / 0) | 3 | 2 | — | 1 | **NON VÉRIFIÉ** | lot 4 : dépôt réel par le capitaine (submit_contest_project) |
| 166 | Résultats | tous | 2 | 2 (1 / 1 / 0 / 0) | 0 | 2 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 4 : classement réel (contest_ranking) ; preuve : tests locaux et réplique 38/38 |
| 167 | Noter un projet | admin,dept | 1 | 7 (1 / 1 / 4 / 0) | 1 | 1 | submissionProvider | 1 | **NON VÉRIFIÉ** | lot 4 : notation réelle par les jurés désignés (score_contest_submission) |
| 168 | Publier un concours | admin,dept | 1 | 3 (0 / 3 / 0 / 0) | 6 | 0 | — | 0 | **NON VÉRIFIÉ** | lot 4 : publication réelle (save_contest) via le bouton « Soumettre pour validation » |
| 169 | Modération des concours | admin,dept | 1 | 1 (0 / 1 / 0 / 0) | 1 | 6 | — | 0 | **CONNECTÉ MAIS PARTIEL** | lot 4 : modération réelle du concours sélectionné ; tableau d’exemple encore affiché |
| 17 | Conditions et confidentialité | tous | 1 | 2 (1 / 1 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 170 | Signaler une annonce | tous | 1 | 8 (1 / 3 / 4 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 171 | Paiement sécurisé | tous | 1 | 3 (0 / 3 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 172 | Confiance du vendeur | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 173 | Partager | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 174 | Centre de confiance | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 175 | Bienvenue, étudiant | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 176 | Bienvenue | tous | 0 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 177 | Bienvenue, entreprise | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 178 | Bienvenue, jury | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 179 | Guide d’utilisation | tous | 1 | 8 (0 / 8 / 0 / 0) | 1 | 1 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 7 : recherche du guide ; preuve : test des articles |
| 18 | État de validation | tous | 1 | 3 (0 / 3 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 180 | Rôles et permissions | admin | 2 | 2 (0 / 2 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche d’en-tête reliée (pages autorisées + catalogue) ; aucun test n’ouvre l’écran |
| 181 | Matrice des permissions | admin | 1 | 1 (0 / 1 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche d’en-tête reliée (pages autorisées + catalogue) ; aucun test n’ouvre l’écran |
| 182 | Explorer (chargement) | tous | 1 | 7 (0 / 7 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche reliée au catalogue (22) ; aucun test n’ouvre l’écran |
| 183 | Mes commandes (hors ligne) | tous | 0 | 7 (0 / 6 / 1 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 184 | Économie de données | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 185 | Language | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 186 | Accessibilité | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 187 | Tableau de bord entreprise | admin,company | 1 | 10 (0 / 10 / 0 / 0) | 2 | 19 | — | 0 | **DONNÉES FICTIVES** | 19 données de maquette visibles, aucune source serveur |
| 188 | Recherche de talents et d’équipes | admin,company | 1 | 3 (0 / 3 / 0 / 0) | 3 | 0 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche reliée aux talents (70) ; aucun test n’ouvre l’écran |
| 189 | Propositions reçues | admin,company | 2 | 3 (0 / 3 / 0 / 0) | 1 | 12 | — | 0 | **DONNÉES FICTIVES** | 12 données de maquette visibles, aucune source serveur |
| 18b | Compléter mon profil | tous | 1 | 5 (1 / 4 / 0 / 0) | 6 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 18c | Vérification étudiant | tous | 3 | 1 (0 / 1 / 0 / 0) | 3 | 1 | — | 0 | **BLOQUÉ PAR UNE DÉPENDANCE** | phase 4 : matricule, niveau et pièces sans modèle de données — migration à préparer |
| 19 | Découvrir | tous | 154 | 9 (0 / 8 / 1 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 190 | Devis et négociations | admin,company | 1 | 2 (0 / 2 / 0 / 0) | 1 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 191 | Votre besoin | tous | 2 | 8 (1 / 1 / 6 / 0) | 3 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 192 | Votre devis | tous | 2 | 4 (2 / 2 / 0 / 0) | 0 | 4 | missionProvider | 1 | **CONNECTÉ ET FONCTIONNEL** | lot 3 : statut, date, équipe et proposition réels ; preuve : tests locaux |
| 193 | Paiement sécurisé | tous | 2 | 4 (1 / 3 / 0 / 0) | 0 | 0 | missionProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 194 | Ma mission | tous | 32 | 8 (1 / 7 / 0 / 0) | 0 | 6 | missionProvider | 0 | **NON VÉRIFIÉ** | lot 3 : équipe, échéance et jalons réels ; aucun test n’ouvre l’écran |
| 195 | Ajouter une preuve | tous | 2 | 3 (2 / 1 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 196 | Dossier | tous | 2 | 3 (2 / 1 / 0 / 0) | 0 | 8 | — | 0 | **NON VÉRIFIÉ** | lot 3 : numéro réel, fil d’exemple masqué, boutons vers le vrai dossier ; aucun test n’ouvre l’écran |
| 197 | Valider le jalon | tous | 1 | 4 (2 / 2 / 0 / 0) | 0 | 3 | missionProvider | 0 | **NON VÉRIFIÉ** | lot 3 : montants calculés sur la mission réelle ; aucun test n’ouvre l’écran |
| 198 | Briefs reçus | admin,dept | 1 | 7 (0 / 7 / 0 / 0) | 1 | 6 | — | 0 | **DONNÉES FICTIVES** | mission ou concours d'exemple affiché (actions honnêtes depuis 6364a6d) |
| 199 | Attribuer | admin,dept | 1 | 2 (1 / 1 / 0 / 0) | 1 | 12 | — | 0 | **DONNÉES FICTIVES** | mission ou concours d'exemple affiché (actions honnêtes depuis 6364a6d) |
| 20 | Résultats de recherche | tous | 1 | 9 (0 / 9 / 0 / 0) | 1 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 200 | Missions et encaissement | admin,dept | 1 | 3 (0 / 3 / 0 / 0) | 1 | 19 | — | 0 | **DONNÉES FICTIVES** | mission ou concours d'exemple affiché (actions honnêtes depuis 6364a6d) |
| 201 | Mes missions | tous | 2 | 8 (0 / 8 / 0 / 0) | 0 | 2 | missionProvider | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 3 : mission, gains et jalons réels, missions inventées masquées ; preuve : tests locaux |
| 202 | Pack Lancement de marque | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 203 | Mes compétences | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 13 | — | 0 | **DONNÉES FICTIVES** | 13 données de maquette visibles, aucune source serveur |
| 204 | Coup de pouce startup | tous | 1 | 6 (0 / 6 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 205 | Soumettre mon projet | tous | 2 | 3 (2 / 1 / 0 / 0) | 3 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 206 | Borne · Accueil | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 207 | Borne · Explorer | tous | 3 | 14 (0 / 7 / 7 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 208 | Borne · Fiche article | tous | 1 | 6 (1 / 4 / 1 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 209 | Borne · QR téléphone | tous | 1 | 3 (1 / 1 / 1 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 21 | Recherche avancée | tous | 1 | 4 (0 / 3 / 1 / 0) | 4 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 210 | Borne · C’est envoyé | tous | 1 | 2 (0 / 1 / 0 / 1) | 0 | 1 | — | 0 | **BLOQUÉ PAR UNE DÉPENDANCE** | action en attente d'un service (paiement, diffusion, messagerie mentor) |
| 211 | Passeport du produit | tous | 2 | 3 (1 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 212 | Vérifier un certificat | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 213 | Registre des certificats | admin,dept | 1 | 6 (1 / 5 / 0 / 0) | 1 | 18 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 18 données de maquette visibles |
| 214 | Départements | tous | 1 | 8 (0 / 8 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 215 | Fiche département | tous | 1 | 3 (0 / 3 / 0 / 0) | 0 | 9 | — | 0 | **DONNÉES FICTIVES** | 9 données de maquette visibles, aucune source serveur |
| 216 | Marché des vœux | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 217 | Fiche d’un vœu | tous | 1 | 2 (1 / 1 / 0 / 0) | 0 | 9 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 9 données de maquette visibles |
| 218 | Publier un vœu | tous | 1 | 3 (2 / 1 / 0 / 0) | 5 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 219 | Nouveau duel | tous | 1 | 3 (0 / 2 / 0 / 1) | 3 | 3 | — | 0 | **BLOQUÉ PAR UNE DÉPENDANCE** | action en attente d'un service (paiement, diffusion, messagerie mentor) |
| 22 | Catalogue de produits | tous | 4 | 20 (0 / 8 / 12 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 220 | Duel de talents | tous | 1 | 12 (2 / 10 / 0 / 0) | 0 | 8 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 8 données de maquette visibles |
| 221 | Résultat du duel | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 222 | Atelier en direct | tous | 4 | 3 (0 / 3 / 0 / 0) | 1 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 223 | Ateliers en direct | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 224 | Validation des vœux | tous | 2 | 3 (2 / 1 / 0 / 0) | 3 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 225 | Jumeau 3D | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 226 | Modération des duels | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 227 | Régie des ateliers en direct | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| 228 | Partager mon CV | tous | 1 | 2 (1 / 1 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 229 | CV vivant | tous | 1 | 2 (2 / 0 / 0 / 0) | 0 | 6 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 6 données de maquette visibles |
| 22b | Services et prestations | tous | 2 | 14 (1 / 8 / 5 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 22c | Tendances et nouveautés | tous | 2 | 9 (0 / 9 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 22d | Pour vous | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 23 | Filtres | tous | 1 | 3 (0 / 2 / 1 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 230 | Assistante vocale Kéla | tous | 101 | 4 (0 / 4 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 231 | Accueil Kéla | tous | 4 | 9 (0 / 9 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 232 | Voix en texte | tous | 2 | 11 (0 / 11 / 0 / 0) | 1 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 233 | WhatsApp · suivi de mission | tous | 1 | 4 (0 / 4 / 0 / 0) | 1 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 234 | WhatsApp · validation de jalon | tous | 1 | 4 (2 / 2 / 0 / 0) | 1 | 6 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 6 données de maquette visibles |
| 235 | WhatsApp · paiement sécurisé | tous | 1 | 2 (0 / 2 / 0 / 0) | 1 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 236 | Canaux et notifications | tous | 1 | 8 (1 / 3 / 4 / 0) | 1 | 0 | channelPrefsProvider | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 237 | Impact par territoire | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 13 | — | 0 | **DONNÉES FICTIVES** | 13 données de maquette visibles, aucune source serveur |
| 238 | Impact de Boutik-École | tous | 2 | 6 (0 / 6 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 239 | Rapport sponsors | admin,dept,direction | 1 | 1 (0 / 1 / 0 / 0) | 1 | 9 | — | 0 | **DONNÉES FICTIVES** | 9 données de maquette visibles, aucune source serveur |
| 24 | Profil vendeur | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 240 | Parrainer et gagner | tous | 1 | 12 (0 / 12 / 0 / 0) | 1 | 7 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 6 : code, gains, palier réels |
| 241 | Mes contacts | tous | 1 | 7 (0 / 5 / 2 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 242 | Kit à partager | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 243 | Mes gains | tous | 1 | 10 (0 / 9 / 0 / 1) | 0 | 6 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 6 : solde, filleuls réels ; preuve : tests locaux et réplique 19/19 |
| 244 | Cercle | tous | 12 | 21 (0 / 21 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 244b | Cercle · publication aimée | tous | 1 | 23 (0 / 23 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 245 | Reels | tous | 3 | 12 (0 / 12 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 7 : fil réel (vérifié en ligne : aucun reel inventé) |
| 246 | Lives | tous | 1 | 14 (0 / 14 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 247 | Profil créateur | tous | 10 | 14 (0 / 14 / 0 / 0) | 0 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| 248 | Boutique du créateur | tous | 5 | 11 (0 / 11 / 0 / 0) | 0 | 10 | — | 0 | **DONNÉES FICTIVES** | 10 données de maquette visibles, aucune source serveur |
| 249 | Créer | tous | 3 | 14 (0 / 14 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 25 | Mes favoris | tous | 2 | 12 (0 / 8 / 4 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 250 | Nouvelle publication | tous | 2 | 4 (0 / 3 / 0 / 1) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | lot 7 : « Publier » réel (create_post) ; recette production OK |
| 250b | Nouvelle publication | tous | 0 | 4 (0 / 3 / 0 / 1) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | lot 7 : variante de 250, « Publier » réel |
| 251 | Découvrir | tous | 10 | 17 (0 / 17 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche reliée au catalogue (22) ; aucun test n’ouvre l’écran |
| 252 | Commentaires et avis | tous | 6 | 4 (0 / 4 / 0 / 0) | 0 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| 253 | Défis et récompenses | tous | 2 | 11 (0 / 11 / 0 / 0) | 0 | 9 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 7 : série, progression, récompenses réelles ; preuve : tests locaux, réplique 22/22 |
| 253b | Défis · récompense récupérée | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 254 | Activité | tous | 3 | 12 (0 / 12 / 0 / 0) | 0 | 10 | — | 0 | **DONNÉES FICTIVES** | 10 données de maquette visibles, aucune source serveur |
| 255 | Suivi de publication | tous | 2 | 5 (0 / 5 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 256 | Contrôles de la fiche | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 257 | Paiement en attente de confirmation | tous | 32 | 5 (1 / 4 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 258 | Paiement échoué | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 259 | Reçu | tous | 30 | 5 (1 / 4 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 25b | Mes collections | tous | 1 | 8 (0 / 8 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | lot 7 : recherche dans les favoris réels |
| 26 | Comparer des offres | tous | 1 | 3 (0 / 3 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 260 | Facture | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 261 | Mon espace client | tous | 1 | 11 (0 / 11 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 262 | Accueil B2B | admin,company | 2 | 1 (0 / 1 / 0 / 0) | 1 | 11 | — | 0 | **DONNÉES FICTIVES** | 11 données de maquette visibles, aucune source serveur |
| 263 | Médiathèque | admin,dept | 1 | 2 (1 / 1 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 264 | Pages éditoriales | admin | 1 | 4 (0 / 3 / 1 / 0) | 2 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 265 | Modèles de notifications | admin | 2 | 3 (1 / 2 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 266 | État technique | admin | 1 | 2 (0 / 2 / 0 / 0) | 1 | 13 | — | 0 | **DONNÉES FICTIVES** | 13 données de maquette visibles, aucune source serveur |
| 267 | Boutik-École Network | admin | 1 | 2 (0 / 2 / 0 / 0) | 1 | 2 | — | 0 | **NON VÉRIFIÉ** | phase 4 : recherche d’en-tête reliée (pages autorisées + catalogue) ; aucun test n’ouvre l’écran |
| 268 | Analytics de la borne | admin,support | 1 | 1 (0 / 1 / 0 / 0) | 1 | 17 | — | 0 | **DONNÉES FICTIVES** | 17 données de maquette visibles, aucune source serveur |
| 269 | Innovation Radar | admin | 1 | 1 (0 / 1 / 0 / 0) | 1 | 9 | — | 0 | **DONNÉES FICTIVES** | 9 données de maquette visibles, aucune source serveur |
| 27 | Mes adresses | tous | 2 | 8 (0 / 8 / 0 / 0) | 0 | 0 | — | 0 | **DONNÉES FICTIVES** | lot 5 : le carnet existe côté serveur ; la liste affichée reste celle de la maquette (à relier) |
| 270 | Showroom national | tous | 1 | 0 (0 / 0 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 271 | Mes liens et réseaux | tous | 1 | 5 (1 / 3 / 1 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 272 | Vérification en 2 étapes | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 273 | Mes données | tous | 2 | 4 (2 / 2 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 274 | Conditions générales | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 275 | Déposer un produit (erreurs) | tous | 0 | 3 (0 / 3 / 0 / 0) | 3 | 2 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | phase 3 : récapitulatif des erreurs réelles de 58 (≥ 2 champs) ; preuve : tests locaux |
| 276 | Borne hors ligne | tous | 1 | 3 (0 / 3 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 277 | Supervision des bornes | admin,support | 2 | 3 (1 / 2 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 278 | Fiche projet · liens et PI | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 279 | Ajouter des fichiers | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 7 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 7 données de maquette visibles |
| 28 | Mes commandes | tous | 1 | 11 (0 / 7 / 4 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 280 | Intégrations | admin | 2 | 3 (1 / 2 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 281 | Rôles et périmètres | admin | 2 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 282 | QR de transfert | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 283 | Registre des certificats | admin,dept | 2 | 4 (1 / 3 / 0 / 0) | 0 | 12 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 12 données de maquette visibles |
| 284 | Registre financier | admin,direction,finance | 2 | 3 (1 / 2 / 0 / 0) | 0 | 15 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 15 données de maquette visibles |
| 285 | Espace projet | admin,company | 1 | 3 (1 / 2 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 286 | Soumissions et équipe | admin,dept | 1 | 4 (1 / 3 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 287 | Catalogue département (tablette) | admin,dept | 1 | 2 (0 / 2 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 288 | Catalogue département (web) | admin,dept | 2 | 3 (1 / 2 / 0 / 0) | 1 | 19 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 19 données de maquette visibles |
| 29 | Détail de la commande | tous | 2 | 5 (3 / 2 / 0 / 0) | 0 | 0 | — | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 30 | Commande reçue | tous | 2 | 4 (1 / 3 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 31 | Avis et évaluations | tous | 1 | 7 (0 / 7 / 0 / 0) | 0 | 11 | — | 0 | **DONNÉES FICTIVES** | 11 données de maquette visibles, aucune source serveur |
| 32 | Détail du produit | tous | 1 | 4 (0 / 3 / 1 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 33 | Histoire du produit | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 34 | Galerie | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 35 | Disponibilité | tous | 1 | 4 (1 / 2 / 1 / 0) | 0 | 7 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 7 données de maquette visibles |
| 36 | Détail du service | tous | 1 | 5 (2 / 3 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 38 | Réputation | tous | 2 | 1 (0 / 1 / 0 / 0) | 0 | 9 | — | 0 | **DONNÉES FICTIVES** | 9 données de maquette visibles, aucune source serveur |
| 39 | Demande de renseignements | tous | 1 | 3 (1 / 2 / 0 / 0) | 2 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 40 | Demande de devis | tous | 1 | 2 (0 / 2 / 0 / 0) | 4 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | phase 4 : saisie enregistrée, envoi request_quote pour le service consulté, sinon rien n’est envoyé ; preuve : tests locaux |
| 41 | Adresse de livraison | tous | 1 | 4 (0 / 4 / 0 / 0) | 5 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | lot 5 : adresse validée et enregistrée (save_address), aucune adresse d’exemple ; preuve : tests locaux et réplique 22/22 |
| 42 | Récapitulatif | tous | 2 | 2 (0 / 2 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 43 | Instructions de paiement | tous | 1 | 3 (1 / 1 / 1 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 44 | Commande confirmée | tous | 1 | 4 (0 / 4 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 45 | Mes commandes | tous | 2 | 12 (0 / 8 / 4 / 0) | 1 | 0 | — | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 46 | Suivi de livraison | tous | 2 | 3 (2 / 1 / 0 / 0) | 0 | 5 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 5 données de maquette visibles |
| 47 | Annuler la commande | tous | 1 | 7 (1 / 2 / 4 / 0) | 0 | 1 | — | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 48 | Réclamation | tous | 1 | 6 (1 / 1 / 4 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 49 | Aide et support | tous | 4 | 9 (0 / 9 / 0 / 0) | 1 | 1 | — | 0 | **NON VÉRIFIÉ** | lot 7 : recherche d’aide → articles qui ouvrent l’écran concerné |
| 50 | Notifications | tous | 1 | 15 (1 / 14 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 51 | Détail d’une notification | tous | 1 | 4 (1 / 3 / 0 / 0) | 0 | 8 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 8 données de maquette visibles |
| 52 | Messages | tous | 2 | 8 (0 / 8 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | lot 7 : recherche dans les conversations réelles |
| 53 | Conversation | tous | 111 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 54 | Conversation commande | tous | 4 | 2 (0 / 2 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 55 | Conversation entreprise | tous | 1 | 2 (0 / 2 / 0 / 0) | 1 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 56 | Notifications et confidentialité | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 57 | Tableau de bord vendeur | admin,dept,student | 2 | 10 (2 / 8 / 0 / 0) | 0 | 2 | listingsProvider, ordersProvider, sellerOrdersProvider, sellerStatusProvider | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 58 | Nouveau produit | admin,dept,student | 5 | 4 (2 / 2 / 0 / 0) | 4 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 59 | Nouveau service | admin,dept,student | 1 | 3 (2 / 1 / 0 / 0) | 6 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 60 | Modifier l’annonce | admin,dept,student | 1 | 3 (2 / 1 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 61 | Mon catalogue | admin,dept,student | 32 | 13 (0 / 8 / 5 / 0) | 1 | 0 | listingsProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 62 | Stocks | admin,dept,student | 1 | 10 (3 / 7 / 0 / 0) | 1 | 0 | listingsProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 63 | Commandes reçues | admin,dept,student | 4 | 10 (0 / 6 / 4 / 0) | 0 | 0 | sellerOrdersProvider, sellerStatusProvider | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 64 | Préparer une commande | admin,dept,student | 1 | 3 (2 / 1 / 0 / 0) | 0 | 1 | — | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 65 | Détail d’une vente | admin,dept,student | 1 | 2 (1 / 1 / 0 / 0) | 0 | 9 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 9 données de maquette visibles |
| 66 | Revenus | admin,dept,student | 1 | 6 (0 / 6 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 67 | Statistiques | admin,dept,student | 1 | 6 (0 / 6 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| 69 | Validations | admin,dept,student | 1 | 3 (0 / 3 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 70 | Talents étudiants | tous | 1 | 14 (5 / 9 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 72 | Ajouter à mon profil | tous | 1 | 2 (1 / 1 / 0 / 0) | 4 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 73 | Mes documents | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 74 | Talent Passport | tous | 1 | 4 (0 / 3 / 1 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
| 75 | Opportunités | tous | 1 | 12 (4 / 8 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 76 | Ma candidature | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 77 | Profil de mentor | tous | 1 | 10 (1 / 9 / 0 / 0) | 0 | 3 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 3 données de maquette visibles |
| 78 | Projets innovants | tous | 3 | 13 (0 / 9 / 4 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 79 | Projet | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 80 | Soumettre un projet | tous | 1 | 5 (1 / 4 / 0 / 0) | 4 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 81 | Équipe du projet | tous | 1 | 2 (0 / 2 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 82 | Journal du projet | tous | 2 | 2 (1 / 1 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 83 | Médias et preuves | tous | 1 | 3 (1 / 2 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 84 | Nouvelle campagne | tous | 1 | 3 (2 / 1 / 0 / 0) | 5 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 84b | Financement | tous | 1 | 2 (0 / 1 / 0 / 1) | 0 | 9 | — | 0 | **BLOQUÉ PAR UNE DÉPENDANCE** | action en attente d'un service (paiement, diffusion, messagerie mentor) |
| 85 | Objectifs et jalons | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 13 | — | 0 | **DONNÉES FICTIVES** | 13 données de maquette visibles, aucune source serveur |
| 86 | Résultats de campagne | tous | 1 | 1 (0 / 1 / 0 / 0) | 0 | 10 | — | 0 | **DONNÉES FICTIVES** | 10 données de maquette visibles, aucune source serveur |
| 87 | Registre des innovations | tous | 2 | 3 (0 / 3 / 0 / 0) | 1 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| 88 | Espace entreprise | admin,company | 1 | 6 (0 / 6 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 89 | Profil de l’entreprise | admin,company | 1 | 12 (1 / 11 / 0 / 0) | 0 | 1 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 1 donnée(s) de maquette |
| 90 | Publier un besoin | admin,company | 3 | 3 (2 / 1 / 0 / 0) | 5 | 1 | — | 1 | **CONNECTÉ ET FONCTIONNEL** | preuve : test local (1) |
| 91 | Rechercher des talents | admin,company | 1 | 9 (0 / 9 / 0 / 0) | 1 | 4 | — | 0 | **DONNÉES FICTIVES** | 4 données de maquette visibles, aucune source serveur |
| 93 | Propositions reçues | admin,company | 1 | 2 (0 / 2 / 0 / 0) | 0 | 12 | — | 0 | **DONNÉES FICTIVES** | 12 données de maquette visibles, aucune source serveur |
| 93b | Proposition | admin,company | 1 | 3 (2 / 1 / 0 / 0) | 0 | 4 | — | 0 | **CONNECTÉ MAIS PARTIEL** | serveur branché mais 4 données de maquette visibles |
| 94 | Comparer les propositions | admin,company | 3 | 2 (0 / 2 / 0 / 0) | 0 | 11 | — | 0 | **DONNÉES FICTIVES** | 11 données de maquette visibles, aucune source serveur |
| 95 | Devis et négociations | admin,company | 1 | 6 (0 / 6 / 0 / 0) | 0 | 9 | — | 0 | **DONNÉES FICTIVES** | 9 données de maquette visibles, aucune source serveur |
| 95b | Demande de devis | admin,client,company,dept,other,student | 1 | 2 (1 / 1 / 0 / 0) | 5 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| 96 | Défis d’innovation | admin,company | 2 | 8 (0 / 8 / 0 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 97 | Recrutement | admin,company | 1 | 8 (0 / 8 / 0 / 0) | 0 | 2 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre ; 2 donnée(s) de maquette |
| 98 | Collaborations | admin,company | 1 | 6 (0 / 6 / 0 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| 99 | Historique | admin,company | 2 | 6 (0 / 6 / 0 / 0) | 0 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| A1 | Assistante vocale Kéla | tous | 3 | 7 (0 / 7 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| A2 | Accueil Kéla | tous | 0 | 8 (0 / 8 / 0 / 0) | 0 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | décision 01/11 : échantillon de 231, mêmes destinations ; preuve : test |
| A3 | Voix en texte | tous | 1 | 11 (0 / 11 / 0 / 0) | 1 | 5 | — | 0 | **DONNÉES FICTIVES** | 5 données de maquette visibles, aucune source serveur |
| D1 | Tableau de bord du studio | tous | 2 | 4 (0 / 4 / 0 / 0) | 2 | 24 | — | 0 | **DONNÉES FICTIVES** | 24 données de maquette visibles, aucune source serveur |
| L1 | Aller en direct | tous | 2 | 5 (0 / 4 / 0 / 1) | 0 | 1 | — | 0 | **BLOQUÉ PAR UNE DÉPENDANCE** | action en attente d'un service (paiement, diffusion, messagerie mentor) |
| P1 | Profil talent | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 3 | — | 0 | **DONNÉES FICTIVES** | 3 données de maquette visibles, aucune source serveur |
| P2 | Profil talent · abonnement | tous | 1 | 8 (0 / 8 / 0 / 0) | 0 | 8 | — | 0 | **DONNÉES FICTIVES** | 8 données de maquette visibles, aucune source serveur |
| P3 | Avis et outils connectés | tous | 4 | 6 (0 / 6 / 0 / 0) | 0 | 7 | — | 0 | **DONNÉES FICTIVES** | 7 données de maquette visibles, aucune source serveur |
| P4 | Nouvelle publication | tous | 0 | 1 (0 / 1 / 0 / 0) | 0 | 0 | — | 0 | **NON VÉRIFIÉ** | lot 7 : variante de 250, « Publier » réel |
| P5 | Connecter mes outils | tous | 2 | 6 (1 / 5 / 0 / 0) | 1 | 0 | — | 0 | **NON VÉRIFIÉ** | aucun test fonctionnel ne l'ouvre |
| S1 | Démarrage animé | tous | 0 | 0 (0 / 0 / 0 / 0) | 0 | 0 | — | 0 | **CONNECTÉ ET FONCTIONNEL** | décision 01/11 : écran de démarrage → 01 ; preuve : test local et Playwright en ligne |
| V1 | Vitrine | tous | 1 | 9 (0 / 9 / 0 / 0) | 0 | 6 | — | 0 | **DONNÉES FICTIVES** | 6 données de maquette visibles, aucune source serveur |
