// GÉNÉRÉ par tool/figma_export/convert.py — écran 91 (nœud Figma 39:601). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_91 extends ConsumerWidget {
  const G_91({super.key});

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
      gP(76, 70, 235, 26, gText('Rechercher des talents', 21, Color(0xFF111015), weight: 700)),
      gP(339.833, 70.75, 24.333, 22.5, gImg('assets/figma/v/93e9ba743f301c.svg')),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Compétence, filière, équipe…', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(338.583, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(329.875, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(337, 141, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(329.875, 141, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(340.167, 147.333, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(329.875, 147.333, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(338.583, 133.083, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(333.833, 139.417, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(340.167, 145.75, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 182, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 182, 122.2, 34, 'Développement', 12.5, 500), GChip(217.8, 182, 70.4, 34, 'Design', 12.5, 500), GChip(296.2, 182, 107.4, 34, 'Audiovisuel', 12.5, 500), GChip(411.6, 182, 77.8, 34, 'Équipes', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 230, 181, 19, gText('48 profils correspondent', 15, Color(0xFF111015), weight: 700)),
      gP(24, 268, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 276, 50, 50, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 280, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 302, 142, 14, gText('Génie informatique · 4.9 ★', 11.5, Color(0xFF66636E))),
      gP(268, 290, 84, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(281.5, 294, 57, 14, gText('Disponible', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 334, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 342, 50, 50, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 346, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 368, 98, 14, gText('MMI · UI/UX · 4.8 ★', 11.5, Color(0xFF66636E))),
      gP(268, 356, 84, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(281.5, 360, 57, 14, gText('Disponible', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 400, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 408, 50, 50, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 412, 126, 17, gText('Équipe Team Innov’', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 434, 160, 14, gText('Génie électrique · 4 membres', 11.5, Color(0xFF66636E))),
      gP(293.6, 422, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(303.8, 426, 38, 14, gText('Équipe', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 466, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 474, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 478, 93, 17, gText('Kouassi Tagne', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 500, 99, 14, gText('Audiovisuel · 4.7 ★', 11.5, Color(0xFF66636E))),
      gP(293.6, 488, 58.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(300.8, 492, 44, 14, gText('Occupé', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
