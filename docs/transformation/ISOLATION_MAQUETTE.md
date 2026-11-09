# Isolation des données de maquette (9 novembre 2026)

Règle du propriétaire : **connecté (`Backend.ready`), aucune donnée de maquette n'est affichée** — ni nom, ni photo, ni montant, ni date, ni appareil, ni produit. Un compte neuf est vierge. La maquette ne subsiste que hors connexion au serveur (aperçu, tests).
Cette règle remplace l'ancienne tolérance « la maquette reste affichée tant qu'aucune donnée réelle n'existe » (talents de l'accueil, fil du réseau).

## Mécanismes

| Mécanisme | Où | Effet |
|---|---|---|
| `gm(demo, blank)` | `lib/figma/live/auth.dart` | texte statique d'écran : valeur d'exemple hors connexion ; connecté `—` (valeur) ou vide (nom, titre) |
| `gSelf(ref, demo)` / `gSelfInst(ref, demo)` | idem | « Mariam Essono », « Bonjour Mariam »… deviennent le nom du titulaire ; « IUT de Douala » son établissement (vide s'il n'en a pas) |
| `gIsMockPhoto` | `lib/figma/gen.dart` | `gBox(image:)` et `gImg()` : toute photo de `assets/figma/img/` (personnes, produits, lieux) devient un aplat neutre connecté ; logo, formes 3D, avion, logos de paiement, fonds d'accueil conservés |
| `tool/demo_guard.py` | outil | applique les gardes `gm`/`gSelf` à tous les `gText('…')` et `gRich` de `lib/figma/g/*.dart` selon `tool/maquette_tokens.json` (personnes, entités, chiffres) ; idempotent ; `--report` pour lister |
| Test `test/journey/maquette_interdite_test.dart` | tests | échoue si (1) un texte littéral de maquette n'est pas gardé dans `lib/figma/g`, (2) un des 315 écrans ouvert connecté avec un compte neuf affiche un nom/produit/photo de maquette |

Pour ajouter un écran : écrire le texte réel depuis une requête filtrée par titulaire (RLS), ou un état vide ; si le texte est un exemple de maquette, lancer `python tool/demo_guard.py`. Ajouter les nouveaux noms d'exemple dans `tool/maquette_tokens.json`.

## Écrans retravaillés à la main

- **148-2 Centre de sécurité** : connecté, affiche le nom et l'e-mail du compte, le téléphone enregistré (masqué), « Authentification à deux facteurs : pas encore disponible », l'appareil courant (« Cet appareil », réel) et le lien de changement de mot de passe envoyé par e-mail ; plus de niveau 80 %, de « 2 actifs », d'iPhone 14, de Chrome · Windows.
- **172 / profil** : icônes de badges différenciées (identité, ventes, avis) dans `SellerTrustBlock`.
- **Accueil 03 et liste de talents 70** : plus de cartes « Exemple » ni d'avatars de maquette connecté ; état vide explicite.
- **Catalogue** : les produits d'exemple (`listings.showcase`) sont exclus côté client et côté serveur (voir migration).

## Base de données (migration `20261106000300_referentiel_universitaire_cameroun.sql`, non destructive)

- Établissements : +36 (grandes écoles et facultés publiques, principaux établissements privés) sans toucher aux 11 existants.
- Départements / filières : l'IUT de Douala (13 départements) et un socle standard pour chaque université d'État, école, institut et établissement privé qui n'en avait aucun.
- Politique `restrictive` « annonces : exemples masqués » sur `listings` : les 11 annonces fictives ne sont plus lisibles par l'API (aucune ligne supprimée ; retour arrière documenté dans le fichier).

Isolation vérifiée par lecture des politiques : `profiles` (select réservé au titulaire et à l'administration), tables utilisateur sous RLS ; les référentiels (établissements, départements, catégories) restent publics en lecture.

## Limites connues

- Les intitulés de départements des universités sont des filières génériques ; la liste officielle des IPES du MINESUP (PDF) reste à importer par l'équipe.
- Les tableaux de bord des consoles (département, direction, finance, administration) n'ont pas encore de source de données : connectés, leurs textes d'exemple sont masqués (« — » / vide) mais les graphiques en barres décoratifs restent dessinés.
- Localisation automatique : web uniquement (position du navigateur après autorisation + géocodage inverse OpenStreetMap) ; sur Android, la saisie manuelle reste proposée.
