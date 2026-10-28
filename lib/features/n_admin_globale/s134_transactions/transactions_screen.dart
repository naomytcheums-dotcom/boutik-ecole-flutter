import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 134 · Transactions et rapprochements.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionNDataProvider);
    return NAdminShell(
      title: 'Transactions et rapprochements',
      selected: 7,
      children: [
        OpsKpiRow(opsKpisOf(d.transactionKpis)),
        const SizedBox(height: 14),
        OpsTable(
          columns: const ['Référence', 'Moyen', 'Montant (FCFA)', 'Date', 'Rapprochement'],
          flex: const [190, 171, 171, 171, 270],
          rows: [
            for (final t in d.transactions)
              [
                OpsCell(t.$1, strong: true),
                OpsCell(t.$2),
                OpsCell(fcfa(t.$3, withUnit: false)),
                OpsCell(t.$4),
                OpsBadge(t.$5, tone: opsToneOf(t.$6)),
              ],
          ],
        ),
      ],
    );
  }
}
