import '../../common/common.dart';

/// 03 · Accueil (« Bienvenue »).
class AccueilScreen extends ConsumerStatefulWidget {
  const AccueilScreen({super.key});

  @override
  ConsumerState<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends ConsumerState<AccueilScreen> {
  int _category = 0;
  final _favorites = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            children: [
              const BrandMark(size: 36),
              const SizedBox(width: 10),
              Material(
                color: Colors.white,
                elevation: 3,
                shadowColor: const Color(0x33B9A5D8),
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => context.openScreen('240'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text('Cercle', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const Spacer(),
              HeaderIcon(AppIcons.search, label: 'Rechercher', onTap: () => context.openScreen('22')),
              HeaderIcon(AppIcons.bell, label: 'Notifications', badge: true, onTap: () => context.openScreen('53')),
              GestureDetector(
                onTap: () => context.openScreen('57'),
                child: const Avatar(image: Photos.avatarWoman, size: 36),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: PageIntro('Bienvenue', subtitle: 'Explorez le talent étudiant'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: SearchField(
            hint: 'Rechercher un produit, service, talent…',
            onTap: () => context.openScreen('19'),
            onFilter: () => context.openScreen('23'),
          ),
        ),
        gap16,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              for (final (i, c) in d.homeCategories.indexed) ...[
                if (i > 0) const SizedBox(width: 20),
                IconTile(
                  icon: c.$2,
                  label: c.$1,
                  selected: i == _category,
                  onTap: () {
                    setState(() => _category = i);
                    if (i > 0) context.openScreen('04');
                  },
                ),
              ],
            ],
          ),
        ),
        gap16,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _HeroBanner(d: d, onTap: () => context.openScreen('78')),
        ),
        gap24,
        SectionHeader('Produits en vedette', action: 'Voir tout', onAction: () => context.openScreen('04')),
        gap8,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, p) in d.featured.indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: ProductCard(
                    title: p.title,
                    price: fcfa(p.price),
                    subtitle: '${p.seller} – ${p.department}',
                    image: p.image,
                    favorite: _favorites.contains(p.id),
                    onFavorite: () => setState(() => _favorites.contains(p.id) ? _favorites.remove(p.id) : _favorites.add(p.id)),
                    onTap: () => context.openScreen('05'),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap24,
        SectionHeader('Talents à découvrir', action: 'Voir tout', onAction: () => context.openScreen('70')),
        gap8,
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              for (final t in d.talents)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 120,
                    child: GestureDetector(
                      onTap: () => context.openScreen('10'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhotoTile(image: t.$3, aspectRatio: 1.2, radius: 20, semanticLabel: t.$1),
                          const SizedBox(height: 6),
                          Text(t.$1, style: AppText.label, overflow: TextOverflow.ellipsis),
                          Text(t.$2, style: AppText.small, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bannière « À la une » : texte sur la photo comme dans la maquette (voir docs/QUESTIONS.md).
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.d, required this.onTap});

  final SectionAData d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${d.heroTitle.replaceAll('\n', ' ')}. ${d.heroText}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 185,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF2B1C12)),
                Positioned(right: 0, top: 0, bottom: 0, width: 220, child: Image.asset(Photos.heroStudent, fit: BoxFit.cover)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xF22B1C12), Color(0xB32B1C12), Color(0x002B1C12)],
                      stops: [0, .45, .8],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(d.heroBadge, tone: BadgeTone.dark),
                      const SizedBox(height: 10),
                      Text(d.heroTitle, style: AppText.h2.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1)),
                      const SizedBox(height: 4),
                      Text(d.heroText, style: AppText.small.copyWith(color: Colors.white)),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const AppIcon(AppIcons.arrowRight, size: 18),
                          ),
                          const Spacer(),
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: i == 0 ? 1 : .5),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
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
