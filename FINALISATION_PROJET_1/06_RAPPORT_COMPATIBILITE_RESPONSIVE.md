# 06 — Compatibilité, responsive et expérience utilisateur

## 1. Plateformes

| Plateforme | Configuration du dépôt | Test réel | Statut |
|---|---|---|---|
| **Flutter Web** (Vercel) | CanvasKit ; routage par fragment (`/#/s/…`) ; en-têtes de sécurité `nosniff`, `SAMEORIGIN`, `strict-origin-when-cross-origin` (`web/vercel.json`) | Playwright en production (31/10), Chromium | **validé pour le visiteur** sur Chromium. Firefox et Safari **non testés** |
| **Android** | avant le 01/11 : manifeste principal **sans permission `INTERNET`** (une version publiée n'aurait pas pu joindre Supabase) et sans `RECORD_AUDIO`. **Corrigé** (`6364a6d`) : `INTERNET`, `RECORD_AUDIO`, libellé « Boutik-École » | **aucun** (pas d'émulateur ni d'`adb` sur ce PC) | **non validé** |
| **iOS** | avant : aucune description d'usage, donc **plantage** à la première demande de micro, de caméra ou de photos (exigence Apple). **Corrigé** : 4 descriptions (`NSMicrophone…`, `NSSpeechRecognition…`, `NSCamera…`, `NSPhotoLibrary…`) | **aucun** (ni Mac ni Xcode) | **non validé** |

Conclusion : **seule la version Web peut être publiée**. Les versions mobiles exigent une compilation et des essais sur appareil
(icônes, notifications, liens profonds, permissions à l'exécution), qui n'ont jamais été faits.

## 2. Responsive (Web, production, 31/10)

| Taille | Débordement horizontal | Preuve |
|---|---|---|
| 375×667, 390×844 (téléphones) | aucun | `visiteur.spec.ts` |
| 768×1024 (tablette) | aucun | idem |
| 1280×800, 1440×900 (ordinateurs) | aucun | idem |

Écrans conçus en largeur fixe (maquette) : 244 mobiles (390), 65 web (1280 et plus), 5 borne (720×1280), 1 tablette (768), mis à
l'échelle par `GScreen`.

**Non testé** :
- l'orientation paysage sur téléphone (le manifeste Web impose `portrait-primary`) ;
- les modales et formulaires longs sur petits écrans ;
- les tableaux web en largeur réduite.

## 3. Accessibilité et expérience

| Point | Constat | Statut |
|---|---|---|
| Langue de la page | `lang="fr"` ajouté (`web/index.html`) : lecteurs d'écran et traduction automatique | corrigé (local) |
| Titre et description | « Boutik-École » et description en français au lieu de « boutik_ecole » et « A new Flutter project. » | corrigé (local) |
| Manifeste installable | nom, couleurs de la charte (#F4EFE6 / #111015), langue | corrigé (local) |
| Arbre d'accessibilité Flutter | utilisé par les tests Playwright (textes lus via `flt-semantics`) ; les listes des dialogues sont des colonnes défilantes pour rester exposées aux lecteurs d'écran (`lots.dart`) | présent ; **audit WCAG non réalisé** |
| Réglages d'accessibilité | taille du texte, gras, contraste élevé, réduction des animations (`app_settings`, `app.dart`) | présents ; non audités |
| Messages d'erreur et confirmations | règle appliquée partout : succès seulement après confirmation du serveur (ou de l'appareil pour un brouillon) ; explication honnête sinon | renforcée le 01/11 |
| États de chargement | dialogues serveur (`_run`, `_load`) et délais du paiement et du retrait | présents |
| Direction artistique | **aucun** pixel modifié : 315 goldens identiques ; aucun mode sombre ajouté | préservée |
| Contraste, zones tactiles, navigation clavier | **non mesurés** (aucun outil d'audit exécuté) | à faire (Lighthouse ou axe sur la version déployée) |

## 4. Ressenti de chargement (voir rapport 07)

Premier affichage : environ 5 Mo compressés à télécharger (bundle de 2,3 Mo et CanvasKit de 2,1 Mo en Brotli). C'est acceptable en 4G,
mais lent en 3G. Aucun écran de chargement personnalisé dans `index.html`.
