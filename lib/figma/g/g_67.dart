// GÉNÉRÉ par tool/figma_export/convert.py — écran 67 (nœud Figma 37:860). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_67 extends ConsumerWidget {
  const G_67({super.key});

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
      gP(24, 70, 124, 26, gText('Statistiques', 21, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 77.8, 34, '7 jours', 12.5, 500), GChip(109.8, 120, 85.2, 34, '30 jours', 12.5, 600), GChip(203, 120, 77.8, 34, '12 mois', 12.5, 500)], selected: 1, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(38, 180, 106, 14, gText('Vues des annonces', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 200, 56, 25, gText('4 280', 20, Color(0xFF111015), weight: 800)),
      gP(38, 232, 32, 14, gText('+18 %', 11, Color(0xFF0F7A52), weight: 600)),
      gP(150, 180, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(154.75, 186.625, 18.5, 14.75, gImg('assets/figma/v/6c31da6f344600.svg')),
      gP(159.125, 189.125, 9.75, 9.75, gImg('assets/figma/v/b916ebbd5954b5.svg')),
      gP(214, 180, 105, 14, gText('Taux de conversion', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 200, 59, 25, gText('3,4 %', 20, Color(0xFF111015), weight: 800)),
      gP(214, 232, 39, 14, gText('+0,6 pt', 11, Color(0xFF0F7A52), weight: 600)),
      gP(326, 180, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(332.625, 186.625, 14.75, 14.75, gImg('assets/figma/v/b3a3ae04257941.svg')),
      gP(332, 186, 9.125, 9.125, gImg('assets/figma/v/e8118c9116f61a.svg')),
      gP(338.875, 192.875, 9.125, 9.125, gImg('assets/figma/v/e8118c9116f61a.svg')),
      gP(40, 288, 133, 18, gText('Ventes par semaine', 14, Color(0xFF111015), weight: 700)),
      gP(320, 290, 30, 14, gText('FCFA', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.right)),
      gP(44, 328, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 389, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 450, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(55.325, 405.636, 27.683, 44.364, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(63.667, 458, 11, 13, gText('S1', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(105.658, 383.455, 27.683, 66.545, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(112.5, 458, 14, 13, gText('S2', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(155.992, 400.091, 27.683, 49.909, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(162.833, 458, 14, 13, gText('S3', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(206.325, 366.818, 27.683, 83.182, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(213.167, 458, 14, 13, gText('S4', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(256.658, 350.182, 27.683, 99.818, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(263.5, 458, 14, 13, gText('S5', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(306.992, 328, 27.683, 122, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(313.833, 458, 14, 13, gText('S6', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 498, 233, 19, gText('Annonces les plus performantes', 15, Color(0xFF111015), weight: 700)),
      gP(40, 550, 135, 16, gText('Lampe en bois recyclé', 12.5, Color(0xFF111015), weight: 600)),
      gP(322, 550, 28, 15, gText('82%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 572, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 572, 254.2, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 594, 101, 16, gText('Sac à dos design', 12.5, Color(0xFF111015), weight: 600)),
      gP(322, 594, 28, 15, gText('64%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 616, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 616, 198.4, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
      gP(40, 638, 115, 16, gText('Support téléphone', 12.5, Color(0xFF111015), weight: 600)),
      gP(325, 638, 25, 15, gText('41%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 660, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 660, 127.1, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
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
