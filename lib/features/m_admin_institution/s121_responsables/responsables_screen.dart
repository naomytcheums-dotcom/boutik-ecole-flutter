import '../m_widgets.dart';

/// 121 · Responsables et encadreurs.
class ResponsablesScreen extends ConsumerWidget {
  const ResponsablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionMDataProvider);
    return MAdminShell(
      title: 'Responsables et encadreurs',
      selected: 4,
      children: [
        OpsKpiRow(lKpis(d.staffKpis)),
        gap16,
        OpsTable(
          columns: const ['Nom', 'Fonction', 'Département', 'Affectations', 'Statut'],
          flex: const [3, 2, 3, 2, 2],
          rows: [
            for (final s in d.staff)
              [OpsCell(s.$1, strong: true), OpsCell(s.$2), OpsCell(s.$3), OpsCell(s.$4), lBadge(s.$5, Tone.success)],
          ],
        ),
      ],
    );
  }
}
