import '../j_widgets.dart';

/// 93 · Propositions reçues sur un besoin publié.
class PropositionsRecuesScreen extends ConsumerStatefulWidget {
  const PropositionsRecuesScreen({super.key});

  @override
  ConsumerState<PropositionsRecuesScreen> createState() => _PropositionsRecuesScreenState();
}

class _PropositionsRecuesScreenState extends ConsumerState<PropositionsRecuesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    final items = [
      for (final p in d.proposals)
        if (_tab == 0 || (_tab == 1 && p.shortlisted) || (_tab == 2 && p.refused)) p,
    ];
    return HPage(
      title: 'Propositions reçues',
      actions: [PrimaryButton(label: 'Comparer la sélection', height: 54, onPressed: () => context.openScreen('94'))],
      children: [
        const SizedBox(height: 1),
        HChips(
          labels: [
            for (final (i, t) in d.proposalTabs.indexed) d.proposalCounts[i] > 0 ? '$t (${d.proposalCounts[i]})' : t,
          ],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const HEmpty('Aucune proposition dans cet onglet.')
        else ...[
          HListCard(
            children: [
              for (final p in items)
                HRow(
                  leading: JAvatar(p.avatar),
                  title: p.name,
                  subtitle: '${fcfa(p.price)} · ${p.days} jours',
                  trailing: JBadge('${p.rating} ★', Tone.warning),
                  onTap: () => context.openScreen('93b'),
                ),
            ],
          ),
          gap12,
          JTable(
            header: const ['Talent', 'Prix (FCFA)', 'Délai'],
            flex: const [124, 99, 87],
            rows: [
              for (final p in items) [p.shortName, fcfa(p.price, withUnit: false), '${p.days} jours'],
            ],
          ),
        ],
      ],
    );
  }
}
