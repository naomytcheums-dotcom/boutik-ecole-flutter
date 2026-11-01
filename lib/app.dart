import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/router/paths.dart';
import 'core/state/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'figma/live/auth.dart' show appSessionExpired;
import 'figma/live/backend.dart';
import 'figma/live/connectivity_stub.dart' if (dart.library.js_interop) 'figma/live/connectivity_web.dart';
import 'figma/live/missions.dart' show missionLoadedProvider, missionProvider, missionScreens, redirectMissionScreen;
import 'figma/live/store.dart' show ordersProvider, ordersLoadedProvider, showEmptyOrders;
import 'figma/live/system_states.dart';
import 'l10n/gen/app_localizations.dart';

class BoutikEcoleApp extends ConsumerStatefulWidget {
  const BoutikEcoleApp({super.key, this.initialLocation = '/s/01'});

  final String initialLocation;

  @override
  ConsumerState<BoutikEcoleApp> createState() => _BoutikEcoleAppState();
}

class _BoutikEcoleAppState extends ConsumerState<BoutikEcoleApp> {
  late final GoRouter _router = buildRouter(initial: widget.initialLocation);

  @override
  void initState() {
    super.initState();
    // Lien de réinitialisation ouvert (session de récupération) : écran 16 « Nouveau mot de passe ».
    Backend.recovery.addListener(_onRecovery);
    if (Backend.recovery.value) WidgetsBinding.instance.addPostFrameCallback((_) => _onRecovery());
    _router.routerDelegate.addListener(_ordersScreen);
    _router.routerDelegate.addListener(_missionScreen);
  }

  void _onRecovery() {
    if (mounted && Backend.recovery.value) _router.go(screenPath('16'));
  }

  /// « Mes commandes » : la liste (45) et l'état vide de la maquette (150-4) s'échangent selon les commandes réellement lues.
  void _ordersScreen() {
    if (!mounted || !browserOnline()) return;
    final here = screenOf(_router);
    if (here != '45' && here != '150-4') return;
    final empty = showEmptyOrders(ready: Backend.ready, loaded: ref.read(ordersLoadedProvider), orders: ref.read(ordersProvider));
    final target = here == '45' && empty ? '150-4' : (here == '150-4' && Backend.ready && ref.read(ordersProvider).isNotEmpty ? '45' : null);
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && screenOf(_router) == here) _router.pushReplacement(screenPath(target));
    });
  }

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// Suivi de mission (192 à 197, 201) sans mission réelle : retour à « Votre besoin » (191), sans la mission d'exemple.
  void _missionScreen() {
    if (!mounted) return;
    final here = screenOf(_router);
    if (!missionScreens.contains(here)) return;
    if (!redirectMissionScreen(ready: Backend.ready, loaded: ref.read(missionLoadedProvider), mission: ref.read(missionProvider))) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || screenOf(_router) != here) return;
      _router.pushReplacement(screenPath('191'));
      _messenger.currentState?.showSnackBar(const SnackBar(content: Text('Aucune mission en cours : décrivez votre besoin pour en démarrer une.'), behavior: SnackBarBehavior.floating));
    });
  }

  @override
  void dispose() {
    Backend.recovery.removeListener(_onRecovery);
    _router.routerDelegate.removeListener(_ordersScreen);
    _router.routerDelegate.removeListener(_missionScreen);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    if (Backend.ready) {
      ref.listen(ordersLoadedProvider, (_, _) => _ordersScreen());
      ref.listen(ordersProvider, (_, _) => _ordersScreen());
      ref.listen(missionLoadedProvider, (_, _) => _missionScreen());
      ref.listen(missionProvider, (_, _) => _missionScreen());
    }
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: 'Boutik-École',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return SystemStates(
          router: _router,
          onSessionExpired: appSessionExpired,
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(mq.textScaler.scale(1) * settings.textScale),
              boldText: mq.boldText || settings.boldText,
              highContrast: mq.highContrast || settings.highContrast,
              disableAnimations: mq.disableAnimations || settings.reduceMotion,
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
