import '../am_widgets.dart';

/// 251 · Découvrir : recherche, filtres par filière, tendances et talents à suivre.
class DecouvrirScreen extends ConsumerStatefulWidget {
  const DecouvrirScreen({super.key});

  @override
  ConsumerState<DecouvrirScreen> createState() => _DecouvrirScreenState();
}

class _DecouvrirScreenState extends ConsumerState<DecouvrirScreen> {
  int _filter = 0;
  final _followed = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final t = d.trends;
    Widget tile(int i, {double? height}) => Semantics(
      button: true,
      label: 'Ouvrir la publication ${i + 1}',
      child: GestureDetector(
        onTap: () => context.openScreen(t[i].$2 == 'Live' ? '246' : (i == 0 ? '245' : '244')),
        child: AmPhoto(
          t[i].$1,
          height: height,
          children: [
            if (t[i].$2 == 'Live')
              const Positioned(right: 10, top: 10, child: AmDarkTag('Live', color: amLive))
            else if (t[i].$2 != null)
              Positioned(left: 10, top: 10, child: AmDarkTag(t[i].$2!)),
          ],
        ),
      ),
    );
    return AppScaffold(
      tab: NavTab.search,
      padding: EdgeInsets.zero,
      header: AmRootHeader(
        'Découvrir',
        actions: [AmHeaderButton(AppIcons.funnel, label: 'Filtres', onTap: () {})],
      ),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: SearchField(hint: 'Rechercher un talent, un produit, un live', showFilter: false),
        ),
        gap8,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (var i = 0; i < d.discoverFilters.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Pill(
                  d.discoverFilters[i],
                  dense: true,
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Tendances', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              ),
              gap12,
              SizedBox(
                height: 236,
                child: Row(
                  children: [
                    Expanded(child: tile(0)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: tile(1)),
                          const SizedBox(height: 8),
                          Expanded(child: tile(2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    for (var i = 3; i < t.length; i++) ...[
                      if (i > 3) const SizedBox(width: 6),
                      Expanded(child: tile(i)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text('Talents à suivre', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
              ),
              gap12,
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: d.talents.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final (name, avatar) = d.talents[i];
              final followed = _followed.contains(name);
              return AmCard(
                radius: 22,
                padding: EdgeInsets.zero,
                child: SizedBox(
                  width: 80,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Avatar(image: avatar, size: 40),
                      const SizedBox(height: 6),
                      Text(name, style: AppText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 26,
                        child: OverflowBox(
                          maxHeight: 44,
                          child: AmChip(
                            followed ? 'Suivi' : 'Suivre',
                            dark: !followed,
                            height: 20,
                            fontSize: 10.5,
                            onTap: () => setState(() => followed ? _followed.remove(name) : _followed.add(name)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
