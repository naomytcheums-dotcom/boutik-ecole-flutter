import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/screens.dart';
import '../../figma/live/access.dart';
import '../../figma/live/espace.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import 'paths.dart';
import 'screen_entry.dart';

final Map<String, ScreenEntry> screensById = {for (final s in allScreens) s.id: s};

GoRouter buildRouter({String initial = '/s/01'}) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: '/', redirect: (_, _) => screenPath('01')),
    GoRoute(path: '/catalogue', builder: (_, _) => const ScreenCatalogue()),
    GoRoute(path: '/espace', builder: (_, _) => const EspaceScreen()),
    GoRoute(
      path: '/s/:id',
      pageBuilder: (context, state) {
        final entry = screensById[state.pathParameters['id']];
        final sid = state.pathParameters['id'] ?? '?';
        final child = entry == null ? MissingScreen(id: sid) : AccessGuard(id: sid, child: entry.builder(context));
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: child,
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
