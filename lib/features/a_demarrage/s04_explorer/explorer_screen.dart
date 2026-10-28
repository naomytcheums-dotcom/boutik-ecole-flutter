import '../../common/common.dart';

/// 04 · Explorer (catalogue filtrable).
class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen> {
  int _filter = 0;
  late final Set<String> _favorites = {
    for (final e in ref.read(sectionADataProvider).explore)
      if (e.favorite) e.title,
  };

  static const _kindColor = {
    'Produit': (Colors.white, AppColors.ink),
    'Service': (Color(0xFF1FB5D6), AppColors.ink),
    'Projet': (Color(0xFF1FB5D6), AppColors.ink),
    'Talent': (Color(0xFF8B7BF0), Colors.white),
  };

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADataProvider);
    final kind = d.exploreFilters[_filter];
    final items = _filter == 0 ? d.explore : d.explore.where((e) => '${e.kind}s' == kind).toList();
    return AppScaffold(
      tab: NavTab.search,
      padding: EdgeInsets.zero,
      header: TitleHeader(
        'Explorer',
        trailing: HeaderIcon(AppIcons.search, label: 'Rechercher', onTap: () => context.openScreen('22')),
      ),
      children: [
        PillBar(labels: d.exploreFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap16,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text('Aucun résultat pour « $kind ».', textAlign: TextAlign.center, style: AppText.secondary),
                )
              : LayoutBuilder(
                  builder: (context, c) => Wrap(
                    spacing: 18,
                    runSpacing: 20,
                    children: [
                      for (final e in items)
                        SizedBox(
                          width: (c.maxWidth - 18) / 2,
                          child: _ExploreCard(
                            item: e,
                            colors: _kindColor[e.kind]!,
                            favorite: _favorites.contains(e.title),
                            onFavorite: () => setState(
                              () => _favorites.contains(e.title) ? _favorites.remove(e.title) : _favorites.add(e.title),
                            ),
                            onTap: () => context.openScreen(switch (e.kind) {
                              'Service' => '34',
                              'Talent' => '10',
                              'Projet' => '79',
                              _ => '05',
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        gap24,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _EnterpriseCard(onTap: () => context.openScreen('262')),
        ),
      ],
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.item, required this.colors, required this.favorite, required this.onFavorite, required this.onTap});

  final ExploreItem item;
  final (Color, Color) colors;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${item.kind} : ${item.title}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                PhotoTile(image: item.image, aspectRatio: 168 / 162, radius: 20, favorite: favorite, onFavorite: onFavorite),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: ShapeDecoration(color: colors.$1, shape: const StadiumBorder()),
                    child: Text(item.kind, style: AppText.label.copyWith(color: colors.$2, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            gap12,
            Text(item.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600), maxLines: 2),
            if (item.price != null) ...[gap8, Text(item.price!, style: AppText.bodyStrong.copyWith(fontSize: 15))],
            const SizedBox(height: 6),
            Text('Département : ${item.department}', style: AppText.small),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseCard extends StatelessWidget {
  const _EnterpriseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 152,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF16141B)),
                Positioned(right: 0, top: 0, bottom: 0, width: 150, child: Image.asset(Photos.enterprise, fit: BoxFit.cover)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF16141B), Color(0xE616141B), Color(0x0016141B)], stops: [0, .55, .85]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'Vous êtes ',
                          children: [
                            TextSpan(text: 'une entreprise ?', style: AppText.h3.copyWith(color: const Color(0xFFF6C84E))),
                          ],
                        ),
                        style: AppText.h3.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Découvrez les talents et projets\nqui peuvent vous intéresser.',
                        style: AppText.small.copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: ShapeDecoration(color: Colors.white.withValues(alpha: .14), shape: const StadiumBorder()),
                        child: Text('En savoir plus →', style: AppText.label.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
