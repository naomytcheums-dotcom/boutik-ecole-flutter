// GÉNÉRÉ par tool/figma_export/convert.py — écran 100 (nœud Figma 40:2). Ne pas éditer à la main.
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

class G_100 extends ConsumerWidget {
  const G_100({super.key});

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
      gP(76, 70, 127, 26, gText('Événements', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      gP(26, 120, 44.857, 58, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16, 16, 16, 16])),
      gP(45.429, 129, 6, 14, gText('L', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(37.929, 147, 21, 20, gText('20', 16, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(74.857, 120, 44.857, 58, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16, 16, 16, 16])),
      gP(92.286, 129, 10, 14, gText('M', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(89.286, 147, 16, 20, gText('21', 16, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(123.714, 120, 44.857, 58, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16, 16, 16, 16])),
      gP(141.143, 129, 10, 14, gText('M', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(136.143, 147, 20, 20, gText('22', 16, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(172.571, 120, 44.857, 58, gBox(color: Color(0xFF111015), radii: [16, 16, 16, 16])),
      gP(192.5, 129, 5, 14, gText('J', 11, Color(0xFFFFFFFF), weight: 500, align: TextAlign.center)),
      gP(185, 147, 20, 20, gText('23', 16, Color(0xFFFFFFFF), weight: 700, align: TextAlign.center)),
      gP(221.429, 120, 44.857, 58, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16, 16, 16, 16])),
      gP(239.857, 129, 8, 14, gText('V', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(233.857, 147, 20, 20, gText('24', 16, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(270.286, 120, 44.857, 58, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16, 16, 16, 16])),
      gP(288.714, 129, 8, 14, gText('S', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(282.714, 147, 20, 20, gText('25', 16, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(319.143, 120, 44.857, 58, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16, 16, 16, 16])),
      gP(337.071, 129, 9, 14, gText('D', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331.571, 147, 20, 20, gText('26', 16, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 192, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 192, 107.4, 34, 'Expositions', 12.5, 500), GChip(203, 192, 85.2, 34, 'Ateliers', 12.5, 500), GChip(296.2, 192, 107.4, 34, 'Conférences', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 240, 107, 19, gText('Cette semaine', 15, Color(0xFF111015), weight: 700)),
      gP(36, 291, 40, 40, gBox(color: Color(0xFFFDEFC8), radii: [13, 13, 13, 13])),
      gP(45.5, 301.333, 21, 21, gImg('assets/figma/v/ffe808ced2c9ec.svg')),
      gP(56.333, 299.667, 6, 9.333, gImg('assets/figma/v/357802c04419d8.svg')),
      gP(49.667, 299.667, 6, 9.333, gImg('assets/figma/v/357802c04419d8.svg')),
      gP(45.5, 306.333, 21, 6, gImg('assets/figma/v/dd90762ca86114.svg')),
      gP(88, 290, 173, 17, gText('Exposition des innovations', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 312, 164, 14, gText('Sam. 24 oct. · 10 h · Hall princi…', 11.5, Color(0xFF66636E))),
      gP(287.2, 300, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(300.6, 304, 38, 14, gText('Gratuit', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 344, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 357, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 376.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(47.167, 366.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(58.833, 376.608, 8.5, 10.892, gImg('assets/figma/v/f73f5c2da1a756.svg')),
      gP(56.333, 366.608, 8.507, 12.458, gImg('assets/figma/v/385c8732cbe0ba.svg')),
      gP(88, 356, 167, 17, gText('Atelier : lancer sa micro-…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 378, 140, 14, gText('Mar. 27 oct. · 15 h · Salle B2', 11.5, Color(0xFF66636E))),
      gP(274.4, 366, 77.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(288.7, 370, 49, 14, gText('12 places', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(88, 410, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 423, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46, 433, 20, 20, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(50.5, 431.667, 11, 16, gImg('assets/figma/v/22d610f8612e15.svg')),
      gP(47.167, 438.333, 17.667, 12.667, gImg('assets/figma/v/6098ffef87a747.svg')),
      gP(53, 445, 6, 9.333, gImg('assets/figma/v/357802c04419d8.svg')),
      gP(88, 422, 169, 17, gText('Conférence : innovation …', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 444, 141, 14, gText('Jeu. 29 oct. · 09 h · Amphi 1', 11.5, Color(0xFF66636E))),
      gP(261.6, 432, 90.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(278.3, 436, 57, 14, gText('Inscription', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 490, 342, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(222.36, 490, 143.64, 132, gBox(image: 'assets/figma/img/cbf050b9f90ddf4164a56ebd171cee79dfa21141.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(195, 490, 68.4, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF1B3F6E), Color(0x001B3F6E)], stops: [0, 1]))),
      gP(42, 506, 174, 40, gText('Salon des créations étudiantes', 15, Color(0xFFFFFFFF), weight: 700, lh: 20, wrap: true)),
      gP(42, 552, 160.32, 30, gText('Réservez votre stand avant le 10 nov.', 11, Color(0xFFE9E4F5), lh: 15, wrap: true)),
      gP(42, 582, 86, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(60.5, 588, 49, 14, gText('Réserver', 11.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
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
