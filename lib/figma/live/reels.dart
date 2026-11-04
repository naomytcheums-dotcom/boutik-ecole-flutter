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
  });
  final String id, author, caption, mediaUrl, listing, authorId;
  final bool video, liked, saved, boosted;
  final int likes, comments, saves, shares;
  final List<String> tags;
  final DateTime? publishedAt;

  /// Compteurs lus sur le serveur. Les champs absents (serveur non migré) valent 0 : rien n'est inventé.
  static Reel fromRow(Map x, String Function(String) url) => Reel(
        id: '${x['id']}',
        author: '${x['author']}',
        caption: '${x['caption'] ?? ''}',
        mediaUrl: url('${x['media_path']}'),
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
        format: r.video ? 'video' : 'image',
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
  @override
  List<Reel>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('reels_feed', {'p_limit': 20});
    if (r.error != null || r.data is! List || !ref.mounted) return;
    String url(String p) {
      try {
        return Supabase.instance.client.storage.from('post-media').getPublicUrl(p);
      } catch (_) {
        return '';
      }
    }

    final reels = [for (final x in r.data as List) Reel.fromRow(x as Map, url)];
    state = rankReels(reels, DateTime.now());
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
  final n = ref.read(reelsProvider)?.length ?? 0;
  if (n == 0) return;
  ref.read(reelIndexProvider.notifier).set((ref.read(reelIndexProvider) + delta).clamp(0, n - 1));
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

Future<void> likeCurrentReel(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  if (!await requireLogin(context, ref, 'aimer une publication') || !context.mounted) return;
  final res = await Backend.rpc('toggle_post_like', {'p_post': r.id});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(res.error!));
  await ref.read(reelsProvider.notifier).refresh();
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
  if (!await requireLogin(context, ref, 'publier') || !context.mounted) return;
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
