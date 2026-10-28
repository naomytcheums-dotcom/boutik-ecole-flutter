import '../g_widgets.dart';

/// 66 · Revenus (disponible, en attente, courbe, relevés).
class RevenusScreen extends ConsumerWidget {
  const RevenusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionGDataProvider);
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const GRootHeader('Revenus'),
      children: [
        GKpiGrid([
          GKpi('Disponible', fcfa(d.availableRevenue), AppIcons.wallet),
          GKpi('En attente', fcfa(d.pendingRevenue), AppIcons.clock, delta: '${d.pendingPayments} paiements', deltaTone: Tone.warning),
        ], valueSize: 20),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Revenus cumulés', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600))),
                  Text(d.revenuePeriod, style: AppText.small),
                ],
              ),
              gap12,
              GLineChart(values: d.cumulativeRevenue),
            ],
          ),
        ),
        const GSectionTitle('Relevés disponibles'),
        GListCard(
          children: [
            for (final s in d.statements)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFF2F0F5), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: const AppIcon(AppIcons.file, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                          Text('PDF · ${s.transactions} transactions', style: AppText.small.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Télécharger ${s.title}',
                      child: GestureDetector(
                        onTap: () => context.toast('${s.title} téléchargé.'),
                        child: const SizedBox(height: 44, child: Center(child: GBadge('Télécharger', Tone.accent))),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}