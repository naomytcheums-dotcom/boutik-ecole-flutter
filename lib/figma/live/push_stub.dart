/// Hors navigateur : pas de notifications web.
Future<String?> subscribeWebPush(String publicKey) async => null;
Future<String?> currentWebPushSubscription() async => null;
bool get webPushSupported => false;
