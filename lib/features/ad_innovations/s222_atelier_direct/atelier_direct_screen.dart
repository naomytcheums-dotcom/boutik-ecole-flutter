import '../ad_widgets.dart';

/// 222 · Atelier en direct (vidéo, vendeur, produit, commentaires).
class AtelierDirectScreen extends ConsumerStatefulWidget {
  const AtelierDirectScreen({super.key});

  @override
  ConsumerState<AtelierDirectScreen> createState() => _AtelierDirectScreenState();
}

class _AtelierDirectScreenState extends ConsumerState<AtelierDirectScreen> {
  final _comment = TextEditingController();
  final _sent = <String>[];
  bool _subscribed = false;
  bool _liked = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _send() {
    final t = _comment.text.trim();
    if (t.isEmpty) {
      context.toast('Écrivez un commentaire avant d’envoyer.');
      return;
    }
    setState(() {
      _sent.add(t);
      _comment.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final p = d.liveProduct;
    return AppScaffold(
      showNav: false,
      header: const AdCenterHeader('Atelier en direct'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      bottomBarHeight: 66,
      bottomBar: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _input()),
      children: [
        _Video(viewers: d.liveViewers, elapsed: d.liveElapsed, image: p.image),
        const SizedBox(height: 12),
        AdCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              AdAvatar(d.liveHost.$3, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.liveHost.$1, style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(d.liveHost.$2, style: AppText.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              AdChipButton(
                _subscribed ? 'Abonné' : 'S’abonner',
                height: 26,
                fontSize: 12,
                onTap: () => setState(() => _subscribed = !_subscribed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              AdThumb(p.image, size: 80, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++) const AppIcon(AppIcons.starFilled, size: 13, color: adAmber),
                        const SizedBox(width: 6),
                        Text(p.rating, style: AppText.small.copyWith(fontSize: 12.5, color: const Color(0xFF4A4752))),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: const ShapeDecoration(color: Color(0xFFFDEFCF), shape: StadiumBorder()),
                          child: Text(
                            p.left,
                            style: AppText.small.copyWith(fontSize: 11.5, color: const Color(0xFF8F5400)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fcfa(p.price),
                            style: AppText.h3.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        AdChipButton(
                          'Commander',
                          height: 26,
                          fontSize: 12.5,
                          onTap: () => context.toast('« ${p.title} » ajouté au panier.'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final c in d.liveComments) _CommentBubble(author: c.$1, avatar: c.$2, text: c.$3),
        for (final t in _sent) _CommentBubble(author: 'Vous', avatar: Photos.avatarWoman, text: t),
      ],
    );
  }

  Widget _input() => Container(
    height: 54,
    padding: const EdgeInsets.only(left: 20, right: 6),
    decoration: const ShapeDecoration(color: Color(0xF2FFFFFF), shape: StadiumBorder(), shadows: adShadow),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _comment,
            onSubmitted: (_) => _send(),
            style: AppText.body,
            decoration: InputDecoration(
              hintText: 'Écrire un commentaire…',
              hintStyle: AppText.secondary.copyWith(fontSize: 13.5, color: const Color(0xFF5E5B66)),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: _liked ? 'Je n’aime plus' : 'J’aime',
          child: GestureDetector(
            onTap: () => setState(() => _liked = !_liked),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFCEFF3)),
                alignment: Alignment.center,
                child: AppIcon(
                  _liked ? AppIcons.heartFilled : AppIcons.heart,
                  size: 17,
                  color: _liked ? const Color(0xFFE11D48) : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        RoundIconButton(
          icon: AppIcons.arrowUp,
          label: 'Envoyer le commentaire',
          size: 42,
          background: AppColors.ink,
          foreground: Colors.white,
          bordered: false,
          onTap: _send,
        ),
      ],
    ),
  );
}

class _Video extends StatelessWidget {
  const _Video({required this.viewers, required this.elapsed, required this.image});

  final String viewers;
  final String elapsed;
  final String image;

  Widget _glass(Widget child, {EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 10)}) => Container(
    height: 26,
    padding: padding,
    decoration: const ShapeDecoration(color: Color(0x99141228), shape: StadiumBorder()),
    child: child,
  );

  Widget _side(String icon, String label, {Color color = AppColors.ink}) => Semantics(
    button: true,
    label: label,
    child: SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xCCFFFFFF)),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 16, color: color),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vidéo en direct, $viewers spectateurs, $elapsed',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 352,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover, excludeFromSemantics: true),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const ShapeDecoration(color: Color(0xFFE11D48), shape: StadiumBorder()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text('EN DIRECT', style: AppText.label.copyWith(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: _glass(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcons.eye, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        viewers,
                        style: AppText.label.copyWith(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 88,
                child: Column(
                  children: [
                    _side(AppIcons.heart, 'J’aime'),
                    _side(AppIcons.starFilled, 'Ajouter aux favoris', color: adAmber),
                    _side(AppIcons.heart, 'Envoyer un cœur'),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 18,
                child: _glass(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIcons.clock, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        elapsed,
                        style: AppText.label.copyWith(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.author, required this.avatar, required this.text});

  final String author;
  final String avatar;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 27,
        constraints: const BoxConstraints(minWidth: 260),
        padding: const EdgeInsets.only(left: 2, right: 14),
        decoration: const ShapeDecoration(color: Color(0x99FFFFFF), shape: StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdAvatar(avatar, size: 23),
            const SizedBox(width: 8),
            Text(author, style: AppText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(fontSize: 12, color: const Color(0xFF4A4752)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
