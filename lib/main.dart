import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'figma/live/auth.dart';
import 'figma/live/backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  final remembered = await loadRemembered();
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

  @override
  void initState() {
    super.initState();
    appReset = () {
      if (!mounted) return;
      setState(() {
        _generation++;
        _loggedOut = true;
      });
    };
  }

  @override
  void dispose() {
    appReset = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
        key: ValueKey(_generation),
        overrides: [if (!_loggedOut && widget.remembered != null) initialAccountProvider.overrideWithValue(widget.remembered!)],
        child: BoutikEcoleApp(initialLocation: _loggedOut ? '/s/11' : '/s/01'),
      );
}
