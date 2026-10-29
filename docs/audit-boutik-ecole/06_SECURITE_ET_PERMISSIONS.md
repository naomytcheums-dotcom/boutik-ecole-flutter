# 06 — Sécurité et permissions

Audit défensif, lecture seule. Aucune exploitation n'a été tentée sur la production. « Confirmé » = démontré par le code/la configuration ; « piste » = à investiguer.

## Mesures sur la production (lecture seule)
- Requêtes anonymes (clé publique, sans connexion) sur les 9 tables : toutes répondent `200 []` — **RLS efficace pour un visiteur non connecté** (mesuré).
- Secrets : aucun jeton `figd_`, `pk_test`, `sb_secret_` ou clé privée dans les fichiers suivis ni dans l'historique Git (recherche par motif). Le jeton Figma est dans `tool/figma_export/.figma_token`, ignoré par Git. La clé Supabase « publishable » présente dans `backend.dart` est publique par conception.
- En-têtes HTTP du site : présents HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` ; absent : `Content-Security-Policy`.
- Fonction `pay` sans clé configurée : répond 503 `not_configured` avant toute authentification (mesuré).

## Constats confirmés
| Réf. | Constat | Gravité |
|---|---|---|
| AN-001 | élévation de rôle par UPDATE de `profiles` | P0 |
| AN-002 | comptes de démonstration (dont admin) en production, mot de passe public | P0 |
| AN-003 | montants/`paid`/`status`/`reference` dictés par le client à l'insertion | P0 |
| AN-004 | un vendeur peut approuver sa propre annonce | P1 |
| AN-005 | rejeu de référence de paiement, montant non comparé | P1 |
| AN-006 | authentification validée côté client, mots de passe en clair en mémoire | P1 |
| AN-011 | vérification simulée, confirmation d'e-mail désactivée | P1 |
| AN-013 | rôles appliqués seulement par l'interface | P1 |
| AN-022 | journal d'audit falsifiable | P2 |
| AN-028/030 | pas de CSP ; CORS `*` sur la fonction | P3 |

## Pistes (non confirmées)
- **XSS** : l'application est rendue sur un canevas (CanvasKit), pas de HTML injecté depuis des saisies : risque faible (PROBABLE) ; le texte saisi est affiché comme texte Flutter.
- **Téléversement** : les images/fichiers du chat restent en mémoire ; aucun stockage serveur, donc pas de risque de fichier public aujourd'hui. Aucune validation de type/taille.
- **Dépendances vulnérables** : audit des versions non exécuté (pas d'outil d'analyse branché) — NON VÉRIFIÉ.
- **Limitation de tentatives** : dépend des réglages Supabase Auth, non examinés — NON VÉRIFIABLE sans accès au tableau de bord dans le cadre de l'audit.
- **Webhooks** : aucun webhook implémenté ; si ajouté, vérifier la signature `X-Notch-Signature` (HMAC-SHA256).

## Matrice des permissions
« Contrôle serveur » = existe dans une politique RLS ou la fonction ; sinon seule l'interface applique la règle.

| Fonctionnalité | Visiteur | Client | Étudiant-vendeur | Resp. département | Finance | Support | Admin | Contrôle serveur vérifié ? | Résultat |
|---|---|---|---|---|---|---|---|---|---|
| Lire les annonces approuvées | oui (RLS select) | oui | oui | oui | oui | oui | oui | oui (politique `status='approved'`) | table vide aujourd'hui |
| Créer une annonce | non | non | oui | oui | non | non | oui | oui (insert) | OK sur le papier |
| Approuver une annonce | non | non | **oui (propre annonce)** | oui | non | non | oui | partiel | **défaut AN-004** |
| Créer une commande | non | oui | oui | oui | oui | oui | oui | oui (`buyer_id`) | montants libres (AN-003) |
| Marquer une commande payée | non | **oui par insertion** | oui | oui | oui | oui | oui | non | **défaut AN-003/005** |
| Lire les commandes d'autrui | non | non | non | non | oui | oui | oui | oui (select) | OK |
| Modifier son rôle | non | **oui** | **oui** | **oui** | **oui** | **oui** | oui | non | **défaut AN-001** |
| Lire le journal d'audit | non | non | non | non | oui | oui | oui (+direction) | oui | OK |
| Écrire dans le journal | non | oui | oui | oui | oui | oui | oui | oui (tout utilisateur connecté) | falsifiable (AN-022) |
| Écrans d'administration | refusé (404) | refusé | refusé | selon écran | selon écran | selon écran | oui | **non** (interface seulement) | AN-013 |
| Paiement Mobile Money | non | oui | oui | oui | oui | oui | oui | oui (JWT + propriétaire de la commande) | montant non vérifié (AN-005) |

## Isolation des données entre utilisateurs
Côté serveur : `orders`, `order_lines`, `favorites`, `missions` filtrent par propriétaire (politiques lisibles dans `schema.sql`). Les tests d'isolation avec deux comptes n'ont **pas** été exécutés (comptes et données de test absents d'un environnement dédié) — NON VÉRIFIÉ en conditions réelles. Côté application : les écrans affichent l'état de la session courante (aucune fuite entre utilisateurs possible tant que les données sont locales, mais aussi aucune donnée partagée).
