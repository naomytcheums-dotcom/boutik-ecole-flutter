import '../l_widgets.dart';

/// 114 · Mentors et encadreurs.
class MentorsScreen extends ConsumerStatefulWidget {
  const MentorsScreen({super.key});

  @override
  ConsumerState<MentorsScreen> createState() => _MentorsScreenState();
}

class _MentorsScreenState extends ConsumerState<MentorsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionLDataProvider);
    final items = d.mentors.where((m) => m.$1.toLowerCase().contains(_query.toLowerCase())).toList();
    return LDepartmentShell(
      title: 'Mentors et encadreurs',
      selected: 6,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(
            hint: 'Rechercher un mentor ou un encadreur…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Ajouter un mentor',
            icon: AppIcons.plus,
            onTap: () => context.toast('Invitation de mentor envoyée.'),
          ),
        ),
        gap16,
        OpsTable(
          columns: const ['Nom', 'Rôle', 'Spécialité', 'Étudiants suivis', 'Statut'],
          flex: const [3, 2, 2, 2, 2],
          emptyLabel: 'Aucun mentor trouvé.',
          rows: [
            for (final m in items)
              [OpsCell(m.$1, strong: true), OpsCell(m.$2), OpsCell(m.$3), OpsCell('${m.$4}'), lBadge(m.$5, m.$6)],
          ],
        ),
      ],
    );
  }
}
