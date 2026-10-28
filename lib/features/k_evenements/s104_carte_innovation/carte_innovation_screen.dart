import '../k_widgets.dart';

/// 104 · Carte de l’innovation (lieux et acteurs).
class CarteInnovationScreen extends ConsumerStatefulWidget {
  const CarteInnovationScreen({super.key});

  @override
  ConsumerState<CarteInnovationScreen> createState() => _CarteInnovationScreenState();
}

class _CarteInnovationScreenState extends ConsumerState<CarteInnovationScreen> {
  int _filter = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionKDataProvider);
    final items = d.places
        .where((p) => _filter == 0 || p.target == d.mapFilters[_filter])
        .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return CPage(
      title: 'Carte de l’innovation',
      trailing: HeaderIcon(AppIcons.funnel, label: 'Filtrer', onTap: () => context.openScreen('23')),
      children: [
        SearchField(hint: 'Rechercher un acteur, un lieu…', showFilter: false, onChanged: (v) => setState(() => _query = v)),
        gap16,
        Semantics(
          image: true,
          label: 'Carte du Cameroun : Douala, Yaoundé, Bafoussam, Bamenda, Bertoua, Ngaoundéré, Garoua, Maroua',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(d.mapImage, height: 300, width: double.infinity, fit: BoxFit.cover),
          ),
        ),
        gap16,
        GTabs(labels: d.mapFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucun lieu trouvé.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          GListCard(
            children: [
              for (final p in items)
                IIconRow(icon: p.icon, title: p.title, subtitle: p.detail, trailing: GBadge(p.badge, p.tone)),
            ],
          ),
      ],
    );
  }
}
