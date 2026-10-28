import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 129 · Institutions (recherche filtrante + ajout).
class InstitutionsScreen extends ConsumerStatefulWidget {
  const InstitutionsScreen({super.key});

  @override
  ConsumerState<InstitutionsScreen> createState() => _InstitutionsScreenState();
}

class _InstitutionsScreenState extends ConsumerState<InstitutionsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    final q = _query.trim().toLowerCase();
    final list = [
      for (final i in d.institutions)
        if (q.isEmpty || i.$1.toLowerCase().contains(q) || i.$2.toLowerCase().contains(q)) i,
    ];
    return NAdminShell(
      title: 'Institutions',
      selected: 2,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(hint: 'Rechercher une institution…', onChanged: (v) => setState(() => _query = v)),
          button: OpsBigButton(
            label: 'Ajouter une institution',
            icon: AppIcons.plus,
            onTap: () => context.toast('Assistant d’ajout d’institution (démonstration).'),
          ),
        ),
        const SizedBox(height: 16),
        OpsTable(
          columns: const ['Institution', 'Ville', 'Utilisateurs', 'Chiffre d’affaires', 'Statut'],
          flex: const [267, 152, 152, 210, 180],
          emptyLabel: 'Aucune institution ne correspond à « $_query ».',
          rows: [
            for (final i in list)
              [
                OpsCell(i.$1, strong: true),
                OpsCell(i.$2),
                OpsCell(i.$3 == null ? '—' : fcfa(i.$3!, withUnit: false)),
                OpsCell(i.$4 == null ? '—' : fcfa(i.$4!, withUnit: false)),
                OpsBadge(i.$5, tone: opsToneOf(i.$6)),
              ],
          ],
        ),
      ],
    );
  }
}
