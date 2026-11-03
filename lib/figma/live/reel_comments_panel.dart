import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'store.dart' show nowProvider;
import 'reels.dart';

/// Commentaires réels du reel affiché (écran 252, connecté au serveur) : chargement, erreur, état vide et liste.
/// Remplace les commentaires figés de la maquette (noms et textes fictifs).
class ReelCommentsPanel extends ConsumerStatefulWidget {
  const ReelCommentsPanel({super.key});

  @override
  ConsumerState<ReelCommentsPanel> createState() => _State();
}

class _State extends ConsumerState<ReelCommentsPanel> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(reelCommentsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(reelCommentsProvider);
    final error = ref.watch(commentsErrorProvider);
    final reel = ref.watch(currentReelProvider);
    final now = ref.watch(nowProvider);
    const grey = Color(0xFF57545F);
    Widget centered(String t) => Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: gText(t, 13, grey, wrap: true, align: TextAlign.center)));
    if (reel == null) return centered('Aucune publication à commenter.');
    if (list == null) return centered('Chargement des commentaires…');
    if (error.isNotEmpty) return centered(error);
    if (list.isEmpty) return centered('Aucun commentaire pour le moment. Soyez le premier à réagir.');
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        final c = list[i];
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE7FF)),
            alignment: Alignment.center,
            child: gText(c.author.isEmpty ? '?' : c.author.characters.first.toUpperCase(), 14, const Color(0xFF5A3FE0), weight: 700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: gText(c.author, 12.5, const Color(0xFF111015), weight: 600, wrap: true, maxLines: 1)),
                const SizedBox(width: 8),
                gText(relativeTime(c.createdAt, now), 10, grey, wrap: true),
              ]),
              const SizedBox(height: 4),
              gText(c.body, 12, const Color(0xFF4A4854), lh: 17, wrap: true),
            ]),
          ),
          if (c.mine)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => deleteReelComment(context, ref, c.id),
              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.delete_outline, size: 18, color: grey)),
            ),
        ]);
      },
    );
  }
}
