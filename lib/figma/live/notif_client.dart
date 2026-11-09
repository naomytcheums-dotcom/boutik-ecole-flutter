import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart' show gToast;
import 'backend.dart';
import 'native_push_stub.dart'
    if (dart.library.io) 'native_push.dart'
    as native_push;
import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';

/// Notifications réelles : enregistre le consentement par canal (table notification_preferences, lue par la mise en file du serveur) et
/// abonne le navigateur aux notifications. L'envoi lui-même est fait par la fonction Edge « dispatch-notifications » quand les clés des services sont posées.

/// Transmet au serveur les choix de canaux enregistrés sur les écrans 156 et 236 (« app » = notifications du navigateur).
Future<void> syncChannelPrefs(Map<String, bool> prefs) async {
  if (!Backend.ready) return;
  const map = {
    'email': 'email',
    'sms': 'sms',
    'whatsapp': 'whatsapp',
    'app': 'push',
  };
  for (final e in map.entries) {
    if (!prefs.containsKey(e.key)) continue;
    await Backend.rpc('set_notification_preference', {
      'p_channel': e.value,
      'p_kind': '*',
      'p_enabled': prefs[e.key],
    });
  }
}

/// Demande l'autorisation, abonne le navigateur et enregistre l'appareil. Renvoie un message à afficher.
Future<String> enableBrowserPush() async {
  if (!Backend.ready) return 'Connexion requise.';
  if (!webPushSupported)
    return 'Ce navigateur ne prend pas en charge les notifications.';
  try {
    final r = await Supabase.instance.client.functions.invoke('push-config');
    final key =
        (r.data is Map ? (r.data as Map)['publicKey'] : null) as String?;
    if (key == null || key.isEmpty)
      return 'Les notifications du navigateur ne sont pas encore configurées par l’administrateur.';
    final sub = await subscribeWebPush(key);
    if (sub == null)
      return 'Autorisation refusée ou impossible. Vérifiez les réglages de votre navigateur.';
    final reg = await Backend.rpc('register_device', {
      'p_token': sub,
      'p_platform': 'web',
    });
    if (reg.error != null) return Backend.userMessage(reg.error!);
    await Backend.rpc('set_notification_preference', {
      'p_channel': 'push',
      'p_kind': '*',
      'p_enabled': true,
    });
    return 'Notifications du navigateur activées.';
  } catch (_) {
    return 'Les notifications du navigateur ne sont pas encore configurées par l’administrateur.';
  }
}

class EnablePushButton extends StatelessWidget {
  const EnablePushButton({super.key, this.width = 342});

  final double width;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final message = kIsWeb
          ? await enableBrowserPush()
          : await native_push.enableNativePush();

      if (context.mounted) {
        gToast(context, message);
      }
    },
    child: Container(
      width: width,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E1EE), width: 1.5),
      ),
      child: Text(
        kIsWeb
            ? 'Activer les notifications du navigateur'
            : 'Activer les notifications sur cet appareil',
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111015),
        ),
      ),
    ),
  );
}
