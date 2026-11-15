import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart' show gToast;
import 'auth.dart' show authProvider;
import 'backend.dart';
import 'store.dart' show IntV;
import 'native_push_stub.dart'
    if (dart.library.io) 'native_push.dart'
    as native_push;
import 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';

/// Notifications réelles : enregistre le consentement par canal (table notification_preferences, lue par la mise en file du serveur) et
/// abonne le navigateur aux notifications. L'envoi lui-même est fait par la fonction Edge « dispatch-notifications » quand les clés des services sont posées.

/// Transmet au serveur les canaux dont la personne a changé le réglage sur les écrans 156 et 236 (« app » = notifications du navigateur).
/// Seuls les canaux touchés sont envoyés : aucun consentement n'est enregistré à la place de la personne.
/// Renvoie le premier message d'erreur du serveur, ou null si tout est enregistré.
Future<String?> syncChannelPrefs(Map<String, bool> prefs, {Set<String>? only}) async {
  if (!Backend.ready) return null;
  const map = {
    'email': 'email',
    'sms': 'sms',
    'whatsapp': 'whatsapp',
    'app': 'push',
  };
  String? first;
  for (final e in map.entries) {
    if (!prefs.containsKey(e.key)) continue;
    if (only != null && !only.contains(e.key)) continue;
    final r = await Backend.rpc('set_notification_preference', {
      'p_channel': e.value,
      'p_kind': '*',
      'p_enabled': prefs[e.key],
    });
    first ??= r.error == null ? null : Backend.userMessage(r.error!);
  }
  return first;
}

/// Réglages réels du compte, relus sur le serveur : consentement par canal, catégories reçues dans l'application, appareil abonné, numéro WhatsApp.
class NotifSettings {
  const NotifSettings({this.channels = const {}, this.categories = const {}, this.hasDevice = false, this.whatsappNumber = ''});

  /// Canaux enregistrés comme activés (email, sms, whatsapp, push) ; un canal absent n'a jamais été activé.
  final Map<String, bool> channels;

  /// Catégories de notifications reçues (orders, messages, promotions, reviews) ; absente = reçue.
  final Map<String, bool> categories;
  final bool hasDevice;
  final String whatsappNumber;

  bool category(String k) => categories[k] ?? true;
}

final notifSettingsProvider = FutureProvider.autoDispose<NotifSettings>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || Backend.userId == null) return const NotifSettings();
  final prefs = await Backend.rows('notification_preferences', 'channel,kind,enabled', limit: 100);
  final dev = await Backend.rows('device_tokens', 'platform', limit: 1);
  final contact = await Backend.rows('notification_contacts', 'whatsapp_number', limit: 1);
  final channels = <String, bool>{};
  final cats = <String, bool>{};
  for (final r in prefs.rows) {
    final kind = '${r['kind']}';
    if (r['channel'] == 'inapp' && kind.startsWith('cat:')) {
      cats[kind.substring(4)] = r['enabled'] == true;
    } else if (kind == '*') {
      channels['${r['channel']}'] = r['enabled'] == true;
    }
  }
  return NotifSettings(
    channels: channels,
    categories: cats,
    hasDevice: dev.rows.isNotEmpty,
    whatsappNumber: contact.rows.isEmpty ? '' : '${contact.rows.first['whatsapp_number']}',
  );
}, retry: (_, _) => null);

/// Compteur de relecture des interrupteurs de l'écran 56 : force leur affichage à l'état réel du serveur après un refus.
final notifSettingsRevisionProvider = NotifierProvider<IntV, int>(IntV.new);

/// Enregistre une catégorie de notifications reçue dans l'application ; renvoie un message d'erreur, ou null.
Future<String?> setNotificationCategory(String cat, bool on) async {
  final r = await Backend.rpc('set_notification_preference', {'p_channel': 'inapp', 'p_kind': 'cat:$cat', 'p_enabled': on});
  return r.error == null ? null : Backend.userMessage(r.error!);
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

/// Déconnexion simple : l'appareil (navigateur ou installation native) cesse de recevoir les notifications du compte.
/// À appeler tant que la session est encore ouverte.
Future<void> unregisterThisDevice() async {
  if (!Backend.ready) return;
  if (kIsWeb) {
    final sub = await currentWebPushSubscription();
    if (sub != null) await Backend.rpc('unregister_device', {'p_token': sub});
    return;
  }
  await native_push.unregisterNativePushForCurrentUser();
}

class EnablePushButton extends StatelessWidget {
  const EnablePushButton({super.key, this.width = 342, this.onDone});

  final double width;

  /// Appelé après la tentative d'abonnement (succès ou non), pour relire l'état réel de l'appareil.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final message = kIsWeb
          ? await enableBrowserPush()
          : await native_push.enableNativePush();

      if (context.mounted) {
        gToast(context, message);
      }
      onDone?.call();
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

/// Canaux réellement configurés sur le serveur (SMS et WhatsApp : secrets Twilio) ; l'e-mail et l'application sont toujours disponibles.
final serverChannelsProvider = FutureProvider.autoDispose<Map<String, bool>>((ref) => Backend.recoveryChannels());
