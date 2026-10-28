import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/state/app_settings.dart';
import 'core/theme/app_theme.dart';
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
  void dispose() {
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
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * settings.textScale),
            boldText: mq.boldText || settings.boldText,
          ),
          child: child!,
        );
      },
    );
  }
}
