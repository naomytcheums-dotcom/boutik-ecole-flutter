# 06 — Compatibilité Web, Android et iOS (phase 4)

| Plateforme | État | Preuve |
|---|---|---|
| **Web** (Vercel) | En production : version `706cb391…` (commit `673c324`) | Empreinte du fichier servi identique au build ; Playwright en ligne 15/15 (visiteur 12, connexion 1, retrait 1, démarrage S1 1) ; mise en page testée en 375×667, 390×844 et en tablette (spécification `visiteur`) |
| Navigateurs | **Chromium seulement** testé | Firefox et WebKit (Safari) non installés pour Playwright : à faire |
| **Android** | Chaîne d'outils **installée** : JDK 17 Temurin, SDK 36, build-tools 36, licences acceptées ; `flutter doctor` vert | `donnees/flutter_doctor_android.txt` |
| APK | **Non compilé** | Mémoire engagée à 58,2 sur 63,7 Go, et Gradle réservé à 8 Go : la compilation aurait fait grossir le fichier d'échange sur un disque presque plein |
| Manifeste Android | Permissions `INTERNET` et `RECORD_AUDIO` ; minSdk, targetSdk et compileSdk de Flutter (compileSdk 36) | `android/app` |
| Signature de publication | **À faire** : la compilation release utilise encore la clé de débogage | création d'une clé de téléversement (keystore), avec votre accord |
| **iOS** | **Impossible sur ce PC** : il faut un Mac avec Xcode | `Info.plist` complété (descriptions d'usage) ; compilation, signature et TestFlight à faire sur Mac |

## Commandes pour terminer Android (après redémarrage de Windows)
1. Facultatif, pour moins de mémoire : `%USERPROFILE%\.gradle\gradle.properties` avec `org.gradle.jvmargs=-Xmx3g`.
2. `flutter build apk --release`. Gradle téléchargera le NDK 28.2 (environ 2,5 Go) et ses dépendances (environ 2 Go) : prévoir au moins 6 Go libres.
3. `adb install build\app\outputs\flutter-apk\app-release.apk` sur un téléphone, puis parcours visiteur et connexion.
