import '../m_widgets.dart';

/// 125 · Rapports consolidés.
class RapportsConsolidesScreen extends ConsumerWidget {
  const RapportsConsolidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionMDataProvider);
    return MAdminShell(
      title: 'Rapports consolidés',
      selected: 8,
      children: [
        ResponsiveGrid(
          columns: 3,
          minItemWidth: 200,
          spacing: 12,
          children: [
            for (final r in d.reports)
              OpsCard(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const OpsIconTile(AppIcons.file),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text(r.$1, style: AppText.bodyStrong), Text(r.$2, style: AppText.small)],
                      ),
                    ),
                    OpsBadge('Exporter', tone: OpsTone.info, onTap: () => context.toast('${r.$1} exporté.')),
                  ],
                ),
              ),
          ],
        ),
        gap16,
        Text('Rapports planifiés', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        gap12,
        OpsTable(
          columns: const ['Rapport', 'Fréquence', 'Destinataires', 'Prochain envoi'],
          flex: const [3, 2, 3, 2],
          rows: [
            for (final s in d.scheduled) [OpsCell(s.$1, strong: true), OpsCell(s.$2), OpsCell(s.$3), OpsCell(s.$4)],
          ],
        ),
      ],
    );
  }
}
