import '../c_widgets.dart';

/// 22c · Tendances et nouveautés.
class TendancesNouveautesScreen extends ConsumerStatefulWidget {
  const TendancesNouveautesScreen({super.key});

  @override
  ConsumerState<TendancesNouveautesScreen> createState() => _TendancesNouveautesScreenState();
}

class _TendancesNouveautesScreenState extends ConsumerState<TendancesNouveautesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    return CPage(
      title: 'Tendances et nouveautés',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.trendTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap8,
        Semantics(
          label: 'Coups de cœur de la semaine. Les créations les plus aimées par la communauté',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(d.trendHero, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xCC1A1630)],
                        stops: [.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coups de cœur de la semaine',
                          style: AppText.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Les créations les plus aimées par la communauté',
                          style: AppText.small.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GSectionTitle('Produits tendance', trailing: TextLink('Voir tout →', onTap: () => context.openScreen('22'))),
        CGrid(d.trending),
        GSectionTitle('Nouveautés', trailing: TextLink('Voir tout →', onTap: () => context.openScreen('22'))),
        GListCard(
          children: [
            for (final n in d.newArrivals)
              GThumbRow(
                image: n.image,
                title: n.title,
                subtitle: n.detail,
                trailing: const GBadge('Nouveau', Tone.accent),
                onTap: () => context.openScreen('05'),
              ),
          ],
        ),
      ],
    );
  }
}
