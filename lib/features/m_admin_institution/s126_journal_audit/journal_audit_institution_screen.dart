import '../m_widgets.dart';

/// 126 · Journal d’audit de l’établissement.
class JournalAuditInstitutionScreen extends ConsumerStatefulWidget {
  const JournalAuditInstitutionScreen({super.key});

  @override
  ConsumerState<JournalAuditInstitutionScreen> createState() => _JournalAuditInstitutionScreenState();
}

class _JournalAuditInstitutionScreenState extends ConsumerState<JournalAuditInstitutionScreen> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionMDataProvider);
    final q = _query.toLowerCase();
    final items = d.audit.where((a) {
      final ok = _tab == 0 || a.$7 == d.auditTabs[_tab];
      return ok && (a.$2.toLowerCase().contains(q) || a.$3.toLowerCase().contains(q));
    }).toList();
    return MAdminShell(
      title: 'Journal d’audit',
      selected: 9,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(
            hint: 'Rechercher une action, un utilisateur…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Exporter le journal',
            icon: AppIcons.download,
            dark: false,
            onTap: () => context.toast('Journal exporté (démonstration).'),
          ),
        ),
        gap16,
        OpsFilterChips(labels: d.auditTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Date', 'Utilisateur', 'Action', 'Cible', 'IP', 'Niveau'],
          flex: const [2, 2, 3, 3, 2, 2],
          emptyLabel: 'Aucune entrée pour ce filtre.',
          rows: [
            for (final a in items)
              [
                OpsCell(a.$1, strong: true),
                OpsCell(a.$2),
                OpsCell(a.$3),
                OpsCell(a.$4),
                OpsCell(a.$5),
                lBadge(a.$6, a.$6 == 'Sensible' ? Tone.accent : Tone.neutral),
              ],
          ],
        ),
      ],
    );
  }
}
