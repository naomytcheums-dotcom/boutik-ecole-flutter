// GÉNÉRÉ par tool/figma_export/convert.py — écran 22d (nœud Figma 35:612). Ne pas éditer à la main.
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
import '../live/docs.dart';
import '../live/kela.dart';
import '../live/chat.dart';
import '../live/share.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_22d extends ConsumerWidget {
  const G_22d({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 925, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF5F0E8), Color(0xFFEFE9F4), Color(0xFFF7E9DB)], stops: [0, 0.55, 1]), children: [
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
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/2e8d6b9b0673a0.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/34ad6fe6386c09.svg')),
      gP(76, 70, 100, 26, gText('Pour vous', 21, Color(0xFF111015), weight: 700)),
      gP(350.833, 71.667, 12.417, 6, gImg('assets/figma/v/0a0e58425c2a5a.svg')),
      gP(340.75, 71.667, 12.417, 6, gImg('assets/figma/v/0a0e58425c2a5a.svg')),
      gP(349, 79, 14.25, 6, gImg('assets/figma/v/fc3284c63b3b59.svg')),
      gP(340.75, 79, 10.583, 6, gImg('assets/figma/v/44a17a4f91db19.svg')),
      gP(352.667, 86.333, 10.583, 6, gImg('assets/figma/v/44a17a4f91db19.svg')),
      gP(340.75, 86.333, 14.25, 6, gImg('assets/figma/v/fc3284c63b3b59.svg')),
      gP(350.833, 69.833, 6, 9.667, gImg('assets/figma/v/d9c4f4918155a5.svg')),
      gP(345.333, 77.167, 6, 9.667, gImg('assets/figma/v/d9c4f4918155a5.svg')),
      gP(352.667, 84.5, 6, 9.667, gImg('assets/figma/v/d9c4f4918155a5.svg')),
      gP(24, 120, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 135, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 140.917, 18.75, 20.167, gImg('assets/figma/v/5231475c96a8ed.svg')),
      gP(76, 134, 277, 34, gText('Recommandations basées sur vos favoris, vos recherches et vos commandes.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(24, 196, 177, 19, gText('Recommandé pour vous', 15, Color(0xFF111015), weight: 700)),
      gP(28, 238, 157, 115.5, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(152, 245, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 249.75, 17.667, 16.5, gImg('assets/figma/v/577d3dca1e0e4f.svg')),
      gP(150, 243, 30, 30, GHeart()),
      gP(36, 361.5, 144, 16, gText('Lampe de bureau recy…', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 379.5, 76, 15, gText('22 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 396.5, 51, 13, gText('Génie civil', 10.5, Color(0xFF5A3FE0))),
      gP(205, 238, 157, 115.5, gBox(image: 'assets/figma/img/93dff03913a5b9f3a8ba8bc190862ebc295fc28d.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(329, 245, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 249.75, 17.667, 16.5, gImg('assets/figma/v/577d3dca1e0e4f.svg')),
      gP(327, 243, 30, 30, GHeart()),
      gP(213, 361.5, 101, 16, gText('Sac à dos design', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 379.5, 76, 15, gText('25 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 396.5, 65, 13, gText('Design – MMI', 10.5, Color(0xFF5A3FE0))),
      gP(28, 435.5, 157, 115.5, gBox(image: 'assets/figma/img/cbf050b9f90ddf4164a56ebd171cee79dfa21141.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(152, 442.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 447.25, 17.667, 16.5, gImg('assets/figma/v/577d3dca1e0e4f.svg')),
      gP(150, 440.5, 30, 30, GHeart()),
      gP(36, 559, 91, 16, gText('Drone éducatif', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 577, 82, 15, gText('150 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 594, 83, 13, gText('Génie électrique', 10.5, Color(0xFF5A3FE0))),
      gP(205, 435.5, 157, 115.5, gBox(image: 'assets/figma/img/b49b6a241d16c8c01f026ab4fe2980adaae1b6f4.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(329, 442.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 447.25, 17.667, 16.5, gImg('assets/figma/v/577d3dca1e0e4f.svg')),
      gP(327, 440.5, 30, 30, GHeart()),
      gP(213, 559, 117, 16, gText('Support ordinateur', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 577, 73, 15, gText('12 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 594, 78, 13, gText('Génie industriel', 10.5, Color(0xFF5A3FE0))),
      gP(24, 631, 137, 19, gText('Talents à découvrir', 15, Color(0xFF111015), weight: 700)),
      gP(301, 633, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 638, 13, 6, gImg('assets/figma/v/fa9a2f5c896b90.svg')),
      gP(356, 634.5, 9.5, 13, gImg('assets/figma/v/18871471ec7ecf.svg')),
      gP(36, 677, 50, 50, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 681, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 703, 115, 14, gText('MMI · UI/UX, Branding', 11.5, Color(0xFF66636E))),
      gP(293.6, 691, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(305.8, 695, 34, 14, gText('Suivre', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 735, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 743, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 747, 102, 17, gText('Brice Ndoumbe', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 769, 94, 14, gText('Électronique · IoT', 11.5, Color(0xFF66636E))),
      gP(293.6, 757, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(305.8, 761, 34, 14, gText('Suivre', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(22, 837, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 858.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 858.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 870.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 858.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 858.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 858.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 857.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 864.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 871.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 858.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 858.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 866.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 843, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 858, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 856.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
