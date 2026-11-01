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
  }

  void _onRecovery() {
    if (mounted && Backend.recovery.value) _router.go(screenPath('16'));
  }

  @override
  void dispose() {
    Backend.recovery.removeListener(_onRecovery);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
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
