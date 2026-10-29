# 02 — Routes et pages

Source : analyse automatique du code généré (`lib/figma/g/g_*.dart`, 315 fichiers) et de `lib/figma/live/access.dart` par un script de lecture seule. Date : 29 octobre 2026.

**Routes de l'application** (`lib/core/router/app_router.dart`) : `/` (redirige vers `/s/01`), `/s/:id` (un écran par identifiant, 315 identifiants), `/catalogue` (liste de tous les écrans), toute autre adresse → page « Écran introuvable ». Les adresses utilisent le hash (`/#/s/05`).

**Contrôle d'accès** : `AccessGuard` (côté application uniquement). Un écran non autorisé affiche une page 404 neutre. Les rôles sont déduits de la *numérotation* de l'écran (`allowedRoles`), pas d'une table de permissions serveur.

## Synthèse par niveau d'implémentation (critères explicites)

| Niveau | Critère de classement (lecture du code de l'écran) | Écrans |
|---|---|---|
| données + actions | lit un état partagé (`ref.watch`) ET écrit dans un état ou déclenche une action (`notifier`, `submit*`, paiement, chat…) | 35 |
| lecture de données | lit un état partagé mais aucune action d'écriture | 20 |
| actions sans lecture | déclenche des actions sans afficher de données d'état | 16 |
| saisie/bascules locales | champs, interrupteurs ou choix qui réagissent mais ne produisent aucun résultat métier | 145 |
| boutons simulés | boutons qui n'affichent qu'un message « Démonstration : … » | 56 |
| navigation seule | uniquement des liens vers d'autres écrans | 33 |
| statique | aucune interaction | 10 |

Total : 315 écrans (244 mobiles, 71 web/borne/tablette). Écrans sans aucun lien entrant dans l'application : 222. Messages « Démonstration » : 192 occurrences sur 129 écrans.

**Important** : « données + actions » signifie que l'écran est branché sur un état en mémoire de l'application. Cela ne prouve pas la persistance serveur : seuls la connexion/inscription, les commandes, le journal d'audit et le paiement sont transmis à Supabase (voir 05).

## Matrice complète

| Écran | Route | Taille | Rôles autorisés (client) | Niveau | Données lues | Actions d'écriture | Champs | Boutons « Démonstration » | Liens sortants | Liens entrants |
|---|---|---|---|---|---|---|---|---|---|---|
| 01 | /s/01 | 390×876 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 0 |
| 02 | /s/02 | 390×876 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 1 |
| 03 | /s/03 | 390×939 | tous | actions sans lecture | 0 | 2 | 0 | 0 | 5 | 87 |
| 04 | /s/04 | 390×1018 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 6 | 1 |
| 05 | /s/05 | 390×1002 | tous | données + actions | 6 | 1 | 0 | 0 | 3 | 5 |
| 06 | /s/06 | 390×900 | tous | lecture de données | 2 | 0 | 0 | 0 | 6 | 3 |
| 07 | /s/07 | 390×900 | tous | données + actions | 10 | 2 | 1 | 0 | 7 | 1 |
| 08 | /s/08 | 390×900 | tous | données + actions | 4 | 4 | 1 | 0 | 7 | 2 |
| 09 | /s/09 | 390×900 | tous | données + actions | 35 | 1 | 0 | 0 | 7 | 5 |
| 10 | /s/10 | 390×844 | tous | données + actions | 3 | 6 | 0 | 0 | 7 | 95 |
| 11 | /s/11 | 390×900 | tous | actions sans lecture | 0 | 5 | 2 | 1 | 2 | 2 |
| 12 | /s/12 | 390×900 | tous | données + actions | 3 | 7 | 5 | 0 | 2 | 2 |
| 13 | /s/13 | 390×900 | tous | données + actions | 15 | 5 | 0 | 0 | 0 | 0 |
| 14 | /s/14 | 390×900 | tous | données + actions | 1 | 2 | 1 | 0 | 1 | 0 |
| 15 | /s/15 | 390×900 | tous | actions sans lecture | 0 | 3 | 1 | 0 | 1 | 1 |
| 16 | /s/16 | 390×900 | tous | actions sans lecture | 0 | 4 | 2 | 1 | 0 | 0 |
| 17 | /s/17 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 18 | /s/18 | 390×900 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 18b | /s/18b | 390×900 | tous | actions sans lecture | 0 | 7 | 6 | 0 | 1 | 0 |
| 18c | /s/18c | 390×900 | tous | saisie/bascules locales | 0 | 0 | 3 | 2 | 0 | 0 |
| 19 | /s/19 | 390×844 | tous | actions sans lecture | 0 | 4 | 1 | 0 | 6 | 154 |
| 20 | /s/20 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 21 | /s/21 | 390×946 | tous | saisie/bascules locales | 0 | 0 | 4 | 2 | 1 | 1 |
| 22 | /s/22 | 390×910 | tous | données + actions | 107 | 13 | 0 | 0 | 6 | 1 |
| 22b | /s/22b | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 22c | /s/22c | 390×1091 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 22d | /s/22d | 390×925 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 23 | /s/23 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 3 | 0 | 0 |
| 24 | /s/24 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 25 | /s/25 | 390×844 | tous | données + actions | 60 | 4 | 0 | 0 | 6 | 0 |
| 25b | /s/25b | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 26 | /s/26 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 1 | 0 |
| 27 | /s/27 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 28 | /s/28 | 390×844 | tous | données + actions | 44 | 4 | 0 | 0 | 6 | 0 |
| 29 | /s/29 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 30 | /s/30 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 3 | 0 | 0 |
| 31 | /s/31 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 32 | /s/32 | 390×1016 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 33 | /s/33 | 390×1053 | tous | boutons simulés | 0 | 0 | 0 | 1 | 1 | 1 |
| 34 | /s/34 | 390×950 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 35 | /s/35 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 36 | /s/36 | 390×956 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 38 | /s/38 | 390×938 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 39 | /s/39 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 2 | 1 | 1 | 0 |
| 40 | /s/40 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 4 | 0 | 1 | 1 |
| 41 | /s/41 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 5 | 1 | 1 | 0 |
| 42 | /s/42 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 43 | /s/43 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 44 | /s/44 | 390×844 | tous | lecture de données | 5 | 0 | 0 | 1 | 2 | 1 |
| 45 | /s/45 | 390×844 | tous | données + actions | 45 | 4 | 1 | 0 | 6 | 0 |
| 46 | /s/46 | 390×854 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 47 | /s/47 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 48 | /s/48 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 1 | 0 | 0 |
| 49 | /s/49 | 390×854 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 50 | /s/50 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 51 | /s/51 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 52 | /s/52 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 53 | /s/53 | 390×844 | tous | actions sans lecture | 0 | 1 | 0 | 0 | 1 | 111 |
| 54 | /s/54 | 390×844 | tous | actions sans lecture | 0 | 1 | 0 | 0 | 1 | 0 |
| 55 | /s/55 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 2 | 1 | 0 |
| 56 | /s/56 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| 57 | /s/57 | 390×846 | étudiant, resp. dépt, admin | lecture de données | 38 | 0 | 0 | 0 | 6 | 0 |
| 58 | /s/58 | 390×844 | étudiant, resp. dépt, admin | actions sans lecture | 0 | 6 | 4 | 2 | 0 | 1 |
| 59 | /s/59 | 390×844 | étudiant, resp. dépt, admin | saisie/bascules locales | 0 | 0 | 6 | 2 | 0 | 0 |
| 60 | /s/60 | 390×866 | étudiant, resp. dépt, admin | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 61 | /s/61 | 390×844 | étudiant, resp. dépt, admin | données + actions | 91 | 2 | 1 | 0 | 6 | 0 |
| 62 | /s/62 | 390×954 | étudiant, resp. dépt, admin | données + actions | 30 | 3 | 1 | 0 | 5 | 0 |
| 63 | /s/63 | 390×844 | étudiant, resp. dépt, admin | données + actions | 80 | 5 | 0 | 0 | 6 | 1 |
| 64 | /s/64 | 390×844 | étudiant, resp. dépt, admin | lecture de données | 4 | 0 | 0 | 2 | 0 | 1 |
| 65 | /s/65 | 390×880 | étudiant, resp. dépt, admin | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 66 | /s/66 | 390×844 | étudiant, resp. dépt, admin | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 67 | /s/67 | 390×844 | étudiant, resp. dépt, admin | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 69 | /s/69 | 390×844 | étudiant, resp. dépt, admin | boutons simulés | 0 | 0 | 0 | 1 | 1 | 0 |
| 70 | /s/70 | 390×844 | tous | données + actions | 76 | 2 | 1 | 0 | 5 | 0 |
| 72 | /s/72 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 4 | 1 | 0 | 0 |
| 73 | /s/73 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| 74 | /s/74 | 390×844 | tous | actions sans lecture | 0 | 1 | 0 | 0 | 1 | 1 |
| 75 | /s/75 | 390×844 | tous | données + actions | 73 | 1 | 0 | 0 | 5 | 0 |
| 76 | /s/76 | 390×846 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 77 | /s/77 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 5 | 0 |
| 78 | /s/78 | 390×844 | tous | données + actions | 60 | 5 | 0 | 0 | 7 | 0 |
| 79 | /s/79 | 390×915 | tous | lecture de données | 8 | 0 | 0 | 1 | 0 | 1 |
| 80 | /s/80 | 390×844 | tous | actions sans lecture | 0 | 5 | 4 | 1 | 0 | 1 |
| 81 | /s/81 | 390×844 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 82 | /s/82 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 83 | /s/83 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 84 | /s/84 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 5 | 2 | 0 | 0 |
| 84b | /s/84b | 390×868 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 85 | /s/85 | 390×844 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 86 | /s/86 | 390×844 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 87 | /s/87 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 1 | 1 | 0 |
| 88 | /s/88 | 390×846 | entreprise, admin | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 89 | /s/89 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 0 | 1 | 5 | 0 |
| 90 | /s/90 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 5 | 2 | 0 | 0 |
| 91 | /s/91 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 93 | /s/93 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 93b | /s/93b | 390×844 | entreprise, admin | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 94 | /s/94 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 95 | /s/95 | 390×844 | entreprise, admin | boutons simulés | 0 | 0 | 0 | 2 | 5 | 0 |
| 95b | /s/95b | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 5 | 1 | 0 | 0 |
| 96 | /s/96 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 97 | /s/97 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 98 | /s/98 | 390×844 | entreprise, admin | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 99 | /s/99 | 390×844 | entreprise, admin | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 100 | /s/100 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 101 | /s/101 | 390×853 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 102 | /s/102 | 390×969 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 103 | /s/103 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 104 | /s/104 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 105 | /s/105 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 106 | /s/106 | 390×915 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 107 | /s/107 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 108 | /s/108 | 1272×760 | resp. dépt, direction, admin | lecture de données | 65 | 0 | 2 | 0 | 3 | 8 |
| 109 | /s/109 | 1280×890 | resp. dépt, direction, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 9 | 7 |
| 110 | /s/110 | 1280×880 | resp. dépt, direction, admin | données + actions | 92 | 3 | 1 | 0 | 9 | 7 |
| 111 | /s/111 | 1280×890 | resp. dépt, direction, admin | lecture de données | 83 | 0 | 1 | 0 | 10 | 8 |
| 112 | /s/112 | 1280×890 | resp. dépt, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 9 | 7 |
| 113 | /s/113 | 1280×890 | resp. dépt, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 9 | 7 |
| 114 | /s/114 | 1280×890 | resp. dépt, direction, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 9 | 7 |
| 115 | /s/115 | 1280×890 | resp. dépt, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 10 | 7 |
| 116 | /s/116 | 1280×890 | resp. dépt, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 9 | 7 |
| 117 | /s/117 | 1272×760 | direction, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 12 | 9 |
| 118 | /s/118 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 1 | 1 | 10 | 9 |
| 119 | /s/119 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 10 | 9 |
| 120 | /s/120 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 10 | 9 |
| 121 | /s/121 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 10 | 9 |
| 122 | /s/122 | 1280×880 | direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 10 | 9 |
| 123 | /s/123 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 10 | 9 |
| 124 | /s/124 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 10 | 9 |
| 125 | /s/125 | 1280×890 | direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 10 | 9 |
| 126 | /s/126 | 1280×890 | direction, admin | données + actions | 92 | 1 | 2 | 0 | 10 | 9 |
| 127 | /s/127 | 1272×760 | admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 3 | 11 |
| 128 | /s/128 | 1280×890 | admin | lecture de données | 85 | 0 | 1 | 0 | 12 | 10 |
| 129 | /s/129 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 12 | 10 |
| 130 | /s/130 | 1280×880 | admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 12 | 10 |
| 131 | /s/131 | 1280×890 | support, admin | lecture de données | 83 | 0 | 1 | 0 | 12 | 10 |
| 132 | /s/132 | 1280×890 | support, admin | données + actions | 82 | 8 | 1 | 0 | 12 | 10 |
| 133 | /s/133 | 1280×880 | support, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 12 | 10 |
| 134 | /s/134 | 1280×890 | finance, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 12 | 10 |
| 135 | /s/135 | 1280×890 | finance, admin | lecture de données | 5 | 0 | 1 | 0 | 12 | 10 |
| 136 | /s/136 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 12 | 10 |
| 137 | /s/137 | 1280×890 | admin | lecture de données | 92 | 0 | 2 | 0 | 12 | 10 |
| 138 | /s/138 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 12 | 10 |
| 139 | /s/139 | 1272×760 | finance, direction, admin | données + actions | 100 | 10 | 2 | 0 | 3 | 0 |
| 140 | /s/140 | 1280×880 | finance, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 141 | /s/141 | 1280×890 | finance, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 142 | /s/142 | 1280×890 | finance, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 143 | /s/143 | 1280×890 | finance, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 144 | /s/144 | 1280×890 | finance, direction, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 145 | /s/145 | 1280×890 | support, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 146_1 | /s/146_1 | 390×844 | support, admin | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 146_2 | /s/146_2 | 390×844 | support, admin | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 147_1 | /s/147_1 | 1280×880 | support, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 147_2 | /s/147_2 | 1280×890 | support, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 147_3 | /s/147_3 | 1280×890 | support, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 148_1 | /s/148_1 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 148_2 | /s/148_2 | 390×900 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 5 | 0 |
| 149 | /s/149 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| 150_1 | /s/150_1 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 1 | 0 |
| 150_2 | /s/150_2 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 1 | 0 |
| 150_3 | /s/150_3 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 5 | 0 |
| 150_4 | /s/150_4 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 5 | 0 |
| 151 | /s/151 | 390×870 | tous | données + actions | 42 | 1 | 0 | 0 | 5 | 0 |
| 152 | /s/152 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 153 | /s/153 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 154 | /s/154 | 390×856 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 155 | /s/155 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 156 | /s/156 | 390×1020 | tous | saisie/bascules locales | 0 | 0 | 1 | 1 | 0 | 0 |
| 157 | /s/157 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 158 | /s/158 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 159 | /s/159 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 160 | /s/160 | 390×858 | tous | données + actions | 33 | 5 | 0 | 0 | 7 | 0 |
| 161 | /s/161 | 390×881 | tous | données + actions | 8 | 1 | 0 | 1 | 2 | 1 |
| 162 | /s/162 | 390×844 | tous | données + actions | 24 | 6 | 2 | 2 | 0 | 1 |
| 163 | /s/163 | 390×844 | tous | données + actions | 73 | 2 | 1 | 0 | 1 | 1 |
| 164 | /s/164 | 390×844 | tous | lecture de données | 4 | 0 | 0 | 2 | 1 | 1 |
| 165 | /s/165 | 390×844 | tous | actions sans lecture | 0 | 4 | 3 | 2 | 0 | 1 |
| 166 | /s/166 | 390×844 | tous | lecture de données | 29 | 0 | 0 | 1 | 0 | 0 |
| 167 | /s/167 | 390×844 | resp. dépt, admin | données + actions | 8 | 4 | 1 | 2 | 0 | 0 |
| 168 | /s/168 | 1280×890 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 6 | 0 | 1 | 0 |
| 169 | /s/169 | 1280×880 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 170 | /s/170 | 390×844 | tous | données + actions | 1 | 5 | 1 | 2 | 0 | 0 |
| 171 | /s/171 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 172 | /s/172 | 390×844 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 173 | /s/173 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 1 | 0 |
| 174 | /s/174 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 175 | /s/175 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 176 | /s/176 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 177 | /s/177 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 178 | /s/178 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 1 | 0 |
| 179 | /s/179 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 180 | /s/180 | 1280×890 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 181 | /s/181 | 1280×890 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 182 | /s/182 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 183 | /s/183 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 184 | /s/184 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| 185 | /s/185 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 186 | /s/186 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| 187 | /s/187 | 1272×760 | entreprise, admin | saisie/bascules locales | 0 | 0 | 2 | 0 | 3 | 0 |
| 188 | /s/188 | 1280×890 | entreprise, admin | saisie/bascules locales | 0 | 0 | 3 | 0 | 1 | 0 |
| 189 | /s/189 | 1280×890 | entreprise, admin | saisie/bascules locales | 0 | 0 | 1 | 1 | 1 | 0 |
| 190 | /s/190 | 1280×880 | entreprise, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 191 | /s/191 | 390×1069 | tous | actions sans lecture | 0 | 8 | 3 | 1 | 0 | 0 |
| 192 | /s/192 | 390×902 | tous | lecture de données | 4 | 0 | 0 | 2 | 0 | 0 |
| 193 | /s/193 | 390×913 | tous | lecture de données | 9 | 0 | 0 | 1 | 0 | 0 |
| 194 | /s/194 | 390×1118 | tous | lecture de données | 5 | 0 | 0 | 2 | 2 | 0 |
| 195 | /s/195 | 390×844 | tous | actions sans lecture | 0 | 2 | 1 | 2 | 0 | 1 |
| 196 | /s/196 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 5 | 0 | 0 |
| 197 | /s/197 | 390×844 | tous | lecture de données | 10 | 0 | 0 | 1 | 0 | 1 |
| 198 | /s/198 | 1280×866 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 4 | 1 | 0 |
| 199 | /s/199 | 1280×866 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 1 | 1 | 0 |
| 200 | /s/200 | 1280×866 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 201 | /s/201 | 390×844 | tous | lecture de données | 8 | 0 | 0 | 0 | 6 | 0 |
| 202 | /s/202 | 390×948 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 203 | /s/203 | 390×890 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 204 | /s/204 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 205 | /s/205 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 3 | 2 | 0 | 0 |
| 206 | /s/206 | 720×1280 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 1 | 1 |
| 207 | /s/207 | 720×1280 | tous | données + actions | 52 | 5 | 1 | 4 | 3 | 2 |
| 208 | /s/208 | 720×1280 | tous | données + actions | 5 | 1 | 0 | 0 | 3 | 1 |
| 209 | /s/209 | 720×1280 | tous | actions sans lecture | 0 | 1 | 0 | 0 | 2 | 1 |
| 210 | /s/210 | 720×1280 | tous | lecture de données | 6 | 0 | 0 | 0 | 1 | 1 |
| 211 | /s/211 | 390×930 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 212 | /s/212 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 1 |
| 213 | /s/213 | 1280×866 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 1 | 2 | 1 |
| 214 | /s/214 | 390×1358 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 215 | /s/215 | 390×938 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 216 | /s/216 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 217 | /s/217 | 390×1112 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 218 | /s/218 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 5 | 2 | 0 | 0 |
| 219 | /s/219 | 390×891 | tous | saisie/bascules locales | 0 | 0 | 3 | 1 | 0 | 0 |
| 220 | /s/220 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 5 | 0 |
| 221 | /s/221 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 222 | /s/222 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 0 | 3 |
| 223 | /s/223 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 224 | /s/224 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 3 | 2 | 0 | 0 |
| 225 | /s/225 | 390×844 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 226 | /s/226 | 390×844 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 227 | /s/227 | 390×914 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 228 | /s/228 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 229 | /s/229 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 230 | /s/230 | 390×844 | tous | données + actions | 2 | 1 | 0 | 0 | 1 | 101 |
| 231 | /s/231 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 5 | 4 |
| 232 | /s/232 | 390×844 | tous | lecture de données | 2 | 0 | 1 | 0 | 6 | 0 |
| 233 | /s/233 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 2 | 1 | 0 |
| 234 | /s/234 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 2 | 1 | 0 |
| 235 | /s/235 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 236 | /s/236 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 1 | 1 | 0 |
| 237 | /s/237 | 1280×820 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 1 |
| 238 | /s/238 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 0 |
| 239 | /s/239 | 1280×866 | direction, resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 240 | /s/240 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 0 |
| 241 | /s/241 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 2 | 1 | 0 |
| 242 | /s/242 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
| 243 | /s/243 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 5 | 0 |
| 244 | /s/244 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 10 | 12 |
| 244b | /s/244b | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 10 | 1 |
| 245 | /s/245 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 7 | 2 |
| 246 | /s/246 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 7 | 1 |
| 247 | /s/247 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 6 | 10 |
| 248 | /s/248 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 6 | 5 |
| 249 | /s/249 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 9 | 3 |
| 250 | /s/250 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 1 | 2 |
| 250b | /s/250b | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 1 | 0 |
| 251 | /s/251 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 5 | 10 |
| 252 | /s/252 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 1 | 5 |
| 253 | /s/253 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 6 | 1 |
| 253b | /s/253b | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 5 | 1 |
| 254 | /s/254 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 9 | 3 |
| 255 | /s/255 | 390×1000 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 1 |
| 256 | /s/256 | 390×900 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 1 |
| 257 | /s/257 | 390×844 | tous | données + actions | 4 | 1 | 0 | 0 | 1 | 1 |
| 258 | /s/258 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 1 |
| 259 | /s/259 | 390×844 | tous | données + actions | 6 | 1 | 0 | 0 | 1 | 0 |
| 260 | /s/260 | 390×900 | tous | données + actions | 34 | 1 | 0 | 0 | 1 | 1 |
| 261 | /s/261 | 390×900 | tous | navigation seule | 0 | 0 | 0 | 0 | 6 | 0 |
| 262 | /s/262 | 1280×890 | entreprise, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 263 | /s/263 | 1280×890 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 1 | 1 | 0 |
| 264 | /s/264 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 2 | 1 | 3 | 0 |
| 265 | /s/265 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 1 | 1 | 2 | 0 |
| 266 | /s/266 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 267 | /s/267 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 268 | /s/268 | 1280×890 | support, admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 269 | /s/269 | 1280×890 | admin | saisie/bascules locales | 0 | 0 | 1 | 0 | 1 | 0 |
| 270 | /s/270 | 390×900 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| 271 | /s/271 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 2 | 1 | 1 |
| 272 | /s/272 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 273 | /s/273 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 0 | 0 |
| 274 | /s/274 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 275 | /s/275 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 3 | 1 | 0 | 0 |
| 276 | /s/276 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 277 | /s/277 | 390×844 | support, admin | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 278 | /s/278 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 279 | /s/279 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 280 | /s/280 | 390×844 | admin | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 281 | /s/281 | 390×844 | admin | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| 282 | /s/282 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 283 | /s/283 | 390×844 | resp. dépt, admin | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 284 | /s/284 | 390×844 | finance, direction, admin | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 285 | /s/285 | 390×844 | entreprise, admin | boutons simulés | 0 | 0 | 0 | 1 | 0 | 0 |
| 286 | /s/286 | 390×844 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 287 | /s/287 | 768×1024 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 0 | 1 | 0 | 0 |
| 288 | /s/288 | 1280×800 | resp. dépt, admin | saisie/bascules locales | 0 | 0 | 1 | 2 | 0 | 0 |
| a1 | /s/a1 | 390×844 | tous | actions sans lecture | 0 | 1 | 0 | 0 | 2 | 0 |
| a2 | /s/a2 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 1 | 5 | 0 |
| a3 | /s/a3 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 1 | 0 | 6 | 0 |
| d1 | /s/d1 | 1500×1100 | tous | saisie/bascules locales | 0 | 0 | 2 | 0 | 3 | 0 |
| l1 | /s/l1 | 390×844 | tous | boutons simulés | 0 | 0 | 0 | 2 | 1 | 0 |
| p1 | /s/p1 | 390×844 | tous | navigation seule | 0 | 0 | 0 | 0 | 7 | 0 |
| p2 | /s/p2 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 6 | 0 |
| p3 | /s/p3 | 390×1330 | tous | navigation seule | 0 | 0 | 0 | 0 | 1 | 0 |
| p4 | /s/p4 | 390×844 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 0 | 0 |
| p5 | /s/p5 | 390×1786 | tous | saisie/bascules locales | 0 | 0 | 1 | 1 | 1 | 0 |
| s1 | /s/s1 | 390×876 | tous | statique | 0 | 0 | 0 | 0 | 0 | 0 |
| v1 | /s/v1 | 390×1600 | tous | saisie/bascules locales | 0 | 0 | 0 | 0 | 5 | 0 |
