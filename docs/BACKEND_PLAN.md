# Plan back-end Boutik-École

> **État : rien de ce qui suit n'est implémenté.** L'application Flutter tourne entièrement sur des données de démonstration locales (`lib/data/demo`). Les écrans affichent des droits, des paiements, des QR signés ou des certificats, mais **aucune de ces garanties n'existe tant que le serveur ci-dessous n'est pas construit et que ses tests ne passent pas.**

Les dépôts de `lib/data/repositories` sont l'unique point de raccordement : chaque `Provider` de démonstration sera remplacé par une implémentation HTTP (`overrideWithValue`), sans toucher aux écrans.

## Architecture proposée

| Brique | Choix | Raison |
|---|---|---|
| API | Dart Frog ou NestJS, REST + OpenAPI | contrat typé, génération du client Dart |
| Base | PostgreSQL 16 avec Row-Level Security | isolation des institutions au niveau des lignes |
| Fichiers | stockage objet S3-compatible (MinIO / R2) + URLs signées | médiathèque, pièces justificatives |
| Files | Redis + worker (BullMQ ou équivalent) | webhooks, notifications, antivirus |
| Auth | jetons courts (15 min) + jeton de rafraîchissement, 2FA TOTP/SMS | écrans 11–16, 272 |
| Observabilité | journaux structurés, traces OpenTelemetry, Sentry | écran 266 |

Chaque table métier porte `institution_id`. Une politique RLS `institution_id = current_setting('app.institution_id')::uuid` s'applique à toutes les requêtes ; l'API pose ce paramètre en début de transaction à partir du jeton.

---

## 1. Droits par rôle (matrice de l'écran 281)

- **Architecture** : table `role_permissions(role, resource, action)` alimentée depuis la matrice de 281 (lire, écrire, valider) ; vérification par un garde unique côté API (`authorize(user, resource, action)`), jamais côté client. Le client ne fait que masquer des boutons.
- **Test vérifiable** : test d'intégration paramétré qui, pour chaque couple (rôle, action) de la matrice, appelle l'endpoint correspondant avec un jeton de ce rôle et vérifie `200/201` si la case est cochée, `403` sinon. 9 rôles × 3 actions × ressources concernées.
- **Critère de réussite** : 100 % des cas de la matrice conformes ; un test échoue si la matrice et le code divergent (la matrice est la source du test).

## 2. Isolation entre institutions

- **Architecture** : RLS PostgreSQL (ci-dessus) + `institution_id` dans le jeton + clés de cache préfixées par l'institution + préfixe de stockage objet par institution. Le catalogue national (270, 267) passe par une vue `shared_listings` qui ne contient que les fiches explicitement partagées.
- **Test vérifiable** : créer deux institutions A (IUT de Douala) et B ; peupler A ; avec un compte administrateur de B, appeler **tous** les endpoints de liste et de détail (générés depuis l'OpenAPI) et vérifier qu'aucune réponse ne contient un identifiant appartenant à A ; tenter un accès direct par identifiant → `404`.
- **Critère de réussite** : zéro fuite sur 100 % des endpoints ; le test est bloquant en CI.

## 3. Paiements Orange Money / MTN MoMo

- **Architecture** : table `payments(id, order_id, provider, amount, status, provider_ref, idempotency_key)` ; création d'intention côté serveur ; écrans 257 (attente), 258 (échec), 259 (reçu). Webhooks reçus sur `/webhooks/{provider}` : signature vérifiée, puis traitement **idempotent** par `provider_ref` (contrainte d'unicité) dans une transaction qui fait passer la commande à « payée » et écrit le registre.
- **Ventilation 70/20/10** : calculée côté serveur en entiers FCFA (le reliquat d'arrondi va à la plateforme, comme `splitPayment` dans `lib/core/utils/money.dart`), sur la base définie par la réponse à la question 8 de `docs/QUESTIONS.md` (brut ou net après frais et taxes). Écriture en partie double dans `ledger_entries` (écran 284).
- **Test vérifiable** : en mode bac à sable de chaque opérateur : (a) paiement réussi → commande payée, 3 écritures de ventilation dont la somme = net ; (b) même webhook rejoué 5 fois → une seule écriture ; (c) webhook à signature invalide → `401`, aucun effet ; (d) échec opérateur → statut « échoué », tentative comptée (258).
- **Critère de réussite** : (a)–(d) verts sur les deux opérateurs ; somme des parts = montant réparti, au FCFA près.

## 4. QR de borne signé, valable 5 minutes, usage unique (écrans 206–210, 282)

- **Architecture** : le serveur émet un jeton `{kiosk_id, cart_id, exp = now + 300 s, nonce}` signé HMAC-SHA256 (clé par borne, rotation possible) ; le nonce est stocké dans Redis avec TTL 300 s. Au scan, vérification signature + expiration + `DEL nonce` atomique (échec si déjà consommé).
- **Test vérifiable** : (a) scan valide → panier transféré ; (b) 2e scan du même QR → refus « déjà utilisé » ; (c) scan à t + 301 s (horloge simulée) → refus « expiré » ; (d) un octet modifié → refus « signature invalide » ; (e) 50 scans concurrents du même QR → exactement 1 succès.
- **Critère de réussite** : (a)–(e) verts.

## 5. Journal d'audit

- **Architecture** : table `audit_log` en ajout seul (droit `INSERT` uniquement pour le rôle applicatif, pas d'`UPDATE/DELETE`), chaque ligne chaînée par `hash = sha256(prev_hash || payload)`. Toute action sensible (validation, publication, émission/révocation de certificat, changement de rôle, restauration, export) écrit une ligne : auteur, institution, action, cible, date, motif.
- **Test vérifiable** : effectuer chaque action sensible et vérifier la présence de la ligne ; tenter un `UPDATE` avec le rôle applicatif → refus ; modifier une ligne en base avec un super-utilisateur → la vérification de chaîne signale la ligne altérée.
- **Critère de réussite** : 100 % des actions sensibles journalisées ; altération détectée.

## 6. Certificats (empreinte SHA-256, ancrage éventuel) — écrans 173, 174, 283

- **Architecture** : à l'émission, PDF généré côté serveur, empreinte SHA-256 du PDF et des métadonnées stockée dans `certificates` ; page publique de vérification `/verify/{id}` (recalcule et compare l'empreinte) ; états émis / remplacé / révoqué (283). Ancrage blockchain **optionnel** : lot quotidien des empreintes dans un arbre de Merkle dont la racine est publiée (ex. OpenTimestamps), sans données personnelles.
- **Test vérifiable** : émettre → vérification publique « valide » ; modifier un octet du PDF → « non conforme » ; révoquer → « révoqué » avec motif ; si ancrage activé, la preuve Merkle d'un certificat se vérifie contre la racine publiée.
- **Critère de réussite** : les quatre cas conformes ; seuls les rôles autorisés par la matrice (281) peuvent émettre ou révoquer.

## 7. Sauvegardes et restauration (écran 266)

- **Architecture** : sauvegarde complète quotidienne (pg_dump chiffré) + WAL continu (PITR) vers un stockage distinct ; versioning du stockage objet ; restauration de test hebdomadaire automatique dans un environnement isolé.
- **Test vérifiable** : job hebdomadaire qui restaure la dernière sauvegarde, lance les migrations et une suite de contrôles (nombre de lignes par table, intégrité de la chaîne d'audit, une commande connue retrouvée).
- **Critère de réussite** : RPO ≤ 15 min, RTO ≤ 2 h mesurés lors du test ; résultat affiché dans la colonne « Test de restauration » de 266.

## 8. Hors connexion (écrans 150, 182, 183, 276)

- **Architecture** : côté app, cache local (Drift/SQLite) du catalogue et des fiches consultées ; file d'actions en attente (favoris, messages, brouillons) rejouée au retour du réseau avec clé d'idempotence ; les paiements et commandes ne sont **jamais** mis en file (refusés hors ligne, conformément à 276). Côté borne, paquet hors ligne signé (catalogue + images) mis à jour périodiquement.
- **Test vérifiable** : test d'intégration Flutter avec réseau coupé : catalogue consultable ; brouillon créé puis synchronisé une seule fois au retour du réseau ; tentative de paiement hors ligne → message explicite, aucune requête envoyée.
- **Critère de réussite** : scénarios verts sur Android et Web.

## 9. Déploiement

- **Architecture** : conteneurs (API, worker) ; PostgreSQL et Redis managés ; CI : `flutter analyze`, `flutter test`, tests d'API, tests d'isolation (2) et de matrice (1) bloquants ; déploiement progressif (préproduction → production) ; secrets dans un coffre (jamais dans le dépôt) ; Flutter Web servi par CDN ; applications mobiles via les stores.
- **Test vérifiable** : pipeline qui déploie en préproduction et exécute le parcours démo de soutenance (`integration_test`) contre l'API réelle en mode bac à sable.
- **Critère de réussite** : parcours démo vert en préproduction avant chaque mise en production.
