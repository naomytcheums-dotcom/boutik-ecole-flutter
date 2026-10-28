import '../l_widgets.dart';

/// 116 · Rapports et exports.
class RapportsDepartementScreen extends ConsumerWidget {
  const RapportsDepartementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionLDataProvider);
    return LDepartmentShell(
      title: 'Rapports et exports',
      selected: 8,
      children: [
        ResponsiveGrid(
          columns: 3,
          minItemWidth: 200,
          spacing: 12,
          children: [
            for (final e in d.exports)
              OpsCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const OpsIconTile(AppIcons.file),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.$1, style: AppText.bodyStrong),
                          Text(e.$2, style: AppText.small),
                        ],
                      ),
                    ),
                    OpsBadge('Exporter', tone: OpsTone.info, onTap: () => context.toast('${e.$1} exporté.')),
                  ],
                ),
              ),
          ],
        ),
        gap16,
        Text('Historique des décisions', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        gap12,
        OpsTable(
          columns: const ['Date', 'Décision', 'Élément', 'Par', 'Résultat'],
          flex: const [2, 3, 3, 2, 2],
          rows: [
            for (final r in d.decisions)
              [OpsCell(r.$1, strong: true), OpsCell(r.$2), OpsCell(r.$3), OpsCell(r.$4), lBadge(r.$5, r.$6)],
          ],
        ),
      ],
    );
  }
}
