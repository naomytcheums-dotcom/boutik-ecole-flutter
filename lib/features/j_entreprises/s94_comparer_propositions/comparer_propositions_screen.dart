import '../j_widgets.dart';

/// 94 · Comparer les propositions retenues.
class ComparerPropositionsScreen extends ConsumerStatefulWidget {
  const ComparerPropositionsScreen({super.key});

  @override
  ConsumerState<ComparerPropositionsScreen> createState() => _ComparerPropositionsScreenState();
}

class _ComparerPropositionsScreenState extends ConsumerState<ComparerPropositionsScreen> {
  int _criterion = 0;

  /// Meilleure proposition selon le critère choisi (prix et délai : le plus bas ; note et portfolio : le plus haut).
  JProposal _best(List<JProposal> ps) {
    num score(JProposal p) => switch (_criterion) {
      0 => -p.price,
      1 => -p.days,
      2 => double.parse(p.rating),
      _ => p.portfolio,
    };
    return ps.reduce((a, b) => score(b) > score(a) ? b : a);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    final ps = d.proposals;
    return HPage(
      title: 'Comparer les propositions',
      actions: [
        PrimaryButton(
          label: 'Choisir une proposition',
          height: 54,
          onPressed: () {
            final b = _best(ps);
            context.toast('Meilleure offre (${d.compareCriteria[_criterion]}) : ${b.shortName}.');
            context.openScreen('93b');
          },
        ),
      ],
      children: [
        const SizedBox(height: 1),
        HChips(labels: d.compareCriteria, selected: _criterion, onSelected: (i) => setState(() => _criterion = i)),
        const SizedBox(height: 8),
        JTable(
          header: ['Critère', for (final p in ps) p.shortName],
          flex: const [87, 74, 81, 70],
          rows: [
            ['Prix', for (final p in ps) fcfa(p.price, withUnit: false)],
            ['Délai', for (final p in ps) '${p.days} jours'],
            ['Note', for (final p in ps) p.rating],
            ['Révisions', for (final p in ps) '${p.revisions}'],
            ['Portfolio', for (final p in ps) '${p.portfolio}'],
          ],
        ),
        gap12,
        const JNote(
          'Comparez les critères puis acceptez la proposition qui répond le mieux à votre besoin.',
          icon: AppIcons.info,
        ),
      ],
    );
  }
}
