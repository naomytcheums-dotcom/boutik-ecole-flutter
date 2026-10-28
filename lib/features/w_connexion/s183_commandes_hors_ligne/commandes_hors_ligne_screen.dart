import '../w_widgets.dart';

/// 183 · Mes commandes hors connexion : données de la dernière synchronisation.
class CommandesHorsLigneScreen extends ConsumerWidget {
  const CommandesHorsLigneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionWDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const QTitle('Mes commandes'),
      children: [
        Semantics(
          liveRegion: true,
          child: WInfoCard(
            icon: AppIcons.wifiOff,
            text:
                'Vous êtes hors ligne. Les données affichées sont celles de votre dernière synchronisation '
                '(${d.lastSync}).',
          ),
        ),
        gap16,
        QCard(
          children: [
            for (final o in d.orders)
              WRow(
                // Vignette non chargée hors connexion : emplacement laissé vide comme dans la maquette.
                leading: const SizedBox(width: 50),
                title: o.ref,
                subtitle: '${o.status} · ${fcfa(o.amount)}',
                trailing: GBadge(o.status, o.tone),
                onTap: () => context.openScreen('46'),
              ),
          ],
        ),
        gap16,
        PrimaryButton(
          label: 'Réessayer la connexion',
          icon: AppIcons.refreshCw,
          height: 50,
          onPressed: () {
            ref.read(appSettingsProvider.notifier).setOffline(false);
            context.toast('Connexion rétablie : vos commandes sont à jour.');
            context.openScreen('45');
          },
        ),
        gap16,
        const WInfoCard(
          icon: AppIcons.cloud,
          text: 'Vos actions (messages, favoris) seront envoyées dès le retour du réseau.',
        ),
      ],
    );
  }
}
