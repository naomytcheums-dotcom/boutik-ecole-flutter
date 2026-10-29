// GÉNÉRÉ par tool/figma_export/convert.py — écran 142 (nœud Figma 43:2046). Ne pas éditer à la main.
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

class G_142 extends ConsumerWidget {
  const G_142({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 16, color: Color(0xFFF7F6F4), children: [
      Positioned.fill(child: GChoiceGroup(chips: [GChip(268, 134, 55.6, 34, 'Mois', 12.5, 600), GChip(331.6, 134, 92.6, 34, 'Trimestre', 12.5, 500), GChip(432.2, 134, 63, 34, 'Année', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, inter: true)),
      gP(268, 182, 485, 210, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(284, 196, 290, 17, gText('Encaissements par département (M FCFA)', 14, Color(0xFF111015), weight: 700, inter: true)),
      gP(708, 198, 29, 14, gText('FCFA', 11.5, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.right)),
      gP(288, 236, 445, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(288, 297, 445, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(288, 358, 445, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(315.5, 236, 34, 122, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(322.5, 366, 20, 13, gText('Info', 10.5, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(404.5, 256.62, 34, 101.38, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(410.5, 366, 22, 13, gText('Civil', 10.5, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(493.5, 275.521, 34, 82.479, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(499, 366, 22, 13, gText('MMI', 10.5, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(582.5, 297, 34, 61, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(587, 366, 25, 13, gText('Élec.', 10.5, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(671.5, 310.746, 34, 47.254, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(676, 366, 24, 13, gText('Agro', 10.5, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(767, 182, 485, 216, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(768, 183, 483, 39, gBox(color: Color(0xFFF4F1F8), radii: [15, 15, 15, 15])),
      gP(783, 195, 46, 13, gText('Vendeur', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(964.2, 195, 38, 13, gText('Ventes', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(1100.1, 195, 66, 13, gText('Commission', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(783, 236, 60, 15, gText('M. Essono', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(964.2, 236, 57, 15, gText('1 245 000', 12, Color(0xFF4A4854), inter: true)),
      gP(1100.1, 236, 41, 15, gText('62 250', 12, Color(0xFF4A4854), inter: true)),
      gP(779, 266, 461, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(783, 280, 69, 15, gText('Y. Mouanga', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(964.2, 280, 49, 15, gText('860 000', 12, Color(0xFF4A4854), inter: true)),
      gP(1100.1, 280, 42, 15, gText('43 000', 12, Color(0xFF4A4854), inter: true)),
      gP(779, 310, 461, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(783, 324, 44, 15, gText('A. Bello', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(964.2, 324, 49, 15, gText('540 000', 12, Color(0xFF4A4854), inter: true)),
      gP(1100.1, 324, 40, 15, gText('27 000', 12, Color(0xFF4A4854), inter: true)),
      gP(779, 354, 461, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(783, 368, 71, 15, gText('B. Ndoumbe', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(964.2, 368, 49, 15, gText('320 000', 12, Color(0xFF4A4854), inter: true)),
      gP(1100.1, 368, 39, 15, gText('16 000', 12, Color(0xFF4A4854), inter: true)),
      gP(268, 412, 984, 50, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [24, 24, 24, 24])),
      gP(706, 428, 133, 18, gText('Exporter le rapport', 14.5, Color(0xFF111015), weight: 600, inter: true, align: TextAlign.center)),
      gP(680.125, 436.125, 18.75, 10.25, gImg('assets/figma/v/e0834926a737bf.svg')),
      gP(682.958, 432.583, 13.083, 9.542, gImg('assets/figma/v/3ee7d7ad9e826a.svg')),
      gP(686.5, 427.625, 6, 14.5, gImg('assets/figma/v/c6f78b73bf1246.svg')),
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(251.375, 20.375, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(259.938, 28.938, 8.687, 8.687, gImg('assets/figma/v/ee5ed5a7003f46.svg')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(color: Color(0xFF111015), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/c7f198a8ce01e5.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(23.375, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 146.375, 17.875, 14.125, gImg('assets/figma/v/b45a94448c908a.svg')),
      gP(23.375, 147.625, 17.25, 16, gImg('assets/figma/v/942aaa660c45c9.svg')),
      gP(52, 147, 111, 15, gText('Paiements déclarés', 12, Color(0xFF55524C), inter: true)),
      gP(24, 185.75, 16, 18.5, gImg('assets/figma/v/b8b641560aad30.svg')),
      gP(26.5, 189.5, 11, 11, gImg('assets/figma/v/f82584207e62a2.svg')),
      gP(29, 188.562, 6, 12.875, gImg('assets/figma/v/084a5a2da19358.svg')),
      gP(52, 187, 95, 15, gText('Journal financier', 12, Color(0xFF55524C), inter: true)),
      gP(12, 218, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(23.375, 226.375, 17.25, 17.25, gImg('assets/figma/v/0e8e9b6945f1c7.svg')),
      gP(32.75, 230.125, 6, 11, gImg('assets/figma/v/4b7c01062373f8.svg')),
      gP(29.625, 227.625, 6, 13.5, gImg('assets/figma/v/9e3bcb7e9c574c.svg')),
      gP(26.5, 233.25, 6, 7.875, gImg('assets/figma/v/5eccc4607ecf23.svg')),
      gP(52, 227, 54, 15, gText('Rapports', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 298.375, 17.25, 16.625, gImg('assets/figma/v/0e7bfe7735ff71.svg')),
      gP(23.375, 301.5, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(29, 303.375, 6, 9.125, gImg('assets/figma/v/43269c010b1817.svg')),
      gP(52, 299, 91, 15, gText('Points de retrait', 12, Color(0xFF55524C), inter: true)),
      gP(22.739, 338.366, 18.51, 17.259, gImg('assets/figma/v/2adfe02c023131.svg')),
      gP(29, 342.125, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(29, 347.125, 6.006, 6, gImg('assets/figma/v/ea7a417c4e88fe.svg')),
      gP(52, 339, 106, 15, gText('Incidents kiosques', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 377.75, 18.5, 18.5, gImg('assets/figma/v/273a872595c6ee.svg')),
      gP(27.181, 380.872, 9.644, 9.753, gImg('assets/figma/v/cb78fa82cc0c37.svg')),
      gP(29, 387.125, 6.006, 6, gImg('assets/figma/v/ea7a417c4e88fe.svg')),
      gP(52, 379, 89, 15, gText('Tickets support', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 418.38, 17.25, 17.25, gImg('assets/figma/v/a50cd9410c0076.svg')),
      gP(23.375, 418.375, 9.125, 9.125, gImg('assets/figma/v/3ad9c2af89ef3b.svg')),
      gP(29, 420.875, 8.5, 10.375, gImg('assets/figma/v/23a92abb65788c.svg')),
      gP(52, 419, 75, 15, gText('Interventions', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 44, 14, gText('Finance', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 98, 11, gText('Finance et opérations', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 225, 29, gText('Rapports financiers', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 226, 15, gText('Vue d’ensemble · mise à jour aujourd’hui', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(967.125, 87.125, 15.75, 15.75, gImg('assets/figma/v/e1d0d9c2726ec6.svg')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1093.667, 88.75, 14.667, 12.5, gImg('assets/figma/v/54d63e10c1f201.svg')),
      gP(1099.083, 87.667, 8.167, 8.167, gImg('assets/figma/v/aa6a66611de441.svg')),
      gP(1095.833, 90.917, 8.167, 8.167, gImg('assets/figma/v/aa6a66611de441.svg')),
      gP(1100.167, 94.167, 8.167, 8.167, gImg('assets/figma/v/aa6a66611de441.svg')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
    ]);
  }
}
