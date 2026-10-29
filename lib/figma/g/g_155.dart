// GÉNÉRÉ par tool/figma_export/convert.py — écran 155 (nœud Figma 60:377). Ne pas éditer à la main.
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

class G_155 extends ConsumerWidget {
  const G_155({super.key});

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
      gP(24, 70, 74, 26, gText('Alertes', 21, Color(0xFF111015), weight: 700)),
      gP(346.25, 76.25, 11.5, 11.5, gImg('assets/figma/v/dd7f4ecaa9b199.svg')),
      gP(339.833, 69.833, 24.333, 24.333, gImg('assets/figma/v/e60784a24bd7e3.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 70.4, 34, 'Toutes', 12.5, 600), GChip(102.4, 120, 77.8, 34, 'Dossier', 12.5, 500), GChip(188.2, 120, 70.4, 34, 'Offres', 12.5, 500), GChip(266.6, 120, 122.2, 34, 'Dates limites', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 85, 19, gText('Aujourd’hui', 15, Color(0xFF111015), weight: 700)),
      gP(36, 219, 40, 40, gBox(color: Color(0xFFFDE6E7), radii: [13, 13, 13, 13])),
      gP(44.652, 228.488, 22.68, 21.012, gImg('assets/figma/v/b4a6b4937f8754.svg')),
      gP(53, 233.5, 6, 9.333, gImg('assets/figma/v/357802c04419d8.svg')),
      gP(53, 240.167, 6.008, 6, gImg('assets/figma/v/7a0aba9eeb97a7.svg')),
      gP(88, 218, 119, 17, gText('Dossier incomplet', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 240, 191, 14, gText('Il manque votre certificat de scola…', 11.5, Color(0xFF66636E))),
      gP(293.6, 228, 58.4, 22, gBox(color: Color(0xFFFDE6E7), radii: [11, 11, 11, 11])),
      gP(305.3, 232, 35, 14, gText('Action', 11, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(88, 272, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 285, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.917, 293.667, 20.167, 19.75, gImg('assets/figma/v/f0d089e1b980ff.svg')),
      gP(56.333, 304.5, 11, 11, gImg('assets/figma/v/b5d7b991b3a965.svg')),
      gP(88, 284, 170, 17, gText('Nouvelle offre compatible', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 306, 166, 14, gText('Stage développeur web · 92 %', 11.5, Color(0xFF66636E))),
      gP(306.4, 294, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(318.7, 298, 21, 14, gText('Voir', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 338, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 351, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 359.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 363, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 350, 149, 17, gText('Date limite dans 2 jours', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 372, 181, 14, gText('Hackathon Orange Digital Center', 11.5, Color(0xFF66636E))),
      gP(312.8, 360, 39.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(323.4, 364, 18, 14, gText('J-2', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 418, 107, 19, gText('Cette semaine', 15, Color(0xFF111015), weight: 700)),
      gP(36, 469, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 477.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 477.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 468, 153, 17, gText('Candidature mise à jour', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 490, 162, 14, gText('Camlight · Entretien à planifier', 11.5, Color(0xFF66636E))),
      gP(336.75, 481.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 522, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 535, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 554.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(47.167, 544.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(58.833, 554.608, 8.5, 10.892, gImg('assets/figma/v/f73f5c2da1a756.svg')),
      gP(56.333, 544.608, 8.507, 12.458, gImg('assets/figma/v/385c8732cbe0ba.svg')),
      gP(88, 534, 123, 17, gText('Invitation d’équipe', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 556, 123, 14, gText('Team Innov’ vous invite', 11.5, Color(0xFF66636E))),
      gP(280.8, 544, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(289.9, 548, 53, 14, gText('Répondre', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
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
