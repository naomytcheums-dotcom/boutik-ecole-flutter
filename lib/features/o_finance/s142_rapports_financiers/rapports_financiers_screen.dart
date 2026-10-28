import '../o_widgets.dart';

/// 142 · Rapports financiers.
class RapportsFinanciersScreen extends ConsumerStatefulWidget {
  const RapportsFinanciersScreen({super.key});

  @override
  ConsumerState<RapportsFinanciersScreen> createState() => _RapportsFinanciersScreenState();
}

class _RapportsFinanciersScreenState extends ConsumerState<RapportsFinanciersScreen> {
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionODataProvider);
    return OFinanceShell(
      title: 'Rapports financiers',
      selected: 3,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OpsFilterChips(labels: d.periods, selected: _period, onSelected: (i) => setState(() => _period = i)),
        ),
        gap12,
        OpsSplit(
          left: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Encaissements par département (M FCFA)', style: AppText.bodyStrong)),
                    Text('FCFA', style: AppText.small),
                  ],
                ),
                gap16,
                GBars(bars: [for (final c in d.cashByDepartment) GBar(c.$1, (c.$2 * 1000000).round())], height: 130),
              ],
            ),
          ),
          right: OpsTable(
            columns: const ['Vendeur', 'Ventes', 'Commission'],
            flex: const [3, 2, 2],
            minWidth: 300,
            rows: [
              for (final s in d.sellers)
                [OpsCell(s.$1, strong: true), OpsCell(fcfa(s.$2, withUnit: false)), OpsCell(fcfa(s.$3, withUnit: false))],
            ],
          ),
        ),
        gap16,
        OpsBigButton(
          label: 'Exporter le rapport',
          icon: AppIcons.download,
          dark: false,
          onTap: () => context.toast('Rapport exporté (démonstration).'),
        ),
      ],
    );
  }
}
