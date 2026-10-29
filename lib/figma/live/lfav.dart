import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gsound.dart';
import 'store.dart';

/// Cœur « favori » lié à la liste de favoris partagée.
class GHeartLive extends ConsumerWidget {
  const GHeartLive({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = title.isNotEmpty && ref.watch(favoritesProvider).contains(title);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (title.isEmpty) return;
        ref.read(favoritesProvider.notifier).toggle(title);
        GSound.play(on ? 'tick' : 'pop');
        HapticFeedback.lightImpact();
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: on ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.elasticOut,
        builder: (_, v, _) => Center(
          child: on ? Transform.scale(scale: 0.6 + 0.4 * v, child: Container(margin: const EdgeInsets.all(5), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(7), child: const FittedBox(child: Icon(Icons.favorite_rounded, color: Color(0xFF111015), size: 40)))) : const SizedBox.expand(),
        ),
      ),
    );
  }
}
