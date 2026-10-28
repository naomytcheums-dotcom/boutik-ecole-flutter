import '../m_widgets.dart';

/// 124 · Événements et campagnes de l’établissement.
class EvenementsCampagnesScreen extends ConsumerStatefulWidget {
  const EvenementsCampagnesScreen({super.key});

  @override
  ConsumerState<EvenementsCampagnesScreen> createState() => _EvenementsCampagnesScreenState();
}

class _EvenementsCampagnesScreenState extends ConsumerState<EvenementsCampagnesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionMDataProvider);
    final items = d.campaigns.where((c) => c.$1.toLowerCase().contains(_query.toLowerCase())).toList();
    return MAdminShell(
      title: 'Événements et campagnes',
      selected: 7,
      children: [
        OpsSearchRow(
          search: OpsSearchBar(
            hint: 'Rechercher un événement…',
            onChanged: (v) => setState(() => _query = v),
            onFilter: () => context.toast('Filtres (démonstration).'),
          ),
          button: OpsBigButton(
            label: 'Nouvel événement',
            icon: AppIcons.plus,
            onTap: () => context.toast('Nouvel événement créé (brouillon).'),
          ),
        ),
        gap16,
        OpsTable(
          columns: const ['Événement', 'Date', 'Lieu', 'Inscrits', 'Statut'],
          flex: const [4, 2, 2, 2, 3],
          emptyLabel: 'Aucun événement.',
          rows: [
            for (final c in items)
              [OpsCell(c.$1, strong: true), OpsCell(c.$2), OpsCell(c.$3), OpsCell(c.$4), lBadge(c.$5, c.$6)],
          ],
        ),
      ],
    );
  }
}
