import '../auth_common.dart';

/// 19 · Découvrir (« Trouvez ce qui vous inspire »).
class DecouvrirScreen extends ConsumerWidget {
  const DecouvrirScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionBDataProvider);
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: Image.asset(Photos.scrabble, fit: BoxFit.cover, semanticLabel: 'Lettres de Scrabble'),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0xB3000000)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 340,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
              children: [
                Row(
                  children: [
                    const BrandMark(size: 30),
                    const Spacer(),
                    HeaderIcon(AppIcons.bell, label: 'Notifications', badge: true, onTap: () => context.openScreen('53')),
                    const Avatar(image: Photos.avatarWoman, size: 32),
                  ],
                ),
                const SizedBox(height: 90),
                Semantics(
                  header: true,
                  child: Text.rich(
                    TextSpan(
                      text: 'Trouvez ce qui\n',
                      children: [
                        TextSpan(text: 'vous', style: AppText.display.copyWith(color: const Color(0xFFF6C84E), fontSize: 34)),
                        TextSpan(text: ' inspire', style: AppText.display.copyWith(color: Colors.white, fontSize: 34)),
                      ],
                    ),
                    style: AppText.display.copyWith(color: Colors.white, fontSize: 34),
                  ),
                ),
                gap12,
                Text(
                  'Produits, services, talents, projets… explorez tout l’univers étudiant de l’IUT de Douala.',
                  style: AppText.body.copyWith(color: Colors.white),
                ),
                gap24,
                AppCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      SearchField(hint: 'Rechercher un produit, service, talent…', showFilter: false, onTap: () => context.openScreen('22')),
                      gap8,
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF4F2F7), borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListRow(
                          title: 'Recherche avancée',
                          leading: const AppIcon(AppIcons.slidersHorizontal, size: 20),
                          onTap: () => context.openScreen('23'),
                        ),
                      ),
                    ],
                  ),
                ),
                gap24,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final (i, c) in d.discoverCategories.indexed)
                      Semantics(
                        button: true,
                        label: c.$1,
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => context.openScreen(['04', '34', '70', '78'][i]),
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: [
                                    const Color(0xFFFBE8B7),
                                    const Color(0xFFDDEFF7),
                                    const Color(0xFFEADFF8),
                                    const Color(0xFFDDF2E6),
                                  ][i],
                                ),
                                alignment: Alignment.center,
                                child: AppIcon(c.$2, size: 22),
                              ),
                              gap8,
                              Text(c.$1, style: AppText.label),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child: GlassNavBar(current: NavTab.home))),
        ],
      ),
    );
  }
}
