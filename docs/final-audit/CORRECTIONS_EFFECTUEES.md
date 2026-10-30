# Corrections effectuées (30/10/2026)

| Sujet | Fichiers / objets | Preuve |
|---|---|---|
| Identité du profil (AN-031) | `lib/figma/live/auth.dart` (modèle, widgets de profil), `lib/figma/g/g_10.dart`, `lib/figma/live/backend.dart`, `supabase/migrations/20261030b_profils_identite.sql` | 18 tests REST sur la base réelle ; `test/account/identity_test.dart` |
| Connexion et inscription réelles | `Backend.login`, `Backend.register`, `submitLogin`, `submitSignup` ; suppression du repli connexion → inscription | tests unitaires ; non testé en navigateur |
| Déconnexion = état vierge | `lib/main.dart` (`AppRoot`), `appReset` | `identity_test.dart` |
| Certification (badge bleu) | colonnes `certification*`, déclencheur `protect_profile_authority`, RPC `request_certification` et `decide_certification` | tests REST + transaction annulée (approbation par un valideur, retours arrière refusés) |
| Favoris persistants et isolés | `Favorites` (`store.dart`), `Backend.loadFavorites/setFavorite`, table `favorites` + RLS existante | 9 tests REST (isolation, reconnexion) |
| Accès à tous les écrans | `lib/figma/live/espace.dart` (route `/espace`), `gEspace`, entrées depuis `g_03` et `g_10` | `test/navigation/rubriques_test.dart` : un rôle voit exactement les écrans que le routeur lui autorise |
| Actions de navigation rendues réelles | 17 actions (`Retour`, `Annuler`, `Fermer`, `Passer`, `Continuer`…) sur 162, 170, 171, 173, 175–178, 18, 21, 150_2/3/4 | `ACTIONS_DEMONSTRATION.md` (175 restantes) |
| Pastilles de catégories de la page de bienvenue | `g_03.dart` (vers 04, 22, 22b, 70, 78) | code ; non testé en navigateur |
| Défilement des écrans hauts | `GScreen` : seuil 1000 → 860 px | goldens régénérés (changement voulu) |
| Coches invisibles, consentement coché par défaut | `g_12`, `g_272`, `g_274`, `GCheck`, `rememberBox`, `termsProvider` | goldens régénérés (changement voulu) |
| Stock bas = 30 | `Listing.lowStock` | `seller_test` |
| Popup « compte existant » | `gAlert` | code |
| Webhook Notch Pay signé | `supabase/functions/notchpay-webhook`, migration `20261030` | 19 tests locaux simulés (voir NOTCHPAY.md) |
| Générateur Figma | `_frozen` dans `bindings.json` : les écrans modifiés à la main ne sont plus écrasés | — |

Décisions techniques : les écrans modifiés à la main sont « figés » (03, 10, 12, 171…) ; la connexion par téléphone est refusée avec le serveur (l'e-mail est l'identifiant) ; les annonces d'exemple ne sont plus chargées quand le serveur est joint.
