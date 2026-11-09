/// Implémentation inactive pour les plateformes sans FCM natif.
Future<void> initNativePush() async {}

Future<String> enableNativePush() async =>
    'Les notifications natives ne sont pas disponibles sur cette plateforme.';

Future<void> syncNativePushForCurrentUser() async {}

Future<void> unregisterNativePushForCurrentUser() async {}
