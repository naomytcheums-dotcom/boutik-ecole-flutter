import '../q_widgets.dart';

/// 150 (3/4) · Connexion impossible (état hors ligne de l’explorateur).
class ConnexionImpossibleScreen extends ConsumerWidget {
  const ConnexionImpossibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      tab: NavTab.search,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const QTitle('Explorer'),
      children: [
        const SizedBox(height: 90),
        QStateView(
          icon: AppIcons.wifiOff,
          title: 'Connexion impossible',
          message: 'Vérifiez votre connexion Internet puis réessayez.\nVos données sont conservées.',
          action: 'Réessayer',
          onAction: () => context.goScreen('04'),
          secondary: 'Voir le mode hors ligne',
          onSecondary: () {
            ref.read(appSettingsProvider.notifier).setOffline(true);
            context.openScreen('150-1');
          },
        ),
      ],
    );
  }
}
