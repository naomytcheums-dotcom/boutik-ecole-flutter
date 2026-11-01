import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/paths.dart';
import 'backend.dart';
import 'connectivity_stub.dart' if (dart.library.js_interop) 'connectivity_web.dart';
import 'sync.dart';

/// États système affichés lorsqu'ils se produisent réellement (et non par un lien) :
/// - coupure réseau → 150-3 « Connexion impossible » (qui propose le mode hors ligne, 182) ;
/// - retour du réseau → retour à l'écran précédent et message « Connexion rétablie » ;
/// - session perdue sans déconnexion demandée (jeton expiré ou révoqué) → 150-2 « Session expirée ».
class SystemStates extends StatefulWidget {
  const SystemStates({super.key, required this.router, required this.child, this.onSessionExpired});
  final GoRouter router;
  final Widget child;

  /// Remet l'application dans un état vierge avant d'afficher 150-2 (aucune donnée du compte précédent ne reste affichée).
  final VoidCallback? onSessionExpired;

  @override
  State<SystemStates> createState() => _SystemStatesState();
}

/// Écrans d'état réseau : on n'empile jamais deux fois l'état hors ligne.
const offlineScreens = {'150-3', '182', '183'};

/// Écran affiché au sommet de la pile (les écrans ouverts par push compris).
String screenOf(GoRouter r) {
  String p;
  try {
    p = r.state.uri.path;
  } catch (_) {
    p = r.routerDelegate.currentConfiguration.uri.path;
  }
  return p.startsWith('/s/') ? p.substring(3) : p;
}

class _SystemStatesState extends State<SystemStates> {
  StreamSubscription<AuthState>? _auth;
  bool _hadSession = false;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _online = browserOnline();
    listenConnectivity(_network);
    widget.router.routerDelegate.addListener(_route);
    if (!_online) WidgetsBinding.instance.addPostFrameCallback((_) => _network(false));
    if (Backend.ready) {
      final a = Supabase.instance.client.auth;
      _hadSession = a.currentSession != null;
      _auth = a.onAuthStateChange.listen((s) {
        if (s.session != null) {
          _hadSession = true;
        } else if (s.event == AuthChangeEvent.signedOut) {
          final expired = _hadSession && !Backend.signingOut;
          _hadSession = false;
          Backend.signingOut = false;
          if (expired) _sessionExpired();
        }
      });
    }
  }

  void _network(bool online) {
    if (!mounted) return;
    _online = online;
    final r = widget.router;
    final here = screenOf(r);
    if (!online) {
      if (!offlineScreens.contains(here)) r.push(screenPath(here == '45' ? '183' : '150-3'));
      return;
    }
    if (offlineScreens.contains(here)) {
      r.canPop() ? r.pop() : r.go(screenPath('03'));
    }
    _notice('Connexion rétablie');
  }

  /// Hors ligne, « Mes commandes » affiche son état hors ligne (183) au lieu d'une liste vide.
  void _route() {
    if (_online || !mounted) return;
    if (screenOf(widget.router) == '45') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_online && screenOf(widget.router) == '45') widget.router.pushReplacement(screenPath('183'));
      });
    }
  }

  void _sessionExpired() {
    if (!mounted) return;
    if (widget.onSessionExpired != null) {
      widget.onSessionExpired!();
    } else {
      widget.router.go(screenPath('150-2'));
    }
  }

  void _notice(String m) {
    final s = ScaffoldMessenger.maybeOf(context);
    s?.showSnackBar(SnackBar(content: Text(m, textAlign: TextAlign.center), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_route);
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// « Réessayer » (150-3, 183) : ne quitte l'état hors ligne que si le réseau est réellement revenu.
/// Compte connecté au serveur : l'état hors ligne laisse place à 150-1, qui relit réellement les données du compte.
void retryNetwork(BuildContext context) {
  if (!browserOnline()) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Toujours hors ligne. Vérifiez votre connexion.'), behavior: SnackBarBehavior.floating));
    return;
  }
  final r = GoRouter.of(context);
  if (Backend.ready && Supabase.instance.client.auth.currentUser != null) {
    ProviderScope.containerOf(context, listen: false).read(syncProvider.notifier).run();
    r.pushReplacement(screenPath('150-1'));
    return;
  }
  r.canPop() ? r.pop() : r.go(screenPath('03'));
}
