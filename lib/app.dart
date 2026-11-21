import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/router/paths.dart';
import 'core/state/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'figma/gsound.dart' show GAnim;
import 'figma/i18n.dart' show I18n, I18nScope;
import 'figma/live/auth.dart' show appSessionExpired, authProvider, promptTermsUpdate, requireLogin, termsNeedAcceptance;
import 'figma/live/access.dart' show roleKey;
import 'figma/live/kiosk_mode.dart' show KioskIdleGuard, KioskTerminal;
import 'figma/live/menu_global.dart' show SharedBottomMenu;
import 'figma/live/qr.dart' show handleQrToken, pendingQrToken;
import 'figma/live/test_accounts.dart' show TestAccountBanner;
import 'figma/gdata.dart';
import 'figma/live/device_prefs.dart' show accessPrefs149Provider, accessPrefsProvider, dataPrefsProvider, textSizeProvider;
import 'figma/gaccess.dart';
import 'figma/live/backend.dart';
import 'figma/live/connectivity_stub.dart' if (dart.library.js_interop) 'figma/live/connectivity_web.dart';
import 'figma/live/missions.dart' show missionLoadedProvider, missionProvider, missionScreens, redirectMissionScreen, redirectProviderScreen;
import 'figma/live/store.dart' show ordersProvider, ordersLoadedProvider, showEmptyOrders, redirectOrderDetail;
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
    _router.routerDelegate.addListener(_orderDetailScreen);
    // Code QR lu par l'appareil photo ordinaire (adresse « …/?qr=<jeton> ») : traité une fois l'écran de départ en place.
    if (pendingQrToken != null) Future.delayed(const Duration(milliseconds: 900), _openPendingQr);
    // Session restaurée : les conditions sont aussi vérifiées (une connexion fraîche les vérifie via l'écoute de l'identifiant dans build).
    if (Backend.ready && ref.read(authProvider).current != null) Future.delayed(const Duration(seconds: 2), _checkTerms);
  }

  String _termsCheckedFor = '';

  /// Une fois par compte et par ouverture : si les CGU acceptées sont absentes ou antérieures à la version en vigueur, la personne est invitée à les accepter.
  Future<void> _checkTerms() async {
    if (!mounted) return;
    final a = ref.read(authProvider).current;
    final id = a?.serverId ?? '';
    if (!mounted || id.isEmpty || id == _termsCheckedFor || Backend.profileMissing) return;
    _termsCheckedFor = id;
    if (!await termsNeedAcceptance() || !mounted) return;
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted || ref.read(authProvider).current?.serverId != id) return;
    await promptTermsUpdate(ctx);
  }

  bool _qrPrompted = false;

  /// Résout le code QR de l'adresse d'ouverture. Sans compte, la connexion est proposée une fois ; le code est repris dès la connexion.
  Future<void> _openPendingQr() async {
    final token = pendingQrToken;
    if (token == null || !mounted || !Backend.ready) return;
    final ctx = _router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    if (ref.read(authProvider).current == null) {
      if (_qrPrompted) return;
      _qrPrompted = true;
      await requireLogin(ctx, ref, 'ouvrir ce code QR');
      return;
    }
    pendingQrToken = null;
    await handleQrToken(ctx, ref, token);
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

  /// Détail, suivi et annulation d'une commande (09, 29, 46, 47) sans commande réelle : retour à « Mes commandes » au lieu
  /// d'afficher une commande d'exemple (D-082, D-083). Hors connexion au serveur, la démonstration reste affichée.
  void _orderDetailScreen() {
    if (!mounted) return;
    final here = screenOf(_router);
    if (!redirectOrderDetail(ready: Backend.ready, loaded: ref.read(ordersLoadedProvider), orders: ref.read(ordersProvider), screen: here)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || screenOf(_router) != here) return;
      _router.pushReplacement(screenPath('45'));
      _messenger.currentState?.showSnackBar(const SnackBar(content: Text('Vous n’avez pas encore de commande.'), behavior: SnackBarBehavior.floating));
    });
  }

  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// Suivi de mission (192 à 197, 201) sans mission réelle : retour à « Votre besoin » (191), sans la mission d'exemple.
  void _missionScreen() {
    if (!mounted) return;
    final here = screenOf(_router);
    if (!missionScreens.contains(here)) return;
    if (redirectProviderScreen(ready: Backend.ready, screen: here, role: roleKey(ref.read(authProvider).current))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || screenOf(_router) != here) return;
        _router.pushReplacement(screenPath('194'));
        _messenger.currentState?.showSnackBar(const SnackBar(content: Text('Cet écran est destiné aux prestataires : voici le suivi de votre mission.'), behavior: SnackBarBehavior.floating));
      });
      return;
    }
    if (!redirectMissionScreen(ready: Backend.ready, loaded: ref.read(missionLoadedProvider), mission: ref.read(missionProvider), screen: here, role: roleKey(ref.read(authProvider).current))) return;
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
    _router.routerDelegate.removeListener(_orderDetailScreen);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    // Réglages d'accessibilité de l'appareil : texte agrandi, taille du texte, contraste, animations réduites, lecture vocale.
    final a1 = ref.watch(accessPrefs149Provider);
    final a2 = ref.watch(accessPrefsProvider);
    bool acc(String k149, String k) => (a1[k149] ?? false) || (a2[k] ?? false);
    final size = ref.watch(textSizeProvider); // 0 petit, 1 normal, 2 grand, 3 très grand
    final accScale = (acc('a149_large_text', 'large_text') ? 1.2 : 1.0) * (size == 0 ? 0.9 : (size == 2 ? 1.12 : (size >= 3 ? 1.25 : 1.0)));
    final accContrast = acc('a149_contrast', 'contrast');
    final accMotion = acc('a149_reduce_motion', 'reduce_motion');
    GAccess.voice = acc('a149_screen_reader', 'screen_reader');
    final dp = ref.watch(dataPrefsProvider);
    GData.saver = dp['data_saver'] ?? true;
    GData.lowImages = dp['low_images'] ?? true;
    GData.wifiVideo = dp['wifi_video'] ?? true;
    GData.wifiSync = dp['wifi_sync'] ?? true;
    GData.syncNever = dp['sync_never'] ?? false;
    // « Réduire les animations » : n'agit que sur un changement de réglage (les animations par défaut restent inchangées).
    if (accMotion != GAccess.motionReduced) {
      GAccess.motionReduced = accMotion;
      GAnim.enabled = !accMotion;
    }
    if (Backend.ready) {
      ref.listen(authProvider.select((a) => a.current?.serverId ?? ''), (_, id) {
        if (id.isNotEmpty && pendingQrToken != null) _openPendingQr();
        if (id.isNotEmpty) Future.delayed(const Duration(seconds: 2), _checkTerms);
      });
      ref.listen(ordersLoadedProvider, (_, _) => _ordersScreen());
      ref.listen(ordersProvider, (_, _) => _ordersScreen());
      ref.listen(ordersLoadedProvider, (_, _) => _orderDetailScreen());
      ref.listen(ordersProvider, (_, _) => _orderDetailScreen());
      ref.listen(missionLoadedProvider, (_, _) => _missionScreen());
      ref.listen(missionProvider, (_, _) => _missionScreen());
    }
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: 'Boutik-École',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: const _MobileScrollBehavior(),
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
        return ValueListenableBuilder<String>(
          valueListenable: I18n.notifier,
          builder: (context, lang, child) => I18nScope(lang: lang, child: child!),
          child: SystemStates(
          router: _router,
          onSessionExpired: appSessionExpired,
          child: MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(mq.textScaler.scale(1) * settings.textScale * accScale),
              boldText: mq.boldText || settings.boldText,
              highContrast: mq.highContrast || settings.highContrast || accContrast,
              disableAnimations: mq.disableAnimations || settings.reduceMotion || accMotion,
            ),
            child: TestAccountBanner(child: SharedBottomMenu(router: _router, child: KioskTerminal.active ? KioskIdleGuard(child: child!) : child!)),
          ),
        ),
        );
      },
    );
  }
}

/// Comportement de défilement d'une application mobile : aucune barre de défilement (même dans un navigateur d'ordinateur),
/// glissement au doigt, à la souris ou au stylet.
class _MobileScrollBehavior extends MaterialScrollBehavior {
  const _MobileScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.stylus, PointerDeviceKind.trackpad};
}
