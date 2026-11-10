import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nav.dart';
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
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), border: Border.all(color: const Color(0xFFECE8F2))),
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
class FeaturedVideo extends ConsumerWidget {
  const FeaturedVideo({super.key, required this.slot});
  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final all = ref.watch(reelsProvider) ?? const <Reel>[];
    final mine = [for (final r in all) if (r.video && me.isNotEmpty && r.authorId == me) r];
    final v = slot < mine.length ? mine[slot] : null;
    const radius = BorderRadius.all(Radius.circular(26));
    if (v == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => publishPost(context, ref),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: radius, border: Border.all(color: const Color(0xCCFFFFFF), width: 1.2)),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_circle_outline, size: 30, color: _grey),
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Vidéo phare', textAlign: TextAlign.center, style: _st(12, c: _grey))),
          ]),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(reelIndexProvider.notifier).set(all.indexWhere((r) => r.id == v.id).clamp(0, all.length - 1));
        gOpen(context, '245');
      },
      child: Container(
        decoration: const BoxDecoration(borderRadius: radius, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2833), Color(0xFF0E0F14)])),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
          if (v.caption.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(v.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11, c: Colors.white))),
        ]),
      ),
    );
  }
}
