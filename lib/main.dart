import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'figma/i18n.dart' show I18n;
import 'figma/live/auth.dart';
import 'figma/live/backend.dart';
import 'figma/live/drafts.dart';
import 'figma/live/native_push_stub.dart'
    if (dart.library.io) 'figma/live/native_push.dart'
    as native_push;

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
  await I18n.init();
  final remembered = await loadRemembered().timeout(const Duration(seconds: 25), onTimeout: () => null);
  if (remembered != null) {
    // notifications natives : en arrière-plan, sans retarder l'ouverture
    native_push.syncNativePushForCurrentUser().timeout(const Duration(seconds: 20), onTimeout: () {}).ignore();
  }
  runApp(AppRoot(remembered: remembered));
}

/// Racine de l'application. À la déconnexion, tout l'état (formulaires, annonces, panier, commandes, profil…) est jeté :
/// l'utilisateur suivant sur le même appareil repart d'un état vierge.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, this.remembered});
  final Account? remembered;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _generation = 0;
  bool _loggedOut = false;
  bool _expired = false;

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
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_generation),
    overrides: [
      if (!_loggedOut && widget.remembered != null)
        initialAccountProvider.overrideWithValue(widget.remembered!),
    ],
    // démarrage à froid sans adresse précise : écran de lancement S1, qui passe seul à l'accueil 01
    child: BoutikEcoleApp(
      initialLocation: _expired ? '/s/150-2' : (_loggedOut ? '/s/03' : '/s/S1'),
    ),
  );
}
