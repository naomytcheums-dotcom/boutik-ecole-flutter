import '../s_widgets.dart';

/// 158 · Candidatures classées (sélection pour comparaison).
class CandidaturesClasseesScreen extends ConsumerStatefulWidget {
  const CandidaturesClasseesScreen({super.key});

  @override
  ConsumerState<CandidaturesClasseesScreen> createState() => _CandidaturesClasseesScreenState();
}

class _CandidaturesClasseesScreenState extends ConsumerState<CandidaturesClasseesScreen> {
  int _tab = 1;
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionSDataProvider);
    final items = d.ranked.where((r) => _tab == 0 || (_tab == 1 ? r.$6 : r.$7)).toList();
    final list = _tab == 1 ? d.ranked : items;
    return GPage(
      title: 'Candidatures classées',
      actions: [
        PrimaryButton(
          label: _selected.length < 2 ? 'Comparer la sélection' : 'Comparer la sélection (${_selected.length})',
          height: 54,
          onPressed: () => _selected.length < 2
              ? context.toast('Sélectionnez au moins 2 candidatures.')
              : context.openScreen('190'),
        ),
      ],
      children: [
        GTabs(labels: d.rankTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap8,
        GListCard(
          children: [
            for (final r in list)
              GThumbRow(
                image: r.$3,
                title: r.$1,
                subtitle: r.$2,
                trailing: GBadge(_selected.contains(r.$1) ? '✓ ${r.$4}' : r.$4, _selected.contains(r.$1) ? Tone.accent : r.$5),
                onTap: () => setState(() => _selected.contains(r.$1) ? _selected.remove(r.$1) : _selected.add(r.$1)),
              ),
          ],
        ),
        gap12,
        const GNote('Le classement est une aide à la décision. La décision finale reste toujours humaine.', icon: AppIcons.info),
      ],
    );
  }
}
