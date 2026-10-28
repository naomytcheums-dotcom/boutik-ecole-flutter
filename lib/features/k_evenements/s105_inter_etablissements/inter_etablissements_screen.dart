import '../k_widgets.dart';

/// 105 · Inter-établissements (créations des autres IUT).
class InterEtablissementsScreen extends ConsumerStatefulWidget {
  const InterEtablissementsScreen({super.key});

  @override
  ConsumerState<InterEtablissementsScreen> createState() => _InterEtablissementsScreenState();
}

class _InterEtablissementsScreenState extends ConsumerState<InterEtablissementsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    final items = _filter == 0
        ? d.otherCampuses
        : d.otherCampuses.where((t) => t.department == d.campusFilters[_filter]).toList();
    return CPage(
      title: 'Inter-établissements',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.campusFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        const GSectionTitle('Créations des autres IUT'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucune création partagée.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          CGrid(items, onTap: (_) => context.openScreen('270')),
        gap16,
        GNote(d.interDelay, icon: AppIcons.truck),
      ],
    );
  }
}
