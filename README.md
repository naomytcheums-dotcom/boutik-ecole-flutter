# Boutik-École (Flutter)

Marketplace de l'expertise et des productions de l'IUT de Douala, codée à partir des maquettes Figma `q3uvJnUobbPfhLbcaj0PzJ` (liste des écrans : [docs/SCREENS_MANIFEST.md](docs/SCREENS_MANIFEST.md)). Cibles : Android, iOS, Web.

> Toutes les données affichées sont des **données de démonstration** (lib/data/demo). Rien de ce qui relève du serveur (droits par rôle, paiements, QR signés, certificats…) n'est implémenté : voir docs/BACKEND_PLAN.md.

## Lancer

```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # appareil connecté
```

Chaque écran a sa route `/s/<numéro>` (ex. `/s/257`, `/s/146-1`). `/catalogue` liste tous les écrans codés.

## Vérifier

```bash
flutter analyze
flutter test                                  # tests de widgets + goldens
flutter test --update-goldens --tags golden   # régénérer les rendus de référence
python tool/compare_figma.py <captures>       # maquette / rendu côte à côte dans build/compare
```

## Organisation

| Dossier | Contenu |
|---|---|
| `lib/core/theme` | couleurs, typographie (Plus Jakarta Sans / Inter), icônes |
| `lib/core/widgets` | composants partagés : `AppScaffold`, `GlassNavBar`, `PrimaryButton`, `Pill`, `AppCard`, `TextFieldWithError`, `StatusBadge`, `Toggle`, `PhotoTile`, `WebShell`, `KioskScaffold`… |
| `lib/core/router` | go_router, registre des écrans |
| `lib/data` | modèles, dépôts (interfaces + implémentations de démonstration), données fictives |
| `lib/features/<section>/<écran>/` | un dossier par écran |
| `tool/` | capture et comparaison des maquettes, génération des icônes |

## Avancement

Voir [docs/PROGRESS.md](docs/PROGRESS.md) et les questions ouvertes dans [docs/QUESTIONS.md](docs/QUESTIONS.md).
