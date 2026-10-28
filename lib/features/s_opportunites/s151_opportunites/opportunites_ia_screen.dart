import '../s_widgets.dart';

/// 151 · Opportunités (assistant IA).
class OpportunitesIaScreen extends ConsumerStatefulWidget {
  const OpportunitesIaScreen({super.key});

  @override
  ConsumerState<OpportunitesIaScreen> createState() => _OpportunitesIaScreenState();
}

class _OpportunitesIaScreenState extends ConsumerState<OpportunitesIaScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionSDataProvider);
    final rubric = d.opportunityFilters[_filter];
    final items = _filter == 0 ? d.forYou : d.forYou.where((i) => i.rubric == rubric).toList();
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      header: GRootHeader(
        'Opportunités',
        action: HeaderIcon(AppIcons.bell, label: 'Alertes', onTap: () => context.openScreen('155')),
      ),
      children: [
        GestureDetector(
          onTap: () => context.openScreen('152'),
          child: SAiCard(title: 'Assistant Opportunités', text: d.assistantText, bullets: d.assistantBullets),
        ),
        gap12,
        GTabs(labels: d.opportunityFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        GSectionTitle('Pour vous', trailing: TextLink('Voir tout →', onTap: () => context.openScreen('152'))),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Aucune opportunité dans cette catégorie.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          SItemList(items),
        const GSectionTitle('Dates limites proches'),
        SItemList(d.deadlines),
      ],
    );
  }
}
