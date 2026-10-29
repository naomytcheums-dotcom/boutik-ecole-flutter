import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// V1 · Vitrine : directs, filtres, produit mis en avant, collage métier et recommandations.
class VitrineScreen extends ConsumerStatefulWidget {
  const VitrineScreen({super.key});

  @override
  ConsumerState<VitrineScreen> createState() => _VitrineScreenState();
}

class _VitrineScreenState extends ConsumerState<VitrineScreen> {
  int _filter = 0;
  bool _liked = false;
  bool _subscribed = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    final section = AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const BrandMark(size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Vitrine', style: AppText.h1.copyWith(fontSize: 25, fontWeight: FontWeight.w600)),
              ),
            ),
            RefGlassButton(icon: AppIcons.search, label: 'Rechercher', onTap: () => context.openScreen('P5')),
            const SizedBox(width: 2),
            RefGlassButton(
              icon: AppIcons.bell,
              label: 'Notifications',
              onTap: () => context.toast('Aucune nouvelle notification'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('En direct maintenant', style: section.copyWith(fontSize: 14))),
            TextLink('Voir tout', onTap: () => context.openScreen('L1')),
          ],
        ),
        SizedBox(
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final (name, photo, tag) in d.lives) _LiveBubble(name: name, photo: photo, tag: tag)],
          ),
        ),
        const SizedBox(height: 14),
        RefPillRow(
          labels: d.vitrineFilters,
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
          height: 36,
          padding: 20,
          fontSize: 13.5,
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 360,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RefPhoto(d.heroImage, radius: 32, semanticLabel: d.productName),
              Positioned(
                left: 14,
                top: 14,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcons.zap, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Boosté',
                        style: AppText.small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: RoundIconButton(
                  icon: AppIcons.play,
                  label: 'Lire la vidéo',
                  size: 44,
                  bordered: false,
                  background: const Color(0x66FFFFFF),
                  foreground: Colors.white,
                  onTap: () => context.toast('Lecture de la vidéo'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RefCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(image: d.sellerAvatar, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(d.sellerName, style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const RefVerifiedDot(size: 16),
                          ],
                        ),
                        Text(d.sellerDept, style: AppText.small.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _subscribed = !_subscribed),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _subscribed ? refChip : AppColors.ink,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _subscribed ? 'Abonné' : 'S’abonner',
                          style: AppText.label.copyWith(
                            color: _subscribed ? AppColors.ink : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(d.productName, style: AppText.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Text(fcfa(d.productPrice), style: AppText.bodyStrong.copyWith(fontSize: 15, color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const RefStars(size: 13, spacing: 1),
                  const SizedBox(width: 2),
                  Text('${d.productRating} · ${d.productReviews} avis', style: AppText.small.copyWith(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.cardBorder),
              Row(
                children: [
                  _Action(
                    icon: _liked ? AppIcons.heartFilled : AppIcons.heart,
                    label: '${d.likes + (_liked ? 1 : 0)}',
                    color: _liked ? refLive : AppColors.ink,
                    semantic: _liked ? 'Je n’aime plus' : 'J’aime',
                    onTap: () => setState(() => _liked = !_liked),
                  ),
                  const SizedBox(width: 22),
                  _Action(
                    icon: AppIcons.messageCircle,
                    label: '${d.comments}',
                    semantic: 'Commentaires',
                    onTap: () => context.openScreen('A3'),
                  ),
                  const Spacer(),
                  _Action(icon: AppIcons.share, label: 'Partager', onTap: () => context.toast('Lien du produit copié')),
                  const SizedBox(width: 16),
                  _Action(icon: AppIcons.star, label: 'Noter', onTap: () => context.openScreen('P3')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Semantics(header: true, child: Text('Dans le même métier', style: section)),
        const SizedBox(height: 8),
        SizedBox(height: 214, child: _Collage(images: d.sameTrade)),
        const SizedBox(height: 14),
        RefCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Angles du produit', style: section),
              const SizedBox(height: 6),
              Text(
                'Touchez pour faire pivoter la lampe et voir chaque face.',
                style: AppText.small.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              RefChipButton(
                'Vue 3D',
                color: AppColors.accentSoft,
                foreground: AppColors.accent,
                height: 26,
                fontSize: 12,
                padding: 24,
                onTap: () => context.toast('Vue 3D : fais glisser pour pivoter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Semantics(header: true, child: Text('Recommandés pour vous', style: section)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < d.recommended.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _Recommended(item: d.recommended[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _LiveBubble extends StatelessWidget {
  const _LiveBubble({required this.name, required this.photo, this.tag});

  final String name;
  final String photo;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final ring = switch (tag) {
      'LIVE' => const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFF0335A), Color(0xFFFF9A5A)]),
      ),
      'BOOST' => const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
      _ => const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDCD8E0)),
    };
    return Semantics(
      button: true,
      label: tag == null ? name : '$name, $tag',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.openScreen('L1'),
        child: SizedBox(
          width: 62,
          child: Column(
            children: [
              SizedBox(
                height: 66,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      padding: EdgeInsets.all(tag == null ? 2 : 3),
                      decoration: ring,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: ClipOval(child: Image.asset(photo, fit: BoxFit.cover)),
                      ),
                    ),
                    if (tag != null)
                      Positioned(
                        bottom: 0,
                        child: RefLiveTag(tag!, color: tag == 'LIVE' ? refLive : AppColors.ink, fontSize: 8.5),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(name, style: AppText.small.copyWith(color: AppColors.ink, fontSize: 11.5), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap, this.color = AppColors.ink, this.semantic});

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(label, style: AppText.body.copyWith(fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Collage extends StatelessWidget {
  const _Collage({required this.images});

  final List<String> images;

  Widget _card(String image, double radius) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 16, offset: Offset(0, 8))],
    ),
    child: RefPhoto(image, radius: radius),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -10,
          top: 10,
          width: 120,
          height: 206,
          child: Transform.rotate(angle: -0.09, child: _card(images[0], 24)),
        ),
        Positioned(
          left: 56,
          top: 2,
          width: 122,
          height: 210,
          child: Transform.rotate(angle: -0.03, child: _card(images[1], 24)),
        ),
        Positioned(
          left: 120,
          top: 4,
          width: 128,
          height: 210,
          child: Transform.rotate(angle: 0.035, child: _card(images[2], 24)),
        ),
        Positioned(right: 0, top: 8, width: 94, height: 100, child: _card(images[3], 20)),
        Positioned(right: 0, top: 118, width: 94, height: 100, child: _card(images[4], 20)),
      ],
    );
  }
}

class _Recommended extends StatelessWidget {
  const _Recommended({required this.item});

  final (String, String, int, String) item;

  @override
  Widget build(BuildContext context) {
    final (name, seller, price, photo) = item;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => context.openScreen('P1'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefPhoto(photo, height: 150, radius: 24, semanticLabel: name),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$seller · ${fcfa(price, withUnit: false)} F', style: AppText.small.copyWith(fontSize: 11)),
                  const SizedBox(height: 4),
                  const RefStars(size: 11, spacing: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
