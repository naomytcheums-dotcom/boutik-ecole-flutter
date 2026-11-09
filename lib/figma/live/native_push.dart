import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import 'backend.dart';

const _consentPrefix = 'boutik_fcm_consent_';

String _consentKey(String userId) => '$_consentPrefix$userId';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Une erreur Firebase ne doit jamais faire planter l'application.
  }
}

StreamSubscription<String>? _registeredSubscription;
StreamSubscription<String>? _unregisteredSubscription;

Completer<void>? _registrationWaiter;

bool _initialized = false;
bool _initializing = false;

bool get _supported => Platform.isAndroid || Platform.isIOS;

/// Initialise Firebase sans demander la permission de notification.
Future<void> initNativePush() async {
  if (!_supported || _initialized || _initializing) return;

  _initializing = true;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;

    // Pas d'inscription automatique avant le consentement explicite.
    await messaging.setAutoInitEnabled(false);

    await _registeredSubscription?.cancel();
    await _unregisteredSubscription?.cancel();

    // Le listener est installé avant tout appel à register().
    _registeredSubscription = messaging.onRegistered.listen((fid) {
      unawaited(_handleRegisteredFid(fid));
    });

    _unregisteredSubscription = messaging.onUnregistered.listen((fid) {
      unawaited(_handleUnregisteredFid(fid));
    });

    // Renouvellement du jeton FCM : on le ré-enregistre (consentement requis).
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((t) {
      if (t.isNotEmpty) unawaited(_handleRegisteredFid(t));
    });

    _initialized = true;
  } catch (_) {
    // Firebase reste facultatif : l'application doit pouvoir démarrer.
  } finally {
    _initializing = false;
  }
}

/// Enregistre le FID de cette installation pour l'utilisateur connecté.
Future<void> _registerFid(String userId, String fid) async {
  if (!Backend.ready || fid.isEmpty) {
    throw Exception('Connexion ou identifiant Firebase indisponible.');
  }

  if (Backend.currentUserId != userId) {
    throw Exception('La session utilisateur a changé.');
  }

  final platform = Platform.isIOS ? 'ios' : 'android';

  final registered = await Backend.rpc('register_device', {
    'p_token': fid,
    'p_platform': platform,
  });

  if (registered.error != null) {
    throw Exception(registered.error);
  }

  if (Backend.currentUserId != userId) {
    throw Exception('La session utilisateur a changé.');
  }

  final preference = await Backend.rpc('set_notification_preference', {
    'p_channel': 'push',
    'p_kind': '*',
    'p_enabled': true,
  });

  if (preference.error != null) {
    throw Exception(preference.error);
  }
}

/// Traite chaque FID émis par Firebase, uniquement après consentement.
Future<void> _handleRegisteredFid(String fid) async {
  final waiter = _registrationWaiter;

  try {
    if (fid.isEmpty || !Backend.ready) return;

    final uid = Backend.currentUserId;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_consentKey(uid)) != true) return;

    // L'API FCM HTTP v1 exige un jeton d'enregistrement FCM, pas l'identifiant
    // d'installation (FID) émis par onRegistered : on l'obtient ici.
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Jeton FCM indisponible.');
    }
    await prefs.setString('boutik_fcm_token_$uid', token);
    await _registerFid(uid, token);

    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  } catch (error, stackTrace) {
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(error, stackTrace);
    }
    // Une erreur de synchronisation ne bloque jamais l'application.
  }
}

/// Retire du serveur un FID que Firebase vient de désinscrire.
Future<void> _handleUnregisteredFid(String fid) async {
  if (fid.isEmpty || !Backend.ready) return;

  final uid = Backend.currentUserId;
  if (uid == null) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('boutik_fcm_token_$uid');
    if (token != null && token.isNotEmpty) {
      await Backend.rpc('unregister_device', {'p_token': token});
      await prefs.remove('boutik_fcm_token_$uid');
    }
  } catch (_) {
    // Le nettoyage sera retenté lors d'une prochaine synchronisation.
  }
}

/// Active les notifications après action explicite de l'utilisateur.
Future<String> enableNativePush() async {
  if (!_supported) {
    return 'Notifications natives indisponibles.';
  }

  if (!Backend.ready || Backend.currentUserId == null) {
    return 'Connectez-vous pour activer les notifications.';
  }

  await initNativePush();

  if (!_initialized) {
    return 'Initialisation des notifications impossible. Réessayez.';
  }

  final uid = Backend.currentUserId;
  if (uid == null) return 'Session expirée. Reconnectez-vous.';

  final prefs = await SharedPreferences.getInstance();

  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return 'Autorisation refusée. Vérifiez les réglages de votre téléphone.';
    }

    // Sur iOS, FCM doit disposer du jeton APNs avant l'inscription.
    if (Platform.isIOS) {
      final apnsToken = await messaging.getAPNSToken();

      if (apnsToken == null || apnsToken.isEmpty) {
        return 'Configuration Apple Push (APNs) incomplète. Réessayez après sa configuration.';
      }
    }

    // Le consentement local est posé avant register(), car onRegistered
    // peut être émis immédiatement après l'inscription.
    await prefs.setBool(_consentKey(uid), true);

    final waiter = Completer<void>();
    _registrationWaiter = waiter;

    await messaging.setAutoInitEnabled(true);
    await messaging.register();

    await waiter.future.timeout(const Duration(seconds: 25));

    return 'Notifications activées sur cet appareil.';
  } catch (_) {
    await prefs.setBool(_consentKey(uid), false);

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
    } catch (_) {}

    return 'Activation impossible. Vérifiez votre connexion et réessayez.';
  } finally {
    _registrationWaiter = null;
  }
}

/// Réinscrit le FID après restauration ou ouverture d'une session,
/// uniquement si cet utilisateur a déjà donné son consentement.
Future<void> syncNativePushForCurrentUser() async {
  if (!_supported || !_initialized || !Backend.ready) return;

  final uid = Backend.currentUserId;
  if (uid == null) return;

  try {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_consentKey(uid)) != true) return;

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.getNotificationSettings();

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    if (Platform.isIOS) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken == null || apnsToken.isEmpty) return;
    }

    await messaging.setAutoInitEnabled(true);
    await messaging.register();
  } catch (_) {
    // Une erreur de synchronisation ne bloque jamais la connexion.
  }
}

/// La déconnexion globale nettoie les appareils via unregister_all_devices.
/// Cette fonction est conservée pour compatibilité avec les anciens appels.
Future<void> unregisterNativePushForCurrentUser() async {
  if (!_supported || !_initialized || !Backend.ready) return;

  final uid = Backend.currentUserId;
  if (uid == null) return;

  try {
    // Retire uniquement l'association de cette installation.
    // Ne désactive pas la préférence push globale du compte.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_consentKey(uid)) != true) return;

    // Le FID est obtenu par l'événement onRegistered.
    // Aucune API getToken() dépréciée n'est utilisée ici.
  } catch (_) {
    // La déconnexion ne doit jamais être bloquée.
  }
}
