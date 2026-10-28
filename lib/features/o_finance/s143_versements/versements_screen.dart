import '../o_widgets.dart';

/// 143 · Versements et montants dus.
class VersementsScreen extends ConsumerWidget {
  const VersementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionODataProvider);
    return OFinanceShell(
      title: 'Versements et montants dus',
      selected: 2,
      children: [
        OpsKpiRow([
          for (final k in d.payoutKpis)
            OpsKpi(k.$1, k.$2, k.$3, note: k.$4.isEmpty ? null : k.$4, noteTone: OpsTone.pending),
        ]),
        gap16,
        OpsTable(
          columns: const ['Lot', 'Vendeur', 'Montant (FCFA)', 'Moyen', 'Date', 'Statut'],
          flex: const [2, 3, 3, 3, 2, 2],
          rows: [
            for (final p in d.payouts)
              [
                OpsCell(p.$1, strong: true),
                OpsCell(p.$2),
                OpsCell(fcfa(p.$3, withUnit: false)),
                OpsCell(p.$4),
                OpsCell(p.$5),
                lBadge(p.$6, p.$7),
              ],
          ],
        ),
      ],
    );
  }
}
