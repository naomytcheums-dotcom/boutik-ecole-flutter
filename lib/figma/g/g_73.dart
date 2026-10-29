// GÉNÉRÉ par tool/figma_export/convert.py — écran 73 (nœud Figma 38:326). Ne pas éditer à la main.
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

class G_73 extends ConsumerWidget {
  const G_73({super.key});

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
      gP(76, 70, 164, 26, gText('Mes documents', 21, Color(0xFF111015), weight: 700)),
      gP(342.583, 79, 18.833, 6, gImg('assets/figma/v/6fe571ab77e960.svg')),
      gP(349, 72.583, 6, 18.833, gImg('assets/figma/v/87cbf4a9a18b64.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 120, 54, 34, 'CV', 12.5, 500), GChip(149.6, 120, 85.2, 34, 'Diplômes', 12.5, 500), GChip(242.8, 120, 114.8, 34, 'Attestations', 12.5, 500), GChip(365.6, 120, 129.6, 34, 'Certifications', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 181, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 189.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 189.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 180, 161, 17, gText('CV_Mariam_Essono.pdf', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 202, 130, 14, gText('Mis à jour le 12 oct. 2026', 11.5, Color(0xFF66636E))),
      gP(287.2, 190, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(302.6, 194, 34, 14, gText('Vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 234, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 247, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 255.667, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(48.833, 264.742, 14.333, 13.592, gImg('assets/figma/v/9253f57ddf05f2.svg')),
      gP(88, 246, 183, 17, gText('Diplôme DUT – Informatique', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 268, 75, 14, gText('Session 2025', 11.5, Color(0xFF66636E))),
      gP(287.2, 256, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(302.6, 260, 34, 14, gText('Vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 300, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 313, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 321.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 321.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 312, 133, 17, gText('Attestation de stage', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 334, 138, 14, gText('Orange Cameroun · 2026', 11.5, Color(0xFF66636E))),
      gP(268, 322, 84, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(282.5, 326, 55, 14, gText('En attente', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(88, 366, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 379, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.658, 387.671, 22.672, 22.665, gImg('assets/figma/v/129b28be71ba2e.svg')),
      gP(50.5, 394.333, 11, 9.333, gImg('assets/figma/v/5fb65d78d14660.svg')),
      gP(88, 378, 123, 17, gText('Certification React', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 400, 64, 14, gText('Meta · 2026', 11.5, Color(0xFF66636E))),
      gP(287.2, 388, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(302.6, 392, 34, 14, gText('Vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 446, 342, 50, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [25, 25, 25, 25])),
      gP(124, 462, 167, 18, gText('Téléverser un document', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(98.125, 470.125, 18.75, 10.25, gImg('assets/figma/v/a7e97d2918c17f.svg')),
      gP(100.958, 461.625, 13.083, 9.542, gImg('assets/figma/v/1c26d529dfe91d.svg')),
      gP(104.5, 461.625, 6, 14.5, gImg('assets/figma/v/e216328073b6cc.svg')),
      gP(24, 510, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 525, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 530.916, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 536.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 524, 277, 34, gText('Les documents vérifiés affichent un badge de confiance sur votre profil.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
