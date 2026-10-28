import '../m_widgets.dart';

/// 119 · Départements et filières.
class DepartementsFilieresScreen extends ConsumerStatefulWidget {
  const DepartementsFilieresScreen({super.key});

  @override
  ConsumerState<DepartementsFilieresScreen> createState() => _DepartementsFilieresScreenState();
}

class _DepartementsFilieresScreenState extends ConsumerState<DepartementsFilieresScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionMDataProvider);
    final q = _query.toLowerCase();
    final items = d.departments.where((x) => x.$1.toLowerCase().contains(q) || x.$2.toLowerCase().contains(q)).toList();
    return MAdminShell(
      title: 'Départements et filières',
      selected: 2,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(
            hint: 'Rechercher un département, une filière…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Ajouter un département',
            icon: AppIcons.plus,
            onTap: () => context.toast('Nouveau département créé (brouillon).'),
          ),
        ),
        gap16,
        OpsTable(
          columns: const ['Département', 'Filières', 'Responsable', 'Étudiants', 'Statut'],
          flex: const [3, 3, 3, 2, 2],
          emptyLabel: 'Aucun département trouvé.',
          rows: [
            for (final x in items)
              [OpsCell(x.$1, strong: true), OpsCell(x.$2), OpsCell(x.$3), OpsCell('${x.$4}'), lBadge(x.$5, x.$6)],
          ],
        ),
      ],
    );
  }
}
