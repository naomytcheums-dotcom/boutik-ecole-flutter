import '../j_widgets.dart';

/// 96 · Défis d’innovation proposés par les entreprises.
class DefisInnovationScreen extends ConsumerStatefulWidget {
  const DefisInnovationScreen({super.key});

  @override
  ConsumerState<DefisInnovationScreen> createState() => _DefisInnovationScreenState();
}

class _DefisInnovationScreenState extends ConsumerState<DefisInnovationScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    final items = d.challenges.where((c) => c.status == d.challengeFilters[_filter]).toList();
    return JNavPage(
      title: 'Défis d’innovation',
      trailing: HHeaderAction(AppIcons.search, label: 'Rechercher', onTap: () => context.openScreen('21')),
      children: [
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: '${d.featuredChallenge}. Prix : ${fcfa(d.featuredPrize)} · ${d.featuredClosing}',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => context.openScreen('79'),
            child: Container(
              height: 168,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFC9C8CC), Color(0xFF8E8B93), Color(0xFF3A3742)],
                  stops: [0, .45, 1],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.featuredChallenge,
                    style: AppText.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18, height: 1.2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Prix : ${fcfa(d.featuredPrize)} · ${d.featuredClosing}',
                    style: AppText.small.copyWith(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        gap8,
        HChips(labels: d.challengeFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        if (items.isEmpty)
          const HEmpty('Aucun défi dans cette catégorie pour le moment.')
        else
          HListCard(
            children: [
              for (final c in items)
                HRow(
                  leading: JIconTile(c.icon),
                  title: c.title,
                  subtitle: '${c.sponsor} · ${c.teams} équipes',
                  trailing: Semantics(
                    label: 'Prix ${fcfa(c.prize)}',
                    excludeSemantics: true,
                    child: JBadge(fcfa(c.prize, withUnit: false), Tone.warning),
                  ),
                  onTap: () => context.openScreen('79'),
                ),
            ],
          ),
      ],
    );
  }
}
