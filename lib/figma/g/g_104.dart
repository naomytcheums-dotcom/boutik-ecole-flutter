// GÉNÉRÉ par tool/figma_export/convert.py — écran 104 (nœud Figma 40:335). Ne pas éditer à la main.
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

class G_104 extends ConsumerWidget {
  const G_104({super.key});

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
      gP(76, 70, 213, 26, gText('Carte de l’innovation', 21, Color(0xFF111015), weight: 700)),
      gP(339.833, 70.75, 24.333, 22.5, gImg('assets/figma/v/93e9ba743f301c.svg')),
      gP(24, 120, 342, 48, GField(hint: 'Rechercher un acteur, un lieu…', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 496, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 496, 85.2, 34, 'Ateliers', 12.5, 500), GChip(180.8, 496, 107.4, 34, 'Entreprises', 12.5, 500), GChip(296.2, 496, 85.2, 34, 'Kiosques', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(36, 557, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 565.667, 19.333, 22.667, gImg('assets/figma/v/e25472574b704c.svg')),
      gP(50.5, 569.833, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 556, 112, 17, gText('Atelier Génie civil', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 578, 139, 14, gText('IUT Douala · Bloc B · 120 m', 11.5, Color(0xFF66636E))),
      gP(293.6, 566, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(303.8, 570, 38, 14, gText('Ouvert', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 610, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 623, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 631.667, 19.333, 22.667, gImg('assets/figma/v/e25472574b704c.svg')),
      gP(50.5, 635.833, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 622, 171, 17, gText('Kiosque de retrait – Bloc A', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 644, 93, 14, gText('IUT Douala · 80 m', 11.5, Color(0xFF66636E))),
      gP(293.6, 632, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(303.8, 636, 38, 14, gText('Ouvert', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
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
      gP(103.132, 196, 183.735, 272, gImg('assets/figma/r/174_16.png')),
      gP(125.924, 404.657, 12, 12, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(89.924, 404.657, 33, 12, gText('Douala', 9.5, Color(0xFF120F14), weight: 600)),
      gP(169.111, 408.807, 12, 12, gBox(color: Color(0xFF111015), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(184.111, 408.807, 41, 12, gText('Yaoundé', 9.5, Color(0xFF120F14), weight: 600)),
      gP(144.472, 372.582, 9, 9, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(87.972, 371.082, 52, 12, gText('Bafoussam', 9.5, Color(0xFF120F14), weight: 500)),
      gP(215.693, 281.286, 9, 9, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(229.193, 279.786, 34, 12, gText('Garoua', 9.5, Color(0xFF120F14), weight: 500)),
      gP(237.665, 250.729, 9, 9, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(251.165, 249.229, 35, 12, gText('Maroua', 9.5, Color(0xFF120F14), weight: 500)),
      gP(219.86, 328.443, 9, 9, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(233.36, 326.943, 58, 12, gText('Ngaoundéré', 9.5, Color(0xFF120F14), weight: 500)),
      gP(222.133, 393.708, 9, 9, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(235.633, 392.208, 37, 12, gText('Bertoua', 9.5, Color(0xFF120F14), weight: 500)),
      gP(138.41, 360.887, 9, 9, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, shadows: [BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), blurRadius: 3, spreadRadius: 0)], oval: true)),
      gP(89.91, 359.387, 44, 12, gText('Bamenda', 9.5, Color(0xFF120F14), weight: 500)),
    ]);
  }
}
