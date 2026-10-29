// GÉNÉRÉ par tool/figma_export/convert.py — écran 245 (nœud Figma 152:125). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_245 extends ConsumerWidget {
  const G_245({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(0, 0, 390, 844, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover)),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(0, 0, 390, 844, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x40000000), Color(0x00000000), Color(0x99000000)], stops: [0, 0.45, 1]))),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFFFFFFFF), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(24, 62, 58, 28, gText('Reels', 22, Color(0xFFFFFFFF), weight: 600)),
      gP(324, 56, 40, 40, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(333.917, 67.333, 20.167, 17.333, gImg('assets/figma/v/d6b1a9cf24c644.svg')),
      gP(338.875, 71.583, 10.25, 10.25, gImg('assets/figma/v/6d51bbc13363b0.svg')),
      gP(161, 366, 68, 68, gBox(color: Color(0x4DFFFFFF), oval: true)),
      gP(187.5, 387.25, 21.167, 25.5, gImg('assets/figma/v/441522099dce07.svg')),
      gP(324, 308, 44, 44, gBox(color: Color(0x38FFFFFF), oval: true)),
      gP(334.667, 319.5, 22.667, 21, gImg('assets/figma/v/f81603d78186bb.svg')),
      gP(328, 312, 36, 36, GHeart()),
      gP(335, 356, 22, 12, gText('2,6 k', 9.5, Color(0xFFFFFFFF), weight: 500)),
      gP(324, 370, 44, 44, gBox(color: Color(0x38FFFFFF), oval: true)),
      gP(335.5, 383.358, 21, 19.142, gImg('assets/figma/v/3fc89363db42fe.svg')),
      gP(338, 418, 16, 12, gText('312', 9.5, Color(0xFFFFFFFF), weight: 500)),
      gP(324, 432, 44, 44, gBox(color: Color(0x38FFFFFF), oval: true)),
      gP(336.333, 451, 19.333, 14.333, gImg('assets/figma/v/624b33ad1df422.svg')),
      gP(339.667, 442.667, 12.667, 9.333, gImg('assets/figma/v/fb09d2f284479b.svg')),
      gP(343, 442.667, 6, 16.833, gImg('assets/figma/v/56fba653ffccbd.svg')),
      gP(326, 480, 40, 12, gText('Partager', 9.5, Color(0xFFFFFFFF), weight: 500)),
      gP(324, 494, 44, 44, gBox(color: Color(0x38FFFFFF), oval: true)),
      gP(337.667, 507.667, 16.667, 15.833, gImg('assets/figma/r/152_156.png')),
      gP(338.5, 542, 15, 12, gText('4,9', 9.5, Color(0xFFFFFFFF), weight: 500)),
      gP(324, 556, 44, 44, gBox(color: Color(0x38FFFFFF), oval: true)),
      gP(336, 568, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '248')),
      gP(335.5, 566.667, 21, 22.667, gImg('assets/figma/v/aede3bf7db6d35.svg')),
      gP(335.5, 570, 21, 12.667, gImg('assets/figma/v/33c7823e8b4d0f.svg')),
      gP(324.5, 604, 43, 12, gText('Boutique', 9.5, Color(0xFFFFFFFF), weight: 500)),
      gP(22, 612, 40, 40, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [20, 20, 20, 20]), tap: () => gOpen(context, '247')),
      gP(72, 614, 52, 17, gText('Brice N.', 13.5, Color(0xFFFFFFFF), weight: 600)),
      gP(160, 610, 77, 25, gBox(color: Color(0x40FFFFFF), radii: [100, 100, 100, 100])),
      gP(172, 616, 53, 13, gText('S’abonner', 10.5, Color(0xFFFFFFFF), weight: 600)),
      gP(22, 664, 293, 34, gText('Pose d’un kit solaire sur le toit de l’atelier. Tout est fait par les étudiants d’Énergies renouvelables !', 12, Color(0xFFFFFFFF), lh: 17, wrap: true)),
      gP(27.375, 708.125, 12.5, 14.125, gImg('assets/figma/v/8069565849e696.svg')),
      gP(24.125, 714.625, 9.25, 9.25, gImg('assets/figma/v/c928a326a5830e.svg')),
      gP(30.625, 713.542, 9.25, 9.25, gImg('assets/figma/v/c928a326a5830e.svg')),
      gP(50, 709, 105, 13, gText('Son original · Brice N.', 10.5, Color(0xFFFFFFFF), weight: 500)),
      gP(22, 736, 346, 3, gBox(color: Color(0x4DFFFFFF), radii: [2, 2, 2, 2])),
      gP(22, 736, 120, 3, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '251')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '247')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '244')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(336, 382, 20, 20, () => gOpen(context, '252')),
      gTap(336, 568, 20, 20, () => gOpen(context, '248')),
      gTap(22, 612, 40, 40, () => gOpen(context, '247')),
    ]);
  }
}
