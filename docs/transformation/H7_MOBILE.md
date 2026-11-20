# H7 — Configuration native Android / iOS

Lot mobile H7. Vérification faite **par lecture du code et des fichiers** sous Windows : aucun build, aucun appareil, aucun Xcode. Rien n'a été simulé.

## 1. Ce qui a été corrigé

| Fichier | Correction |
|---|---|
| `ios/Runner/Runner.entitlements` (nouveau) + `ios/Runner.xcodeproj/project.pbxproj` | Absence totale d'entitlements : sans `aps-environment`, aucune notification push iOS n'est possible. Fichier ajouté et `CODE_SIGN_ENTITLEMENTS` branché sur Debug/Release/Profile. La valeur `development` est remplacée par Xcode (`production`) à la signature de distribution. |
| `ios/Runner/Info.plist` | `UIBackgroundModes` : `remote-notification` (push FCM) et `audio` (recommandé par livekit_client pour le direct). `CFBundleURLTypes` : schéma `cm.iutdouala.boutik_ecole` (lien de réinitialisation, identique à Android). `FlutterDeepLinkingEnabled=false` (comme `flutter_deeplinking_enabled` sur Android : supabase_flutter traite le lien, le routeur ne doit pas afficher « écran introuvable »). |
| `android/app/src/main/AndroidManifest.xml` | `<queries>` pour `android.speech.RecognitionService` (dictée Kéla sur Android 11+, exigé par speech_to_text) ; canal de notification par défaut `boutik_notifications` et icône monochrome `ic_stat_notification` (sans icône monochrome, Android affiche un carré blanc). |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Création du canal `boutik_notifications` (priorité haute) : le serveur (`dispatch-notifications`) n'envoie aucun `channel_id`, FCM utilisait le canal de secours de priorité moyenne. |
| `android/app/src/main/res/drawable/ic_stat_notification.xml` (nouveau) | Icône de notification (cloche, blanche). Remplaçable par un visuel de marque. |
| `android/app/build.gradle.kts` | Commentaire qui renvoyait vers un document inexistant (`PUBLICATION_ANDROID.md`) : renvoie maintenant vers ce document. |

Aucune migration, aucun fichier Dart modifié (donc pas d'`flutter analyze` nécessaire), `pubspec.yaml` inchangé.

## 2. Android

### Vérifié (lecture)
- `applicationId` / `namespace` = `cm.iutdouala.boutik_ecole`, identique à `package_name` de `google-services.json`, à `firebase_options.dart` et au schéma du lien profond.
- Version : `pubspec.yaml` `0.1.0+1` → `versionName/versionCode` via `flutter.*` (cohérent avec `local.properties` : 0.1.0 / 1).
- `minSdk` = `flutter.minSdkVersion` (24 dans Flutter 3.47.8), `targetSdk`/`compileSdk` = 36 : au-dessus des minimums des plugins utilisés (speech_to_text 21, mobile_scanner 23, firebase 23, livekit/WebRTC 24).
- Permissions déclarées vs usages réels :
  - `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE` : Supabase, LiveKit.
  - `RECORD_AUDIO` : record (messages vocaux), speech_to_text (Kéla), LiveKit.
  - `CAMERA` (+ `uses-feature camera required=false`) : image_picker, mobile_scanner, LiveKit.
  - `POST_NOTIFICATIONS` : demandée à l'exécution par `FirebaseMessaging.requestPermission` (`native_push.dart`, après action explicite et consentement).
  - `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH*` (plafonnés à l'API 30 sauf `BLUETOOTH_CONNECT`) : LiveKit/speech_to_text ; `Permission.bluetoothConnect` est demandée à l'exécution (`live_transport_native.dart`).
  - Absentes à raison : localisation (`geo_*` n'est actif que sur le web), contacts (fonction interne à l'application, pas le carnet du téléphone), biométrie (aucun plugin), stockage (image_picker/file_picker passent par le sélecteur système).
- Lien de réinitialisation : intent-filter `cm.iutdouala.boutik_ecole://reset-callback` présent ; `Backend.recoveryRedirect()` l'utilise sur Android.
- Signature release : `key.properties` et `*.jks`/`*.keystore` sont ignorés par git (`android/.gitignore`), seul `key.properties.example` est versionné ; sans `key.properties` la release est **non signée** (aucun repli sur la clé de débogage). Aucun secret dans le dépôt.
- Firebase : plugin `com.google.gms.google-services` 4.5.0 appliqué ; `google-services.json` présent localement, coordonnées cohérentes (projet `boutik-ecole`). Il est ignoré par git (`.gitignore` racine). Les clés de `firebase_options.dart` sont des identifiants publics de client Firebase, pas des secrets serveur.
- Code natif / web : tous les fichiers `*_web.dart` (`dart:js_interop`, `package:web`) sont importés par import conditionnel (`dart.library.js_interop`) avec un `_stub` natif ; `native_push.dart` n'est chargé que si `dart.library.io` ; `Platform.*` n'est utilisé que dans les fichiers natifs.
- Push (Dart) : initialisation sans demande de permission, `setAutoInitEnabled(false)` tant qu'il n'y a pas de consentement, jeton FCM enregistré par RPC `register_device`, renouvellement géré (`onTokenRefresh`), retrait du jeton à la déconnexion.

### Non vérifié (exige un build / un appareil)
- Compilation Android (aucun build lancé, consigne du lot) : en particulier `MainActivity.kt` et l'icône ajoutés ici.
- R8/ProGuard : aucun `proguard-rules.pro` ni `minify` explicite ; le comportement dépend des valeurs par défaut du plugin Flutter. À tester sur un APK **release** (LiveKit/WebRTC, Firebase, record) avant publication.
- Réception réelle d'une notification (application fermée, canal, icône) ; Android 13+ : les notifications reçues au premier plan ne sont pas affichées par le système (aucun gestionnaire `onMessage` : les notifications internes de l'application font foi).
- Ouverture réelle du lien de réinitialisation depuis un e-mail.
- Pas de liens d'application `https://boutik-ecole.vercel.app/...` (App Links) : les liens de partage s'ouvrent dans le navigateur, qui charge la version web. Les ajouter exige `assetlinks.json` sur le domaine avec l'empreinte SHA-256 de la clé de signature (voir blocages).

## 3. iOS

### Vérifié sous Windows (lecture de fichiers uniquement)
- Bundle id : `cm.iutdouala.boutikEcole` (Runner) ; identique dans `GoogleService-Info.plist` (`BUNDLE_ID`), `firebase_options.dart` (`iosBundleId`) et `project.pbxproj`. Il diffère volontairement du package Android (le tiret bas est interdit dans un bundle id iOS).
- `IPHONEOS_DEPLOYMENT_TARGET = 15.0` : ≥ aux exigences des plugins lus (firebase_core/messaging 15.0, livekit 13.0, mobile_scanner 12.0).
- Version : `CFBundleShortVersionString`/`CFBundleVersion` = `FLUTTER_BUILD_NAME/NUMBER` (0.1.0 / 1, comme `pubspec.yaml`).
- `Info.plist` : `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` (image_picker, mobile_scanner, record, LiveKit, speech_to_text), clés Firebase Messaging, **ajoutés par H7** : modes d'arrière-plan, schéma d'URL, désactivation du deep linking Flutter. Fichiers plist validés syntaxiquement.
- Aucune clé de localisation / contacts / Face ID : aucun plugin correspondant.
- `GoogleService-Info.plist` présent localement, ignoré par git. Il n'est pas référencé dans `project.pbxproj` ; sans conséquence : Firebase est initialisé avec `DefaultFirebaseOptions` (Dart).
- Entitlements : `aps-environment` ajouté (voir §1). Pas de « Associated Domains » : l'application n'utilise pas de Universal Links.
- Lien de réinitialisation : le schéma est maintenant enregistré, mais `Backend.recoveryRedirect()` renvoie volontairement l'adresse web sur iOS (comportement existant, conservé, non testable ici). Basculer iOS sur le schéma natif est possible une fois testé sur un iPhone.
- Podfile : aucun n'est versionné ; Flutter 3.47 utilise Swift Package Manager (`ios/Flutter/ephemeral/Packages`). `permission_handler_apple` 9.6.5 active ses permissions d'après les clés `Info.plist` (caméra, micro) en mode SPM. Sous CocoaPods, il faudrait les macros `PERMISSION_*` dans un Podfile.

### Exige macOS / Xcode (non fait, non simulé)
- `flutter build ios`, compilation du projet et de `Runner.entitlements`, résolution des paquets Swift.
- Signature (équipe de développement, profils de provisioning), archive, **TestFlight**/App Store Connect.
- **APNs** : création de la clé APNs (.p8) et son téléversement dans Firebase ; test d'une notification réelle sur iPhone (le simulateur ne reçoit pas de vrai push). Le code Dart renvoie « Configuration Apple Push (APNs) incomplète » tant que le jeton APNs est absent.
- Confirmer, après `flutter build ios` sur Mac, que `ios/Runner/Info.plist` garde les permissions caméra/micro actives pour permission_handler (variable `PERMISSION_HANDLER_VERBOSE=1`).
- Capability « Push Notifications » et « Background Modes » visibles dans Xcode (Signing & Capabilities) : elles découlent de l'entitlement et de `UIBackgroundModes`, à confirmer visuellement.

## 4. Dépendances (`flutter pub outdated`, lecture seule)
Aucun conflit. Mises à jour mineures disponibles, volontairement non appliquées (risque de régression sans test sur appareil) : file_picker 13.4.0, firebase_core 5.2.0, firebase_messaging 17.1.0, flutter_riverpod 3.5.0, flutter_svg 2.5.0, go_router 18.1.4, livekit_client 2.14.0, record 7.2.0 ; `qr` 4.0.1 est une version majeure. Tous les plugins déclarés prennent en charge Android et iOS ; `web` n'est utilisé que sur le web.

## 5. Blocages propriétaire (liste exacte)
1. **Clé de signature Android** : `android/key.properties` + fichier `.jks` doivent exister sur la machine de build du propriétaire (un `key.properties` est présent sur le poste actuel et son `storeFile` existe, contenu non lu). À sauvegarder hors dépôt ; sans elle, pas de publication Play Store. Modèle : `android/key.properties.example`.
2. **`android/app/google-services.json`** et **`ios/Runner/GoogleService-Info.plist`** : ignorés par git ; un clone propre ou une CI ne compile pas Android (plugin google-services) tant que `google-services.json` n'est pas fourni. À télécharger depuis la console Firebase (projet `boutik-ecole`) ou à injecter par la CI. Ajouter les empreintes SHA-1/SHA-256 de la clé de signature dans la console Firebase.
3. **APNs** : clé d'authentification APNs (.p8) à créer dans le compte Apple Developer et à téléverser dans Firebase Cloud Messaging → sans elle, aucun push iOS.
4. **Compte Apple Developer** (équipe, certificats, profils) et machine macOS avec Xcode pour build, signature, TestFlight.
5. **Supabase Auth → Redirect URLs** : ajouter `cm.iutdouala.boutik_ecole://reset-callback/` (sinon le lien Android de réinitialisation est refusé par Supabase) en plus de `https://boutik-ecole.vercel.app/**`.
6. **Secret serveur Firebase** (compte de service FCM utilisé par la fonction `dispatch-notifications`) : à confirmer par le propriétaire côté Supabase ; non consulté dans ce lot.
7. **App Links Android / Universal Links iOS** (optionnel) : exigent `assetlinks.json` / `apple-app-site-association` sur `boutik-ecole.vercel.app` (SHA-256 de la clé de signature, identifiant d'équipe Apple). Décision propriétaire.
8. **Visuels de publication** : icône de notification de marque (remplacement de `ic_stat_notification.xml`), icônes/écran de démarrage finaux, fiches Play Store/App Store.

## 6. Procédure de signature Android (rappel)
1. Générer une clé : `keytool -genkey -v -keystore boutik-ecole-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias boutik-ecole` (hors du dépôt).
2. Copier `android/key.properties.example` en `android/key.properties` et le remplir (fichier ignoré par git).
3. `flutter build appbundle --release` ; sans `key.properties` l'artefact est non signé.

## Builds Android réellement exécutés (20 novembre 2026, poste de développement Windows)

- `flutter build apk --debug` : réussi (254 Mo). `flutter build apk --release` : réussi (182,4 Mo, R8 inclus), signé avec la clé locale hors dépôt. Manifeste vérifié avec `aapt2` : `cm.iutdouala.boutik_ecole`, versionCode 1, versionName 0.1.0, minSdk 24, targetSdk 36, compileSdk 37, permissions conformes.
- Trois obstacles réels rencontrés et traités :
  1. `permission_handler_android` exige `compileSdk` 37 alors que Flutter fournit 36 : `android/app/build.gradle.kts` utilise désormais `maxOf(flutter.compileSdkVersion, 37)` (targetSdk inchangé). La plateforme Android 37 s'est installée sous le nom `android-37.0` : une jonction `platforms\android-37` a été créée sur le poste (hors dépôt).
  2. Sur ce poste, `GRADLE_USER_HOME` et la jonction `C:\Users\NITROV15\.gradle` pointent vers le disque `D:` absent : les builds ont utilisé `GRADLE_USER_HOME=C:\tmp\gradlehome` (variable de processus). À corriger sur le poste (réattacher le disque D: ou changer la variable).
  3. `android/key.properties` (non versionné) avait `storeFile` avec des barres inverses non échappées, ce qui donnait un chemin invalide : remplacé par des barres obliques. Les mots de passe n'ont pas été lus.
- Un `flutter build apk --release --no-pub` échoue si le registre de plugins a été généré par un build debug (`integration_test` absent en release) : lancer `flutter pub get` avant un build release.
- Toujours NON validé : exécution sur un appareil ou un émulateur, réception réelle d'une notification push, lien de réinitialisation, caméra/micro réels, iOS (macOS et Xcode indispensables).
