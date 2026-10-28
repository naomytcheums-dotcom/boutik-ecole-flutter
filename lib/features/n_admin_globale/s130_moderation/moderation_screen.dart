import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 130 · Modération (files par type de contenu).
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    return NAdminShell(
      title: 'Modération',
      selected: 3,
      children: [
        OpsTabs(labels: d.moderationTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 18),
        OpsTable(
          columns: const ['Contenu', 'Auteur', 'Motif', 'Signalé', 'Décision'],
          flex: const [286, 190, 210, 114, 180],
          emptyLabel: 'Aucun contenu signalé dans cette file.',
          rows: [
            for (final m in d.moderationQueues[_tab])
              [
                OpsCell(m.$1, strong: true),
                OpsCell(m.$2),
                OpsCell(m.$3),
                OpsCell(m.$4),
                OpsBadge('Examiner', tone: OpsTone.info, onTap: () => context.toast('Examen de « ${m.$1} » (démonstration).')),
              ],
          ],
        ),
      ],
    );
  }
}
