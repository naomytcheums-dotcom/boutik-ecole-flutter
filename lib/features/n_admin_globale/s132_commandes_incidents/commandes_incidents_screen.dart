import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 132 · Commandes et incidents.
class CommandesIncidentsScreen extends ConsumerWidget {
  const CommandesIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionNDataProvider);
    return NAdminShell(
      title: 'Commandes et incidents',
      selected: 5,
      children: [
        OpsKpiRow(opsKpisOf(d.orderKpis)),
        const SizedBox(height: 14),
        OpsTable(
          columns: const ['Commande', 'Client', 'Vendeur', 'Montant (FCFA)', 'Statut'],
          flex: const [171, 190, 190, 152, 270],
          rows: [
            for (final o in d.orders)
              [
                OpsCell(o.$1, strong: true),
                OpsCell(o.$2),
                OpsCell(o.$3),
                OpsCell(fcfa(o.$4, withUnit: false)),
                OpsBadge(o.$5, tone: opsToneOf(o.$6)),
              ],
          ],
        ),
      ],
    );
  }
}
