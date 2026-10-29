// GÉNÉRÉ par tool/figma_export/convert.py — écran 244 (nœud Figma 152:17). Ne pas éditer à la main.
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
import '../live/ops.dart';
import '../live/missions.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_244 extends ConsumerWidget {
  const G_244({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 42, 77, 30, gText('Cercle', 24, Color(0xFF111015), weight: 600)),
      gP(286, 36, 40, 40, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(298.042, 53, 15.917, 6, gImg('assets/figma/v/253e5d47822704.svg')),
      gP(303, 48.042, 6, 15.917, gImg('assets/figma/v/2a781469bb9f84.svg')),
      gP(330, 36, 40, 40, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(340.625, 45.917, 18.75, 16.625, gImg('assets/figma/v/b2ae09d0fd46bb.svg')),
      gP(345.796, 59.375, 8.408, 6.712, gImg('assets/figma/v/f59da0513c0b4c.svg')),
      gP(356, 39, 10, 10, gBox(color: Color(0xFFE5484D), oval: true)),
      gP(14, 104, 56, 56, gBox(color: Color(0xFFDAD6E2), oval: true)),
      gP(17, 107, 50, 50, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(19, 109, 46, 46, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(51, 141, 18, 18, gBox(color: Color(0xFF111015), oval: true)),
      gP(54.083, 147, 11.833, 6, gImg('assets/figma/v/1cf8181865cf08.svg')),
      gP(57, 144.083, 6, 11.833, gImg('assets/figma/v/9ec048d7730068.svg')),
      gP(35.5, 172, 13, 12, gText('Toi', 9.5, Color(0xFF111015), weight: 500)),
      gP(76, 104, 56, 56, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFFF4B6E), Color(0xFFFF8A3D)], stops: [0, 1]), oval: true)),
      gP(79, 107, 50, 50, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(81, 109, 46, 46, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(90, 154, 28, 14, gBox(color: Color(0xFFFF2D55), radii: [7, 7, 7, 7])),
      gP(96.5, 156, 15, 9, gText('LIVE', 7, Color(0xFFFFFFFF), weight: 700), fx: 'pulse'),
      gP(86, 172, 36, 12, gText('Yannick', 9.5, Color(0xFF111015), weight: 500)),
      gP(138, 104, 56, 56, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFFF4B6E), Color(0xFFFF8A3D)], stops: [0, 1]), oval: true)),
      gP(141, 107, 50, 50, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(143, 109, 46, 46, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(152, 154, 28, 14, gBox(color: Color(0xFFFF2D55), radii: [7, 7, 7, 7])),
      gP(158.5, 156, 15, 9, gText('LIVE', 7, Color(0xFFFFFFFF), weight: 700), fx: 'pulse'),
      gP(145, 172, 42, 12, gText('Atelier GI', 9.5, Color(0xFF111015), weight: 500)),
      gP(200, 104, 56, 56, gBox(color: Color(0xFF111015), oval: true)),
      gP(203, 107, 50, 50, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(205, 109, 46, 46, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(214, 154, 28, 14, gBox(color: Color(0xFF111015), radii: [7, 7, 7, 7])),
      gP(215, 156, 26, 9, gText('BOOST', 7, Color(0xFFFFFFFF), weight: 700)),
      gP(211.5, 172, 33, 12, gText('Kamga', 9.5, Color(0xFF111015), weight: 500)),
      gP(262, 104, 56, 56, gBox(color: Color(0xFFDAD6E2), oval: true)),
      gP(265, 107, 50, 50, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(267, 109, 46, 46, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(271, 172, 38, 12, gText('Aminata', 9.5, Color(0xFF111015), weight: 500)),
      gP(324, 104, 56, 56, gBox(color: Color(0xFFDAD6E2), oval: true)),
      gP(327, 107, 50, 50, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(329, 109, 46, 46, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(335.5, 172, 33, 12, gText('Équipe', 9.5, Color(0xFF111015), weight: 500)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(20, 200, 88.8, 32, 'Pour toi', 11.5, 500), GChip(116.8, 200, 111.6, 32, 'Abonnements', 11.5, 400), GChip(236.4, 200, 73.6, 32, 'Vidéos', 11.5, 400), GChip(318, 200, 96.4, 32, 'Boutiques', 11.5, 400)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 16)),
      gP(20, 246, 350, 300, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 14), blurRadius: 26, spreadRadius: 0)], radii: [38, 38, 38, 38])),
      gP(34, 260, 76, 25, gBox(color: Color(0xD1FFFFFF), radii: [100, 100, 100, 100])),
      gP(46, 266, 52, 13, gText('Génie civil', 10.5, Color(0xFF111015), weight: 600)),
      gP(182, 527, 6, 6, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(192, 527, 6, 6, gBox(color: Color(0x80FFFFFF), oval: true)),
      gP(202, 527, 6, 6, gBox(color: Color(0x80FFFFFF), oval: true)),
      gP(285, 260, 71, 25, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(285, 260, 71, 25, const SizedBox.expand(), tap: () => gOpen(context, '248')),
      gP(297, 266, 47, 13, gText('Boutique', 10.5, Color(0xFFFFFFFF), weight: 600)),
      gP(22, 560, 38, 38, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [19, 19, 19, 19]), tap: () => gOpen(context, '247')),
      gP(70, 562, 70, 17, gText('Yannick M.', 13.5, Color(0xFF111015), weight: 600), tap: () => gOpen(context, '247')),
      gP(151, 563, 14, 14, gBox(color: Color(0xFF2F7DF6), oval: true)),
      gP(152, 564.75, 12, 10.125, gImg('assets/figma/v/b3d82fb04f89ab.svg')),
      gP(70, 582, 91, 13, gText('Génie civil · il y a 1 h', 10.5, Color(0xFF66636E))),
      gP(288, 566, 80, 26, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(300, 572, 56, 14, gText('S’abonner', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(22, 610, 349, 36, gText('Lampe en bois recyclé : fabrication terminée, disponible dans ma boutique.', 12.5, Color(0xFF111015), lh: 18, wrap: true)),
      gP(22, 648, 47, 14, gText('Voir plus', 11.5, Color(0xFF66636E), weight: 500)),
      gP(24, 678, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '244b')),
      gP(22.667, 677.5, 22.667, 21, gImg('assets/figma/v/0c92a89d2e95e8.svg')),
      gP(16, 670, 36, 36, GHeart()),
      gP(50, 680, 22, 14, gText('248', 11.5, Color(0xFF111015), weight: 500)),
      gP(101.5, 679.358, 21, 19.142, gImg('assets/figma/v/bb0d88afb786ef.svg')),
      gP(128, 680, 12, 14, gText('31', 11.5, Color(0xFF111015), weight: 500)),
      gP(180.333, 685, 19.333, 14.333, gImg('assets/figma/v/9c92298f9fd6b2.svg')),
      gP(183.667, 676.667, 12.667, 9.333, gImg('assets/figma/v/bb8ad3c4792df6.svg')),
      gP(187, 676.667, 6, 16.833, gImg('assets/figma/v/5bb53be308dfb1.svg')),
      gP(206, 680, 12, 14, gText('12', 11.5, Color(0xFF111015), weight: 500)),
      gP(267.667, 679.667, 16.667, 15.833, gImg('assets/figma/r/152_105.png')),
      gP(292, 680, 19, 14, gText('4,8', 11.5, Color(0xFF111015), weight: 500)),
      gP(231, 674, 137, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(231, 674, 137, 25, const SizedBox.expand(), tap: () => gOpen(context, '248')),
      gP(243, 680, 113, 13, gText('Voir l’article · 25 000 F', 10.5, Color(0xFF5A3FE0), weight: 600)),
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
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true)),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(298, 48, 17, 17, () => gOpen(context, '249')),
      gTap(342, 48, 17, 17, () => gOpen(context, '254')),
      gTap(81, 109, 46, 46, () => gOpen(context, '222')),
      gTap(143, 109, 46, 46, () => gOpen(context, '222')),
      gTap(285, 260, 71, 25, () => gOpen(context, '248')),
      gTap(22, 560, 38, 38, () => gOpen(context, '247')),
      gTap(70, 562, 70, 17, () => gOpen(context, '247')),
      gTap(24, 678, 20, 20, () => gOpen(context, '244b')),
      gTap(102, 678, 20, 20, () => gOpen(context, '252')),
      gTap(231, 674, 137, 25, () => gOpen(context, '248')),
    ]);
  }
}
