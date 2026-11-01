import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/screens.dart';
import '../../figma/gsound.dart' show GAnim;
import '../../figma/live/access.dart';
import '../../figma/live/espace.dart';
import '../../figma/live/shared_cv.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import 'paths.dart';
import 'screen_entry.dart';

final Map<String, ScreenEntry> screensById = {for (final s in allScreens) s.id: s};

/// Écran du manifeste pour un identifiant, sans tenir compte de la casse (`p3` et `P3` désignent le même écran du studio)
/// ni du séparateur des variantes (`148_1`, nom des fichiers générés, et `148-1`, identifiant du manifeste).
ScreenEntry? screenById(String? id) {
  if (id == null) return null;
  for (final k in {id, id.toUpperCase(), id.toLowerCase(), id.replaceAll('_', '-')}) {
    final e = screensById[k];
    if (e != null) return e;
  }
  return null;
}

GoRouter buildRouter({String initial = '/s/01'}) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/', redirect: (_, _) => screenPath('01')),
    GoRoute(path: '/catalogue', builder: (_, _) => const ScreenCatalogue()),
    GoRoute(path: '/espace', builder: (_, _) => const EspaceScreen()),
    GoRoute(path: '/cv/:token', builder: (_, state) => SharedCvScreen(token: state.pathParameters['token'] ?? '')),
    GoRoute(
      path: '/s/:id',
      pageBuilder: (context, state) {
        final entry = screenById(state.pathParameters['id']);
        final sid = entry?.id ?? state.pathParameters['id'] ?? '?';
        final child = entry == null ? MissingScreen(id: sid) : AccessGuard(id: sid, child: entry.builder(context));
        // S1 « Démarrage animé » : écran de lancement, puis passage automatique à l'accueil (01).
        final page = sid == 'S1' ? SplashAdvance(child: child) : child;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondary, child) {
            final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child),
            );
          },
        );
      },
    ),
  ],
  errorBuilder: (_, state) => MissingScreen(id: state.uri.toString()),
);

/// Écran de démarrage (S1) : laisse voir le logo, puis remplace l'écran par l'accueil (01). Sans animation (tests, rendus de
/// référence), aucun minuteur n'est lancé ; avec « réduire les animations », le passage est plus rapide.
class SplashAdvance extends StatefulWidget {
  const SplashAdvance({super.key, required this.child, this.next = '01'});
  final Widget child;
  final String next;

  static const delay = Duration(milliseconds: 1200);

  @override
  State<SplashAdvance> createState() => _SplashAdvanceState();
}

class _SplashAdvanceState extends State<SplashAdvance> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!GAnim.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final quick = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      _t = Timer(quick ? const Duration(milliseconds: 300) : SplashAdvance.delay, () {
        if (mounted) GoRouter.of(context).go(screenPath(widget.next));
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Affiché pour un numéro d'écran absent du registre.
class MissingScreen extends StatelessWidget {
  const MissingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const ScreenHeader(title: 'Écran introuvable'),
      children: [
        const SizedBox(height: 40),
        Text('L’écran « $id » n’existe pas.', style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(screenPath(NavTargets.home))),
      ],
    );
  }
}

/// Catalogue de tous les écrans codés (revue de maquette).
class ScreenCatalogue extends StatelessWidget {
  const ScreenCatalogue({super.key});

  @override
  Widget build(BuildContext context) {
    final bySection = <String, List<ScreenEntry>>{};
    for (final s in allScreens) {
      bySection.putIfAbsent(s.section, () => []).add(s);
    }
    return AppScaffold(
      showNav: false,
      header: const ScreenHeader(title: 'Catalogue des écrans', showBack: false),
      children: [
        Text('${allScreens.length} écrans', style: AppText.secondary),
        for (final e in bySection.entries) ...[
          const SizedBox(height: 16),
          Text('Section ${e.key}', style: AppText.h3),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final s in e.value)
                  ListRow(
                    title: '${s.id} · ${s.title}',
                    subtitle: '${s.format.name} · Figma ${s.node}',
                    onTap: () => context.push(screenPath(s.id)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text('Données de démonstration', style: AppText.small.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
