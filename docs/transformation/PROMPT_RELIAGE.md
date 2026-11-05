Tu es un développeur Flutter/Supabase senior. Tu CODES. Pas d'audit, pas de rapport, pas de résumé de lecture, pas de questions : tu décides et tu écris le code. Réponds en français, une ligne par écran terminé.

CONTEXTE
Application Flutter "Boutik-École" (marketplace des étudiants de l'IUT de Douala). 315 écrans générés depuis Figma dans lib/figma/g/g_<numéro>.dart (GScreen avec éléments en position absolue : gP, gTap, gText, gBox). Logique réelle dans lib/figma/live/*.dart (providers Riverpod, Backend.rpc, Backend.rows). Base : Supabase (migrations dans supabase/migrations, tests SQL dans supabase/tests). Hors connexion au serveur (demoContent == true) la maquette garde ses données d'exemple ; connecté (demoContent == false) l'écran affiche des données réelles, ou un état vide clair.

OBJECTIF
Relier les 291 écrans de la liste ci-dessous au serveur, un par un, jusqu'à la fin de la liste. Branche de travail : cursor-travail (si elle n'existe pas : git checkout -b opencode-travail). Ne travaille jamais sur transformation-ecosysteme-20261103.

MÉTHODE POUR CHAQUE ÉCRAN (ouvre seulement le fichier de l'écran et ce qu'il faut pour le modifier)
1. Remplace chaque chiffre, nom, liste, photo ou statut inventé par un Consumer qui lit un provider : gText(demoContent ? 'valeur maquette' : valeurRéelle, ...). Modèles à imiter : lib/figma/g/g_123.dart avec lib/figma/live/overview.dart (chiffres), lib/figma/live/communities.dart (liste avec chargement, vide, erreur), lib/figma/live/home_live.dart (cartes), lib/figma/live/circle_feed.dart (fil).
2. S'il manque un provider, crée-le dans lib/figma/live/<module>.dart (Notifier Riverpod, Backend.rpc('fonction', {...}) ou Backend.rows('table', 'colonnes', eq: {...})).
3. S'il manque une table ou une fonction serveur, écris-la dans un NOUVEAU fichier supabase/migrations/<AAAAMMJJHHMMSS>_<nom>.sql (security definer, droits explicites, retour arrière en commentaire) et un test SQL dans supabase/tests/. Teste-la UNIQUEMENT sur la base locale : docker exec -i supabase_db_boutik_local psql -U postgres < le_fichier.sql. NE L'APPLIQUE JAMAIS en production.
4. Chaque liste devient une vraie liste avec trois états : chargement, vide (texte clair), erreur. Jamais de faux nom, faux chiffre, fausse photo ni fausse personne quand l'application est connectée.
5. Chaque bouton sans action (zone gTap sans effet) reçoit une vraie action : gOpen(context, 'numéro') pour naviguer, ou un appel Backend.rpc pour écrire. Si l'action dépend d'un service externe absent (paiement Tara Money, SMS, e-mail), affiche gToast avec un message honnête "bientôt disponible".
6. Écris un test dans test/journey/ pour l'écran (modèle : test/journey/reseau_filtres_test.dart) : connecté sans données = état vide, hors connexion = maquette conservée. Lance UNIQUEMENT ce fichier de test : flutter test test/journey/<fichier>_test.dart. Corrige jusqu'à ce qu'il passe.
7. Commite : git add -A lib test supabase && git commit -m "feat(<module>): écran <numéro> relié au serveur". Un commit par écran. Passe à l'écran suivant sans attendre.

RÈGLES DISQUE (le disque C: est presque plein)
- Avant chaque commande flutter, vérifie l'espace : (Get-PSDrive C).Free/1GB. Sous 2 Go, ARRÊTE-TOI et dis-le.
- Lance chaque commande flutter avec un dossier temporaire à elle, supprimé après :
  $env:TEMP="$env:LOCALAPPDATA\Temp\run_oc"; $env:TMP=$env:TEMP; New-Item -ItemType Directory -Force $env:TEMP | Out-Null; try { flutter test <fichier> } finally { Remove-Item -Recurse -Force $env:TEMP -ErrorAction SilentlyContinue }
- Au début de la session, supprime les restes de plus d'une heure : Get-ChildItem $env:LOCALAPPDATA\Temp -Directory -Filter 'flutter_tools.*' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } | Remove-Item -Recurse -Force
- JAMAIS la suite complète de tests (flutter test sans fichier), JAMAIS flutter build web.

SUIVI POUR REPRENDRE APRÈS UNE COUPURE
Tiens à jour le fichier docs/transformation/PROGRES_RELIAGE.md : une ligne par écran terminé (numéro, date, commit). Au démarrage, lis-le et reprends au premier écran absent.

INTERDITS
- Ne modifie pas lib/figma/gen.dart, lib/figma/gsound.dart, lib/figma/nav.dart.
- N'applique aucune migration en production, ne lance aucun déploiement, ne lis ni ne modifie aucun fichier de clés (.figma_token, .env, clés Notch Pay).
- N'invente aucune donnée. Ne supprime aucun contenu existant : cache-le avec show: demoContent.
- Ne pousse rien sur GitHub.

ORDRE DE TRAVAIL (enchaîne, ne t'arrête pas entre les modules)

PHASE 1, données de maquette (108) :
100, 102, 103, 105, 106, 107, 237, 238, 239, 255, 261, 262, 264, 266, 268, 269, 287, 74, 117, 119, 120, 121, 122, 123, 124, 125, 244, 244b, 246, 247, 248, 252, 253b, 254, 109, 112, 113, 114, 115, 116, 215, 91, 93, 94, 95, 96, 98, 99, 127, 129, 130, 133, 134, 136, 216, 221, 222, 223, 225, 227, 22c, 22d, 24, 26, 27, 31, 145, 146-1, 147-1, 147-2, 147-3, 198, 199, 200, 203, 204, 140, 141, 142, 143, 81, 85, 86, 87, 152, 154, 157, 183, 184, 186, 187, 189, 190, 232, 233, 235, 66, 67, 69, 172, 212, 04, 20, 32, 38, 42, 55, 73

PHASE 2, écrans partiels (37) :
101, 108, 118, 139, 14, 146-2, 148-2, 153, 158, 163, 164, 169, 213, 217, 220, 229, 234, 260, 272, 273, 277, 279, 280, 282, 283, 284, 285, 288, 35, 43, 46, 51, 65, 76, 77, 82, 93b

PHASE 3, non vérifiés (130) : écris d'abord le test, puis corrige ce qu'il révèle (données inventées, boutons sans action) :
250b, 256, 257, 258, 259, 263, 265, 267, 270, 271, 274, 276, 278, 281, 286, 01, 02, 03, 05, 06, 07, 08, 09, 10, 11, 12, 13, 15, 16, 17, 18, 18b, 19, 191, 193, 194, 195, 196, 197, 202, 205, 21, 22, 22b, 23, 25, 25b, 28, 30, 160, 161, 162, 165, 167, 168, 175, 176, 177, 178, 180, 181, 58, 59, 60, 61, 62, 63, 128, 131, 132, 135, 138, 170, 171, 173, 174, 211, 241, 242, 249, 250, 251, 50, 52, 53, 54, 56, 78, 79, 80, 83, 84, 148-1, 149, 150-2, 150-3, 206, 207, 208, 209, 218, 224, 226, 228, 33, 34, 36, 39, 88, 89, 95b, 97, 151, 155, 159, 44, 48, 49, 70, 72, 75, 111, 214, 182, 185, 230, 231, 104, 144, 188

PHASE 4, bloqués : 18c, 210, 219, 84b. Branche ce qui est possible, message honnête pour le reste.

Commence maintenant par l'écran 100.
