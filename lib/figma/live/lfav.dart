import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gsound.dart';
import 'auth.dart';
import 'store.dart';

/// Cœur « favori » lié à la liste de favoris partagée.
class GHeartLive extends ConsumerWidget {
  const GHeartLive({super.key, required this.title, this.pad = EdgeInsets.zero});
  final String title;

  /// Marge de toucher invisible (zone de 48 dp au moins) autour du cœur dessiné.
  final EdgeInsets pad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = title.isNotEmpty && ref.watch(favoritesProvider).contains(title);
    Future<void> toggle() async {
      if (title.isEmpty) return;
      if (!await requireLogin(context, ref, 'enregistrer vos favoris')) return;
      if (!context.mounted) return;
      ref.read(favoritesProvider.notifier).toggle(title);
      GSound.play(on ? 'tick' : 'pop');
      HapticFeedback.lightImpact();
    }

    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Retirer des favoris : $title' : 'Ajouter aux favoris : $title',
      excludeSemantics: true,
      onTap: toggle,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggle,
      child: Padding(padding: pad, child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: on ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.elasticOut,
        builder: (_, v, _) => Center(
          child: on ? Transform.scale(scale: 0.6 + 0.4 * v, child: Container(margin: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(7), child: const FittedBox(child: Icon(Icons.favorite_rounded, color: Color(0xFF111015), size: 40)))) : const SizedBox.expand(),
        ),
      )),
    ));
  }
}
