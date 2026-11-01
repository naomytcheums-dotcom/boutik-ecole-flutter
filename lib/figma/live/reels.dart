import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'talents.dart' show askText;

/// Reels et défis (migration 20261101000600, règles § 2.1 et § 4). Avec le serveur : vraies publications, vrais points ;
/// rien n'est inventé. Hors serveur : maquette inchangée.

class Reel {
  const Reel({required this.id, required this.author, required this.caption, required this.mediaUrl, required this.video, this.likes = 0, this.liked = false, this.listing = ''});
  final String id, author, caption, mediaUrl, listing;
  final bool video, liked;
  final int likes;
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

    state = [
      for (final x in r.data as List)
        Reel(
          id: '${(x as Map)['id']}',
          author: '${x['author']}',
          caption: '${x['caption'] ?? ''}',
          mediaUrl: url('${x['media_path']}'),
          video: x['media_kind'] == 'video',
          likes: (x['likes'] as num?)?.toInt() ?? 0,
          liked: x['liked'] == true,
          listing: '${x['listing_title'] ?? ''}',
        ),
    ];
  }
}

final reelsProvider = NotifierProvider<ReelsNotifier, List<Reel>?>(ReelsNotifier.new);

/// Reel affiché (le premier du fil) ; null : aucun reel publié.
final currentReelProvider = Provider<Reel?>((ref) {
  final l = ref.watch(reelsProvider);
  return (l == null || l.isEmpty) ? null : l.first;
});

Future<void> likeCurrentReel(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  if (!await requireLogin(context, ref, 'aimer une publication') || !context.mounted) return;
  final res = await Backend.rpc('toggle_post_like', {'p_post': r.id});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Action impossible', res.error!);
  await ref.read(reelsProvider.notifier).refresh();
}

Future<void> reportCurrentReel(BuildContext context, WidgetRef ref) async {
  final r = ref.read(currentReelProvider);
  if (r == null) return;
  if (!await requireLogin(context, ref, 'signaler une publication') || !context.mounted) return;
  final why = await askText(context, title: 'Signaler', body: 'Pourquoi cette publication pose-t-elle problème ?', hint: 'Contenu trompeur…', ok: 'Signaler', min: 3);
  if (why == null || !context.mounted) return;
  final res = await Backend.rpc('report_post', {'p_post': r.id, 'p_reason': why});
  if (context.mounted) res.error != null ? gAlert(context, 'Signalement impossible', res.error!) : gToast(context, 'Signalement transmis à la modération');
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
