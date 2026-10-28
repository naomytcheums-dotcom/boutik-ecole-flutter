import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';
import '../n_widgets.dart';

/// 137 · Journal d'audit global (recherche, filtres par catégorie, export).
class JournalAuditScreen extends ConsumerStatefulWidget {
  const JournalAuditScreen({super.key});

  @override
  ConsumerState<JournalAuditScreen> createState() => _JournalAuditScreenState();
}

class _JournalAuditScreenState extends ConsumerState<JournalAuditScreen> {
  int _filter = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionNDataProvider);
    final q = _query.trim().toLowerCase();
    final entries = [
      for (final e in d.auditEntries)
        if ((_filter == 0 || e.$8 == d.auditFilters[_filter]) &&
            (q.isEmpty || '${e.$2} ${e.$3} ${e.$4} ${e.$5}'.toLowerCase().contains(q)))
          e,
    ];
    return NAdminShell(
      title: 'Journal d’audit global',
      selected: 10,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(hint: 'Rechercher dans le journal…', onChanged: (v) => setState(() => _query = v)),
          button: OpsBigButton(
            label: 'Exporter',
            icon: AppIcons.download,
            dark: false,
            onTap: () => context.toast('Export du journal préparé (démonstration).'),
          ),
        ),
        const SizedBox(height: 6),
        OpsFilterChips(labels: d.auditFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        const SizedBox(height: 6),
        OpsTable(
          columns: const ['Date', 'Acteur', 'Action', 'Cible', 'Institution', 'Niveau'],
          flex: const [133, 152, 266, 190, 114, 120],
          emptyLabel: 'Aucune entrée ne correspond à ces critères.',
          rows: [
            for (final e in entries)
              [
                OpsCell(e.$1, strong: true),
                OpsCell(e.$2),
                OpsCell(e.$3),
                OpsCell(e.$4),
                OpsCell(e.$5),
                OpsBadge(e.$6, tone: opsToneOf(e.$7)),
              ],
          ],
        ),
      ],
    );
  }
}
