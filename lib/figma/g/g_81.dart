// GÉNÉRÉ par tool/figma_export/convert.py — écran 81 (nœud Figma 38:952). Ne pas éditer à la main.
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
import '../live/seller.dart';
import '../live/review.dart';
import '../live/audit.dart';
import '../live/admin.dart';
import '../live/talents.dart';
import '../live/hackathons.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_81 extends ConsumerWidget {
  const G_81({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 168, 26, gText('Équipe du projet', 21, Color(0xFF111015), weight: 700)),
      gP(342.583, 79, 18.833, 6, gImg('assets/figma/v/6fe571ab77e960.svg')),
      gP(349, 72.583, 6, 18.833, gImg('assets/figma/v/87cbf4a9a18b64.svg')),
      gP(24, 120, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 132, 102, 17, gText('Brice Ndoumbe', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 157, 14, gText('Électronique · Chef de projet', 11.5, Color(0xFF66636E))),
      gP(306.4, 142, 45.6, 22, gBox(color: Color(0xFFE1E7F0), radii: [11, 11, 11, 11])),
      gP(315.7, 146, 27, 14, gText('Chef', 11, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(98, 186, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 194, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 198, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 220, 96, 14, gText('MMI · Conception', 11.5, Color(0xFF66636E))),
      gP(293.6, 208, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(304.3, 212, 37, 14, gText('Design', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 252, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 260, 50, 50, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 264, 114, 17, gText('Yannick Mouanga', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 286, 114, 14, gText('Génie civil · Structure', 11.5, Color(0xFF66636E))),
      gP(274.4, 274, 77.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(285.7, 278, 55, 14, gText('Technique', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(98, 318, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 326, 50, 50, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 330, 93, 17, gText('Kouassi Tagne', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 352, 158, 14, gText('Audiovisuel · Communication', 11.5, Color(0xFF66636E))),
      gP(300, 340, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(309.5, 344, 33, 14, gText('Média', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 398, 227, 19, gText('Répartition des responsabilités', 15, Color(0xFF111015), weight: 700)),
      gP(24, 436, 342, 148, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 450, 73, 16, gText('Conception', 12.5, Color(0xFF111015), weight: 600)),
      gP(321, 450, 29, 15, gText('80%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 472, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 472, 248, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 494, 66, 16, gText('Réalisation', 12.5, Color(0xFF111015), weight: 600)),
      gP(322, 494, 28, 15, gText('55%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 516, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 516, 170.5, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
      gP(40, 538, 97, 16, gText('Communication', 12.5, Color(0xFF111015), weight: 600)),
      gP(323, 538, 27, 15, gText('35%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 560, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 560, 108.5, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(24, 598, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 613, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 625.292, 18.75, 13.792, gImg('assets/figma/v/98eafa7aa487dc.svg')),
      gP(45.458, 618.917, 13.083, 12.375, gImg('assets/figma/v/cbd17bba51f32b.svg')),
      gP(76, 612, 277, 34, gText('Chaque membre peut modifier uniquement les étapes qui lui sont attribuées.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
