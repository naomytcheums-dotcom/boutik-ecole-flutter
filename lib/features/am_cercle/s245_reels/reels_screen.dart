import '../am_widgets.dart';

/// 245 · Reels : vidéo verticale plein écran, actions à droite, légende en bas.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  bool _playing = false;
  bool _liked = false;
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final white = AppText.body.copyWith(color: Colors.white);
    final actions = [
      (
        _liked ? AppIcons.heartFilled : AppIcons.heart,
        d.reelStats[0],
        'J’aime',
        () => setState(() => _liked = !_liked),
      ),
      (AppIcons.messageCircle, d.reelStats[1], 'Commentaires', () => context.openScreen('252')),
      (AppIcons.share, d.reelStats[2], 'Partager', () => context.openScreen('240')),
      (AppIcons.star, d.reelStats[3], 'Note', () => context.openScreen('252')),
      (AppIcons.shoppingBag, d.reelStats[4], 'Boutique', () => context.openScreen('248')),
    ];
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(d.reelImage, fit: BoxFit.cover, semanticLabel: 'Vidéo : pose d’un kit solaire'),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80000000), Color(0x14000000), Color(0x33000000), Color(0xD9000000)],
                  stops: [0, .3, .55, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.only(top: 28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 22, GlassNavBar.height + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Reels',
                            style: AppText.h1.copyWith(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      RoundIconButton(
                        icon: AppIcons.camera,
                        label: 'Créer un reel',
                        bordered: false,
                        elevated: true,
                        background: const Color(0x33FFFFFF),
                        foreground: Colors.white,
                        onTap: () => context.openScreen('249'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child: _playing
                              ? Semantics(
                                  button: true,
                                  label: 'Mettre en pause',
                                  child: GestureDetector(
                                    onTap: () => setState(() => _playing = false),
                                    child: const SizedBox.square(dimension: 68),
                                  ),
                                )
                              : AmPlayButton(size: 68, onTap: () => setState(() => _playing = true)),
                        ),
                        Positioned(
                          right: -4,
                          bottom: 0,
                          child: Column(
                            children: [
                              for (final a in actions) ...[
                                RoundIconButton(
                                  icon: a.$1,
                                  label: a.$3,
                                  bordered: false,
                                  background: const Color(0x40FFFFFF),
                                  foreground: a.$1 == AppIcons.heartFilled ? amLive : Colors.white,
                                  onTap: a.$4,
                                ),
                                Text(a.$2, style: AppText.small.copyWith(color: Colors.white, fontSize: 10)),
                                const SizedBox(height: 4),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  gap8,
                  Row(
                    children: [
                      Avatar(image: d.reelAvatar, size: 36),
                      const SizedBox(width: 10),
                      Text(d.reelAuthor, style: white.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 30),
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: () => setState(() => _following = !_following),
                          child: Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            decoration: const ShapeDecoration(color: Color(0x40FFFFFF), shape: StadiumBorder()),
                            child: Text(
                              _following ? 'Abonné' : 'S’abonner',
                              style: AppText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  gap12,
                  Padding(
                    padding: const EdgeInsets.only(right: 50),
                    child: Text(d.reelText, style: white.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500)),
                  ),
                  gap12,
                  Row(
                    children: [
                      const AppIcon(AppIcons.music, size: 16, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(d.reelSound, style: AppText.small.copyWith(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                  gap12,
                  Semantics(
                    label: 'Progression de la vidéo',
                    value: '${(d.reelProgress * 100).round()} %',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          children: [
                            const Positioned.fill(child: ColoredBox(color: Color(0x59FFFFFF))),
                            FractionallySizedBox(
                              widthFactor: d.reelProgress,
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: GlassNavBar(current: NavTab.home)),
          ),
        ],
      ),
    );
  }
}
