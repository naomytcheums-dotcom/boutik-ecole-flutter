# H8 — Écrans générés `lib/figma/g/g_*` : corrections manuelles à préserver

Les fichiers `lib/figma/g/g_*.dart` sont produits par `tool/figma_export/convert.py`, mais ont été **corrigés directement** (H6/H7/H8).
Base de comparaison : dernier état poussé `63e98a55`. Liste établie avec `git diff --name-only 63e98a55 HEAD -- lib/figma/g`
(113 fichiers, listés ci-dessous) ; en plus, l'état de travail non commité contenait au moment de l'écriture `g_193` et `g_201` (retouches d'un autre lot H8 en parallèle, gelés : `193`, `201`
sont dans `_frozen`) — à classer dans le groupe voulu par leur auteur.
Contrôle automatique : `test/journey/h8_generes_garde_test.dart`.

## Ce que fait réellement `convert.py` (lecture du code)

- Usage : `python tool/figma_export/convert.py [id ...]` (sans argument : tous les écrans de `lib/features/**/screens.dart`).
- **Aucune option de dossier de sortie** : `ROOT` = parent de `tool/` ; il écrit dans `ROOT/lib/figma/g/g_<id>.dart`, `ROOT/lib/figma/registry.dart`,
  `ROOT/assets/figma/{img,v,r}` et `tool/figma_export/cache/sizes.json`.
- Entrées : `tool/figma_export/cache/` (JSON Figma, ignoré par git, ~124 Mo, local), `.figma_token` (ignoré par git, **ne pas lire ni copier ailleurs que dans le bac à sable**),
  `bindings.json` et `links.txt` (versionnés), `lib/features/**/screens.dart` (registre id → nodeId).
- **Écrans gelés** : `bindings.json › _frozen` (liste d'ids, avec doublons). Pour un id gelé, `convert()` imprime
  « écran figé (modifié à la main), non régénéré » et **n'écrit pas** le fichier. Sur 315 `g_*`, 262 sont gelés ; **tous sauf 8** des 113 fichiers modifiés sont gelés.
  Les 8 modifiés **non gelés**, donc écrasés par une régénération : `13, 45, 62, 63, 96, 98, 99, 281`.
- Correctifs déjà intégrés au générateur (reproduits tels quels à chaque régénération) : remplacement des textes « à confirmer avec l'IUT… » par les formulations validées,
  icône menu `44747303a472e2.svg` → `menu3.svg` + zone vers `231` (écrans 230, 232, a1, a3 : non gelés, rien à refaire), remplacement `gBox(image: …2b51b5d6…)` → `kelaOrb(…)` et
  `GMic(child:` → `GMic(onResult: … kelaToggle …)`, menus latéraux (`SIDEBAR`), `COLOR_FIX` (contrastes), et tout ce qui est déclaré dans `bindings.json`
  (`nodes › show/before/after/labels/onChanged/image/fill/favorite`, `links`, `dropLinks`, `replace`, `rows`, `skipRegion/liveCall`). Les écrans 13, 45, 62, 63 ont des entrées `bindings.json` (nœuds, liens).
- `tool/admin_clean.py` (idempotent, `--report` pour lister) rejoue le masquage d'en-tête / `gSelf` / zones de maquette sur : `127–138, 145, 147_1/2/3, 180, 181, 264–269, 281`.
- Une exécution complète appelle l'API Figma **uniquement** pour les images/rasters absents de `assets/figma/{img,r}` (`download_images`, `export_rasters`) ; elle réécrit toujours `registry.dart` et `cache/sizes.json`.

## Groupes de corrections et ce qu'il faut préserver

| # | Nature | Fichiers | À préserver | Rejouable par script ? |
|---|---|---|---|---|
| G1 | **Barre d'état « 9:41 » de maquette masquée connecté** (`show: demoContent`) | 88 89 90 91 93 93b 94 95 95b 96 97 98 99 146_1 146_2 167 205 277 280 281 282 283 284 285 286 | `gText('9:41', …), show: demoContent` | Non (96, 98, 99, 281 non gelés : à refaire à la main) |
| G2 | **En-tête de console masqué hors démo** : trois photos d'équipe, pastille « +3 », point sombre, bouton « Exporter » et son icône (`show: demoContent` / `if (demoContent) Positioned.fill(GChoiceGroup…)`) | 108–126, 127–145 (127–139 et 140–144), 147_1/2/3, 168 169 180 181 188 189 190 198 199 200 213 239 263 264–269 | chaque élément d'en-tête gardé par `demoContent` ; la maquette reste intacte en démo | Partiel : `admin_clean.py` couvre 127–138, 145, 147_*, 180, 181, 264–269 ; le reste est manuel |
| G3 | **Nom du compte en pied de menu** (`gSelf(ref, 'Super admin'\|'Finance')` à la place du nom figé) | 127–138, 145, 147_1/2/3, 180, 181 | `gSelf(` | Oui (`admin_clean.py`) |
| G4 | **Orbe Kéla** (cercle + deux SVG génériques `d177b28382093d` / `6fd6a3c35cbbc1` remplacés par `kelaOrb(image: …2b51b5d6…png, fit: contain)`) et textes associés (« Kéla · Opportunités », « Conseil pour votre dossier », « Comparatif des propositions », « Compat. », « Recommandé pour vous » ; 151 : `tap: gTab(context,'231')`) | 151 154 159 189 | `kelaOrb` ; **aucune** référence aux deux SVG génériques ; textes sans « IA » | Non. `convert.py` ne remplace que le PNG `2b51…` ; les deux SVG sont re-générés tels quels depuis le cache Figma |
| G5 | **Menu** (burger `menu3.svg` + zone `gOpen('231')`, menus latéraux `gTap`) | 230 232 a1 a3 (+ sidebars des consoles) | — | **Oui, natif à `convert.py`** (aucune retouche manuelle depuis `63e98a55`) |
| G6 | **Pied de menu département** `deptFooterText(ref)` (nom de l'établissement/département réel connecté, « Dép. Génie informatique » seulement en démo) + `DeptConsoleOverview` (108) / `DeptConsolePage('109'…'115')` (`if (!demoContent)`) ; import `../live/dept_space.dart` | 108–116 | `deptFooterText`, import `dept_space.dart`, widgets live gardés par `!demoContent` | Non |
| G7 | **Widgets live insérés** (connecté : données réelles ; démo : maquette) | Direction `direction.dart` : 117 (`DirectionDashboardPanel`), 119–123, 125, 126 (autres panneaux), 239 (`SponsorReportByRole`), 284 (`financialRegisterView(ref, …)`) ; Admin `admin_consoles.dart` : 128 (`AdminUsersList`, `AdminRolesNote`), 130 (`ModerationQueue`), 131 (`ReportsList`), 132 (`AdminOrdersTable`), 137 (`AuditTable`), 181 et 281 (`PermissionCatalog`) ; 127 (`institutionsList`) ; 177 (`CmsPageOverlay`) ; 10 (profil d'organisation, import `console.dart`) | `if (!demoContent) gP(…, Widget)`, imports, et le masquage (`admin_clean.py` `REGIONS`/`LIST_SCREENS`) des lignes de maquette correspondantes | 127/128/130/131/132/137/180/181/281 : masquage par `admin_clean.py` ; l'insertion des widgets est manuelle |
| G8 | **Valeurs réelles à la place de chiffres de maquette** (`Consumer` + `demoContent ? 'maquette' : réel/« — »`) | 161 167 170 210 22b 231 240 243 253 45 61 62 63 64 a2 ; libellés 131 (« Résolus »), 132 (« Expédiées »/« Annulées »), 135, 137 (« Catégorie »), 168 (champs vides connecté) | ternaires `demoContent ?` ; `—` quand la donnée manque | Partiel (45, 61–64 via `bindings.json`) |
| G9 | **Textes de maquette corrigés** (« Entreprise » → « Organisation », « Mon espace client » → « Mon espace », « Recommandé par l'IA » → « Recommandé pour vous », libellés de menu élargis 117–126 : boîtes 64→150 px) | 04 13 88 89 177 187 18b 159 261 117–126 | formulations et largeurs ; 04 : bandeau « une organisation ? » gardé `demoContent` | Non |
| G10 | **Routage / garde d'écran** | 03 (`CompanyHomeScreen` seulement si `me.role == 2`), 10 (`isCo`), 275 (`GRedirect('/s/58')` sans erreur réelle), 18b | conditions `!demoContent && …` | Non |

## Procédure sûre pour régénérer (sans perdre les corrections)

Règle : **ne jamais régénérer directement dans `lib/figma/g`** (aucune option de sortie ; les écrans non gelés sont écrasés sans sauvegarde).
Travailler dans un bac à sable puis reporter à la main ce qui est voulu.

1. **Pré-requis** : arbre git propre pour `lib/figma/g` (`git status --short lib/figma/g` vide) ou commit/stash préalable ; vérifier que le test garde passe avant (étape 7).
2. **Bac à sable** (tout en `C:\tmp\h8\regen`, copie de la racine utile ; aucun accès réseau nécessaire si `assets/figma` est copié) :
   ```powershell
   $R='C:\tmp\h8\regen'; $S=(Get-Location).Path
   robocopy "$S\tool\figma_export" "$R\tool\figma_export" /E /XF fetch_figma.py
   robocopy "$S\lib\features" "$R\lib\features" screens.dart /S
   robocopy "$S\lib\figma\g" "$R\lib\figma\g" /E
   robocopy "$S\assets\figma" "$R\assets\figma" /E
   ```
   (le `.figma_token` est copié avec le dossier : ne pas le lire, l'afficher ni le committer ; supprimer le bac à sable ensuite.)
3. **Régénérer dans le bac à sable** : `cd $R\tool\figma_export; python convert.py [ids…]` (ids ciblés recommandés). Les écrans gelés affichent « écran figé… non régénéré ».
   Attention : un id retiré de `_frozen` est écrasé ; un id gelé ne reçoit plus aucune évolution du Figma.
4. **Comparer** au dépôt : `git diff --no-index --stat "$S\lib\figma\g" "$R\lib\figma\g"`. Résultat attendu pour une régénération « à l'identique » : **aucune différence** pour tous les écrans gelés ;
   pour les 8 non gelés (13, 45, 62, 63, 96, 98, 99, 281), les différences listent exactement les corrections manuelles qui seraient perdues (G1, G7, G9, G8) ;
   `registry.dart` du bac à sable doit rester identique à `lib/figma/registry.dart` (hors nouveaux écrans).
5. **Reporter** uniquement les écarts voulus : `git diff --no-index "$S\lib\figma\g\g_X.dart" "$R\lib\figma\g\g_X.dart"` → relire, copier les hunks utiles dans `lib/figma/g/g_X.dart`
   (ou `git apply` d'un patch restreint). Pour un écran non gelé régénéré en entier : **rejouer** ensuite `python tool/admin_clean.py` (G2/G3/G7 admin ; commencer par `--report`),
   puis refaire à la main G1 (`show: demoContent` sur « 9:41 »), G9, G7 et G8 d'après la table ci-dessus.
   Si un écran contient désormais des corrections manuelles durables, **l'ajouter à `_frozen`** plutôt que de le régénérer à chaque fois.
6. **Ne jamais** copier en bloc `$R\lib\figma\g\*` ni `registry.dart` vers le dépôt ; nettoyer `C:\tmp\h8\regen` (contient le jeton).
7. **Vérification après régénération** (un seul test à la fois, `-j 1`) :
   - `flutter test --no-pub test/journey/h8_generes_garde_test.dart` (garde statique : `demoContent` sur les consoles, `kelaOrb` 151/154/159/189, aucun SVG générique `d177b28382093d`/`6fd6a3c35cbbc1`, `deptFooterText` 108–116) ;
   - `test/journey/maquette_interdite_test.dart`, `h6_admin_propre_test.dart`, `h6_menu_kela_test.dart`, `h7_admin_restant_propre_test.dart`, `h7_clients_etudiants_propre_test.dart`,
     `h7_org_dept_direction_propre_test.dart`, `h7_isolation_comptes_test.dart` ;
   - `test/journey/ecrans_mode_connecte_test.dart`, `ecrans_sans_source_test.dart`, `consoles_web_adaptatives_test.dart` ;
   - `python tool/admin_clean.py --report` doit afficher `total 0` (tout est déjà appliqué) ;
   - `flutter analyze --no-pub lib/figma` ; la suite complète est lancée par le chef avant tout build/déploiement.
