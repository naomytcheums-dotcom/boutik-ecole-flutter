# 09 — Registre des anomalies

Audit réalisé le 29 octobre 2026, en lecture seule (aucun déploiement, aucun commit, aucune donnée de production créée ou modifiée). Chaque fiche indique son statut de vérification : **VÉRIFIÉ** (code ou mesure identifiés), **PROBABLE**, **NON VÉRIFIABLE**, **NON IMPLÉMENTÉ**, **À CONFIRMER**.

**Décompte (après recensement) : 30 anomalies — P0 : 3 · P1 : 11 · P2 : 13 · P3 : 3.** **Mise à jour (2e passe) : AN-004 et AN-022 corrigées et testées ; AN-005 corrigée mais non vérifiée.** **Mise à jour du 29 octobre 2026 : les 3 P0 sont corrigés et vérifiés sur la production (voir « Correctif » dans chaque fiche) ; il reste 27 anomalies ouvertes (P1 : 11, P2 : 13, P3 : 3).** Une anomalie « VÉRIFIÉ par le code » n'a pas été exploitée sur la production (règle de l'audit) ; son exploitabilité découle de la lecture du schéma et de la fonction serveur.

---

## P0 — Critiques

### AN-001 · Un utilisateur peut s'attribuer le rôle administrateur — ✅ CORRIGÉ (29/10/2026)
- **Correctif appliqué** : déclencheur `trg_protect_profile` (seul un administrateur modifie `role`/`suspended`) + `WITH CHECK` sur la mise à jour (`supabase/migrations/20261029_p0_securite.sql`). **Vérifié** sur la production avec un compte jetable (supprimé ensuite) : `PATCH role=admin` → erreur `P0001` ; insertion d'un profil `admin` → erreur RLS `42501`.
- **Domaine** : sécurité / permissions (base de données). **Statut** : VÉRIFIÉ par le code du schéma.
- **Description** : la règle RLS `profil modifiable par soi` autorise la mise à jour de la ligne `profiles` de l'utilisateur sans restriction de colonnes ni `WITH CHECK`. La colonne `role` y figure.
- **Preuve** : `supabase/schema.sql:124` — `for update using (id = auth.uid())`. Aucune contrainte ni trigger n'empêche la modification de `role` ou `suspended`.
- **Reproduction (non exécutée sur la production)** : se connecter avec n'importe quel compte, puis envoyer `PATCH /rest/v1/profiles?id=eq.<son id>` avec `{"role":"admin"}` et son jeton.
- **Attendu** : le rôle ne change que par un administrateur. **Constaté** : changement possible par l'utilisateur lui-même (par déduction).
- **Cause racine** : politique d'écriture trop large ; pas de séparation entre colonnes modifiables par l'utilisateur et colonnes d'autorité.
- **Impact** : prise de contrôle des politiques fondées sur `current_role_name()` (annonces, commandes, journal, missions).
- **Correction** : retirer le droit d'UPDATE sur `role`/`suspended` (privilèges de colonnes ou trigger `BEFORE UPDATE` qui refuse leur changement hors admin) ; ajouter `WITH CHECK`.
- **Critères d'acceptation** : un utilisateur standard reçoit une erreur en modifiant `role` ; un admin peut le faire.
- **Test de non-régression** : test SQL/REST avec deux comptes (standard, admin).

### AN-002 · Comptes de démonstration, dont l'administrateur, présents en production avec un mot de passe public — ✅ CORRIGÉ (29/10/2026)
- **Correctif appliqué** : les 8 comptes sont rétrogradés (`role='client'`), suspendus, bannis (`banned_until`), leur mot de passe est invalidé et leurs sessions supprimées. **Vérifié** : connexion avec l'ancien mot de passe → `user_banned` ; 0 profil privilégié. Les comptes ne sont pas supprimés (réversible). Les identifiants restent lisibles dans le code de démonstration de l'application (usage local uniquement) : la séparation complète des environnements reste recommandée (étape 0.1).
- **Domaine** : sécurité / configuration. **Statut** : VÉRIFIÉ (création faite pendant le développement ; mot de passe lisible dans le code).
- **Description** : 8 comptes ont été créés dans la base de production (`admin@boutik-ecole.cm` rôle `admin`, `finance@…`, `direction@…`, etc.) avec le mot de passe le mot de passe de démonstration (visible dans `auth.dart`), lequel figure en clair dans `lib/figma/live/auth.dart:52-60` et donc dans `main.dart.js` public.
- **Impact** : toute personne lisant le code peut se connecter à Supabase en administrateur global (rôle `admin` dans `profiles`).
- **Cause racine** : jeu de données de démonstration déployé dans le même environnement que la production.
- **Correction** : supprimer ou désactiver ces comptes avant toute utilisation réelle, séparer les environnements (projet Supabase de démonstration distinct), changer les mots de passe.
- **Critères d'acceptation** : aucune connexion possible avec le mot de passe de démonstration (visible dans `auth.dart`) ; plus de profil `admin` de démonstration.
- **Test** : tentative de connexion avec les anciens identifiants → refus.

### AN-003 · Les montants, l'état de paiement et le statut d'une commande sont dictés par le client — ✅ CORRIGÉ (29/10/2026)
- **Correctif appliqué** : suppression de l'insertion directe sur `orders`/`order_lines` ; fonction `create_order` (security definer) qui recalcule les prix depuis `listings` (catalogue de la plateforme de 11 articles, `seller_id` nul), force `paid=false`, `status=0`, `reference=null`, numérote par séquence serveur. L'application l'utilise (`Backend.createOrder`). **Vérifié** : insertion directe avec `paid=true` → refusée (`42501`) ; produit inconnu → `Produit indisponible` ; commande valide de 2 « Jus de bissap » + livraison → sous-total 3 000, frais 5 000, `paid=false` ; appel anonyme → `permission denied`. Conséquences : seuls les articles du catalogue serveur peuvent être commandés (les annonces créées par des vendeurs ne sont pas encore côté serveur, AN-007) ; le stock n'est toujours pas décrémenté (AN-008).
- **Domaine** : commandes / paiements. **Statut** : VÉRIFIÉ par le code.
- **Description** : la règle `un client passe sa commande` n'impose que `buyer_id = auth.uid()` ; le client choisit `subtotal`, `fee`, `paid`, `status`, `reference`. La fonction `pay` calcule le montant à prélever à partir de `order.subtotal + order.fee` lus en base.
- **Preuve** : `supabase/schema.sql:137` ; `supabase/functions/pay/index.ts:41` ; `lib/figma/live/backend.dart` (`saveOrder` envoie `subtotal`, `fee`, `status`, `paid`).
- **Reproduction (non exécutée)** : insérer une commande avec `subtotal = 1`, `paid = true`.
- **Impact** : prix falsifiables ; commandes marquées payées sans paiement.
- **Cause racine** : absence de calcul serveur des montants (aucune table de prix serveur utilisée ; le catalogue est local).
- **Correction** : créer les commandes uniquement par une fonction serveur qui recalcule les prix depuis une table `listings`, force `paid=false`, `status=0`, ignore `reference` ; retirer le droit d'INSERT direct.
- **Critères d'acceptation** : une commande insérée avec un faux montant est rejetée ou corrigée ; `paid` ne passe à vrai que par la confirmation du fournisseur.
- **Test** : tests d'API avec valeurs falsifiées.

---

## P1 — Bloquants

### AN-004 · Auto-validation d'annonce par le vendeur — ✅ CORRIGÉE ET TESTÉE (29/10/2026)
- **Preuve** (transaction annulée, aucune donnée conservée) : insertion avec `status=approved` → enregistrée `pending` ; mise à jour vers `approved` par le vendeur → refusée (« Seul le département peut valider ou refuser une annonce »).
- **Statut** : VÉRIFIÉ par le code. `supabase/schema.sql:132` — `for update using (seller_id = auth.uid() or …)` sans `WITH CHECK` : un vendeur peut passer `status` à `approved`.
- **Impact** : la validation par le département peut être contournée. **Correction** : séparer les colonnes (le vendeur ne modifie pas `status`) ; transition contrôlée côté serveur. **Test** : mise à jour de `status` par un étudiant → refus.

### AN-005 · Paiement : rejeu de référence et montant non vérifié — CORRIGÉE ET VÉRIFIÉE EN SANDBOX (30/10/2026) ; reste ouvert : webhook signé
- **Vérification 30/10/2026 (sandbox, compte jetable)** : modification directe de `orders.paid`/`reference` par l'acheteur → 0 ligne modifiée, commande restée non payée ; commande d'un autre utilisateur → 404 ; relance sur commande déjà payée → 409 `already_paid` ; numéro non camerounais → 400. Le contrôle montant/devise n'a pas été exercé avec un cas de sous-paiement (le sandbox ne permet pas de le provoquer).
- **Déploiement confirmé** : la fonction `pay` en ligne applique le nouveau CORS (origine `https://boutik-ecole.vercel.app` renvoyée même pour une origine étrangère). Les contrôles référence/montant/devise sont dans le code déployé mais n'ont pas pu être exercés sans clé Notch Pay.
- **Effet du correctif AN-003** : `orders.reference` n'est plus écrivable par le client (seule la fonction `pay` la renseigne) et le montant prélevé vient d'une commande calculée par le serveur. **Reste ouvert** : comparaison du montant/devise renvoyés par Notch Pay et webhook signé.
- **Statut** : VÉRIFIÉ par le code. `pay/index.ts:57-66` : l'action `status` lit `order.reference` (colonne écrite par le client à la création) puis marque la commande payée si Notch Pay renvoie `complete`. Rien ne contrôle que la référence appartient à cette commande ni que le montant payé correspond.
- **Impact** : une commande peut être marquée payée avec la référence d'un autre paiement terminé. **Correction** : ne stocker la référence que côté serveur, comparer montant et devise à la réponse du fournisseur, ajouter un webhook signé (HMAC `X-Notch-Signature`). **Test** : référence étrangère → refus.

### AN-006 · L'authentification de l'application est locale ; le serveur n'est qu'un miroir
- **Statut** : VÉRIFIÉ. `lib/figma/live/auth.dart:168-197` (`submitLogin`) valide l'identifiant et le mot de passe contre la liste en mémoire (`seedAccounts` + comptes inscrits), puis appelle `Backend.signIn` en second plan ; en cas d'échec serveur il crée le compte (`backend.dart:36`).
- **Impact** : l'interface se déverrouille sans session serveur ; les mots de passe sont stockés en clair dans l'état de l'application (`Account.password`) ; un compte local peut diverger du compte serveur (mot de passe changé localement mais pas côté serveur).
- **Correction** : faire de Supabase Auth la seule source de vérité (session, réinitialisation, vérification), supprimer `Account.password`. **Test** : connexion refusée si le serveur refuse.

### AN-007 · La plupart des données métier ne sont pas persistées
- **Statut** : VÉRIFIÉ. Appels serveur de l'application : `profiles`, `orders`, `order_lines`, `audit_log`, fonction `pay` (`backend.dart`, `pay.dart`). Tout le reste (annonces, stocks, favoris, missions, hackathons, chat, validations, signalements, QR de la borne, talents, projets, configuration des commissions) est un état Riverpod en mémoire (`lib/figma/live/*.dart`, 95 providers) : perdu au rechargement. Les tables `listings`, `favorites`, `missions`, `hackathon_teams`, `kiosk_sessions` existent mais ne sont jamais lues ni écrites.
- **Impact** : deux utilisateurs ne voient jamais les mêmes données ; une annonce créée par un vendeur n'atteint pas le département. **Correction** : brancher chaque module sur la base (dépôts de données), avec chargement initial et mise à jour. **Test** : créer, recharger, relire.

### AN-008 · Le stock n'est jamais décrémenté et rien ne contrôle les quantités
- **Statut** : VÉRIFIÉ. `Orders.place()` (`store.dart:122-139`) ne touche pas aux annonces ; `setStock` n'est appelé que depuis l'écran de gestion manuelle (`seller.dart:46`). Aucune vérification stock ≥ quantité, aucune protection contre la concurrence.
- **Impact** : survente. **Correction** : décrément transactionnel côté serveur lors de la création de commande. **Test** : deux commandes concurrentes pour le dernier exemplaire.

### AN-009 · Numéros de commande générés côté client, double insertion, échecs silencieux — PARTIELLEMENT CORRIGÉ
- **Effet du correctif AN-003** : numérotation par séquence serveur, une seule création (RPC), erreur affichée à l'utilisateur et commande locale annulée en cas d'échec lors du paiement. **Reste ouvert** : les autres écritures (`audit_log`, profil) ignorent encore les erreurs (AN-010).
- **Statut** : VÉRIFIÉ. `store.dart:118,128` (`_n = 143`, compteur local) ; `Backend.saveOrder` est appelé deux fois pour le même paiement (`store.dart:137` et `pay.dart:116`). `orders.number` est unique : deux appareils produisent les mêmes numéros → la seconde insertion échoue sans message.
- **Impact** : commandes absentes de la base sans alerte ; le paiement échoue ensuite (« commande introuvable »). **Correction** : numérotation par séquence serveur, une seule insertion, erreurs remontées à l'utilisateur.

### AN-010 · Les erreurs serveur sont ignorées ; l'écran annonce un succès
- **Statut** : VÉRIFIÉ. `backend.dart` : 5 blocs `catch (_) {}`. Exemple : inscription (« Code envoyé… ») affichée même si Supabase refuse l'inscription.
- **Impact** : états incohérents entre interface et serveur. **Correction** : propager les erreurs, afficher un message et ne pas avancer. **Test** : serveur simulé en échec → message d'erreur.

### AN-011 · Vérification par code simulée et confirmation d'e-mail désactivée
- **Statut** : VÉRIFIÉ. Le code de vérification est constant (`auth.dart:53`, `demoCode = '482917'`, affiché dans le message) ; aucune SMS n'est envoyée. Côté Supabase, « Confirm email » a été désactivé à la demande du propriétaire.
- **Impact** : n'importe qui peut ouvrir un compte avec une adresse ou un téléphone qui ne lui appartient pas. **Correction** : fournisseur SMS/e-mail réel, réactiver la confirmation. **Test** : inscription impossible sans code reçu.

### AN-012 · Les tableaux de bord affichent des données de démonstration
- **Statut** : VÉRIFIÉ. Historique de commandes codé en dur (`store.dart:159-171`, `_history`), liste d'utilisateurs issue de `seedAccounts` (`admin.dart:12`), annonces d'origine dans `seller.dart:37-43`. Les indicateurs ne proviennent pas de la base.
- **Impact** : les chiffres ne reflètent aucune activité réelle. **Correction** : calculs côté serveur (vues SQL) selon le rôle.

### AN-013 · Le contrôle d'accès par rôle n'existe que dans l'application
- **Statut** : VÉRIFIÉ. `AccessGuard`/`allowedRoles` (`access.dart:43-90`) déduit les droits du *numéro d'écran* ; les écrans d'administration lisent des états locaux, donc aucune règle serveur ne les protège. Modifier l'état local (ou lire le bundle) suffit à les afficher.
- **Impact** : aucune garantie réelle tant que les données restent locales ; une fois branchées sur la base, il faudra que chaque requête soit protégée par RLS. **Correction** : voir plan (phase backend).

### AN-014 · Paiement Mobile Money non vérifié de bout en bout
- **Mise à jour 30/10/2026** : clé configurée ; sandbox MTN `+237670000000` : création → prélèvement → statut `complete` (commandes #BE-2026-0146/0147/0150 testées) ; `+237670000004` → `failed`. Le numéro `+237670000001` a été validé `complete` (et non « solde insuffisant » comme la documentation le laissait attendre) : comportement du sandbox à reconfirmer. Orange Money et production non testés ; le webhook signé reste à faire.
- **Statut initial** : NON VÉRIFIABLE. La clé Notch Pay n'était pas configurée côté serveur pendant l'audit (la fonction répond `not_configured`, mesuré). Les points d'accès de la documentation du fournisseur sont partiellement contradictoires (`/payment` vs `/payments`).
- **Impact** : parcours de paiement principal non prouvé. **Test à réussir** : paiement de test (numéro `+237 670 00 00 00`) → commande payée ; échec `…000001` ; annulation `…000004`.

---

## P2 — Importants

- **AN-015 · 222 écrans sur 315 sans aucun lien entrant** (VÉRIFIÉ, analyse des `gOpen`/`gTab`) : accessibles uniquement par l'adresse ou `/catalogue`. Parcours incomplets. Correction : cartographier les liens métier et les ajouter.
- **AN-016 · 192 actions « Démonstration : … » sur 129 écrans** (VÉRIFIÉ, `lib/figma/g/*`) : boutons qui n'affichent qu'un message. Correction : implémenter par groupes fonctionnels.
- **AN-017 · 10 écrans statiques** (34, 38, 81, 85, 86, 172, 225, 226, 281, S1) : aucune interaction.
- **AN-018 · Poids de l'application** (VÉRIFIÉ, mesure) : `main.dart.js` = 9,06 Mo (13,4 s téléchargé depuis le poste d'audit), 1 950 fichiers d'assets, 66 Mo de build ; plus de 480 requêtes au premier affichage. Correction : chargement différé des écrans et des images, compression, formats d'image légers.
- **AN-019 · Mise en page non adaptative** (VÉRIFIÉ par le code, `gen.dart` : `FittedBox`) : chaque écran est une toile de taille fixe mise à l'échelle. Les consoles web (1280 px) deviennent illisibles sur téléphone.
- **AN-020 · Clavier mobile** (PROBABLE) : `resizeToAvoidBottomInset: false` (`gen.dart:38`) évite le redimensionnement de la toile mais peut laisser le clavier masquer un champ ; non testé sur appareil.
- **AN-021 · Accessibilité non vérifiée** (NON VÉRIFIÉ) : positions absolues, contrastes de gris clair, zones tactiles et sémantique (lecteur d'écran) jamais mesurés ; voir `docs/ACCESSIBILITY.md` pour l'existant.
- **AN-022 · Journal d'audit falsifiable — ✅ CORRIGÉE ET TESTÉE (29/10/2026)** : écriture directe refusée (RLS) ; `log_audit` écrit avec l'acteur pris dans le profil (« Test », non fourni par le client). Ancien constat : (VÉRIFIÉ par le code) : `schema.sql:147` laisse tout utilisateur connecté insérer des lignes arbitraires, y compris sous un autre nom (`actor` libre).
- **AN-023 · QR de la borne signé côté client** (VÉRIFIÉ) : `missions.dart:32-40`, empreinte maison avec un secret constant embarqué ; l'usage unique n'existe qu'en mémoire locale.
- **AN-024 · Canal WhatsApp non implémenté** (NON IMPLÉMENTÉ) : écrans 230–236 dessinés sans aucune intégration.
- **AN-025 · Voix et messagerie** (VÉRIFIÉ pour le code, NON VÉRIFIÉ sur appareil) : la transcription utilise le moteur du système (non open source) ; les messages, photos, fichiers et vocaux restent en mémoire locale (`chat.dart`).
- **AN-026 · 32 variantes de la section « Doublons à trancher » non codées** (VÉRIFIÉ par comparaison avec Figma) : en attente d'un choix métier.
- **AN-027 · Deux couches de code** (VÉRIFIÉ) : 472 fichiers Dart dans `lib/features` (ancienne version) restent compilés alors que 315 écrans générés les remplacent ; risque de confusion et poids inutile.

## P3 — Mineurs

- **AN-028 · Pas de Content-Security-Policy** (VÉRIFIÉ, en-têtes de `https://boutik-ecole.vercel.app/`) : présents : HSTS, nosniff, X-Frame-Options, Referrer-Policy.
- **AN-029 · Liens de réseaux sociaux génériques** (VÉRIFIÉ) : `g_10.dart` ouvre les pages d'accueil de Instagram, LinkedIn, TikTok, GitHub, pas les comptes de l'étudiant.
- **AN-030 · Fonction `pay` : CORS `*` et vérification JWT du fournisseur désactivée** (VÉRIFIÉ, `index.ts:7`, paramètres de la fonction) : acceptable car le code contrôle l'utilisateur lui-même, mais à documenter et à restreindre au domaine de production.
