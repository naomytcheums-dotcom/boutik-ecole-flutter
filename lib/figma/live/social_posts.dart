import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'dictation_stub.dart' if (dart.library.js_interop) 'dictation_web.dart';
import 'reels.dart';
import 'share.dart';
import 'store.dart' show nowProvider;
import 'talents.dart' show askText;

/// Réseau social : briques communes (badge certifié, photo de profil, cœur animé, commentaires en feuille inférieure, menu à trois
/// points, partage, republication, publication complète, carrousel de médias). Écrans 244, 244b, 245, 247, 250, 252.

const kInk = Color(0xFF111015);
const kGrey = Color(0xFF57545F);
const kLine = Color(0xFFECE8F2);
const kLike = Color(0xFFE5484D);
TextStyle sty(double size, {FontWeight w = FontWeight.w500, Color c = kInk, double? h}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h);

/// Badge bleu : affiché UNIQUEMENT quand le serveur confirme que le compte est certifié (`certification = approved`).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Compte certifié',
        child: Container(width: size, height: size, decoration: const BoxDecoration(color: Color(0xFF2F7DF6), shape: BoxShape.circle), alignment: Alignment.center, child: Icon(Icons.check, color: Colors.white, size: size * 0.72)),
      );
}

/// Nom suivi, si le compte est certifié, du badge bleu.
class NameWithBadge extends StatelessWidget {
  const NameWithBadge({super.key, required this.name, required this.verified, required this.style, this.badgeSize = 14, this.maxLines = 1});
  final String name;
  final bool verified;
  final TextStyle style;
  final double badgeSize;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(name, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style)),
        if (verified) ...[const SizedBox(width: 5), VerifiedBadge(size: badgeSize)],
      ]);
}

/// Photo de profil réelle du titulaire ; à défaut, son initiale (jamais une photo de maquette).
Widget socialAvatar(String url, String name, double size) {
  final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
  final fallback = Container(width: size, height: size, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE9F6)), child: Text(initial, style: sty(size * 0.38, w: FontWeight.w700, c: const Color(0xFF4A4854))));
  if (url.isEmpty) return fallback;
  return ClipOval(child: SizedBox(width: size, height: size, child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback)));
}

// ------------------------------------------------------------------ cœur

/// Cœur animé : l'icône ne rétrécit jamais (impulsion 1 → 1,3 → 1), un appui enregistre ou retire la réaction sans quitter l'écran.
class LikeHeart extends StatefulWidget {
  const LikeHeart({super.key, required this.liked, required this.onTap, this.size = 24, this.idleColor = kInk, this.emoji, this.onLongPress});
  final bool liked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? emoji; // réaction choisie autre que le cœur
  final double size;
  final Color idleColor;
  @override
  State<LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<LikeHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.32).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.32, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 55),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        toggled: widget.liked,
        label: widget.liked ? 'Retirer mon j’aime' : 'J’aime',
        excludeSemantics: true,
        onTap: _tap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          onLongPress: widget.onLongPress == null ? null : () {
            HapticFeedback.mediumImpact();
            widget.onLongPress!();
          },
          child: SizedBox(
            width: math.max(44, widget.size + 16),
            height: math.max(44, widget.size + 16),
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: widget.emoji != null ? Text(widget.emoji!, style: TextStyle(inherit: false, fontSize: widget.size * .92, height: 1)) : Icon(widget.liked ? Icons.favorite : Icons.favorite_border, size: widget.size, color: widget.liked ? kLike : widget.idleColor),
              ),
            ),
          ),
        ),
      );

  void _tap() {
    HapticFeedback.lightImpact();
    _c.forward(from: 0);
    widget.onTap();
  }
}

// ------------------------------------------------------------------ duo et remix

/// Vidéo verticale : 3 min au plus ; vidéo horizontale : 5 min au plus. Renvoie un message si la durée est dépassée.
Future<String?> videoLimitError(String path) async {
  final c = VideoPlayerController.networkUrl(Uri.parse(Backend.postMediaUrl(path)));
  try {
    await c.initialize().timeout(const Duration(seconds: 20));
    final vertical = c.value.size.height > c.value.size.width;
    final secs = c.value.duration.inSeconds;
    if (secs > (vertical ? 180 : 300)) {
      final m = secs ~/ 60, r = secs % 60;
      return vertical ? 'Une vidéo verticale dure 3 min au plus (la vôtre : $m min $r s).' : 'Une vidéo horizontale dure 5 min au plus (la vôtre : $m min $r s).';
    }
  } catch (_) {
    // durée illisible : on laisse passer, le serveur reste juge
  } finally {
    await c.dispose();
  }
  return null;
}

/// Duo (côte à côte avec l'originale) ou remix (réponse qui renvoie vers l'originale) : on choisit ou on filme sa vidéo, puis on publie.
Future<void> createRemix(BuildContext context, WidgetRef ref, Reel original, String kind) async {
  if (!original.video) return gToast(context, 'Le duo et le remix se font à partir d’une vidéo.');
  if (!await requireLogin(context, ref, kind == 'duet' ? 'faire un duo' : 'faire un remix') || !context.mounted) return;
  final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['mp4', 'mov']);
  if (p.isEmpty || !context.mounted) return;
  final up = await uploadPostMedia(context, p.first);
  if (up == null || !context.mounted) return;
  final err = await videoLimitError(up.path);
  if (err != null) {
    try {
      await Supabase.instance.client.storage.from('post-media').remove([up.path]);
    } catch (_) {}
    if (context.mounted) gToast(context, err);
    return;
  }
  final res = await Backend.rpc('create_remix', {'p_original': original.id, 'p_kind': kind, 'p_path': up.path, 'p_caption': ''});
  if (!context.mounted) return;
  if (res.error != null) {
    try {
      await Supabase.instance.client.storage.from('post-media').remove([up.path]);
    } catch (_) {}
    return gAlert(context, kind == 'duet' ? 'Duo impossible' : 'Remix impossible', Backend.userMessage(res.error!));
  }
  ref.invalidate(remixesProvider);
  await ref.read(reelsProvider.notifier).refresh();
  if (context.mounted) gToast(context, kind == 'duet' ? 'Votre duo est publié.' : 'Votre remix est publié.');
}

/// Publications qui sont un duo ou un remix : { identifiant → (originale, type) }.
final remixesProvider = FutureProvider.autoDispose<Map<String, ({String of, String kind})>>((ref) async {
  if (!Backend.ready) return const {};
  try {
    final rows = await Supabase.instance.client.from('posts').select('id,remix_of,remix_kind').not('remix_of', 'is', null).limit(300);
    return {for (final x in rows) '${x['id']}': (of: '${x['remix_of']}', kind: '${x['remix_kind']}')};
  } catch (_) {
    return const {};
  }
});

/// Média de la vidéo d'origine d'un duo : { chemin public, auteur }.
final originalVideoProvider = FutureProvider.autoDispose.family<({String url, String author})?, String>((ref, id) async {
  try {
    final row = await Supabase.instance.client.from('posts').select('media_path,author_id,profiles(name)').eq('id', id).maybeSingle();
    if (row == null) return null;
    final name = (row['profiles'] is Map ? (row['profiles'] as Map)['name'] : null) ?? '';
    return (url: Backend.postMediaUrl('${row['media_path']}'), author: '$name');
  } catch (_) {
    return null;
  }
});

class _DuoPlayer extends StatefulWidget {
  const _DuoPlayer({super.key, required this.url, this.sound = false});
  final String url;
  final bool sound;
  @override
  State<_DuoPlayer> createState() => _DuoPlayerState();
}

class _DuoPlayerState extends State<_DuoPlayer> {
  VideoPlayerController? _c;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _c = c;
    c.initialize().then((_) {
      c.setVolume(0);
      c.setLooping(true);
      c.play();
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Color(0xFF18171F));
    return GestureDetector(
      onTap: () {
        _on = !_on;
        c.setVolume(_on ? 1 : 0);
        setState(() {});
      },
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
        if (widget.sound) Positioned(right: 8, bottom: 8, child: Icon(_on ? Icons.volume_up : Icons.volume_off, color: Colors.white, size: 20)),
      ]),
    );
  }
}

/// Duo : la vidéo d'origine à gauche, la réponse à droite, lues ensemble.
class DuetView extends ConsumerWidget {
  const DuetView({super.key, required this.originalId, required this.url});
  final String originalId, url;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(originalVideoProvider(originalId)).value;
    return ClipRRect(
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Row(children: [
          Expanded(child: o == null ? const ColoredBox(color: Color(0xFF18171F)) : _DuoPlayer(key: ValueKey('o$originalId'), url: o.url)),
          const SizedBox(width: 2),
          Expanded(child: _DuoPlayer(key: ValueKey(url), url: url, sound: true)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ réactions

const kReactions = {'like': '👍', 'love': '❤️', 'haha': '😂', 'wow': '😮', 'sad': '😢', 'fire': '🔥', 'clap': '👏'};

/// Ma réaction (autre que le simple cœur) sur chaque publication : { identifiant de publication → type de réaction }.
final myReactionsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  if (!Backend.ready) return const {};
  final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (me.isEmpty) return const {};
  final r = await Backend.rows('post_reactions', 'post_id,kind', limit: 1000);
  return {for (final x in r.rows) '${x['post_id']}': '${x['kind']}'};
});

/// Enregistre (ou retire, si c'est la même) une réaction sur une publication.
Future<void> reactTo(BuildContext context, WidgetRef ref, Reel post, String kind) async {
  if (!await requireLogin(context, ref, 'réagir à une publication') || !context.mounted) return;
  final res = await Backend.rpc('react_post', {'p_post': post.id, 'p_kind': kind});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Réaction impossible', Backend.userMessage(res.error!));
  ref.invalidate(myReactionsProvider);
  await ref.read(reelsProvider.notifier).refresh();
}

/// Appui long sur le cœur : choix d'une réaction parmi sept.
Future<void> showReactionPicker(BuildContext context, WidgetRef ref, Reel post) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (final e in kReactions.entries)
          Semantics(
            button: true,
            label: 'Réagir : ${e.key}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(ctx).pop();
                reactTo(context, ref, post, e.key);
              },
              child: Padding(padding: const EdgeInsets.all(8), child: Text(e.value, style: const TextStyle(inherit: false, fontSize: 30, height: 1))),
            ),
          ),
      ]),
    ),
  );
}

// ------------------------------------------------------------------ envoi de médias

/// Dépose un fichier choisi dans le dossier de la personne (`post-media/<uid>/…`) et renvoie son chemin ; null si refusé (message affiché).
Future<({String path, String kind, String mime})?> uploadPostMedia(BuildContext context, PlatformFile f) async {
  final ext = f.name.split('.').last.toLowerCase();
  const mimes = {'mp4': 'video/mp4', 'mov': 'video/quicktime', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'gif': 'image/gif'};
  final mime = mimes[ext];
  if (mime == null) {
    await gAlert(context, 'Format refusé', 'Vidéo MP4 ou MOV, ou image JPG, PNG, WebP.');
    return null;
  }
  final bytes = await f.readAsBytes();
  if (!context.mounted) return null;
  if (bytes.length > 50 * 1024 * 1024) {
    await gAlert(context, 'Fichier trop lourd', '50 Mo au maximum par fichier (vidéo de 60 secondes au plus).');
    return null;
  }
  final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
  try {
    await Supabase.instance.client.storage.from('post-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
  } catch (_) {
    if (context.mounted) await gAlert(context, 'Envoi impossible', 'Le fichier n’a pas pu être déposé. Vérifiez votre connexion et réessayez.');
    return null;
  }
  return (path: path, kind: mime.startsWith('video') ? 'video' : 'image', mime: mime);
}

// ------------------------------------------------------------------ commentaires

class PostComment {
  const PostComment({required this.id, required this.parentId, required this.author, required this.authorId, required this.avatar, required this.verified, required this.mine, required this.body, required this.createdAt, required this.likes, required this.liked, required this.attachment});
  final String id, parentId, author, authorId, avatar, body, attachment;
  final bool verified, mine, liked;
  final int likes;
  final DateTime createdAt;

  static PostComment fromRow(Map x) => PostComment(
        id: '${x['id']}',
        parentId: '${x['parent_id'] ?? ''}',
        author: '${x['author']}',
        authorId: '${x['author_id'] ?? ''}',
        avatar: '${x['author_avatar'] ?? ''}',
        verified: x['author_verified'] == true,
        mine: x['mine'] == true,
        body: '${x['body'] ?? ''}',
        createdAt: DateTime.tryParse('${x['created_at']}')?.toLocal() ?? DateTime.now(),
        likes: (x['likes'] as num?)?.toInt() ?? 0,
        liked: x['liked'] == true,
        attachment: (x['attachment_path'] == null || '${x['attachment_path']}'.isEmpty) ? '' : Backend.postMediaUrl('${x['attachment_path']}'),
      );
}

/// Commentaires d'une publication (racines puis réponses). Repli sur l'ancienne fonction si le serveur n'est pas encore migré.
final postCommentsProvider = FutureProvider.autoDispose.family<List<PostComment>, String>((ref, postId) async {
  var r = await Backend.rpc('post_comment_list_v2', {'p_post': postId, 'p_limit': 200});
  if (r.error != null || r.data is! List) r = await Backend.rpc('post_comment_list', {'p_post': postId, 'p_limit': 200});
  if (r.error != null || r.data is! List) throw Exception('Les commentaires ne peuvent pas être chargés pour le moment.');
  return [for (final x in r.data as List) PostComment.fromRow(x as Map)];
});

/// « Commenter » : feuille inférieure par-dessus l'écran, la publication (ou la vidéo) reste visible au-dessus.
Future<void> showCommentsSheet(BuildContext context, String postId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x14000000),
      useSafeArea: false,
      builder: (_) => _CommentsSheet(postId: postId),
    );

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;
  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _dictation = Dictation();
  PostComment? _replyTo;
  PlatformFile? _file;
  bool _sending = false, _listening = false;
  String _before = '';

  @override
  void dispose() {
    _dictation.stop();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif']);
    if (p.isEmpty || !mounted) return;
    setState(() => _file = p.first);
  }

  void _dictate() {
    if (_listening) {
      _dictation.stop();
      return;
    }
    if (!_dictation.supported) return gToast(context, 'La dictée vocale n’est pas disponible sur cet appareil.');
    _before = _text.text;
    setState(() => _listening = true);
    _dictation.start(
      onText: (t, _) {
        if (!mounted) return;
        final joined = _before.isEmpty ? t : '$_before $t';
        _text.value = TextEditingValue(text: joined.length > 500 ? joined.substring(0, 500) : joined, selection: TextSelection.collapsed(offset: math.min(joined.length, 500)));
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _listening = false);
        if (e == 'not-allowed' || e == 'service-not-allowed') gToast(context, 'Autorisez le micro pour dicter votre commentaire.');
      },
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    final body = _text.text.trim();
    if (body.isEmpty && _file == null) return;
    if (!Backend.ready) return gToast(context, 'Les commentaires nécessitent la connexion au serveur.');
    if (ref.read(authProvider).current == null) return gToast(context, 'Connectez-vous pour commenter.');
    setState(() => _sending = true);
    String? path, kind;
    if (_file != null) {
      final up = await uploadPostMedia(context, _file!);
      if (up == null || !mounted) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      path = up.path;
      kind = up.kind;
    }
    var res = await Backend.rpc('add_post_comment_v2', {'p_post': widget.postId, 'p_body': body, 'p_parent': _replyTo?.id, 'p_attachment_path': path, 'p_attachment_kind': kind});
    if (res.error != null && path == null && (res.error!.toLowerCase().contains('add_post_comment_v2') || res.error!.toLowerCase().contains('could not find'))) {
      res = await Backend.rpc('add_post_comment', {'p_post': widget.postId, 'p_body': body, 'p_parent': _replyTo?.id});
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.error != null) return gToast(context, Backend.userMessage(res.error!));
    _text.clear();
    setState(() {
      _replyTo = null;
      _file = null;
    });
    FocusScope.of(context).unfocus();
    ref.invalidate(postCommentsProvider(widget.postId));
    ref.read(reelsProvider.notifier).patch(widget.postId, (x) => x.copyWith(comments: x.comments + 1));
  }

  Future<void> _like(PostComment c) async {
    if (ref.read(authProvider).current == null) return gToast(context, 'Connectez-vous pour réagir.');
    final r = await Backend.rpc('toggle_comment_like', {'p_comment': c.id});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    ref.invalidate(postCommentsProvider(widget.postId));
  }

  Future<void> _delete(PostComment c) async {
    final r = await Backend.rpc('delete_post_comment', {'p_comment': c.id});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    ref.invalidate(postCommentsProvider(widget.postId));
    ref.read(reelsProvider.notifier).patch(widget.postId, (x) => x.copyWith(comments: (x.comments - 1).clamp(0, 1 << 30)));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    // la feuille laisse toujours voir le haut de la publication ; avec le clavier elle remonte sans dépasser l'écran
    final maxH = mq.size.height - keyboard - mq.padding.top - 56;
    final h = math.min(mq.size.height * 0.6, maxH).clamp(240.0, mq.size.height);
    final comments = ref.watch(postCommentsProvider(widget.postId));
    final count = ref.watch(reelsProvider.select((l) => l?.where((r) => r.id == widget.postId).firstOrNull?.comments)) ?? comments.value?.length ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: h,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18)), boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24)]),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD9D5E2), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(children: [
              Expanded(child: Text(count == 0 ? 'Commentaires' : '$count commentaire${count > 1 ? 's' : ''}', style: sty(15, w: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, size: 22, color: kInk), tooltip: 'Fermer'),
            ]),
          ),
          const Divider(height: 1, color: kLine),
          Expanded(child: _list(comments)),
          _composer(mq),
        ]),
      ),
    );
  }

  Widget _list(AsyncValue<List<PostComment>> comments) => comments.when(
        loading: () => Center(child: Text('Chargement des commentaires…', style: sty(13, c: kGrey))),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Les commentaires ne peuvent pas être chargés pour le moment.', textAlign: TextAlign.center, style: sty(13, c: kGrey)),
              TextButton(onPressed: () => ref.invalidate(postCommentsProvider(widget.postId)), child: Text('Réessayer', style: sty(13, w: FontWeight.w700))),
            ]),
          ),
        ),
        data: (list) {
          if (list.isEmpty) return Center(child: Text('Aucun commentaire pour le moment.\nSoyez le premier à réagir.', textAlign: TextAlign.center, style: sty(13, c: kGrey, h: 1.5)));
          final roots = [for (final c in list) if (c.parentId.isEmpty) c];
          final replies = <String, List<PostComment>>{};
          for (final c in list) {
            if (c.parentId.isNotEmpty) (replies[c.parentId] ??= []).add(c);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            children: [
              for (final c in roots) ...[
                _row(c, 0),
                for (final r in replies[c.id] ?? const <PostComment>[]) _row(r, 1),
              ],
            ],
          );
        },
      );

  Widget _row(PostComment c, int depth) {
    final now = ref.watch(nowProvider);
    return Padding(
      padding: EdgeInsets.only(left: depth * 38.0, top: 10, bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(onTap: c.authorId.isEmpty ? null : () => gOpenProfile(context, c.authorId), child: socialAvatar(c.avatar, c.author, depth == 0 ? 36 : 28)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: NameWithBadge(name: c.author, verified: c.verified, style: sty(12.5, w: FontWeight.w700), badgeSize: 13)),
              const SizedBox(width: 8),
              Text(relativeTime(c.createdAt, now), style: sty(10.5, c: kGrey)),
            ]),
            if (c.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(c.body, style: sty(13, c: const Color(0xFF2A2833), h: 1.4))),
            if (c.attachment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200, maxWidth: 220), child: Image.network(c.attachment, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink())),
              ),
            Row(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _replyTo = c);
                  _focus.requestFocus();
                },
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Répondre', style: sty(11.5, w: FontWeight.w600, c: kGrey))),
              ),
              if (c.mine) ...[
                const SizedBox(width: 16),
                GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _delete(c), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Supprimer', style: sty(11.5, w: FontWeight.w600, c: kGrey)))),
              ],
            ]),
          ]),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _like(c),
          child: SizedBox(width: 44, child: Column(children: [
            Icon(c.liked ? Icons.favorite : Icons.favorite_border, size: 18, color: c.liked ? kLike : kGrey),
            if (c.likes > 0) Text(compactCount(c.likes), style: sty(10.5, c: kGrey)),
          ])),
        ),
      ]),
    );
  }

  Widget _composer(MediaQueryData mq) {
    final bottomZone = mq.viewInsets.bottom > 0 ? 0.0 : mq.viewPadding.bottom; // zone système Android (barre de gestes) quand le clavier est fermé
    final signedIn = !Backend.ready || ref.watch(authProvider.select((a) => a.current != null));
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
      padding: EdgeInsets.fromLTRB(10, 8, 10, 10 + bottomZone),
      child: !signedIn
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Center(child: Text('Connectez-vous pour commenter.', style: sty(13, c: kGrey))))
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (_replyTo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Row(children: [
                    Expanded(child: Text('Réponse à ${_replyTo!.author}', style: sty(12, c: kGrey))),
                    GestureDetector(onTap: () => setState(() => _replyTo = null), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 16, color: kGrey))),
                  ]),
                ),
              if (_file != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Row(children: [
                    const Icon(Icons.image_outlined, size: 18, color: kGrey),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_file!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(12, c: kGrey))),
                    GestureDetector(onTap: () => setState(() => _file = null), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, size: 16, color: kGrey))),
                  ]),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(onPressed: _sending ? null : _pick, tooltip: 'Joindre une image', icon: const Icon(Icons.attach_file, size: 22, color: kInk)),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    style: sty(14),
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      hintText: _replyTo == null ? 'Ajouter un commentaire…' : 'Votre réponse…',
                      hintStyle: sty(14, c: kGrey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      filled: true,
                      fillColor: const Color(0xFFF3F1F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                IconButton(onPressed: _dictate, tooltip: _listening ? 'Arrêter la dictée' : 'Dicter', icon: Icon(_listening ? Icons.mic : Icons.mic_none, size: 22, color: _listening ? kLike : kInk)),
                IconButton(
                  onPressed: _sending ? null : _send,
                  tooltip: 'Envoyer',
                  icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 22, color: kInk),
                ),
              ]),
            ]),
    );
  }
}

// ------------------------------------------------------------------ partage, republication, menu

String postLink(Reel r) => '$siteUrl/#/s/244?post=${r.id}';

/// Partage réel : feuille de partage du système (ou copie du lien), puis déclaration du partage au serveur.
Future<void> sharePost(BuildContext context, WidgetRef ref, Reel r) async {
  final cap = r.caption.trim();
  final text = '${r.author} sur Boutik-École${cap.isEmpty ? '' : ' : ${cap.length > 140 ? '${cap.substring(0, 140)}…' : cap}'}\n${postLink(r)}';
  await shareText(context, text, subject: 'Publication de ${r.author}');
  if (Backend.ready && ref.read(authProvider).current != null) {
    final res = await Backend.rpc('record_post_share', {'p_post': r.id});
    if (res.error == null) await ref.read(reelsProvider.notifier).refresh();
  }
}

Future<void> copyPostLink(BuildContext context, Reel r) async {
  await Clipboard.setData(ClipboardData(text: postLink(r)));
  if (context.mounted) gToast(context, 'Lien copié');
}

Future<void> toggleSavePost(BuildContext context, WidgetRef ref, Reel r) async {
  if (!Backend.ready) return gToast(context, 'Publication enregistrée (démonstration)');
  if (ref.read(authProvider).current == null) return gToast(context, 'Connectez-vous pour enregistrer une publication.');
  ref.read(reelsProvider.notifier).patch(r.id, (x) => x.copyWith(saved: !x.saved, saves: x.saved ? (x.saves - 1).clamp(0, 1 << 30) : x.saves + 1));
  final res = await Backend.rpc('toggle_post_save', {'p_post': r.id});
  if (res.error != null) {
    ref.read(reelsProvider.notifier).patch(r.id, (x) => x.copyWith(saved: r.saved, saves: r.saves));
    if (context.mounted) gToast(context, Backend.userMessage(res.error!));
  } else if (context.mounted) {
    gToast(context, res.data == true ? 'Publication enregistrée' : 'Retirée de vos enregistrements');
  }
}

Future<void> reportPost(BuildContext context, WidgetRef ref, Reel r) async {
  if (!await requireLogin(context, ref, 'signaler une publication') || !context.mounted) return;
  final why = await askText(context, title: 'Signaler', body: 'Pourquoi cette publication pose-t-elle problème ?', hint: 'Contenu trompeur…', ok: 'Signaler', min: 3);
  if (why == null || !context.mounted) return;
  final res = await Backend.rpc('report_post', {'p_post': r.id, 'p_reason': why});
  if (context.mounted) res.error != null ? gAlert(context, 'Signalement impossible', Backend.userMessage(res.error!)) : gToast(context, 'Signalement transmis à la modération');
}

/// Republier : ajoute la publication d'origine (avec un commentaire facultatif) à son propre fil.
Future<void> repostPost(BuildContext context, WidgetRef ref, Reel r) async {
  if (!Backend.ready) return gToast(context, 'Republication (démonstration)');
  if (!await requireLogin(context, ref, 'republier') || !context.mounted) return;
  final note = await askText(context, title: 'Republier', body: 'Ajoutez un mot si vous le souhaitez (facultatif).', hint: 'Votre commentaire…', ok: 'Republier', min: 0);
  if (note == null || !context.mounted) return;
  final res = await Backend.rpc('create_post_v2', {'p_caption': note, 'p_media': const [], 'p_link': null, 'p_tags': const <String>[], 'p_listing': null, 'p_repost_of': r.repostId.isNotEmpty && r.caption.isEmpty ? r.repostId : r.id});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Republication impossible', Backend.userMessage(res.error!));
  final st = res.data is Map ? '${(res.data as Map)['status']}' : '';
  await ref.read(reelsProvider.notifier).refresh();
  if (context.mounted) gToast(context, st == 'published' ? 'Publication republiée' : 'Republication envoyée : visible après validation');
}

/// Menu à trois points d'une publication.
Future<void> showPostMenu(BuildContext context, WidgetRef ref, Reel r) {
  Widget item(BuildContext ctx, IconData icon, String label, FutureOr<void> Function() run, {Color color = kInk}) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: sty(14, w: FontWeight.w600, c: color)),
        onTap: () {
          Navigator.of(ctx).pop();
          run();
        },
      );
  final me = ref.read(authProvider).current?.serverId ?? '';
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFFD9D5E2), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),
        item(ctx, r.saved ? Icons.bookmark : Icons.bookmark_border, r.saved ? 'Retirer des enregistrements' : 'Enregistrer', () => toggleSavePost(context, ref, r)),
        item(ctx, Icons.repeat, 'Republier', () => repostPost(context, ref, r)),
        if (r.video) item(ctx, Icons.splitscreen_outlined, 'Faire un duo', () => createRemix(context, ref, r, 'duet')),
        if (r.video) item(ctx, Icons.auto_awesome_motion_outlined, 'Faire un remix', () => createRemix(context, ref, r, 'remix')),
        item(ctx, Icons.ios_share, 'Partager', () => sharePost(context, ref, r)),
        item(ctx, Icons.link, 'Copier le lien', () => copyPostLink(context, r)),
        if (r.authorId.isNotEmpty) item(ctx, Icons.person_outline, 'Voir le profil', () => gOpenProfile(context, r.authorId)),
        if (r.authorId != me) item(ctx, Icons.flag_outlined, 'Signaler', () => reportPost(context, ref, r), color: kLike),
        const SizedBox(height: 8),
      ])),
    ),
  );
}

// ------------------------------------------------------------------ carrousel de médias

/// Médias d'une publication : défilement horizontal sans limite de nombre, indicateurs de pagination, proportions d'origine préservées
/// (jamais rognées : l'image est contenue dans un cadre aux proportions de la première photo).
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({super.key, required this.media, this.onOpenReels});
  final List<ReelMedia> media;
  final VoidCallback? onOpenReels;
  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    if (m.isEmpty) return const SizedBox.shrink();
    final ratio = (m.first.ratio ?? (m.first.video ? 9 / 12 : 4 / 3)).clamp(0.75, 1.6);
    return Stack(children: [
      AspectRatio(
        aspectRatio: ratio,
        child: ColoredBox(
          color: const Color(0xFFF1EFF5),
          child: PageView.builder(
            controller: _page,
            itemCount: m.length,
            onPageChanged: (v) => setState(() => _i = v),
            itemBuilder: (_, k) => m[k].video
                ? InlineVideo(url: m[k].url, onFull: widget.onOpenReels)
                : Image.network(m[k].url, fit: BoxFit.contain, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: kGrey)), loadingBuilder: (_, child, p) => p == null ? child : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
          ),
        ),
      ),
      if (m.length > 1) ...[
        Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), color: const Color(0xB3111015), child: Text('${_i + 1}/${m.length}', style: sty(11, w: FontWeight.w600, c: Colors.white)))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < m.length; k++)
              AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: k == _i ? 16 : 6, height: 6, color: k == _i ? Colors.white : const Color(0x99FFFFFF), foregroundDecoration: BoxDecoration(border: Border.all(color: const Color(0x33000000), width: 0.5))),
          ]),
        ),
      ],
    ]);
  }
}

/// Vidéo lue dans le fil : l'image d'attente devient une lecture au toucher (le fichier n'est chargé qu'à la demande).
class InlineVideo extends StatefulWidget {
  const InlineVideo({super.key, required this.url, this.onFull});
  final String url;
  final VoidCallback? onFull;
  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _c;
  bool _loading = false, _failed = false;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_c != null) {
      _c!.value.isPlaying ? await _c!.pause() : await _c!.play();
      if (mounted) setState(() {});
      return;
    }
    setState(() => _loading = true);
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _loading = false;
      });
    } catch (_) {
      await c.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _start,
      child: ColoredBox(
        color: const Color(0xFF18171F),
        child: Stack(alignment: Alignment.center, children: [
          if (c != null && c.value.isInitialized) Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
          if (_loading) const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          if (!_loading && (c == null || !c.value.isPlaying)) Icon(_failed ? Icons.error_outline : Icons.play_circle_fill, color: Colors.white, size: 52),
          if (_failed) Positioned(bottom: 14, child: Text('Vidéo indisponible. Touchez pour réessayer.', style: sty(12, c: Colors.white))),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ carte de publication

/// Publication du Cercle : angles droits, marges de page respectées (la carte occupe la largeur de la colonne), texte, liens, médias,
/// republication, actions (j'aime, commentaires, republier, partager, enregistrer) et menu à trois points.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, required this.index});
  final Reel post;
  final int index;
  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _more = false;

  void _openReels() {
    ref.read(reelIndexProvider.notifier).set(widget.index < 0 ? 0 : widget.index);
    gOpen(context, '245');
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final now = ref.watch(nowProvider);
    final long = post.caption.length > 160;
    Widget action(Widget icon, String label, VoidCallback onTap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(height: 44, child: Row(mainAxisSize: MainAxisSize.min, children: [icon, if (label.isNotEmpty) ...[const SizedBox(width: 2), Text(label, style: sty(12))], const SizedBox(width: 10)])),
        );
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 0),
          child: Row(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: post.authorId.isEmpty ? null : () => gOpenProfile(context, post.authorId),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                socialAvatar(post.authorAvatar, post.author, 40),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NameWithBadge(name: post.author, verified: post.authorVerified, style: sty(13.5, w: FontWeight.w700)),
                    if (post.publishedAt != null) Text(relativeTime(post.publishedAt!, now), style: sty(11, c: kGrey)),
                  ]),
                ),
              ]),
            ),
            const Spacer(),
            IconButton(onPressed: () => showPostMenu(context, ref, post), tooltip: 'Plus d’options', icon: const Icon(Icons.more_horiz, color: kInk)),
          ]),
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: GestureDetector(
              onTap: long ? () => setState(() => _more = !_more) : null,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: long && !_more ? '${post.caption.substring(0, 160)}… ' : post.caption, style: sty(13, c: const Color(0xFF2A2833), h: 1.45)),
                if (long) TextSpan(text: _more ? ' Réduire' : 'Voir plus', style: sty(12, w: FontWeight.w600, c: kGrey)),
              ])),
            ),
          ),
        if (post.linkUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: GestureDetector(
              onTap: () => openUrl(context, post.linkUrl),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF6F4FA), border: Border.all(color: kLine)),
                child: Row(children: [
                  const Icon(Icons.link, size: 18, color: Color(0xFF5A3FE0)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(post.linkUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(12.5, w: FontWeight.w600, c: const Color(0xFF5A3FE0)))),
                  const Icon(Icons.open_in_new, size: 15, color: kGrey),
                ]),
              ),
            ),
          ),
        if (post.repostId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: kLine), color: const Color(0xFFFAF9FC)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.repeat, size: 14, color: kGrey), const SizedBox(width: 6), Flexible(child: Text(post.repostAuthor, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(12.5, w: FontWeight.w700)))]),
                    if (post.repostCaption.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(post.repostCaption, maxLines: 4, overflow: TextOverflow.ellipsis, style: sty(12.5, c: const Color(0xFF2A2833), h: 1.4))),
                  ]),
                ),
                if (post.repostMediaUrl.isNotEmpty && !post.repostMediaVideo) Padding(padding: const EdgeInsets.only(left: 10), child: SizedBox(width: 64, height: 64, child: Image.network(post.repostMediaUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()))),
              ]),
            ),
          ),
        if (post.allMedia.isNotEmpty)
          Builder(builder: (context) {
            final rx = ref.watch(remixesProvider).value?[post.id];
            final orig = rx == null ? null : ref.watch(originalVideoProvider(rx.of)).value;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (rx != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(rx.kind == 'duet' ? 'Duo${orig == null || orig.author.isEmpty ? '' : ' avec ${orig.author}'}' : 'Remix${orig == null || orig.author.isEmpty ? '' : ' de ${orig.author}'}', style: sty(12, w: FontWeight.w700, c: const Color(0xFF5A3FE0)))),
                if (rx != null && rx.kind == 'duet' && post.allMedia.first.video) DuetView(originalId: rx.of, url: post.allMedia.first.url) else MediaCarousel(media: post.allMedia, onOpenReels: _openReels),
              ]),
            );
          }),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 8, 4),
          child: Row(children: [
            LikeHeart(
              liked: post.liked,
              emoji: kReactions[ref.watch(myReactionsProvider).value?[post.id]],
              onTap: () {
                final k = ref.read(myReactionsProvider).value?[post.id];
                k == null ? toggleLike(context, ref, post) : reactTo(context, ref, post, k);
              },
              onLongPress: () => showReactionPicker(context, ref, post),
              size: 23,
            ),
            Transform.translate(offset: const Offset(-8, 0), child: Padding(padding: const EdgeInsets.only(right: 4), child: Text(compactCount(post.likes), style: sty(12)))),
            action(const Icon(Icons.chat_bubble_outline, size: 21, color: kInk), compactCount(post.comments), () => showCommentsSheet(context, post.id)),
            action(const Icon(Icons.repeat, size: 22, color: kInk), post.reposts == 0 ? '' : compactCount(post.reposts), () => repostPost(context, ref, post)),
            action(const Icon(Icons.ios_share, size: 21, color: kInk), '', () => sharePost(context, ref, post)),
            const Spacer(),
            if (post.listing.isNotEmpty) action(const Icon(Icons.storefront_outlined, size: 21, color: kInk), 'Boutique', () => gOpen(context, '22')),
            action(Icon(post.saved ? Icons.bookmark : Icons.bookmark_border, size: 22, color: kInk), compactCount(post.saves), () => toggleSavePost(context, ref, post)),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ publication complète

/// Nouvelle publication : texte, plusieurs photos ou vidéos (10 au plus), lien, mots-clés avec « # ». Le serveur décide de la
/// validation (immédiate si le compte est certifié, sinon après relecture).
Future<void> publishPost(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'Publication envoyée');
  if (!await requireLogin(context, ref, 'publier') || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ComposerSheet(),
  );
}

class _ComposerSheet extends ConsumerStatefulWidget {
  const _ComposerSheet();
  @override
  ConsumerState<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends ConsumerState<_ComposerSheet> {
  final _text = TextEditingController(), _link = TextEditingController();
  final List<PlatformFile> _files = [];
  DateTime? _at; // publication programmée (jusqu'à 6 mois)
  bool _busy = false;
  String _step = '';

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['mp4', 'mov', 'jpg', 'jpeg', 'png', 'webp', 'gif']);
    if (p.isEmpty || !mounted) return;
    setState(() {
      for (final f in p) {
        _files.add(f);
      }
    });
  }

  static const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  String _fmt(DateTime d) => '${d.day} ${_mois[d.month - 1]} ${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Choix de la date et de l'heure de publication (de dans 5 minutes à 6 mois) ; un second appui annule la programmation.
  Future<void> _pickSchedule() async {
    if (_at != null) return setState(() => _at = null);
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 183)), helpText: 'Date de publication');
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0), helpText: 'Heure de publication');
    if (t == null || !mounted) return;
    final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (at.isBefore(now.add(const Duration(minutes: 2)))) return gToast(context, 'Choisissez une date et une heure à venir.');
    setState(() => _at = at);
  }

  Future<void> _publish() async {
    final txt = _text.text.trim(), link = _link.text.trim();
    if (txt.isEmpty && link.isEmpty && _files.isEmpty) return gToast(context, 'Écrivez un texte ou ajoutez un média ou un lien.');
    if (link.isNotEmpty && !RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(link)) return gToast(context, 'Le lien doit commencer par http:// ou https://');
    setState(() => _busy = true);
    final uploaded = <Map<String, dynamic>>[];
    for (var i = 0; i < _files.length; i++) {
      setState(() => _step = 'Envoi du média ${i + 1} sur ${_files.length}…');
      final up = await uploadPostMedia(context, _files[i]);
      if (!mounted) return;
      if (up == null) {
        if (mounted) setState(() => _busy = false);
        if (uploaded.isNotEmpty) {
          try {
            await Supabase.instance.client.storage.from('post-media').remove([for (final u in uploaded) '${u['path']}']);
          } catch (_) {}
        }
        return;
      }
      if (up.kind == 'video') {
        setState(() => _step = 'Vérification de la vidéo…');
        final err = await videoLimitError(up.path);
        if (err != null) {
          try {
            await Supabase.instance.client.storage.from('post-media').remove([up.path, for (final u in uploaded) '${u['path']}']);
          } catch (_) {}
          if (mounted) {
            setState(() => _busy = false);
            gToast(context, err);
          }
          return;
        }
      }
      uploaded.add({'path': up.path, 'kind': up.kind});
    }
    if (_at != null) {
      setState(() => _step = 'Programmation…');
      final tagsS = [for (final m in RegExp(r'#([\p{L}\p{N}_-]{2,30})', unicode: true).allMatches(txt)) m.group(1)!];
      final r = await Backend.rpc('schedule_post', {'p_caption': txt, 'p_media': uploaded, 'p_link': link.isEmpty ? null : link, 'p_tags': tagsS, 'p_at': _at!.toUtc().toIso8601String()});
      if (!mounted) return;
      if (r.error != null) {
        try {
          if (uploaded.isNotEmpty) await Supabase.instance.client.storage.from('post-media').remove([for (final u in uploaded) '${u['path']}']);
        } catch (_) {}
        setState(() => _busy = false);
        gToast(context, Backend.userMessage(r.error!));
        return;
      }
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final when = _at!;
      nav.pop();
      messenger?.showSnackBar(SnackBar(content: Text('Publication programmée le ${_fmt(when)}'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _step = 'Publication…');
    final tags = [for (final m in RegExp(r'#([\p{L}\p{N}_-]{2,30})', unicode: true).allMatches(txt)) m.group(1)!];
    final res = await Backend.rpc('create_post_v2', {'p_caption': txt, 'p_media': uploaded, 'p_link': link.isEmpty ? null : link, 'p_tags': tags, 'p_listing': null, 'p_repost_of': null});
    if (!mounted) return;
    if (res.error != null) {
      try {
        if (uploaded.isNotEmpty) await Supabase.instance.client.storage.from('post-media').remove([for (final u in uploaded) '${u['path']}']);
      } catch (_) {}
      setState(() => _busy = false);
      if (mounted) gToast(context, Backend.userMessage(res.error!));
      return;
    }
    final st = res.data is Map ? '${(res.data as Map)['status']}' : '';
    await ref.read(reelsProvider.notifier).refresh();
    if (!mounted) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    nav.pop();
    messenger?.showSnackBar(SnackBar(content: Text(st == 'published' ? 'Publication en ligne' : 'Publication envoyée : elle sera visible après validation par le département'), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + (mq.viewInsets.bottom > 0 ? 0 : mq.viewPadding.bottom)),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Nouvelle publication', style: sty(16, w: FontWeight.w700))),
              IconButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ]),
            TextField(controller: _text, minLines: 4, maxLines: 8, maxLength: 2000, enabled: !_busy, style: sty(14), decoration: InputDecoration(hintText: 'Quoi de neuf ? Ajoutez des mots-clés avec #', hintStyle: sty(14, c: kGrey), border: const OutlineInputBorder(), counterText: '')),
            const SizedBox(height: 10),
            TextField(controller: _link, enabled: !_busy, keyboardType: TextInputType.url, style: sty(14), decoration: InputDecoration(prefixIcon: const Icon(Icons.link), hintText: 'Lien (facultatif)', hintStyle: sty(14, c: kGrey), border: const OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            if (_files.isNotEmpty)
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    final isVideo = ['mp4', 'mov'].contains(f.name.split('.').last.toLowerCase());
                    return Stack(children: [
                      Container(width: 74, height: 74, color: const Color(0xFFF1EFF5), alignment: Alignment.center, child: Icon(isVideo ? Icons.videocam_outlined : Icons.image_outlined, color: kGrey)),
                      Positioned(top: 0, right: 0, child: GestureDetector(onTap: _busy ? null : () => setState(() => _files.removeAt(i)), child: Container(color: const Color(0xB3111015), padding: const EdgeInsets.all(3), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                    ]);
                  },
                ),
              ),
            Row(children: [
              TextButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_files.isEmpty ? 'Photos ou vidéos' : 'Ajouter', style: sty(13, w: FontWeight.w600))),
              TextButton(onPressed: _busy ? null : () => showScheduledSheet(context), child: Text('Programmées', style: sty(12.5, c: kGrey))),
              TextButton.icon(onPressed: _busy ? null : _pickSchedule, icon: Icon(_at == null ? Icons.schedule : Icons.event_available, size: 20), label: Text(_at == null ? 'Programmer' : _fmt(_at!), style: sty(13, w: FontWeight.w600))),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _publish,
                style: FilledButton.styleFrom(backgroundColor: kInk, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_at == null ? 'Publier' : 'Programmer', style: sty(14, w: FontWeight.w700, c: Colors.white)),
              ),
            ]),
            if (_busy) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_step, style: sty(12, c: kGrey))),
          ]),
        ),
      ),
    );
  }
}

/// Mes publications programmées : liste des publications en attente, avec annulation.
Future<void> showScheduledSheet(BuildContext context) async {
  final rows = ValueNotifier<List<Map<String, dynamic>>?>(null);
  Future<void> load() async {
    final r = await Backend.rows('scheduled_posts', 'id,caption,publish_at,status,error', order: 'publish_at', ascending: true, limit: 100);
    rows.value = [for (final x in r.rows) if (x['status'] == 'pending' || x['status'] == 'failed') x];
  }

  load();
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: ValueListenableBuilder<List<Map<String, dynamic>>?>(
        valueListenable: rows,
        builder: (ctx, list, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Publications programmées', style: sty(17, w: FontWeight.w800)),
          const SizedBox(height: 10),
          if (list == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Aucune publication programmée.', style: sty(13, c: kGrey)))
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final x in list)
                  Builder(builder: (_) {
                    final d = DateTime.tryParse('${x['publish_at']}')?.toLocal();
                    final failed = x['status'] == 'failed';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${x['caption']}'.isEmpty ? '(sans texte)' : '${x['caption']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: sty(13.5, w: FontWeight.w600)),
                      subtitle: Text(failed ? 'Échec : ${x['error'] ?? 'publication refusée'}' : (d == null ? '' : '${d.day} ${mois[d.month - 1]} ${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'), style: sty(12, c: failed ? kLike : kGrey)),
                      trailing: failed ? null : IconButton(tooltip: 'Annuler', icon: const Icon(Icons.delete_outline), onPressed: () async {
                        final r = await Backend.rpc('cancel_scheduled_post', {'p_id': x['id']});
                        if (r.error != null && ctx.mounted) gToast(ctx, Backend.userMessage(r.error!));
                        await load();
                      }),
                    );
                  }),
              ]),
            ),
        ]),
      ),
    ),
  );
  rows.dispose();
}
