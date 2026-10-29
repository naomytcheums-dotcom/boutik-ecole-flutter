// GÉNÉRÉ par tool/figma_export/convert.py — écran 106 (nœud Figma 40:523). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../live/auth.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_106 extends ConsumerWidget {
  const G_106({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 915, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 151.95, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 636.9, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 202, 26, gText('Économie circulaire', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 85.2, 34, 'Recyclés', 12.5, 600), GChip(117.2, 120, 100, 34, 'Réparables', 12.5, 500), GChip(225.2, 120, 122.2, 34, 'Réutilisables', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 150, gBox(image: 'assets/figma/img/285ea8d512e6fd1079056dd514be7a2ebad70bf2.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 168, 342, 150, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 256, 309, 23, gText('Seconde vie, premier choix', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 284, 309, 15, gText('Des créations à partir de matériaux récupérés', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(28, 336, 157, 115.5, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(152, 343, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 347.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(150, 341, 30, 30, GHeart()),
      gP(36, 459.5, 136, 16, gText('Lampe en bois recyclé', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 477.5, 76, 15, gText('25 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 494.5, 51, 13, gText('Génie civil', 10.5, Color(0xFF5A3FE0))),
      gP(205, 336, 157, 115.5, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(329, 343, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 347.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(327, 341, 30, 30, GHeart()),
      gP(213, 459.5, 137, 16, gText('Sac en bâche recyclée', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 477.5, 73, 15, gText('12 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 494.5, 35, 13, gText('Design', 10.5, Color(0xFF5A3FE0))),
      gP(28, 533.5, 157, 115.5, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(152, 540.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 545.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(150, 538.5, 30, 30, GHeart()),
      gP(36, 657, 103, 16, gText('Table en palettes', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 675, 77, 15, gText('45 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 692, 51, 13, gText('Génie civil', 10.5, Color(0xFF5A3FE0))),
      gP(205, 533.5, 157, 115.5, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(329, 540.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 545.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(327, 538.5, 30, 30, GHeart()),
      gP(213, 657, 104, 16, gText('Pots en plastique', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 675, 69, 15, gText('6 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 692, 56, 13, gText('Agronomie', 10.5, Color(0xFF5A3FE0))),
      gP(24, 729, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 744, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.318, 749.917, 18.057, 18.75, gImg('assets/figma/v/6b32e99463f5ba.svg')),
      gP(41.917, 757, 13.792, 12.375, gImg('assets/figma/v/5a42605c735300.svg')),
      gP(76, 743, 277, 34, gText('Chaque achat évite des déchets : retrouvez l’impact dans « Mon impact ».', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 903, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 827, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 848.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 848.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 860.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 848.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 848.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 848.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 847.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 854.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 861.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 848.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 848.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 856.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 833, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 848, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 846.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
