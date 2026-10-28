import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 131 · Signalements.
class SignalementsScreen extends ConsumerWidget {
  const SignalementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionNDataProvider);
    return NAdminShell(
      title: 'Signalements',
      selected: 4,
      children: [
        OpsKpiRow(opsKpisOf(d.reportKpis)),
        const SizedBox(height: 14),
        OpsTable(
          columns: const ['Signalement', 'Type', 'Reçu', 'Assigné à', 'Statut'],
          flex: const [286, 171, 133, 190, 200],
          rows: [
            for (final r in d.reports)
              [OpsCell(r.$1, strong: true), OpsCell(r.$2), OpsCell(r.$3), OpsCell(r.$4), OpsBadge(r.$5, tone: opsToneOf(r.$6))],
          ],
        ),
      ],
    );
  }
}
