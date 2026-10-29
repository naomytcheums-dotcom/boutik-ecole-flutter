// GÉNÉRÉ par tool/figma_export/convert.py — écran 147-1 (nœud Figma 43:2783). Ne pas éditer à la main.
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

class G_147_1 extends ConsumerWidget {
  const G_147_1({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 880, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 160, 984, 1, gBox(color: Color(0xFFECE8F2))),
      gP(351, 134, 81, 16, gText('Ouverts (14)', 13, Color(0xFF111015), weight: 700, inter: true, align: TextAlign.center)),
      gP(304.9, 158, 172.2, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(599, 134, 76, 16, gText('En cours (6)', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(858.5, 134, 49, 16, gText('Résolus', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(1098, 134, 63, 16, gText('Escaladés', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(268, 178, 984, 216, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(269, 179, 982, 39, gBox(color: Color(0xFFF4F1F8), radii: [15, 15, 15, 15])),
      gP(284, 191, 34, 13, gText('Ticket', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(417.28, 191, 28, 13, gText('Sujet', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(721.92, 191, 62, 13, gText('Demandeur', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(912.32, 191, 27, 13, gText('Reçu', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(1045.6, 191, 33, 13, gText('Statut', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(284, 232, 50, 15, gText('#T-2041', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(417.28, 232, 128, 15, gText('Paiement non reconnu', 12, Color(0xFF4A4854), inter: true)),
      gP(721.92, 232, 59, 15, gText('M. Essono', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 232, 46, 15, gText('Il y a 1 h', 12, Color(0xFF4A4854), inter: true)),
      gP(1045.6, 229, 58.4, 22, gBox(color: Color(0xFFFDE6E7), radii: [11, 11, 11, 11])),
      gP(1056.3, 233, 37, 13, gText('Urgent', 11, Color(0xFFE5484D), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 262, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 276, 52, 15, gText('#T-2040', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(417.28, 276, 102, 15, gText('Retrait impossible', 12, Color(0xFF4A4854), inter: true)),
      gP(721.92, 276, 67, 15, gText('Y. Mouanga', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 276, 48, 15, gText('Il y a 3 h', 12, Color(0xFF4A4854), inter: true)),
      gP(1045.6, 273, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(1057.7, 277, 47, 13, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 306, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 320, 52, 15, gText('#T-2038', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(417.28, 320, 124, 15, gText('Modifier une annonce', 12, Color(0xFF4A4854), inter: true)),
      gP(721.92, 320, 43, 15, gText('A. Bello', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 320, 24, 15, gText('Hier', 12, Color(0xFF4A4854), inter: true)),
      gP(1045.6, 317, 58.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(1056.8, 321, 37, 13, gText('Ouvert', 11, Color(0xFF8F5400), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 350, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 364, 52, 15, gText('#T-2035', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(417.28, 364, 88, 15, gText('Compte bloqué', 12, Color(0xFF4A4854), inter: true)),
      gP(721.92, 364, 59, 15, gText('C. Mbarga', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 364, 24, 15, gText('Hier', 12, Color(0xFF4A4854), inter: true)),
      gP(1045.6, 361, 71.2, 22, gBox(color: Color(0xFFF2EFF6), radii: [11, 11, 11, 11])),
      gP(1056.7, 365, 49, 13, gText('Escaladé', 11, Color(0xFF66636E), weight: 600, inter: true, align: TextAlign.center)),
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, gBox(color: Color(0xFFF4F3F1), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(251.375, 20.375, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(259.938, 28.938, 8.687, 8.687, gImg('assets/figma/v/ee5ed5a7003f46.svg')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(color: Color(0xFF111015), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/c7f198a8ce01e5.svg')),
      gP(0, 56, 240, 824, gBox(color: Color(0xFFF1EFEC))),
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
      gP(23.375, 226.375, 17.25, 17.25, gImg('assets/figma/v/0e8e9b6945f1c7.svg')),
      gP(32.75, 230.125, 6, 11, gImg('assets/figma/v/4b7c01062373f8.svg')),
      gP(29.625, 227.625, 6, 13.5, gImg('assets/figma/v/9e3bcb7e9c574c.svg')),
      gP(26.5, 233.25, 6, 7.875, gImg('assets/figma/v/5eccc4607ecf23.svg')),
      gP(52, 227, 52, 15, gText('Rapports', 12, Color(0xFF55524C), inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 298.375, 17.25, 16.625, gImg('assets/figma/v/0e7bfe7735ff71.svg')),
      gP(23.375, 301.5, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(29, 303.375, 6, 9.125, gImg('assets/figma/v/43269c010b1817.svg')),
      gP(52, 299, 91, 15, gText('Points de retrait', 12, Color(0xFF55524C), inter: true)),
      gP(22.739, 338.366, 18.51, 17.259, gImg('assets/figma/v/2adfe02c023131.svg')),
      gP(29, 342.125, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(29, 347.125, 6.006, 6, gImg('assets/figma/v/ea7a417c4e88fe.svg')),
      gP(52, 339, 106, 15, gText('Incidents kiosques', 12, Color(0xFF55524C), inter: true)),
      gP(12, 370, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(22.75, 377.75, 18.5, 18.5, gImg('assets/figma/v/273a872595c6ee.svg')),
      gP(27.181, 380.872, 9.644, 9.753, gImg('assets/figma/v/cb78fa82cc0c37.svg')),
      gP(29, 387.125, 6.006, 6, gImg('assets/figma/v/ea7a417c4e88fe.svg')),
      gP(52, 379, 92, 15, gText('Tickets support', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(23.375, 418.38, 17.25, 17.25, gImg('assets/figma/v/a50cd9410c0076.svg')),
      gP(23.375, 418.375, 9.125, 9.125, gImg('assets/figma/v/3ad9c2af89ef3b.svg')),
      gP(29, 420.875, 8.5, 10.375, gImg('assets/figma/v/23a92abb65788c.svg')),
      gP(52, 419, 75, 15, gText('Interventions', 12, Color(0xFF55524C), inter: true)),
      gP(12, 804, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 814, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 817, 44, 14, gText('Finance', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 834, 98, 11, gText('Finance et opérations', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 216, 29, gText('Tickets de support', 24, Color(0xFF18181B), weight: 500, inter: true)),
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
