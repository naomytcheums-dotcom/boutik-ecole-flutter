import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/feed_ranker.dart';
import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'talents.dart' show askText;

/// Reels et défis (migration 20261101000600, règles § 2.1 et § 4). Avec le serveur : vraies publications, vrais points ;
/// rien n'est inventé. Hors serveur : maquette inchangée.

/// Un média d'une publication (photo ou vidéo), avec ses proportions quand elles sont connues.
class ReelMedia {
  const ReelMedia({required this.url, required this.video, this.width, this.height});
  final String url;
  final bool video;
  final int? width, height;

  /// Largeur / hauteur ; null si inconnues.
  double? get ratio => (width != null && height != null && width! > 0 && height! > 0) ? width! / height! : null;
}

class Reel {
  const Reel({
    required this.id,
    required this.author,
    required this.caption,
    required this.mediaUrl,
    required this.video,
    this.likes = 0,
    this.liked = false,
    this.listing = '',
    this.authorId = '',
    this.comments = 0,
    this.saves = 0,
    this.shares = 0,
    this.saved = false,
    this.boosted = false,
    this.tags = const [],
    this.publishedAt,
    this.authorAvatar = '',
    this.authorVerified = false,
    this.linkUrl = '',
    this.reposts = 0,
    this.media = const [],
    this.repostId = '',
    this.repostAuthor = '',
    this.repostCaption = '',
    this.repostMediaUrl = '',
    this.repostMediaVideo = false,
  });
  final String id, author, caption, mediaUrl, listing, authorId, authorAvatar, linkUrl, repostId, repostAuthor, repostCaption, repostMediaUrl;
  final bool video, liked, saved, boosted, authorVerified, repostMediaVideo;
  final int likes, comments, saves, shares, reposts;
  final List<String> tags;
  final List<ReelMedia> media;
  final DateTime? publishedAt;

  /// Publication avec au moins un média (photo ou vidéo) : seules celles-ci s'ouvrent dans l'écran Reels.
  bool get hasMedia => media.isNotEmpty || mediaUrl.isNotEmpty;

  /// Tous les médias, dans l'ordre ; à défaut de liste détaillée, le média principal.
  List<ReelMedia> get allMedia => media.isNotEmpty ? media : (mediaUrl.isEmpty ? const [] : [ReelMedia(url: mediaUrl, video: video)]);

  Reel copyWith({bool? liked, int? likes, bool? saved, int? saves, int? comments, int? shares, int? reposts}) => Reel(
        id: id, author: author, caption: caption, mediaUrl: mediaUrl, video: video, likes: likes ?? this.likes, liked: liked ?? this.liked,
        listing: listing, authorId: authorId, comments: comments ?? this.comments, saves: saves ?? this.saves, shares: shares ?? this.shares,
        saved: saved ?? this.saved, boosted: boosted, tags: tags, publishedAt: publishedAt, authorAvatar: authorAvatar, authorVerified: authorVerified,
        linkUrl: linkUrl, reposts: reposts ?? this.reposts, media: media, repostId: repostId, repostAuthor: repostAuthor, repostCaption: repostCaption,
        repostMediaUrl: repostMediaUrl, repostMediaVideo: repostMediaVideo,
      );

  /// Compteurs lus sur le serveur. Les champs absents (serveur non migré) valent 0 : rien n'est inventé.
  /// Le badge « certifié » n'est affiché que si le serveur le confirme (`author_verified`).
  static Reel fromRow(Map x, String Function(String) url) => Reel(
        id: '${x['id']}',
        author: '${x['author']}',
        caption: '${x['caption'] ?? ''}',
        mediaUrl: (x['media_path'] == null || '${x['media_path']}'.isEmpty) ? '' : url('${x['media_path']}'),
        video: x['media_kind'] == 'video',
        likes: (x['likes'] as num?)?.toInt() ?? 0,
        liked: x['liked'] == true,
        listing: '${x['listing_title'] ?? ''}',
        authorId: '${x['author_id'] ?? ''}',
        comments: (x['comments'] as num?)?.toInt() ?? 0,
        saves: (x['saves'] as num?)?.toInt() ?? 0,
        shares: (x['shares'] as num?)?.toInt() ?? 0,
        saved: x['saved'] == true,
        boosted: x['boosted'] == true,
        tags: [for (final t in (x['tags'] as List? ?? const [])) '$t'],
        publishedAt: DateTime.tryParse('${x['published_at'] ?? ''}'),
        authorAvatar: '${x['author_avatar'] ?? ''}',
        authorVerified: x['author_verified'] == true,
        linkUrl: '${x['link_url'] ?? ''}',
        reposts: (x['reposts'] as num?)?.toInt() ?? 0,
        media: [
          for (final m in (x['media'] as List? ?? const []))
            if (m is Map && '${m['path'] ?? ''}'.isNotEmpty) ReelMedia(url: url('${m['path']}'), video: m['kind'] == 'video', width: (m['w'] as num?)?.toInt(), height: (m['h'] as num?)?.toInt()),
        ],
        repostId: '${x['repost_id'] ?? ''}',
        repostAuthor: '${x['repost_author'] ?? ''}',
        repostCaption: '${x['repost_caption'] ?? ''}',
        repostMediaUrl: (x['repost_media_path'] == null || '${x['repost_media_path']}'.isEmpty) ? '' : url('${x['repost_media_path']}'),
        repostMediaVideo: x['repost_media_kind'] == 'video',
      );
}

/// Ordre du fil : les publications dont la visibilité a été gagnée (boost) d'abord, puis le classement du moteur
/// (fraîcheur, intérêt, qualité, popularité plafonnée, diversité d'auteurs). `signals` vient des abonnements, masquages et
/// intérêts réels de la personne ; sans signal, le classement repose sur la fraîcheur, la qualité et la popularité plafonnée.
List<Reel> rankReels(List<Reel> reels, DateTime now, {FeedSignals signals = const FeedSignals(), FeedMode mode = FeedMode.pourToi, FeedRanker ranker = const FeedRanker()}) {
  final byId = {for (final r in reels) r.id: r};
  FeedItem item(Reel r) => FeedItem(
        id: r.id,
        authorId: r.authorId.isEmpty ? r.author : r.authorId,
        createdAt: r.publishedAt ?? now,
        category: r.tags.isEmpty ? '' : r.tags.first.toLowerCase(),
        format: r.video ? 'video' : (r.hasMedia ? 'image' : 'text'),
        likes: r.likes,
        comments: r.comments,
        saves: r.saves,
        shares: r.shares,
        // qualité : légende renseignée, mots-clés, lien vers une annonce ; jamais déduite des mentions j'aime
        quality: (0.3 + (r.caption.trim().length >= 20 ? 0.3 : 0) + (r.tags.isNotEmpty ? 0.2 : 0) + (r.listing.isNotEmpty ? 0.2 : 0)).clamp(0.0, 1.0),
      );
  final ranked = [for (final x in ranker.rank([for (final r in reels) item(r)], signals, now, mode: mode, limit: reels.length)) byId[x.item.id]!];
  final boosted = [for (final r in ranked) if (r.boosted) r];
  return [...boosted, for (final r in ranked) if (!r.boosted) r];
}

String compactCount(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')} k' : '$n';

class ReelsNotifier extends Notifier<List<Reel>?> {
  /// Met à jour une publication du fil sans le recharger (cœur, enregistrement : réponse immédiate).
  void patch(String id, Reel Function(Reel) change) {
    final l = state;
    if (l == null) return;
    state = [for (final r in l) r.id == id ? change(r) : r];
  }

  /// Ajoute une publication absente du fil (ouverte depuis un profil) pour qu'elle s'affiche dans l'écran Reels.
  void ensure(Reel r) {
    final l = state ?? const <Reel>[];
    if (l.any((x) => x.id == r.id)) return;
    state = [...l, r];
  }

  @override
  List<Reel>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    // publie d'abord les publications programmées arrivées à échéance (sans attendre la minute suivante du planificateur)
    if (ref.read(authProvider).current != null) await Backend.rpc('publish_due_posts', const {});
    var r = await Backend.rpc('circle_feed', {'p_limit': 30});
    // serveur pas encore migré (migration 20261110000000) : repli sur l'ancien fil de médias
    if (r.error != null || r.data is! List) r = await Backend.rpc('reels_feed', {'p_limit': 20});
    if (r.error != null || r.data is! List || !ref.mounted) return;
    String url(String p) {
      try {
        return Supabase.instance.client.storage.from('post-media').getPublicUrl(p);
      } catch (_) {
        return '';
      }
    }

    final reels = [for (final x in r.data as List) Reel.fromRow(x as Map, url)];
    // signaux réels de la personne : créateurs suivis, centres d'intérêt et affinités déduits de ce qu'elle a aimé ou enregistré
    final following = ref.read(followingIdsProvider) ?? const <String>{};
    final interests = <String, double>{}, affinity = <String, double>{};
    for (final r in reels) {
      if (!(r.liked || r.saved)) continue;
      for (final t in r.tags) {
        final k = t.toLowerCase();
        interests[k] = ((interests[k] ?? 0) + 0.25).clamp(0.0, 1.0);
      }
      if (r.authorId.isNotEmpty) affinity[r.authorId] = ((affinity[r.authorId] ?? 0) + 0.3).clamp(0.0, 1.0);
    }
    state = rankReels(reels, DateTime.now(), signals: FeedSignals(followed: following, interests: interests, affinity: affinity));
    ref.read(reelIndexProvider.notifier).clamp(reels.length);
  }
}

final reelsProvider = NotifierProvider<ReelsNotifier, List<Reel>?>(ReelsNotifier.new);

/// Position du reel affiché dans le fil (balayage vertical de l'écran 245).
class ReelIndex extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v < 0 ? 0 : v;
  void clamp(int length) {
    if (length > 0 && state >= length) state = length - 1;
  }
}

final reelIndexProvider = NotifierProvider<ReelIndex, int>(ReelIndex.new);

/// Reel affiché ; null : aucun reel publié.
final currentReelProvider = Provider<Reel?>((ref) {
  final l = ref.watch(reelsProvider);
  if (l == null || l.isEmpty) return null;
  final i = ref.watch(reelIndexProvider);
  return l[i < l.length ? i : l.length - 1];
});

/// Balayage : `delta` = +1 reel suivant, -1 reel précédent (borné au fil).
void moveReel(WidgetRef ref, int delta) {
  final list = ref.read(reelsProvider) ?? const <Reel>[];
  if (list.isEmpty) return;
  final i = ref.read(reelIndexProvider);
  final step = delta >= 0 ? 1 : -1;
  var j = i + step;
  // les publications sans média (texte seul) ne s'ouvrent pas dans les Reels : on les saute
  if (list.any((r) => r.hasMedia)) {
    while (j >= 0 && j < list.length && !list[j].hasMedia) {
      j += step;
    }
  }
  if (j < 0 || j >= list.length) return;
  ref.read(reelIndexProvider.notifier).set(j);
}

/// Personnes suivies par la personne connectée (`engagements` de type `follow`), lues sur le serveur.
/// `null` : lecture en cours (l'onglet « Abonnements » attend) ; ensemble vide : aucun abonnement.
class FollowingIdsNotifier extends Notifier<Set<String>?> {
  @override
  Set<String>? build() {
    if (!Backend.ready) return null;
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isEmpty) return const {};
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final rows = await Backend.myEngagements(kind: 'follow');
    if (!ref.mounted) return;
    state = {for (final e in rows) if (e['status'] == 'active') '${e['ref']}'};
  }
}

final followingIdsProvider = NotifierProvider<FollowingIdsNotifier, Set<String>?>(FollowingIdsNotifier.new);

/// « S'abonner » : suit (ou ne suit plus) l'auteur du reel affiché, par le mécanisme d'engagements existant (`follow`).
Future<void> toggleFollowReelAuthor(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  if (!await requireLogin(context, ref, 'suivre un créateur') || !context.mounted) return;
  if (r.authorId.isEmpty) return gAlert(context, 'S’abonner', 'Ce créateur ne peut pas être suivi pour le moment.');
  if (r.authorId == ref.read(authProvider).current?.serverId) return gToast(context, 'C’est votre publication.');
  final err = await Backend.engage('follow', r.authorId, const {});
  if (!context.mounted) return;
  if (err == null) {
    ref.invalidate(followingIdsProvider);
    return gToast(context, 'Vous suivez ${r.author}');
  }
  if (err.contains('Déjà')) {
    final e2 = await Backend.cancelEngagement('follow', r.authorId);
    if (!context.mounted) return;
    if (e2 == null) ref.invalidate(followingIdsProvider);
    return e2 == null ? gToast(context, 'Vous ne suivez plus ${r.author}') : gAlert(context, 'Action impossible', Backend.userMessage(e2));
  }
  gAlert(context, 'Action impossible', Backend.userMessage(err));
}

/// Enregistrer ou retirer la publication affichée.
Future<void> saveCurrentReel(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  if (!await requireLogin(context, ref, 'enregistrer une publication') || !context.mounted) return;
  final res = await Backend.rpc('toggle_post_save', {'p_post': r.id});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(res.error!));
  await ref.read(reelsProvider.notifier).refresh();
  if (context.mounted) gToast(context, res.data == true ? 'Publication enregistrée' : 'Publication retirée de vos enregistrements');
}

/// Déclare un partage (compté une fois par personne connectée) ; l'envoi du lien lui-même est fait par l'appelant.
Future<void> recordReelShare(WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  await Backend.rpc('record_post_share', {'p_post': r.id});
  await ref.read(reelsProvider.notifier).refresh();
}

/// Libellé du temps écoulé : « à l'instant », « 5 min », « 2 h », « 3 j », puis la date.
String relativeTime(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'à l’instant';
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  if (d.inDays < 7) return '${d.inDays} j';
  return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
}

class ReelComment {
  const ReelComment({required this.id, required this.author, required this.body, required this.mine, required this.createdAt});
  final String id, author, body;
  final bool mine;
  final DateTime createdAt;

  static ReelComment fromRow(Map x) => ReelComment(
        id: '${x['id']}',
        author: '${x['author']}',
        body: '${x['body']}',
        mine: x['mine'] == true,
        createdAt: DateTime.tryParse('${x['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Commentaires du reel affiché. `null` : lecture en cours ; en cas d'échec, `commentsErrorProvider` porte un message lisible.
class ReelCommentsNotifier extends Notifier<List<ReelComment>?> {
  @override
  List<ReelComment>? build() => null;

  Future<void> load() async {
    final r = ref.read(currentReelProvider);
    if (r == null) {
      state = const [];
      return;
    }
    final res = await Backend.rpc('post_comment_list', {'p_post': r.id, 'p_limit': 100});
    if (!ref.mounted) return;
    if (res.error != null || res.data is! List) {
      ref.read(commentsErrorProvider.notifier).set('Les commentaires ne peuvent pas être chargés pour le moment.');
      state = const [];
      return;
    }
    ref.read(commentsErrorProvider.notifier).set('');
    state = [for (final x in res.data as List) ReelComment.fromRow(x as Map)];
  }
}

final reelCommentsProvider = NotifierProvider<ReelCommentsNotifier, List<ReelComment>?>(ReelCommentsNotifier.new);

class ReelsMessage extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final commentsErrorProvider = NotifierProvider<ReelsMessage, String>(ReelsMessage.new);

/// 252 : saisie puis dépôt d'un commentaire sur le reel affiché.
Future<void> addReelComment(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return gAlert(context, 'Commenter', 'Aucune publication à commenter.');
  if (!await requireLogin(context, ref, 'commenter') || !context.mounted) return;
  final text = await askText(context, title: 'Commenter', body: 'Votre commentaire (500 caractères au plus).', hint: 'Écrivez votre commentaire…', ok: 'Publier', min: 1);
  if (text == null || !context.mounted) return;
  final res = await Backend.rpc('add_post_comment', {'p_post': r.id, 'p_body': text.trim(), 'p_parent': null});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Commentaire refusé', Backend.userMessage(res.error!));
  await ref.read(reelCommentsProvider.notifier).load();
  await ref.read(reelsProvider.notifier).refresh();
}

Future<void> deleteReelComment(BuildContext context, WidgetRef ref, String id) async {
  final res = await Backend.rpc('delete_post_comment', {'p_comment': id});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Suppression impossible', Backend.userMessage(res.error!));
  await ref.read(reelCommentsProvider.notifier).load();
  await ref.read(reelsProvider.notifier).refresh();
}

/// Cœur : un appui enregistre ou retire la réaction, tout de suite (mise à jour optimiste), sans jamais quitter l'écran.
/// Sans compte, un message bref explique comment réagir : aucune redirection. Si le serveur refuse, l'état précédent est rétabli.
Future<void> toggleLike(BuildContext context, WidgetRef ref, Reel r) async {
  if (!Backend.ready) {
    ref.read(reelsProvider.notifier).patch(r.id, (x) => x.copyWith(liked: !x.liked, likes: x.liked ? (x.likes - 1).clamp(0, 1 << 30) : x.likes + 1));
    return;
  }
  if (ref.read(authProvider).current == null) return gToast(context, 'Connectez-vous pour réagir à une publication.');
  final before = ref.read(reelsProvider)?.where((x) => x.id == r.id).firstOrNull ?? r;
  final nowLiked = !before.liked;
  ref.read(reelsProvider.notifier).patch(r.id, (x) => x.copyWith(liked: nowLiked, likes: nowLiked ? x.likes + 1 : (x.likes - 1).clamp(0, 1 << 30)));
  final res = await Backend.rpc('toggle_post_like', {'p_post': r.id});
  if (res.error != null) {
    ref.read(reelsProvider.notifier).patch(r.id, (x) => x.copyWith(liked: before.liked, likes: before.likes));
    if (context.mounted) gToast(context, Backend.userMessage(res.error!));
  } else if (res.data is bool && res.data != nowLiked) {
    ref.read(reelsProvider.notifier).patch(r.id, (x) => x.copyWith(liked: res.data as bool));
  }
}

Future<void> likeCurrentReel(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  await toggleLike(context, ref, r);
}

Future<void> reportCurrentReel(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  if (!await requireLogin(context, ref, 'signaler une publication') || !context.mounted) return;
  final why = await askText(context, title: 'Signaler', body: 'Pourquoi cette publication pose-t-elle problème ?', hint: 'Contenu trompeur…', ok: 'Signaler', min: 3);
  if (why == null || !context.mounted) return;
  final res = await Backend.rpc('report_post', {'p_post': r.id, 'p_reason': why});
  if (context.mounted) res.error != null ? gAlert(context, 'Signalement impossible', Backend.userMessage(res.error!)) : gToast(context, 'Signalement transmis à la modération');
}

/// 250 « Publier » : choix d'une vidéo (60 s, 50 Mo, MP4/MOV) ou d'une image, légende, dépôt dans son dossier, puis create_post.
Future<void> publishReel(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'Publication envoyée');
  if (!await requireCertified(context, ref, 'publier') || !context.mounted) return;
  final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['mp4', 'mov', 'jpg', 'jpeg', 'png', 'webp']);
  if (picked.isEmpty || !context.mounted) return;
  final f = picked.first;
  final ext = f.name.split('.').last.toLowerCase();
  final mime = const {'mp4': 'video/mp4', 'mov': 'video/quicktime', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'}[ext];
  if (mime == null) return gAlert(context, 'Format refusé', 'Vidéo MP4 ou MOV, ou image JPG, PNG, WebP.');
  final bytes = await f.readAsBytes();
  if (!context.mounted) return;
  if (bytes.length > 50 * 1024 * 1024) return gAlert(context, 'Fichier trop lourd', '50 Mo au maximum (vidéo de 60 secondes au plus).');
  final caption = await askText(context, title: 'Légende', body: 'Décrivez votre publication (300 caractères au plus). Ajoutez des mots-clés avec # .', hint: 'Pose d’un kit solaire… #énergie', ok: 'Publier', min: 0);
  if (caption == null || !context.mounted) return;
  final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
  final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
  try {
    await Supabase.instance.client.storage.from('post-media').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
  } catch (_) {
    if (context.mounted) await gAlert(context, 'Envoi impossible', 'Le média n’a pas pu être déposé. Vérifiez votre connexion et réessayez.');
    return;
  }
  final tags = [for (final m in RegExp(r'#([\p{L}\p{N}_-]{2,30})', unicode: true).allMatches(caption)) m.group(1)!];
  final res = await Backend.rpc('create_post', {'p_media_path': path, 'p_media_kind': mime.startsWith('video') ? 'video' : 'image', 'p_caption': caption.trim(), 'p_tags': tags, 'p_listing': null});
  if (!context.mounted) return;
  if (res.error != null) {
    try {
      await Supabase.instance.client.storage.from('post-media').remove([path]);
    } catch (_) {}
    if (context.mounted) await gAlert(context, 'Publication refusée', res.error!);
    return;
  }
  final st = (res.data is Map) ? '${(res.data as Map)['status']}' : '';
  await ref.read(reelsProvider.notifier).refresh();
  if (context.mounted) gToast(context, st == 'published' ? 'Publication en ligne' : 'Publication envoyée : elle sera visible après validation par le département');
}

// ------------------------------------------------------------------ défis (253)

class Challenges {
  const Challenges({this.streak = 0, this.nextIn = 6, this.streakClaimable = false, this.weekEndDays = 0, this.postsWeek = 0, this.postsClaimable = false, this.points = 0});
  final int streak, nextIn, weekEndDays, postsWeek, points;
  final bool streakClaimable, postsClaimable;

  factory Challenges.fromJson(Map<String, dynamic> j) => Challenges(
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        nextIn: (j['next_reward_in'] as num?)?.toInt() ?? 6,
        streakClaimable: j['streak_reward_claimable'] == true,
        weekEndDays: (j['week_end_days'] as num?)?.toInt() ?? 0,
        postsWeek: (j['posts_week'] as num?)?.toInt() ?? 0,
        postsClaimable: j['posts_claimable'] == true,
        points: (j['points'] as num?)?.toInt() ?? 0,
      );

  String get streakLabel => 'Série de $streak jour${streak > 1 ? 's' : ''}';
  String get nextLabel => streakClaimable
      ? 'Série de 6 jours atteinte : récupérez votre boost de 24 h'
      : (nextIn <= 0 ? 'Boost du jour déjà récupéré' : 'Encore $nextIn jour${nextIn > 1 ? 's' : ''} pour gagner un boost de 24 h');
}

class ChallengesNotifier extends Notifier<Challenges?> {
  @override
  Challenges? build() {
    if (!Backend.ready) return null;
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) Future.microtask(refresh);
    return null;
  }

  /// La visite de l'écran compte comme présence du jour (une fois par jour, côté serveur).
  Future<void> refresh() async {
    await Backend.rpc('daily_checkin', const {});
    final r = await Backend.rpc('my_challenges', const {});
    if (r.error == null && r.data is Map && ref.mounted) state = Challenges.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final challengesProvider = NotifierProvider<ChallengesNotifier, Challenges?>(ChallengesNotifier.new);

/// 253 « Récupérer » : boost de série (6 jours) ou, à défaut, défi « 3 publications » ; le serveur décide.
Future<void> claimReward(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return;
  if (!await requireLogin(context, ref, 'récupérer une récompense') || !context.mounted) return;
  final c = ref.read(challengesProvider);
  final fn = (c?.streakClaimable ?? false) ? 'claim_streak_boost' : 'claim_challenge';
  final res = await Backend.rpc(fn, fn == 'claim_challenge' ? {'p_code': 'posts3'} : const {});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Récompense indisponible', res.error!);
  await ref.read(challengesProvider.notifier).refresh();
  if (context.mounted) gToast(context, fn == 'claim_streak_boost' ? 'Boost de 24 h activé sur votre dernière publication' : '+200 points ajoutés');
}

/// Fond du reel affiché (écran 245) : le média de la publication quand c'est une image qui se charge, sinon un fond neutre.
/// Jamais la photo de la maquette avec une vraie publication.
class ReelBackdrop extends ConsumerWidget {
  const ReelBackdrop({super.key});

  static const _neutral = DecoratedBox(
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B2740), Color(0xFF15131F)])),
    child: SizedBox.expand(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(currentReelProvider);
    if (r == null || r.video || r.mediaUrl.isEmpty) return _neutral;
    return Image.network(r.mediaUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => _neutral, loadingBuilder: (_, child, p) => p == null ? child : _neutral);
  }
}
