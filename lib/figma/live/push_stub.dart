/// Hors navigateur : pas de notifications web.
Future<String?> subscribeWebPush(String publicKey) async => null;
bool get webPushSupported => false;
