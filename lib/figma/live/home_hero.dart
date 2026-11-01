import 'package:flutter/material.dart';

/// Carrousel « À la une » de l'accueil 03 : la flèche et le glissement font défiler les 3 visuels
/// (indiqués par les 3 points de la maquette). Visuels et textes repris des maquettes 03, 175 et 177.
class HomeHero {
  HomeHero._();

  static const slides = <({String image, String title, String sub})>[
    (image: 'assets/figma/img/6baf8125049f662c1c5c4c23c6b514db2881910c.png', title: 'L’innovation\nétudiante en action', sub: 'Des projets qui transforment\ndemain.'),
    (image: 'assets/figma/img/a30d4e56acc9216d03ba2d7972f7dfac533b78bf.png', title: 'Vendez vos\ncréations', sub: 'Produits, services et\nprojets de l’IUT'),
    (image: 'assets/figma/img/e48f8827338ec470670d1109125a15b7d0f21476.png', title: 'Recrutez les\ntalents de demain', sub: 'Stages, défis et\ncollaborations'),
  ];

  static final index = ValueNotifier<int>(0);

  static void next() => index.value = (index.value + 1) % slides.length;
  static void previous() => index.value = (index.value - 1 + slides.length) % slides.length;
}

/// Contenu d'un emplacement du carrousel, reconstruit à chaque changement de diapositive (fondu).
Widget heroSlot(Widget Function(({String image, String title, String sub}) s, int i) build) => ValueListenableBuilder<int>(
      valueListenable: HomeHero.index,
      builder: (_, i, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: KeyedSubtree(key: ValueKey(i), child: build(HomeHero.slides[i], i)),
      ),
    );

/// Zone de glissement horizontal sur la carte (n'empêche pas le défilement vertical).
Widget heroSwipe(double x, double y, double w, double h) {
  var dx = 0.0;
  return Positioned(
    left: x,
    top: y,
    width: w,
    height: h,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => dx = 0,
      onHorizontalDragUpdate: (d) => dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -50 || dx < -40) {
          HomeHero.next();
        } else if (v > 50 || dx > 40) {
          HomeHero.previous();
        }
      },
    ),
  );
}
