import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/router/paths.dart';
import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'reels.dart' show relativeTime;
import 'social_posts.dart';

/// Histoires de 24 h : barre en tête du Cercle, anneau sur la photo du profil, visionneuse plein écran avec défilement,
/// passage à l'histoire suivante, retour, pause, et accès au profil du créateur (ses publications).

class Story {
  const Story({required this.id, required this.authorId, required this.author, required this.avatar, required this.verified, required this.mediaUrl, required this.video, required this.caption, required this.createdAt, required this.seen});
  final String id, authorId, author, avatar, mediaUrl, caption;
  final bool verified, video, seen;
  final DateTime createdAt;

  static Story fromRow(Map x) => Story(
        id: '${x['id']}',
        authorId: '${x['author_id']}',
        author: '${x['author']}',
        avatar: '${x['author_avatar'] ?? ''}',
        verified: x['author_verified'] == true,
        mediaUrl: Backend.postMediaUrl('${x['media_path']}'),
        video: x['media_kind'] == 'video',
        caption: '${x['caption'] ?? ''}',
        createdAt: DateTime.tryParse('${x['created_at']}')?.toLocal() ?? DateTime.now(),
        seen: x['seen'] == true,
      );
}

class StoryGroup {
  const StoryGroup(this.authorId, this.author, this.avatar, this.verified, this.stories);
  final String authorId, author, avatar;
  final bool verified;
  final List<Story> stories;
  bool get hasUnseen => stories.any((s) => !s.seen);
}

/// Histoires actives groupées par créateur : les vôtres d'abord, puis celles pas encore vues.
final storiesProvider = FutureProvider.autoDispose<List<StoryGroup>>((ref) async {
  if (!Backend.ready) return const [];
  final r = await Backend.rpc('stories_active', {'p_author': null});
  if (r.error != null || r.data is! List) return const [];
  final me = ref.read(authProvider).current?.serverId ?? '';
  final by = <String, List<Story>>{};
  for (final x in r.data as List) {
    final s = Story.fromRow(x as Map);
    (by[s.authorId] ??= []).add(s);
  }
  final groups = [for (final e in by.entries) StoryGroup(e.key, e.value.first.author, e.value.first.avatar, e.value.first.verified, e.value)];
  int rank(StoryGroup g) => g.authorId == me ? 0 : (g.hasUnseen ? 1 : 2);
  groups.sort((a, b) => rank(a).compareTo(rank(b)));
  return groups;
});

Future<void> addStory(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'publier une histoire') || !context.mounted) return;
  // Plusieurs histoires à la fois : chaque photo ou vidéo choisie devient une histoire.
  final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov']);
  if (p.isEmpty || !context.mounted) return;
  var ok = 0;
  for (final f in p) {
    final up = await uploadPostMedia(context, f);
    if (up == null || !context.mounted) continue;
    final res = await Backend.rpc('create_story', {'p_path': up.path, 'p_kind': up.kind, 'p_caption': ''});
    if (!context.mounted) return;
    if (res.error != null) {
      await gAlert(context, 'Histoire non publiée', Backend.userMessage(res.error!));
      continue;
    }
    ok++;
  }
  ref.invalidate(storiesProvider);
  if (ok > 0 && context.mounted) gToast(context, ok == 1 ? 'Votre histoire est en ligne pour 24 heures' : '$ok histoires en ligne pour 24 heures');
}

Future<void> openStories(BuildContext context, List<StoryGroup> groups, int start) {
  if (groups.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    pageBuilder: (_, _, _) => StoryViewer(groups: groups, start: start),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Rangée d'histoires du Cercle. Rien n'est inventé : sans histoire active, seule l'invitation à publier la sienne apparaît.
class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(storiesProvider).value ?? const <StoryGroup>[];
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final mine = groups.where((g) => g.authorId == me).firstOrNull;
    final others = [for (final g in groups) if (g.authorId != me) g];
    Widget ring(Widget child, bool unseen) => Container(
          width: 62,
          height: 62,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: unseen ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF4B6E), Color(0xFFFF8A3D)]) : null, color: unseen ? null : const Color(0xFFDAD6E2)),
          child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: child),
        );
    Widget item(Widget avatar, String label, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(width: 68, child: Column(children: [avatar, const SizedBox(height: 4), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(10, c: kInk))])),
        );
    return SizedBox(
      height: 92,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
        item(
          Stack(clipBehavior: Clip.none, children: [
            ring(socialAvatar(me.isEmpty ? '' : (mine?.avatar ?? ''), 'Moi', 52), mine?.hasUnseen ?? false),
            Positioned(right: -8, bottom: -8, child: Semantics(button: true, label: 'Ajouter une histoire', child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => addStory(context, ref), child: Padding(padding: const EdgeInsets.all(8), child: Container(width: 22, height: 22, decoration: BoxDecoration(color: kInk, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add, size: 14, color: Colors.white)))))),
          ]),
          'Votre histoire',
          () => mine == null ? addStory(context, ref) : openStories(context, groups, groups.indexOf(mine)),
        ),
        for (final g in others) ...[
          const SizedBox(width: 6),
          item(ring(socialAvatar(g.avatar, g.author, 52), g.hasUnseen), g.author, () => openStories(context, groups, groups.indexOf(g))),
        ],
      ]),
    );
  }
}

/// Anneau d'histoire autour de la photo d'un profil : touchez pour ouvrir ses histoires actives ; sans histoire, aucun anneau.
class ProfileStoryRing extends ConsumerWidget {
  const ProfileStoryRing({super.key, required this.userId, required this.child});
  final String userId;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(storiesProvider).value ?? const <StoryGroup>[];
    final g = groups.where((x) => x.authorId == userId).firstOrNull;
    if (g == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openStories(context, groups, groups.indexOf(g)),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: g.hasUnseen ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF4B6E), Color(0xFFFF8A3D)]) : null, color: g.hasUnseen ? null : const Color(0xFFDAD6E2)),
        child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: child),
      ),
    );
  }
}

class StoryViewer extends ConsumerStatefulWidget {
  const StoryViewer({super.key, required this.groups, required this.start});
  final List<StoryGroup> groups;
  final int start;
  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer> with SingleTickerProviderStateMixin {
  late int _g = widget.start.clamp(0, widget.groups.length - 1);
  int _i = 0;
  late final AnimationController _timer = AnimationController(vsync: this, duration: const Duration(seconds: 5))..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    final g = widget.groups[_g];
    final firstUnseen = g.stories.indexWhere((s) => !s.seen);
    _i = firstUnseen < 0 ? 0 : firstUnseen;
    _show();
  }

  @override
  void dispose() {
    _timer.dispose();
    _video?.dispose();
    super.dispose();
  }

  Story get _story => widget.groups[_g].stories[_i];

  Future<void> _show() async {
    _timer.stop();
    final old = _video;
    _video = null;
    await old?.dispose();
    final s = _story;
    if (Backend.ready) Backend.rpc('mark_story_seen', {'p_story': s.id});
    if (s.video) {
      final c = VideoPlayerController.networkUrl(Uri.parse(s.mediaUrl));
      try {
        await c.initialize();
        if (!mounted || _story.id != s.id) {
          await c.dispose();
          return;
        }
        _video = c;
        final d = c.value.duration;
        _timer.duration = d > const Duration(seconds: 30) ? const Duration(seconds: 30) : (d.inMilliseconds < 1000 ? const Duration(seconds: 5) : d);
        await c.play();
      } catch (_) {
        await c.dispose();
        _timer.duration = const Duration(seconds: 5);
      }
    } else {
      _timer.duration = const Duration(seconds: 5);
    }
    if (mounted) {
      setState(() {});
      _timer.forward(from: 0);
    }
  }

  void _next() {
    final g = widget.groups[_g];
    if (_i < g.stories.length - 1) {
      _i++;
    } else if (_g < widget.groups.length - 1) {
      _g++;
      _i = 0;
    } else {
      return _close();
    }
    _show();
  }

  void _prev() {
    if (_i > 0) {
      _i--;
    } else if (_g > 0) {
      _g--;
      _i = widget.groups[_g].stories.length - 1;
    }
    _show();
  }

  void _close() {
    ref.invalidate(storiesProvider);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _delete() async {
    _timer.stop();
    final r = await Backend.rpc('hide_story', {'p_story': _story.id});
    if (!mounted) return;
    if (r.error != null) {
      _timer.forward();
      return gToast(context, Backend.userMessage(r.error!));
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.groups[_g];
    final s = _story;
    final me = ref.read(authProvider).current?.serverId ?? '';
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => d.localPosition.dx < mq.size.width / 3 ? _prev() : _next(),
        onLongPressStart: (_) {
          _timer.stop();
          _video?.pause();
        },
        onLongPressEnd: (_) {
          _timer.forward();
          _video?.play();
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) _close();
        },
        child: Stack(fit: StackFit.expand, children: [
          if (s.video)
            (_video != null && _video!.value.isInitialized) ? Center(child: AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!))) : const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            ColoredBox(color: Colors.white, child: Image.network(s.mediaUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 44)), loadingBuilder: (_, c, p) => p == null ? c : const Center(child: CircularProgressIndicator(color: Colors.white)))),
          const Positioned(top: 0, left: 0, right: 0, height: 130, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000)]))))),
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            right: 12,
            child: Column(children: [
              Row(children: [
                for (var k = 0; k < g.stories.length; k++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: k < _i
                          ? Container(height: 3, color: Colors.white)
                          : k == _i
                              ? AnimatedBuilder(animation: _timer, builder: (_, _) => LinearProgressIndicator(value: _timer.value, minHeight: 3, backgroundColor: const Color(0x66FFFFFF), color: Colors.white))
                              : Container(height: 3, color: const Color(0x66FFFFFF)),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                GestureDetector(onTap: () => gOpenProfile(context, g.authorId), child: socialAvatar(g.avatar, g.author, 36)),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(children: [
                    Flexible(child: NameWithBadge(name: g.author, verified: g.verified, style: sty(13.5, w: FontWeight.w700, c: Colors.white))),
                    const SizedBox(width: 8),
                    Text(relativeTime(s.createdAt, DateTime.now()), style: sty(11, c: const Color(0xCCFFFFFF))),
                  ]),
                ),
                if (g.authorId == me) IconButton(onPressed: _delete, tooltip: 'Supprimer cette histoire', icon: const Icon(Icons.delete_outline, color: Colors.white)),
                IconButton(onPressed: _close, tooltip: 'Fermer', icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ]),
          ),
          if (s.caption.isNotEmpty) Positioned(left: 20, right: 20, bottom: mq.padding.bottom + 78, child: Text(s.caption, textAlign: TextAlign.center, style: sty(14, w: FontWeight.w600, c: Colors.white, h: 1.4))),
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.padding.bottom + 18,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final router = GoRouter.of(context);
                  final id = g.authorId;
                  _close();
                  router.push('${screenPath('247')}?user=${Uri.encodeQueryComponent(id)}');
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11), decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(30)), child: Text('Voir le profil et ses publications', style: sty(12.5, w: FontWeight.w700, c: Colors.white))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
