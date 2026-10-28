import '../m_widgets.dart';

/// 123 · Ventes et activité de l’établissement.
class VentesActiviteScreen extends ConsumerWidget {
  const VentesActiviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionMDataProvider);
    return MAdminShell(
      title: 'Ventes et activité',
      selected: 6,
      children: [
        OpsKpiRow([for (final k in d.salesKpis) OpsKpi(k.$1, k.$2, k.$3, note: k.$4)]),
        gap16,
        OpsSplit(
          left: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Ventes par département (M FCFA)', style: AppText.bodyStrong)),
                    Text('FCFA', style: AppText.small),
                  ],
                ),
                gap16,
                GBars(bars: [for (final s in d.salesByDepartment) GBar(s.$1, (s.$2 * 1000000).round())], height: 130),
              ],
            ),
          ),
          right: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Commandes mensuelles', style: AppText.bodyStrong)),
                    Text('6 mois', style: AppText.small),
                  ],
                ),
                gap16,
                GLineChart(values: d.monthlyOrders, height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
