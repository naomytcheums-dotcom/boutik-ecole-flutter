import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import '../nav.dart' show gBack, gOpen;
import 'auth.dart';
import 'marche/marche_data.dart' show kGrey, kInk, kViolet, mst;
import 'social_posts.dart' show PostComposerBody;
import 'tp_ui.dart' show TpRound;

/// Écran 250 « Nouvelle publication » en service réel : le même décor que la maquette (fond dégradé, croix, titre, quatre choix avec leur
/// icône), avec un vrai formulaire (texte, photos ou vidéos, lien, programmation) à la place de l'exemple figé. Chaque bouton agit.
class PublishPage extends ConsumerStatefulWidget {
  const PublishPage({super.key});

  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  String _kind = 'post';

  Widget _chip(String id, IconData icon, String label, VoidCallback onTap) {
    final on = _kind == id;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: on ? kInk : Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: on ? kInk : const Color(0xFFE6E2EE))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: on ? Colors.white : kInk),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, style: mst(11, w: FontWeight.w700, c: on ? Colors.white : kInk)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider.select((a) => a.current));
    final isSeller = me != null && me.role == 1 && me.staff.isEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFEEE8F3),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1])),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                height: 48,
                child: Stack(alignment: Alignment.center, children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 56), child: Text('Nouvelle publication', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: mst(17, w: FontWeight.w600, c: kInk))),
                  Align(alignment: Alignment.centerLeft, child: TpRound(icon: Icons.close, label: 'Fermer', onTap: () => gBack(context))),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
              child: Row(children: [
                _chip('post', Icons.grid_view_rounded, 'Publication', () => setState(() => _kind = 'post')),
                _chip('reel', Icons.movie_creation_outlined, 'Reel', () {
                  setState(() => _kind = 'reel');
                  gToast(context, 'Ajoutez une vidéo : elle apparaît aussi dans Reels.');
                }),
                _chip('live', Icons.sensors, 'Live', () => gOpen(context, 'L1')),
                if (isSeller) _chip('shop', Icons.storefront_outlined, 'Boutique', () => gOpen(context, '58')),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                const PostComposerBody(),
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => gOpen(context, 'P5'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.share_outlined, color: kViolet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Publier aussi sur mes réseaux', style: mst(13.5, w: FontWeight.w700)),
                          Text('Connectez vos comptes pour diffuser en un geste.', style: mst(12, c: kGrey)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: kGrey),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
