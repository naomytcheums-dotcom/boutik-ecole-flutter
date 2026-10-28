import '../../../core/utils/validators_am.dart';
import '../am_widgets.dart';

/// 252 · Commentaires et avis d'un article, avec saisie de commentaire.
class CommentairesScreen extends ConsumerStatefulWidget {
  const CommentairesScreen({super.key});

  @override
  ConsumerState<CommentairesScreen> createState() => _CommentairesScreenState();
}

class _CommentairesScreenState extends ConsumerState<CommentairesScreen> {
  final _input = TextEditingController();
  final _liked = <String>{};
  final _added = <AmComment>[];
  int _tab = 0;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final error = validateComment(_input.text);
    setState(() {
      _error = error;
      if (error == null) {
        _added.add((
          author: 'Moi',
          avatar: 'assets/images/q_av_mariam.jpg',
          time: 'à l’instant',
          mention: null,
          text: _input.text.trim(),
          likes: 0,
        ));
        _input.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final comments = [...d.comments, ..._added];
    return AppScaffold(
      showNav: false,
      header: ScreenHeader(
        title: d.articleTitle,
        subtitle: d.articleAuthor,
        actions: [AmHeaderButton(AppIcons.ellipsisVertical, label: 'Plus d’options', onTap: () {})],
      ),
      bottomBarHeight: _error == null ? 64 : 88,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error)),
              ),
            ),
          _Composer(controller: _input, onSend: _send, onChanged: () => setState(() => _error = null)),
        ],
      ),
      children: [
        Row(
          children: [
            AmPhoto(d.articleImage, width: 64, height: 64, radius: 14),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fcfa(d.articlePrice),
                  style: AppText.h3.copyWith(color: amViolet, fontWeight: FontWeight.w700),
                ),
                AmChip('Voir dans la boutique', tone: Tone.accent, height: 26, onTap: () => context.openScreen('248')),
              ],
            ),
          ],
        ),
        gap12,
        Container(
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
          child: Row(
            children: [
              for (final (i, label) in ['Commentaires (${d.commentsCount})', 'Avis (${d.reviewsCount})'].indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == _tab,
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: i == _tab ? AppColors.ink : Colors.transparent,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          label,
                          style: AppText.label.copyWith(
                            color: i == _tab ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        gap16,
        Row(
          children: [
            Text(d.rating, style: AppText.display.copyWith(fontSize: 34, fontWeight: FontWeight.w700)),
            const SizedBox(width: 18),
            Expanded(
              child: Semantics(
                label: 'Note ${d.rating} sur 5',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 5; i++) ...[
                          const AppIcon(AppIcons.starFilled, size: 16, color: Color(0xFFF5A524)),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(d.verifiedReviews, style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ),
            AmChip('Donner mon avis', dark: true, height: 30, onTap: () => setState(() => _tab = 1)),
          ],
        ),
        gap16,
        for (final c in (_tab == 0 ? comments : comments.take(1)))
          _CommentRow(
            comment: c,
            liked: _liked.contains(c.author + c.time),
            onLike: () => setState(() {
              final k = c.author + c.time;
              _liked.contains(k) ? _liked.remove(k) : _liked.add(k);
            }),
          ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.liked, required this.onLike});

  final AmComment comment;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Avatar(image: comment.avatar, size: 38),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment.author, style: AppText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Text(comment.time, style: AppText.small.copyWith(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    if (comment.mention != null)
                      TextSpan(
                        text: comment.mention,
                        style: const TextStyle(color: amViolet),
                      ),
                    TextSpan(text: comment.text),
                  ],
                ),
                style: AppText.secondary.copyWith(color: const Color(0xFF4A4752)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: liked ? 'Je n’aime plus' : 'J’aime',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onLike,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              child: Column(
                children: [
                  AppIcon(
                    liked ? AppIcons.heartFilled : AppIcons.heart,
                    size: 18,
                    color: liked ? amLive : AppColors.ink,
                  ),
                  const SizedBox(height: 4),
                  Text('${comment.likes + (liked ? 1 : 0)}', style: AppText.small.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: const ShapeDecoration(
      color: Colors.white,
      shape: StadiumBorder(),
      shadows: [BoxShadow(color: Color(0x142A1B5C), blurRadius: 18, offset: Offset(0, 6))],
    ),
    child: Row(
      children: [
        RoundIconButton(
          icon: AppIcons.paperclip,
          label: 'Joindre un fichier',
          size: 36,
          bordered: false,
          background: AppColors.accentSoft,
          onTap: () {},
        ),
        const SizedBox(width: 2),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSend(),
            textInputAction: TextInputAction.send,
            style: AppText.body.copyWith(fontSize: 13),
            decoration: InputDecoration(
              filled: false,
              hintText: 'Ajouter un commentaire… (@ pour mentionner)',
              hintStyle: AppText.secondary.copyWith(fontSize: 13),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        RoundIconButton(
          icon: AppIcons.atSign,
          label: 'Mentionner un compte',
          size: 30,
          bordered: false,
          background: AppColors.accentSoft,
          foreground: AppColors.accent,
          onTap: () => controller.text = '${controller.text}@',
        ),
        RoundIconButton(
          icon: controller.text.trim().isEmpty ? AppIcons.mic : AppIcons.send,
          label: controller.text.trim().isEmpty ? 'Message vocal' : 'Envoyer',
          size: 40,
          bordered: false,
          background: AppColors.ink,
          foreground: Colors.white,
          onTap: onSend,
        ),
      ],
    ),
  );
}
