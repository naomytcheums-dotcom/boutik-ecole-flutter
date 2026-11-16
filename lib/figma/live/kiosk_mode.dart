import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'missions.dart' show kioskSessionProvider;

/// Mode « borne » (S9-40). Un terminal public s'ouvre par l'adresse `…/?kiosk=borne-2&kt=<jeton>` (jeton créé par le support avec
/// `kiosk_provision`). Dans ce mode :
///  - aucune session personnelle n'est jamais conservée sur le terminal (une session restaurée est fermée au démarrage) ;
///  - la borne envoie un battement de cœur toutes les minutes (état « en ligne » réellement mesuré) ;
///  - « Commander » passe par un code d'appariement émis SANS compte : l'étudiant continue sur SON téléphone, connecté à son propre
///    compte ; aucun mot de passe n'est saisi sur la borne ;
///  - à l'inactivité, le code est révoqué et l'application revient à zéro (panier, recherche, session).
class KioskTerminal {
  KioskTerminal._();

  static String? _id;
  static String? _token;
  static Timer? _beat;

  /// Inactivité (en secondes) avant le retour à zéro d'un terminal ou la déconnexion d'une session ouverte sur un écran de borne.
  static const idleSeconds = 90;

  static bool get active => _id != null && _token != null;
  static String get id => _id ?? '';

  /// « Borne n°2 » pour les journaux ; « Borne » quand l'appareil n'est pas un terminal enregistré.
  static String get label {
    final n = RegExp(r'^borne-(\d{1,3})$').firstMatch(_id ?? '')?.group(1);
    return n == null ? 'Borne' : 'Borne n°$n';
  }

  /// Lit `kiosk` et `kt` dans l'adresse d'ouverture. Sans les deux paramètres, l'appareil n'est pas un terminal.
  static void configure([Uri? uri]) {
    final q = (uri ?? Uri.base).queryParameters;
    final id = (q['kiosk'] ?? '').trim();
    final tok = (q['kt'] ?? '').trim();
    if (RegExp(r'^borne-\d{1,3}$').hasMatch(id) && tok.length >= 32) {
      _id = id;
      _token = tok;
    } else {
      _id = null;
      _token = null;
    }
  }

  /// Démarrage d'un terminal : ferme toute session personnelle restaurée et lance le battement de cœur.
  static Future<void> start() async {
    if (!active || !Backend.ready) return;
    if (Backend.sessionEmail != null) {
      await Backend.signOut();
      Backend.signingOut = false;
      await saveRemembered(null);
    }
    unawaited(heartbeat());
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(heartbeat()));
  }

  static Future<void> heartbeat() async {
    if (!active || !Backend.ready) return;
    await Backend.rpc('kiosk_heartbeat', {'p_kiosk': _id, 'p_token': _token});
  }

  /// Code d'appariement pour une annonce : (jeton, null) ou (null, message).
  static Future<({String? token, String? error})> pairIssue(String listingId) async {
    final r = await Backend.rpc('kiosk_pair_issue', {'p_kiosk': _id, 'p_token': _token, 'p_listing': listingId, 'p_ttl_seconds': 300});
    if (r.error != null) return (token: null, error: r.error);
    final d = r.data;
    final t = d is Map ? d['token'] : null;
    return t is String ? (token: t, error: null) : (token: null, error: 'Code indisponible pour le moment.');
  }

  /// pending · used · expired · revoked · unknown (null : borne injoignable).
  static Future<String?> pairStatus(String pairing) async {
    final r = await Backend.rpc('kiosk_pair_status', {'p_kiosk': _id, 'p_token': _token, 'p_pairing': pairing});
    return r.error == null && r.data is String ? r.data as String : null;
  }

  static Future<void> pairRevoke(String pairing) async {
    await Backend.rpc('kiosk_pair_revoke', {'p_kiosk': _id, 'p_token': _token, 'p_pairing': pairing});
  }
}

/// Surveille l'inactivité (toucher, souris, stylet). Au bout de [KioskTerminal.idleSeconds] sans geste : le code de transfert en cours est
/// révoqué, une session ouverte est fermée et, sur un terminal, l'application revient à zéro. Pendant qu'un code attend le scan du
/// téléphone, le délai est prolongé jusqu'à son expiration. [screenLevel] : placé sur les écrans 206 à 210, sans effet sur un terminal
/// (où la garde de l'application s'applique déjà).
class KioskIdleGuard extends ConsumerStatefulWidget {
  const KioskIdleGuard({super.key, this.child, this.screenLevel = false});
  final Widget? child;
  final bool screenLevel;

  @override
  ConsumerState<KioskIdleGuard> createState() => _KioskIdleGuardState();
}

class _KioskIdleGuardState extends ConsumerState<KioskIdleGuard> {
  Timer? _timer;
  DateTime _last = DateTime.now();
  bool _touched = false;

  bool get _enabled => Backend.ready && !(widget.screenLevel && KioskTerminal.active);

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _onPointer(PointerEvent e) {
    _last = DateTime.now();
    _touched = true;
  }

  int _limit() {
    final s = ref.read(kioskSessionProvider);
    if (s != null && s.server && !s.used && !s.expired) return s.secondsLeft() + 30;
    return KioskTerminal.idleSeconds;
  }

  void _tick() {
    if (!mounted || DateTime.now().difference(_last).inSeconds < _limit()) return;
    _last = DateTime.now();
    final signedIn = ref.read(authProvider).current != null;
    final pending = ref.read(kioskSessionProvider) != null;
    if (pending) ref.read(kioskSessionProvider.notifier).cancel();
    if (signedIn) {
      ref.read(authProvider.notifier).logout();
    } else if (KioskTerminal.active && (_touched || pending)) {
      appReset?.call();
    }
    _touched = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
