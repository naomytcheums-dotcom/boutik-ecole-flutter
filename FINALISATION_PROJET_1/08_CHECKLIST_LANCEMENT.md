# 08 — Checklist de lancement (01/11/2026)

Légende :
- ✅ **validé** : preuve en production, ou preuve locale suffisante quand la production n'est pas concernée ;
- 🟡 **partiellement validé** ;
- ❌ **non validé** ;
- ⛔ **bloqué** (dépend d'une action ou d'une autorisation) ;
- ❓ **nécessite une décision**.

| Domaine | Élément | État | Preuve ou condition |
|---|---|---|---|
| Application | Version en ligne = commit déployé connu (`69753e6`, `main.dart.js` 0e6f976a…) | ✅ | empreinte recalculée le 01/11 |
| Application | Corrections du 01/11 (`6364a6d`, `04a0dbd`) en ligne | ⛔ | déploiement Vercel à autoriser |
| Application | Analyse statique (0 erreur, 0 avertissement) et tests Flutter (421 réussis) | ✅ | rapport 05 |
| Application | Plus aucun succès affiché sans confirmation (détection automatique : 0 bouton concerné) | 🟡 | vrai en local ; en ligne après déploiement |
| Application | Écrans de mission (192-197) et de concours (160-166) sans données d'exemple | ❌ | affichage encore fictif (P1) |
| Backend | 16 migrations synchronisées | ✅ | `migration list` du 01/11 |
| Backend | Migration `20261101000000` (administration des comptes, modération) | ⛔ | 20/20 sur la réplique ; application en production à autoriser |
| Backend | RLS partout, `search_path` fixé partout | ✅ | catalogue de production (lecture seule) |
| Backend | RPC appelées par l'application = existantes | ✅ (54/54, 31/10) ; 🟡 pour les 2 nouvelles | migration |
| Base de données | Données de test en production | ❌ | 46 comptes `zz-test` (rapport 01), nettoyage à autoriser |
| Base de données | Catalogue « plateforme » (11 annonces sans vendeur, stock 100) | ❓ | produits réels ou à masquer ? |
| Sécurité | Aucun secret dans le bundle | ✅ | analyse du bundle en ligne |
| Sécurité | Clés Notch Pay renouvelées | ⛔ | exposées (historique), procédure : rapport 07 §4 |
| Sécurité | Administration des rôles et suspensions côté serveur | ⛔ | migration et déploiement |
| Sécurité | En-têtes CSP et HSTS | ❌ | amélioration recommandée |
| Paiements | Paiement sandbox de bout en bout, webhook signé authentique | ⛔ | clés, puis votre autorisation |
| Paiements | Contrôles anti-rejeu, montant, annulation, paiement tardif | 🟡 | tests R et revue de code ; jamais éprouvés avec un vrai événement |
| Paiements | MCP avec la vraie clé ; `verify_jwt` à aligner | ❌ | rapport 07 |
| Retraits | Interface sans faux succès | ✅ | production avec trafic intercepté (31/10) |
| Retraits | Code sûr, 5 essais, journal, pas de double remise | 🟡 | R (`security_31` 24/24, 01/11) ; remise réelle non faite |
| Notifications | Dans l'application (lecture, compteurs) | 🟡 | code et tests R |
| Notifications | Push, e-mail, SMS | ❓ | absentes : dans le périmètre ? |
| Authentification | Connexion | ✅ | production (31/10) |
| Authentification | Mot de passe oublié réel | ⛔ | corrigé en local ; déploiement, puis essai avec une adresse réelle ; vérifier l'URL du site et le modèle d'e-mail dans Supabase Auth |
| Authentification | Inscription, confirmation par e-mail, MFA | 🟡 | code et tests R ; non rejoués en production |
| Compatibilité | Web (Chromium) | ✅ | Playwright en production |
| Compatibilité | Firefox, Safari | ❌ | non testés |
| Compatibilité | Android, iOS | ❌ | configurations corrigées, jamais compilées ni testées |
| Responsive | 5 tailles d'écran sans débordement | ✅ | production (31/10) |
| Responsive | Paysage, modales et tableaux étroits | ❌ | non testés |
| Performances | Premier chargement d'environ 5 Mo compressés | 🟡 | acceptable en 4G ; cache et images à optimiser |
| Confidentialité | Demande d'export et de suppression enregistrée | 🟡 | traitement manuel, sans export automatique |
| Confidentialité | Politique de confidentialité et mentions légales publiées | ❓ | non trouvées dans l'audit : à fournir |
| Conditions d'utilisation | Acceptation enregistrée (`terms_accepted`) | 🟡 | texte juridique à valider par vous |
| Support | Rôle support (retrait, incidents, signalements) | 🟡 | fonctions prêtes ; **aucun compte support réel** |
| Administration | Compte administrateur réel | ⛔ | aucun admin actif en production (comptes de démonstration bannis) ; à créer par vous |
| Sauvegardes | Sauvegardes Supabase | ❌ | offre et rétention non vérifiées |
| Supervision | Disponibilité, erreurs, échecs de webhook | ❌ | rien n'est configuré |
| Poste de développement | Espace disque (0,34 Go) et fichier d'échange | ⛔ | risque pour toute compilation (audit de stockage) |
