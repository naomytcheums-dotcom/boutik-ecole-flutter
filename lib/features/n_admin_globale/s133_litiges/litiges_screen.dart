import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 133 · Litiges et remboursements.
class LitigesScreen extends ConsumerStatefulWidget {
  const LitigesScreen({super.key});

  @override
  ConsumerState<LitigesScreen> createState() => _LitigesScreenState();
}

class _LitigesScreenState extends ConsumerState<LitigesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    return NAdminShell(
      title: 'Litiges et remboursements',
      selected: 6,
      children: [
        OpsTabs(labels: d.disputeTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 18),
        OpsTable(
          columns: const ['Dossier', 'Commande', 'Motif', 'Montant (FCFA)', 'Statut'],
          flex: const [152, 171, 228, 152, 270],
          emptyLabel: 'Aucun dossier dans cette file.',
          rows: [
            for (final l in d.disputeQueues[_tab])
              [
                OpsCell(l.$1, strong: true),
                OpsCell(l.$2),
                OpsCell(l.$3),
                OpsCell(fcfa(l.$4, withUnit: false)),
                OpsBadge(l.$5, tone: opsToneOf(l.$6)),
              ],
          ],
        ),
        const SizedBox(height: 14),
        OpsInfoNote(d.disputeNote),
      ],
    );
  }
}
