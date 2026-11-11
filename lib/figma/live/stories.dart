import '../gdata.dart' show gNetImage;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
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
  const Story({required this.id, required this.authorId, required this.author, required this.avatar, required this.verified, required this.mediaUrl, required this.video, required this.caption, required this.createdAt, this.sticker, this.expiresAt, this.myChoice, this.myAnswer, required this.seen});
  final String id, authorId, author, avatar, mediaUrl, caption;
  final bool verified, video, seen;
  final DateTime createdAt;
  final Map<String, dynamic>? sticker; // {type: poll|question, text, options}
  final DateTime? expiresAt;
  final int? myChoice;
  final String? myAnswer;

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
        sticker: x['sticker'] is Map ? Map<String, dynamic>.from(x['sticker'] as Map) : null,
        expiresAt: DateTime.tryParse('${x['expires_at']}')?.toLocal(),
        myChoice: x['my_choice'] is num ? (x['my_choice'] as num).toInt() : null,
        myAnswer: x['my_answer'] == null ? null : '${x['my_answer']}',
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

/// Réglages d'une histoire avant publication : durée (24, 48 ou 72 h) et, au choix, une question ou un sondage.
class _StoryOptions {
  _StoryOptions(this.hours, this.sticker);
  final int hours;
  final Map<String, dynamic>? sticker;
}

Future<_StoryOptions?> _askStoryOptions(BuildContext context, int count) {
  var hours = 24;
  var kind = 'none';
  final text = TextEditingController();
  final opts = [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()];
  return showModalBottomSheet<_StoryOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        Widget chip(String label, bool on, VoidCallback tap) => GestureDetector(
              onTap: tap,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: on ? kInk : const Color(0xFFF1EDF7), borderRadius: BorderRadius.circular(20)), child: Text(label, style: sty(12.5, w: FontWeight.w600, c: on ? Colors.white : kInk))),
            );
        InputDecoration dec(String hint) => InputDecoration(hintText: hint, isDense: true, filled: true, fillColor: const Color(0xFFF7F4FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none));
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(count > 1 ? 'Publier $count histoires' : 'Publier une histoire', style: sty(17, w: FontWeight.w800)),
                const SizedBox(height: 14),
                Text('Durée de visibilité', style: sty(13, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [for (final h in const [24, 48, 72]) chip('$h h', hours == h, () => set(() => hours = h))]),
                const SizedBox(height: 16),
                Text('Interaction (facultatif)', style: sty(13, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [chip('Aucune', kind == 'none', () => set(() => kind = 'none')), chip('Question', kind == 'question', () => set(() => kind = 'question')), chip('Sondage', kind == 'poll', () => set(() => kind = 'poll'))]),
                if (kind != 'none') ...[
                  const SizedBox(height: 12),
                  TextField(controller: text, maxLength: 120, decoration: dec(kind == 'poll' ? 'Votre question' : 'Posez une question à vos abonnés')),
                ],
                if (kind == 'poll') ...[
                  for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: opts[i], maxLength: 40, decoration: dec(i < 2 ? 'Choix ${i + 1}' : 'Choix ${i + 1} (facultatif)'))),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Map<String, dynamic>? st;
                      if (kind == 'question' || kind == 'poll') {
                        final q = text.text.trim();
                        if (q.isEmpty) return gToast(ctx, 'Écrivez la question.');
                        if (kind == 'poll') {
                          final o = [for (final c in opts) if (c.text.trim().isNotEmpty) c.text.trim()];
                          if (o.length < 2) return gToast(ctx, 'Un sondage propose au moins 2 choix.');
                          st = {'type': 'poll', 'text': q, 'options': o};
                        } else {
                          st = {'type': 'question', 'text': q};
                        }
                      }
                      Navigator.of(ctx).pop(_StoryOptions(hours, st));
                    },
                    child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(25)), child: Text('Publier', style: sty(15, w: FontWeight.w700, c: Colors.white))),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> addStory(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'publier une histoire') || !context.mounted) return;
  // Plusieurs histoires à la fois : chaque photo ou vidéo choisie devient une histoire.
  final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov']);
  if (p.isEmpty || !context.mounted) return;
  final o = await _askStoryOptions(context, p.length);
  if (o == null || !context.mounted) return;
  var ok = 0;
  for (final f in p) {
    final up = await uploadPostMedia(context, f);
    if (up == null || !context.mounted) continue;
    final res = await Backend.rpc('create_story', {'p_path': up.path, 'p_kind': up.kind, 'p_caption': '', 'p_hours': o.hours, 'p_sticker': o.sticker});
    if (!context.mounted) return;
    if (res.error != null) {
      await gAlert(context, 'Histoire non publiée', Backend.userMessage(res.error!));
      continue;
    }
    ok++;
  }
  ref.invalidate(storiesProvider);
  if (ok > 0 && context.mounted) gToast(context, ok == 1 ? 'Votre histoire est en ligne pour ${o.hours} heures' : '$ok histoires en ligne pour ${o.hours} heures');
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
            ColoredBox(color: Colors.white, child: gNetImage(s.mediaUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 44)), loadingBuilder: (_, c, p) => p == null ? c : const Center(child: CircularProgressIndicator(color: Colors.white)))),
          if (s.sticker != null)
            Positioned(left: 20, right: 20, bottom: mq.padding.bottom + 90, child: _StickerPanel(key: ValueKey('sticker-${s.id}'), story: s, mine: s.authorId == me, onBusy: (b) { if (b) { _timer.stop(); _video?.pause(); } else { _timer.forward(); _video?.play(); } })),
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


/// Question ou sondage posé sur une histoire : on répond sans quitter l'histoire ; l'auteur voit les résultats.
class _StickerPanel extends ConsumerStatefulWidget {
  const _StickerPanel({super.key, required this.story, required this.mine, required this.onBusy});
  final Story story;
  final bool mine;
  final void Function(bool busy) onBusy;
  @override
  ConsumerState<_StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends ConsumerState<_StickerPanel> {
  final _text = TextEditingController();
  late int? _choice = widget.story.myChoice;
  late bool _sent = widget.story.myAnswer != null;
  List<int>? _counts;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.mine && widget.story.sticker?['type'] == 'poll') _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Backend.rpc('story_results', {'p_story': widget.story.id});
    if (!mounted || r.error != null || r.data is! Map) return;
    final c = (r.data as Map)['counts'];
    if (c is List) setState(() => _counts = [for (final x in c) (x as num).toInt()]);
  }

  Future<void> _answer({int? choice, String? text}) async {
    if (!await requireLogin(context, ref, 'répondre à une histoire') || !mounted) return;
    setState(() => _busy = true);
    final r = await Backend.rpc('answer_story', {'p_story': widget.story.id, 'p_choice': choice, 'p_answer': text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Réponse impossible', Backend.userMessage(r.error!));
    widget.onBusy(false);
    FocusScope.of(context).unfocus();
    setState(() {
      if (choice != null) _choice = choice;
      if (text != null) _sent = true;
    });
  }

  Future<void> _showAnswers() async {
    widget.onBusy(true);
    final r = await Backend.rpc('story_results', {'p_story': widget.story.id});
    if (!mounted) return;
    final list = r.data is Map && (r.data as Map)['answers'] is List ? (r.data as Map)['answers'] as List : const [];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Réponses (${list.length})', style: sty(16, w: FontWeight.w800)),
        content: SizedBox(
          width: 320,
          child: list.isEmpty
              ? Text('Aucune réponse pour le moment.', style: sty(13, c: kGrey))
              : ListView(shrinkWrap: true, children: [for (final a in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${(a as Map)['name']}', style: sty(12, w: FontWeight.w700)), Text('${a['answer']}', style: sty(13))]))]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer'))],
      ),
    );
    if (mounted) widget.onBusy(false);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.story.sticker!;
    final poll = st['type'] == 'poll';
    final opts = poll ? [for (final o in (st['options'] as List)) '$o'] : const <String>[];
    final showResults = poll && (widget.mine || _choice != null);
    final total = (_counts ?? const <int>[]).fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(18)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${st['text']}', style: sty(14, w: FontWeight.w800)),
        const SizedBox(height: 10),
        if (poll)
          for (var i = 0; i < opts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.mine || _choice != null || _busy ? null : () => _answer(choice: i),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(color: _choice == i ? kInk : const Color(0xFFF1EDF7), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: Text(opts[i], style: sty(13, w: FontWeight.w600, c: _choice == i ? Colors.white : kInk))),
                    if (showResults && widget.mine && _counts != null && i < _counts!.length) Text(total == 0 ? '0' : '${_counts![i]} · ${(100 * _counts![i] / total).round()} %', style: sty(11.5, w: FontWeight.w700, c: kGrey)),
                  ]),
                ),
              ),
            )
        else if (widget.mine)
          GestureDetector(onTap: _showAnswers, child: Text('Voir les réponses', style: sty(13, w: FontWeight.w700, c: const Color(0xFF5A3FE0))))
        else if (_sent)
          Text('Réponse envoyée. Merci !', style: sty(13, c: kGrey))
        else
          Row(children: [
            Expanded(
              child: TextField(
                controller: _text,
                maxLength: 300,
                onTap: () => widget.onBusy(true),
                decoration: InputDecoration(hintText: 'Votre réponse', counterText: '', isDense: true, filled: true, fillColor: const Color(0xFFF7F4FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _busy ? null : () => _text.text.trim().isEmpty ? gToast(context, 'Écrivez votre réponse.') : _answer(text: _text.text.trim()),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(12)), child: Text('Envoyer', style: sty(12.5, w: FontWeight.w700, c: Colors.white))),
            ),
          ]),
      ]),
    );
  }
}
