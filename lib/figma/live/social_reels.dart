import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'reels.dart';
import 'social_posts.dart';

/// Écran Reels (245) : lecture réelle de la vidéo (ou carrousel des photos), colonne d'interactions posée directement sur la vidéo
/// (aucun fond), commentaires en feuille inférieure.

const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 8)];
TextStyle _w(double s, {FontWeight w = FontWeight.w600}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: s, fontWeight: w, color: Colors.white, shadows: _shadow);

class ReelPlayerBackdrop extends ConsumerWidget {
  const ReelPlayerBackdrop({super.key});

  static const _neutral = DecoratedBox(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B2740), Color(0xFF15131F)])),
    child: SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(currentReelProvider);
    if (r == null || !r.hasMedia) return _neutral;
    final media = r.allMedia;
    if (media.length == 1 && media.first.video) return _ReelVideo(key: ValueKey('v-${r.id}'), url: media.first.url);
    return _ReelPhotos(key: ValueKey('p-${r.id}'), media: media);
  }
}

class _ReelPhotos extends StatefulWidget {
  const _ReelPhotos({super.key, required this.media});
  final List<ReelMedia> media;
  @override
  State<_ReelPhotos> createState() => _ReelPhotosState();
}

class _ReelPhotosState extends State<_ReelPhotos> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Stack(children: [
        const SizedBox.expand(child: ColoredBox(color: Color(0xFF15131F))),
        PageView.builder(
          itemCount: widget.media.length,
          onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (_, k) => widget.media[k].video
              ? InlineVideo(url: widget.media[k].url)
              : Image.network(widget.media[k].url, fit: BoxFit.contain, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40))),
        ),
        if (widget.media.length > 1)
          Positioned(
            left: 0,
            right: 0,
            top: 104,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < widget.media.length; k++) AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: k == _i ? 18 : 6, height: 6, decoration: BoxDecoration(color: k == _i ? Colors.white : const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(3))),
            ]),
          ),
      ]);
}

class _ReelVideo extends StatefulWidget {
  const _ReelVideo({super.key, required this.url});
  final String url;
  @override
  State<_ReelVideo> createState() => _ReelVideoState();
}

class _ReelVideoState extends State<_ReelVideo> {
  VideoPlayerController? _c;
  bool _failed = false, _paused = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      await c.setLooping(true);
      try {
        await c.play();
      } catch (_) {
        await c.setVolume(0); // lecture automatique avec le son refusée par le navigateur : on démarre sans le son
        await c.play();
      }
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null) return;
    if (c.value.volume == 0 && !_paused) {
      c.setVolume(1);
      setState(() {});
      return;
    }
    _paused ? c.play() : c.pause();
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: ColoredBox(
        color: const Color(0xFF15131F),
        child: Stack(alignment: Alignment.center, children: [
          if (c != null && c.value.isInitialized) SizedBox.expand(child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)))),
          if (c == null && !_failed) const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          if (_failed) Padding(padding: const EdgeInsets.all(32), child: Text('La vidéo ne peut pas être lue pour le moment. Vérifiez votre connexion.', textAlign: TextAlign.center, style: _w(13, w: FontWeight.w500))),
          if (_paused) const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 84),
          if (c != null && c.value.volume == 0 && !_paused) Positioned(top: 110, right: 24, child: Row(children: [const Icon(Icons.volume_off, color: Colors.white, size: 18, shadows: _shadow), const SizedBox(width: 6), Text('Touchez pour le son', style: _w(11, w: FontWeight.w500))])),
        ]),
      ),
    );
  }
}

/// Colonne d'interactions (cœur, commentaires, partage, enregistrer, boutique) posée directement sur la vidéo : icônes blanches avec
/// une ombre légère, sans disque ni cadre.
class ReelActions extends ConsumerWidget {
  const ReelActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(currentReelProvider);
    Widget col(Widget icon, String label, VoidCallback? onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(width: 60, child: Column(mainAxisSize: MainAxisSize.min, children: [icon, Text(label, style: _w(10.5, w: FontWeight.w600))])),
        );
    return Column(mainAxisAlignment: MainAxisAlignment.start, children: [
      Stack(alignment: Alignment.center, children: [
        LikeHeart(
          liked: r?.liked ?? false,
          size: 32,
          idleColor: Colors.white,
          emoji: r == null ? null : kReactions[ref.watch(myReactionsProvider).value?[r.id]],
          onTap: () {
            if (r == null) return;
            final k = ref.read(myReactionsProvider).value?[r.id];
            k == null ? toggleLike(context, ref, r) : reactTo(context, ref, r, k);
          },
          onLongPress: r == null ? null : () => showReactionPicker(context, ref, r),
        ),
      ]),
      Text(compactCount(r?.likes ?? 0), style: _w(10.5)),
      const SizedBox(height: 6),
      col(const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 31, shadows: _shadow), compactCount(r?.comments ?? 0), r == null ? null : () => showCommentsSheet(context, r.id)),
      const SizedBox(height: 6),
      col(const Icon(Icons.ios_share_rounded, color: Colors.white, size: 30, shadows: _shadow), 'Partager', r == null ? null : () => sharePost(context, ref, r)),
      const SizedBox(height: 6),
      col(Icon((r?.saved ?? false) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Colors.white, size: 32, shadows: _shadow), compactCount(r?.saves ?? 0), r == null ? null : () => toggleSavePost(context, ref, r)),
      const SizedBox(height: 6),
      col(const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 32, shadows: _shadow), 'Plus', r == null ? null : () => showPostMenu(context, ref, r)),
      const SizedBox(height: 6),
      col(const Icon(Icons.storefront_outlined, color: Colors.white, size: 30, shadows: _shadow), 'Boutique', () => gOpen(context, '248')),
    ]);
  }
}

/// Auteur du reel : vraie photo de profil, nom suivi du badge bleu seulement si le compte est certifié.
class ReelAuthorRow extends ConsumerWidget {
  const ReelAuthorRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(currentReelProvider);
    if (r == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => gOpenProfile(context, r.authorId),
      child: Row(children: [
        socialAvatar(r.authorAvatar, r.author, 40),
        const SizedBox(width: 10),
        Expanded(child: NameWithBadge(name: r.author, verified: r.authorVerified, style: _w(13.5, w: FontWeight.w700), badgeSize: 14)),
      ]),
    );
  }
}

/// 252 hors démonstration : plus de page indépendante. L'écran montre la publication et ouvre la feuille de commentaires par-dessus ;
/// la fermer ramène à l'écran précédent.
class CommentsHost extends ConsumerStatefulWidget {
  const CommentsHost({super.key});
  @override
  ConsumerState<CommentsHost> createState() => _CommentsHostState();
}

class _CommentsHostState extends ConsumerState<CommentsHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final r = ref.read(currentReelProvider);
      if (r == null) return gBack(context);
      await showCommentsSheet(context, r.id);
      if (mounted) gBack(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Stack(children: [ReelPlayerBackdrop(), SizedBox.expand(child: ColoredBox(color: Color(0x33000000)))]);
}

/// Indique si l'utilisateur est connecté (aide pour les écrans qui masquent des actions sans compte).
bool signedIn(WidgetRef ref) => !Backend.ready || ref.read(authProvider).current != null;
