import '../l_widgets.dart';

/// 113 · Suivi des productions.
class SuiviProductionsScreen extends ConsumerWidget {
  const SuiviProductionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionLDataProvider);
    return LDepartmentShell(
      title: 'Suivi des productions',
      selected: 5,
      children: [
        OpsKpiRow(lKpis(d.productionKpis)),
        gap16,
        OpsTable(
          columns: const ['Production', 'Équipe', 'Encadreur', 'Avancement', 'État'],
          flex: const [3, 2, 2, 2, 2],
          rows: [
            for (final p in d.productions)
              [OpsCell(p.$1, strong: true), OpsCell(p.$2), OpsCell(p.$3), OpsCell('${p.$4} %'), lBadge(p.$5, p.$6)],
          ],
        ),
      ],
    );
  }
}
