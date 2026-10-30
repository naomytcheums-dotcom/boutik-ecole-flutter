# Audit initial (état réel constaté le 30/10/2026)

Méthode : lecture du dépôt, de l'historique Git, des migrations, des fonctions, de la base réelle (requêtes REST et SQL), analyse statique des 315 écrans (`tool/audit/*.py`).

## Dépôt
- Branche `feat/figma-fidele`, poussée aussi sur `main` du dépôt public `naomytcheums-dotcom/boutik-ecole-flutter`. Le dépôt privé `naomytcheums-dotcom/boutik-ecole` est un autre projet (Next.js) : non touché.
- Le commit `ab33d35` (documentation) n'avait **pas** été poussé : `main` était à `b3160af`. Corrigé en début de session.
- Aucun secret dans les fichiers suivis ni dans l'historique (recherche de motifs `pk_*`, `sk_*`, jetons Figma, URL de base, clés privées).

## Base de données (Supabase `zxqcnmgwhtbxkdpjqtlr`)
- 9 profils : 8 comptes de démonstration neutralisés (suspendus, bannis) et 1 compte réel. Aucune photo, aucune certification, aucun doublon de téléphone.
- Migrations appliquées et prouvées : `20261029`, `20261029b`, `20261030` (journal anti-rejeu), `20261030b` (identité et certification).
- Tables sans usage applicatif réel : `listings` (côté vendeur), `missions`, `hackathon_teams`, `kiosk_sessions` ; notifications et messagerie : tables inexistantes.

## Application
- 315 écrans générés depuis Figma (`lib/figma/g`), tous rendus par des tests golden.
- Navigation : **255 écrans non atteignables par des liens contextuels depuis le démarrage** (calcul de ce jour, `tool/audit/nav_graph.py`) ; le chiffre historique de 222 venait d'une autre méthode.
- **192 actions « Démonstration » sur 129 écrans** (confirmé).
- Seuls 5 écrans ont un comportement relié au serveur (heuristique de la matrice) : connexion, inscription, profil, favoris, paiement.

## Incidents constatés
- Profil hérité et badge bleu : cause = contenu fixe de la maquette sur l'écran Profil (voir CORRECTIONS_EFFECTUEES.md).
- Webhook Notch Pay : requête reçue et rejetée (signature invalide) ; cause non établie (voir NOTCHPAY.md).
