import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'figma/gdata.dart' show GData;
import 'figma/i18n.dart' show I18n;
import 'figma/live/auth.dart';
import 'figma/live/backend.dart';
import 'figma/live/drafts.dart';
import 'figma/live/referral.dart' show capturePendingReferral;
import 'figma/live/kiosk_mode.dart' show KioskTerminal;
import 'figma/live/qr.dart' show capturePendingQr;
import 'figma/live/native_push_stub.dart'
    if (dart.library.io) 'figma/live/native_push.dart'
    as native_push;
import 'figma/live/start_gate.dart' show SecondFactorGate;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    // Android : plein écran « bord à bord » ; la barre système (boutons ou gestes) devient transparente et laisse voir le fond de l'application,
    // sans second menu noir ou blanc. Le menu de Boutik-École se place au-dessus de la zone réservée (MediaQuery.padding.bottom).
    // Barre de navigation du téléphone masquée (comme Facebook) : un balayage depuis le bas la fait réapparaître un instant.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ));
  }
  // Démarrage borné : sur un réseau lent, aucune étape réseau ne doit retenir l'écran blanc plus de quelques secondes.
  const limite = Duration(seconds: 8);
  await Backend.init().timeout(limite, onTimeout: () {});
  await native_push.initNativePush().timeout(limite, onTimeout: () {});
  await Drafts.load().timeout(limite, onTimeout: () {});
  await capturePendingReferral().timeout(limite, onTimeout: () {});
  capturePendingQr();
  // Terminal public (?kiosk=…&kt=…) : jamais de session personnelle, battement de cœur de la borne.
  KioskTerminal.configure();
  await KioskTerminal.start().timeout(limite, onTimeout: () {});
  await I18n.init();
  final remembered = await loadRemembered().timeout(const Duration(seconds: 25), onTimeout: () => null);
  // Session restaurée d'un compte protégé par la vérification en 2 étapes : le code est exigé avant tout accès (porte SecondFactorGate).
  final secondFactor = remembered == null ? null : await Backend.pendingSecondFactor().timeout(const Duration(seconds: 10), onTimeout: () => null);
  if (remembered != null && secondFactor == null) {
    // notifications natives : en arrière-plan, sans retarder l'ouverture
    native_push.syncNativePushForCurrentUser().timeout(const Duration(seconds: 20), onTimeout: () {}).ignore();
  }
  GData.watchNetwork(); // type de réseau (Wi-Fi ou données mobiles) pour l'économie de données
  // La présentation (S1, 01, 02) n'est montrée qu'au tout premier démarrage ; ensuite : accueil du rôle (connecté) ou accueil visiteur.
  final firstRun = remembered == null && !await introSeen();
  if (firstRun || remembered != null) await markIntroSeen();
  runApp(AppRoot(remembered: remembered, secondFactorId: secondFactor, firstRun: firstRun));
}

/// Racine de l'application. À la déconnexion, tout l'état (formulaires, annonces, panier, commandes, profil…) est jeté :
/// l'utilisateur suivant sur le même appareil repart d'un état vierge.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, this.remembered, this.secondFactorId, this.firstRun = true});
  final Account? remembered;

  /// Facteur TOTP dont le code reste à saisir avant d'ouvrir la session restaurée ; null : aucune vérification en attente.
  final String? secondFactorId;

  /// Premier démarrage : la présentation S1 → 01 → 02 est montrée. Sinon l'application s'ouvre directement sur l'accueil.
  final bool firstRun;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _generation = 0;
  bool _loggedOut = false;
  bool _expired = false;
  late bool _gated = widget.secondFactorId != null && widget.remembered != null;

  @override
  void initState() {
    super.initState();
    appReset = () {
      if (!mounted) return;
      setState(() {
        _generation++;
        _loggedOut = true;
        _expired = false;
      });
    };
    appSessionExpired = () {
      if (!mounted) return;
      setState(() {
        _generation++;
        _loggedOut = true;
        _expired = true;
      });
    };
  }

  @override
  void dispose() {
    appReset = null;
    appSessionExpired = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gated) {
      return SecondFactorGate(
        factorId: widget.secondFactorId!,
        onPassed: () {
          native_push.syncNativePushForCurrentUser().timeout(const Duration(seconds: 20), onTimeout: () {}).ignore();
          setState(() => _gated = false);
        },
        onRefused: () => setState(() {
          _gated = false;
          _loggedOut = true;
        }),
      );
    }
    return ProviderScope(
      key: ValueKey(_generation),
      overrides: [
        if (!_loggedOut && widget.remembered != null)
          initialAccountProvider.overrideWithValue(widget.remembered!),
      ],
      child: BoutikEcoleApp(initialLocation: _startLocation),
    );
  }

  /// Session ouverte : accueil du rôle. Premier démarrage : présentation S1 (qui passe seule à 01). Sinon : accueil visiteur.
  String get _startLocation {
    if (KioskTerminal.active) return '/s/206';
    if (_expired) return '/s/150-2';
    if (_loggedOut) return '/s/03';
    final a = widget.remembered;
    if (a != null) return '/s/${homeScreenFor(a)}';
    return widget.firstRun ? '/s/S1' : '/s/03';
  }
}
