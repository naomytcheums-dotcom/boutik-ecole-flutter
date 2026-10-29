// GÉNÉRÉ par tool/figma_export/convert.py — écran 160 (nœud Figma 60:752). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_160 extends ConsumerWidget {
  const G_160({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 858, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 133.14, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 587.88, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 249, 26, gText('Hackathons et concours', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 120, 85.2, 34, 'En ligne', 12.5, 500), GChip(180.8, 120, 70.4, 34, 'Douala', 12.5, 500), GChip(259.2, 120, 77.8, 34, 'Yaoundé', 12.5, 500), GChip(345, 120, 85.2, 34, 'Gratuits', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 170, gBox(image: 'assets/figma/img/a30d4e56acc9216d03ba2d7972f7dfac533b78bf.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 168, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 276, 309, 23, gText('Hackathon Orange Digital Center', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 304, 309, 15, gText('Inscriptions ouvertes · 48 h · Douala', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(24, 352, 144, 19, gText('Prochains concours', 15, Color(0xFF111015), weight: 700)),
      gP(301, 354, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 359, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 355.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 390, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 403, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 413.333, 9.333, 10.167, gImg('assets/figma/v/ff038cff524fea.svg')),
      gP(58, 413.333, 9.333, 10.167, gImg('assets/figma/v/6d7d6e6c277316.svg')),
      gP(46.333, 428.333, 19.333, 6, gImg('assets/figma/v/3035c903f4ca6a.svg')),
      gP(48, 411.667, 16, 16.833, gImg('assets/figma/v/ddb12173c17b9f.svg')),
      gP(88, 402, 163, 17, gText('Orange Digital Challenge', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 424, 200, 14, gText('14–16 nov. · Douala · 5 000 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(293.6, 412, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(303.8, 416, 38, 14, gText('Ouvert', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 456, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 469, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(56.333, 481, 11, 16, gImg('assets/figma/v/3de20d1ecd59fd.svg')),
      gP(44.667, 481, 11, 16, gImg('assets/figma/v/cfb3b9604bdf74.svg')),
      gP(88, 468, 162, 17, gText('Hackathon IoT et énergie', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 490, 115, 14, gText('28–29 nov. · Yaoundé', 11.5, Color(0xFF66636E))),
      gP(306.4, 478, 45.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(318.2, 482, 22, 14, gText('J-12', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(88, 522, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 535, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 543.667, 16, 16, gImg('assets/figma/v/f44e883cdba29a.svg')),
      gP(50.5, 557, 11, 6, gImg('assets/figma/v/c4124addb3c439.svg')),
      gP(51.333, 560.333, 9.333, 6, gImg('assets/figma/v/df31b3079c9886.svg')),
      gP(88, 534, 203, 17, gText('Concours d’innovation étudia…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 556, 178, 14, gText('En ligne · Prix de 1 000 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(293.6, 544, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(303.8, 548, 38, 14, gText('Ouvert', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 602, 342, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(222.36, 602, 143.64, 132, gBox(image: 'assets/figma/img/6baf8125049f662c1c5c4c23c6b514db2881910c.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(195, 602, 68.4, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF1B3F6E), Color(0x001B3F6E)], stops: [0, 1]))),
      gP(42, 618, 174, 20, gText('Pas encore d’équipe ?', 15, Color(0xFFFFFFFF), weight: 700, lh: 20, wrap: true)),
      gP(42, 664, 160.32, 30, gText('Trouvez des coéquipiers dans l’annuaire des talents.', 11, Color(0xFFE9E4F5), lh: 15, wrap: true)),
      gP(42, 694, 156, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(67.5, 700, 105, 14, gText('Trouver une équipe', 11.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 846, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 770, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 791.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 791.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 803.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 791.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 791.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 791.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 790.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 797.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 804.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 791.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 791.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 799.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 776, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 791, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 789.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
