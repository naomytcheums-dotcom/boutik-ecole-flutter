import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert;
import '../nav.dart';
import 'backend.dart';
import 'auth.dart';
import 'premium_pub.dart';
import 'reels.dart';
import 'social_posts.dart';

/// Fil du réseau social (écran 244), connecté au serveur : publications réelles, j'aime, enregistrement, commentaires, publication
/// d'une photo ou d'une vidéo, et filtres. Aucune publication de maquette n'est affichée ; sans publication, un état vide explicite.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class CircleTab extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

/// Onglet choisi : 0 Pour toi · 1 Abonnements · 2 Vidéos · 3 Boutique · autres : tout.
final circleTabProvider = NotifierProvider<CircleTab, int>(CircleTab.new);

/// Publications visibles selon l'onglet. « Abonnements » ne garde que les auteurs réellement suivis
/// (`engagements.follow`) ; `following` vaut null tant que la liste n'est pas lue.
List<Reel> filterCircle(List<Reel> all, int tab, {Set<String>? following}) => switch (tab) {
      1 => [for (final r in all) if (following?.contains(r.authorId) ?? false) r],
      2 => [for (final r in all) if (r.video) r],
      3 => [for (final r in all) if (r.listing.isNotEmpty) r],
      _ => all,
    };

class CircleFeed extends ConsumerWidget {
  const CircleFeed({super.key, this.width = 350, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(reelsProvider);
    final tab = ref.watch(circleTabProvider);
    final following = ref.watch(followingIdsProvider);
    Widget note(String t, {String? action, VoidCallback? onTap}) => Container(
          width: width,
          height: 260,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11), decoration: const BoxDecoration(color: _ink), child: Text(action, style: _st(13, w: FontWeight.w600, c: Colors.white))),
              ),
            ],
          ]),
        );
    if (all == null) return note('Chargement des publications…');
    if (tab == 1 && following == null) return note('Chargement des abonnements…');
    final list = filterCircle(all, tab, following: following);
    if (list.isEmpty) {
      if (tab == 1) {
        return note(following!.isEmpty ? 'Vous ne suivez personne pour le moment.\nSuivez un créateur pour retrouver ses publications ici.' : 'Aucune publication récente des créateurs que vous suivez.', action: 'Découvrir', onTap: () => gOpen(context, '251'));
      }
      return note(all.isEmpty ? 'Aucune publication pour le moment.\nSoyez le premier à partager une photo ou une vidéo.' : 'Aucune publication dans cette catégorie.', action: 'Publier', onTap: () => publishPost(context, ref));
    }
    // publicités validées, toujours marquées « Sponsorisé » : une après la 2e publication, une après la 5e
    final ads = tab == 0 ? ref.watch(adFeedProvider) : const <Map<String, dynamic>>[];
    final items = <Object>[];
    for (var k = 0; k < list.length; k++) {
      items.add(list[k]);
      if (k == 1 && ads.isNotEmpty) items.add(ads[0]);
      if (k == 4 && ads.length > 1) items.add(ads[1]);
    }
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          if (i == 0) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => publishPost(context, ref),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _ink),
                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.add, color: Colors.white, size: 20), const SizedBox(width: 6), Text('Nouvelle publication', style: _st(13, w: FontWeight.w600, c: Colors.white))]),
              ),
            );
          }
          final it = items[i - 1];
          if (it is Map<String, dynamic>) return SponsoredCard(key: ValueKey('ad-${it['id']}'), ad: it);
          final post = it as Reel;
          return PostCard(key: ValueKey('post-${post.id}'), post: post, index: all.indexWhere((r) => r.id == post.id));
        },
      ),
    );
  }
}

/// Les trois vidéos phares du profil (écran 10, derrière la photo) : les trois dernières vidéos publiées par la personne connectée.
/// Un emplacement libre invite à publier une vidéo ; rien n'est inventé.
/// Ajoute une photo ou une vidéo à la couverture du profil : ouvre directement la galerie ou le sélecteur de fichiers, sans texte ni lien.
Future<void> _addCover(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return;
  if (!await requireLogin(context, ref, 'ajouter une couverture') || !context.mounted) return;
  final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov']);
  if (p.isEmpty || !context.mounted) return;
  final up = await uploadPostMedia(context, p.first);
  if (up == null || !context.mounted) return;
  final res = await Backend.rpc('create_post_v2', {'p_caption': '', 'p_media': [{'path': up.path, 'kind': up.kind}], 'p_link': null, 'p_tags': const <String>[], 'p_listing': null, 'p_repost_of': null});
  if (!context.mounted) return;
  if (res.error != null) return gAlert(context, 'Ajout impossible', Backend.userMessage(res.error!));
  await ref.read(reelsProvider.notifier).refresh();
}

class FeaturedVideo extends ConsumerWidget {
  const FeaturedVideo({super.key, required this.slot});
  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final all = ref.watch(reelsProvider) ?? const <Reel>[];
    final mine = [for (final r in all) if (r.mediaUrl.isNotEmpty && me.isNotEmpty && r.authorId == me) r];
    final v = slot < mine.length ? mine[slot] : null;
    const radius = BorderRadius.all(Radius.circular(26));
    if (v == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _addCover(context, ref),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: radius, border: Border.all(color: const Color(0xCCFFFFFF), width: 1.2)),
          alignment: Alignment.center,
          child: const Icon(Icons.add_circle_outline, size: 34, color: _grey, semanticLabel: 'Ajouter une photo ou une vidéo'),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(reelIndexProvider.notifier).set(all.indexWhere((r) => r.id == v.id).clamp(0, all.length - 1));
        gOpen(context, '245');
      },
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(fit: StackFit.expand, children: [
          if (v.video)
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2833), Color(0xFF0E0F14)])))
          else
            Image.network(v.mediaUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEDE9F6))),
          if (v.video) const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
        ]),
      ),
    );
  }
}
