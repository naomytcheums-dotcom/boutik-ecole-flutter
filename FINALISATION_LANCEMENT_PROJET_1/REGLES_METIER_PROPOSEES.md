# Règles métier proposées — base de travail (à valider)

Date : 01/11/2026. Document rédigé à votre demande, pour débloquer les phases « concours » et « données de maquette ».

Chaque règle part de ce qui **existe déjà** : maquettes validées, code, schéma de la base. Elle n'invente rien de contraire au design.

Les montants et les seuils repris des maquettes sont signalés « (maquette) ». Les ajouts sont signalés « (proposé) ».

**Principe commun : aucun argent n'est versé, prélevé ni promis comme disponible tant que le paiement Mobile Money n'est pas activé.**

Avant activation :
- les gains et les prix sont **enregistrés** (« acquis, versement à l'activation des paiements ») ;
- aucun écran n'affiche « payé » ou « versé ».

---

## 1. Concours et hackathons (écrans 160 à 169, 178)

### 1.1 Publication (168, 169)
| Règle | Valeur | Origine |
|---|---|---|
| Qui publie | Département ou administrateur. Les entreprises **proposent** (défis 96) ; le département valide et publie. | accès actuel de 168 et 169 (`dept`, `admin`) |
| Champs obligatoires | titre ; date de clôture des inscriptions ; dates de début et de finale ; lieu, ou « en ligne » ; dotation en FCFA (0 autorisé) ; nombre de places (équipes) ; thématique, critères et conditions | champs de 168 et 161 (maquette) |
| États | brouillon → publié → inscriptions closes → en cours → jury → résultats publiés → archivé. Annulation possible jusqu'à « en cours », avec notification des inscrits. | (proposé) |
| Modification après publication | Les dates et la dotation ne peuvent qu'être **prolongées ou augmentées**. Toute modification est journalisée (audit). | (proposé) |

### 1.2 Inscription (162, 163)
| Règle | Valeur | Origine |
|---|---|---|
| Qui peut s'inscrire | Comptes **étudiants** connectés (rôle `student`). Les autres rôles peuvent suivre le concours. | (proposé) ; cohérent avec « talents » |
| Format | Individuel, ou en équipe de **2 à 5 membres**, avec un capitaine | « Individuelle / En équipe », « Capitaine » (maquette) |
| Règlement | Acceptation obligatoire, enregistrée avec la date | « J'accepte le règlement » (maquette) ; `hackathon_teams.rules_accepted` existe |
| Places | Une place = une équipe ou un candidat individuel. Inscriptions refusées quand les places sont pleines ou la date de clôture passée. | `placesLeft` existe (code) |
| Unicité | Une seule équipe par étudiant et par concours | (proposé) |
| Coéquipiers (163) | Invitation par le capitaine, acceptée par l'invité. Recherche dans l'annuaire des talents. | (maquette) |

### 1.3 Dépôt du projet (165)
| Règle | Valeur | Origine |
|---|---|---|
| Contenu | Titre, description, lien de démonstration (facultatif), présentation PDF ≤ **10 Mo**, vidéo ≤ **2 minutes** | (maquette) |
| Originalité | Case « Je certifie que le projet est original » obligatoire | (maquette) |
| Échéance | Dépôt modifiable jusqu'à l'heure limite, verrouillé ensuite | « Dépôt possible jusqu'au… » (maquette) |
| Un dépôt par équipe | Oui ; seul le capitaine soumet | (proposé) |
| Stockage | Fichiers privés, visibles de l'équipe, du jury et du département. Mêmes contrôles que les dossiers de mission (31b et 31c). | cohérent avec 31b et 31c |

### 1.4 Jury et notation (167, 178)
| Règle | Valeur | Origine |
|---|---|---|
| Jurés | Désignés par le département pour chaque concours, parmi les comptes existants : enseignants, entreprises partenaires, personnel. **Aucun nouveau rôle** n'est nécessaire. | 178 « Bienvenue, jury » ; rôles actuels |
| Conflit d'intérêts | Un juré ne note pas une équipe dont il est membre ou encadrant | (proposé) |
| Critères | Innovation, Faisabilité, Impact social, Qualité du pitch : **chacun sur 10, total sur 40** | (maquette 167) |
| Note finale | Moyenne des jurés ayant noté. Le classement n'est publiable que si **tous** les projets ont au moins 2 notes. | (proposé) |
| Égalité | Départage par Innovation, puis Impact social, puis l'heure du dépôt | (proposé) |
| Commentaire | Facultatif, visible de l'équipe après publication des résultats | (proposé) |

### 1.5 Résultats et récompenses (166)
| Règle | Valeur | Origine |
|---|---|---|
| Publication | Par le département, après vérification. Le classement devient public. | (proposé) |
| Prix en argent | Enregistré comme « prix attribué ». **Versé hors plateforme par l'organisateur** tant que Mobile Money n'est pas activé ; jamais affiché « payé » sans preuve. | principe commun |
| Prix non monétaires | Mentorat (3 mois), visibilité, Passeport des talents | (maquette 166) |
| Certificat | Délivré aux lauréats par la fonction existante `issue_certificate` (type `project` ou `talent`) | 31a et 31c (existant) |

### 1.6 Modération (169)
Le département peut masquer une équipe ou un dépôt contraire au règlement (motif obligatoire, journalisé). L'équipe est notifiée.

---

## 2. Reels et lives (245, 246, 250, P4, 250b, L1, 222 à 227)

### 2.1 Reels (vidéos courtes)
| Règle | Valeur | Origine |
|---|---|---|
| Qui publie | Comptes **étudiants** et **département**. Les entreprises publient sur leur page (P1 et P2). | (proposé) |
| Format | Vidéo ≤ **60 s**, ≤ **50 Mo**, en MP4 ou MOV ; légende ≤ 300 caractères ; mots-clés | (proposé) ; légende et mots-clés visibles en 250 |
| Lien « Boutique » | Seulement vers une **annonce approuvée appartenant à l'auteur** | bouton « Boutique » (maquette 245) ; règle de propriété des annonces (code) |
| Publication | Immédiate pour les comptes certifiés ; **après validation** du département pour les autres | certification existante (`request_certification`) |
| Signalement | Bouton « Signaler », traité par le support | signalements existants (20261101000000) |
| « Propulser » (boost payant) | **Désactivé** tant que les paiements ne sont pas activés (déjà le cas) | `unavailableAction` existant |
| Publication sur les réseaux externes (Instagram, TikTok…) | Lien de partage uniquement ; aucune connexion de compte externe au lancement | (proposé) ; évite des intégrations non sécurisées |
| Droits | Son original ou libre de droits ; l'auteur certifie détenir les droits | (proposé) |

Rôle des écrans en double, une fois la publication créée :
- **250** : écran principal de publication ;
- **P4** : premier état, avant le choix du média (« Photo ou vidéo ») ;
- **250b** : état « mention d'un compte » (comptes suggérés).

### 2.2 Lives
**Dépendance externe** : un fournisseur de diffusion vidéo (choix et coût à valider). En attendant, « Aller en direct » reste indisponible, avec son message actuel.

Règles prévues :
- réservé aux comptes certifiés et au département ;
- programmation obligatoire (date, titre) ;
- modération en direct par la régie (227).

---

## 3. Parrainage (240) et gains (243)

### 3.1 Barème — on garde les paliers et montants de la maquette, en changeant **le déclencheur**
| Palier | Filleuls actifs | Prime par filleul actif | Part des ventes du filleul | Origine |
|---|---|---|---|---|
| Bronze | 1 à 4 | 500 FCFA | — | (maquette) |
| Argent | 5 à 19 | 750 FCFA | 2 % | (maquette) |
| Or | 20 et plus | 1 000 FCFA | 3 % | (maquette) |

**Correction de cohérence (importante)** : la maquette dit « chaque ami **inscrit** te rapporte ». Payer à l'inscription ouvre la porte aux faux comptes et coûte de l'argent sans recette.

Règle proposée : un filleul devient **actif** à sa **première commande payée d'au moins 10 000 FCFA**, ou à sa première mission payée, dans les **90 jours** qui suivent son inscription. Le texte « par inscrit » de 240 devient « par filleul actif ».

### 3.2 Financement et plafonds
| Règle | Valeur |
|---|---|
| Commission de la plateforme sur les produits | **10 %** (proposé), alignée sur la part plateforme des missions (règle 70 / 20 / 10 déjà codée) |
| Part des ventes (2 ou 3 %) | Prélevée **sur la commission de 10 % de la plateforme**, jamais sur le vendeur. Durée : 12 mois après le parrainage. |
| Plafond | 50 filleuls actifs rémunérés par mois et par parrain |
| Exclusions | Auto-parrainage, même téléphone ou même appareil, comptes du personnel, commandes annulées ou remboursées |

### 3.3 Gains (243)
| Règle | Valeur |
|---|---|
| Statuts d'un gain | **En attente** pendant 14 jours (délai d'annulation), puis **disponible**. Annulé si la commande est annulée. |
| Retrait vers Orange Money | Minimum **5 000 FCFA** ; compte certifié ; **désactivé tant que Mobile Money n'est pas activé**. Le bouton affiche alors la raison et ne simule rien. |
| Journal | Chaque gain est une ligne horodatée : source, filleul abrégé (« Brice N. »), montant, statut |
| Identité des filleuls | Prénom et initiale seulement |

---

## 4. Défis, points et badges (253, 253b)

| Règle | Valeur | Origine |
|---|---|---|
| Nature | Points et **boosts de visibilité** uniquement. **Jamais convertibles en argent**, ce qui évite tout jeu d'argent. | (proposé) |
| Série quotidienne | 1 connexion par jour ; à 6 jours, un boost de 24 h | (maquette 253) |
| Défis de la semaine | Publier 3 posts : +200 pts ; lancer un live : +500 pts ; répondre à 5 commentaires : +100 pts | (maquette) ; « live » inactif tant que les lives le sont |
| Boost | Mise en avant d'un post pendant 24 h dans « Découvrir » ; 1 boost actif à la fois | (proposé) |
| Badges | Première vente, 100 abonnés, Live star, Top 10, calculés à partir de données réelles | (maquette) |

---

## 5. Livraison (07, 27, 41, 46)

| Règle | Valeur | Origine |
|---|---|---|
| Mode par défaut | **Retrait sur campus**, gratuit, au kiosque, avec le **code à 6 chiffres** (5 essais) | existant et testé (31c) |
| Livraison à domicile | Activée **à Douala uniquement** ; frais **5 000 FCFA** ; délai **72 h ouvrées** après la mention « prête » | 5 000 FCFA déjà codés dans `create_order` |
| Qui livre | L'équipe logistique de l'IUT (rôle `support`). La remise est confirmée par **le même code à 6 chiffres** que l'acheteur donne au livreur. | réutilise `confirm_pickup` (aucun nouveau circuit de confiance) |
| Échec | 2 tentatives, puis retour au kiosque ; l'acheteur est notifié et peut retirer sur campus | (proposé) |
| Carnet d'adresses (27, 41) | Destinataire, téléphone, ville et quartier, adresse précise, point de repère ; 5 adresses au plus ; visibles seulement du titulaire et, pour une commande, du livreur | champs de 41 (maquette) |
| Suivi (46) | Nouvelle → acceptée → en préparation → prête → **en livraison** → livrée | états 0 à 4 existants, plus un état « en livraison » (proposé) |

**Si aucune équipe logistique n'est disponible au lancement**, le serveur doit refuser la livraison à domicile, et l'écran 07 l'indique : « Livraison à domicile non proposée pour le moment ». Aucun frais n'est alors facturé.

---

## 6. Vérification de cohérence

| # | Contrôle | Résultat |
|---|---|---|
| C1 | Aucune règle ne verse d'argent sans Mobile Money actif | ✅ prix, gains et retraits « enregistrés », jamais « payés » |
| C2 | Les primes de parrainage ont une source de financement | ✅ part des ventes prise sur la commission de 10 % ; prime versée seulement après une vraie commande payée ≥ **10 000 FCFA**, dont la commission (≥ 1 000 F) couvre la prime la plus haute (1 000 F, palier Or). Avec un seuil de 5 000 F, la prime Or aurait dépassé la commission : seuil corrigé lors de cette vérification. |
| C3 | Les pourcentages ne dépassent pas la part de la plateforme | ✅ 2 % et 3 % < 10 % (produits) ; missions : la part plateforme est de 10 % (règle 70 / 20 / 10 existante) |
| C4 | Les rôles utilisés existent déjà | ✅ `student`, `dept`, `admin`, `support`, `company` ; jurés désignés par concours, sans nouveau rôle |
| C5 | Les montants et seuils des maquettes sont conservés | ✅ paliers 500 / 750 / 1 000 F, 2 % et 3 %, notes sur 10 et 40, PDF de 10 Mo, vidéo de 2 min, livraison à 5 000 F. Seul « par inscrit » devient « par filleul actif ». |
| C6 | Aucune règle ne contredit le code testé | ✅ code de retrait réutilisé, frais de livraison identiques, certificats par `issue_certificate`, signalements existants |
| C7 | Points non convertibles en argent | ✅ pas de risque de jeu d'argent |
| C8 | Données personnelles minimisées | ✅ filleuls en « Prénom I. », adresses visibles du seul titulaire et du livreur, fichiers de concours privés |

## 7. Ce que ces règles impliquent techniquement (migrations locales, testées sur la réplique)

1. **Concours** :
   - tables `contests`, `contest_teams` (prolonge `hackathon_teams`), `contest_members`, `contest_submissions`, `contest_jurors`, `contest_scores`, plus une vue de classement ;
   - fonctions de publication, d'inscription, de dépôt, de notation et de publication des résultats, avec la RLS correspondante.
2. **Livraison** : table `addresses`, colonnes d'adresse sur `orders`, état « en livraison », réglage `home_delivery_enabled` vérifié par `create_order`.
3. **Parrainage et gains** : `referral_codes`, `referrals`, `earnings` (registre en attente / disponible / annulé), déclencheur sur la première commande payée.
4. **Reels et défis** : `posts` (vidéo, légende, annonce liée, statut de modération), `post_reports`, `points_ledger`, `boosts`.

Aucune de ces migrations ne sera appliquée en production sans votre autorisation.
