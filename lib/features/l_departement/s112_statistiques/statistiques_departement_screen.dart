import '../l_widgets.dart';

/// 112 · Statistiques du département.
class StatistiquesDepartementScreen extends ConsumerStatefulWidget {
  const StatistiquesDepartementScreen({super.key});

  @override
  ConsumerState<StatistiquesDepartementScreen> createState() => _StatistiquesDepartementScreenState();
}

class _StatistiquesDepartementScreenState extends ConsumerState<StatistiquesDepartementScreen> {
  int _period = 1;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionLDataProvider);
    return LDepartmentShell(
      title: 'Statistiques du département',
      selected: 4,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OpsFilterChips(labels: d.statsPeriods, selected: _period, onSelected: (i) => setState(() => _period = i)),
        ),
        gap12,
        OpsKpiRow([for (final k in d.statsKpis) OpsKpi(k.$1, k.$2, k.$3, note: k.$4)]),
        gap16,
        OpsSplit(
          left: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Ventes par semaine (k FCFA)', style: AppText.bodyStrong)),
                    Text('FCFA', style: AppText.small),
                  ],
                ),
                gap16,
                GBars(bars: [for (final w in d.weeklySales) GBar(w.$1, w.$2)], height: 120),
              ],
            ),
          ),
          right: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Évolution des commandes', style: AppText.bodyStrong)),
                    Text('6 mois', style: AppText.small),
                  ],
                ),
                gap16,
                GLineChart(values: d.ordersCurve, height: 118),
              ],
            ),
          ),
        ),
        gap16,
        OpsCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              for (final (i, m) in d.salesMix.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Text(m.$1, style: AppText.bodyStrong)),
                    Text('${m.$2}%', style: AppText.small),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(value: m.$2 / 100, color: Color(m.$3), height: 5),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
