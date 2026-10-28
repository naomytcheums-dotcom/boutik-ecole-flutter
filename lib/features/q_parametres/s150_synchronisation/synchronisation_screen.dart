import '../q_widgets.dart';

/// 150 (1/4) · Synchronisation (mode hors ligne).
class SynchronisationScreen extends ConsumerWidget {
  const SynchronisationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionQDataProvider);
    final s = ref.watch(appSettingsProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const CHeader('Synchronisation'),
      bottomBar: PrimaryButton(
        label: 'Synchroniser maintenant',
        icon: AppIcons.refreshCw,
        onPressed: () => context.toast('Synchronisation lancée.'),
      ),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55), borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              const AppIcon(AppIcons.wifiOff, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mode hors ligne : certaines fonctions sont limitées. Vos actions seront synchronisées au retour du réseau.',
                  style: AppText.small.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
        gap12,
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GGauge(percent: d.syncPercent, size: 96),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Synchronisation en cours', style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
                    Text(d.syncDetail, style: AppText.small.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap12,
        QCard(
          children: [
            for (final i in d.syncItems) QRow(icon: i.$1, title: i.$2, subtitle: i.$3, trailing: GBadge(i.$4, i.$5)),
          ],
        ),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
          child: ToggleRow(
            title: 'Mode économie de données',
            subtitle: 'Charger moins d’images',
            value: s.lightMode,
            onChanged: ref.read(appSettingsProvider.notifier).setLightMode,
          ),
        ),
        gap12,
        KeyValueCard(rowGap: 14, rows: [KV('Dernière synchronisation', d.lastSync), KV('Disponibilité du service', d.serviceStatus)]),
      ],
    );
  }
}
