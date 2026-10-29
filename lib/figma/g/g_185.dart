// GÉNÉRÉ par tool/figma_export/convert.py — écran 185 (nœud Figma 61:1084). Ne pas éditer à la main.
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
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_185 extends ConsumerWidget {
  const G_185({super.key});

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
      gP(76, 70, 101, 26, gText('Language', 21, Color(0xFF111015), weight: 700)),
      gP(40, 132, 55, 17, gText('Français', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 154, 94, 14, gText('Default language', 11.5, Color(0xFF66636E))),
      gP(40, 186, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 198, 47, 17, gText('English', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 220, 107, 14, gText('English (Cameroon)', 11.5, Color(0xFF66636E))),
      gP(293.6, 208, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(305.8, 212, 34, 14, gText('Active', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 266, 60, 19, gText('Preview', 15, Color(0xFF111015), weight: 700)),
      gP(36, 312, 50, 50, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 316, 153, 17, gText('Recycled wooden lamp', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 338, 171, 14, gText('25,000 FCFA · Civil Engineering', 11.5, Color(0xFF66636E))),
      gP(280.8, 326, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(295.4, 330, 42, 14, gText('In stock', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 370, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 383, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 393.333, 9.333, 10.167, gImg('assets/figma/v/ff038cff524fea.svg')),
      gP(58, 393.333, 9.333, 10.167, gImg('assets/figma/v/6d7d6e6c277316.svg')),
      gP(46.333, 408.333, 19.333, 6, gImg('assets/figma/v/3035c903f4ca6a.svg')),
      gP(48, 391.667, 16, 16.833, gImg('assets/figma/v/ddb12173c17b9f.svg')),
      gP(88, 382, 163, 17, gText('Orange Digital Challenge', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 404, 143, 14, gText('Registration open · Douala', 11.5, Color(0xFF66636E))),
      gP(306.4, 392, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(313.7, 396, 31, 14, gText('Open', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 450, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 465, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 470.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(46.167, 470.917, 11.667, 20.167, gImg('assets/figma/v/31f0124115ee48.svg')),
      gP(41.917, 478, 20.167, 6, gImg('assets/figma/v/4330c328ce106e.svg')),
      gP(76, 464, 277, 34, gText('Switch language anytime in Settings. Short, clear texts in both French and English.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
