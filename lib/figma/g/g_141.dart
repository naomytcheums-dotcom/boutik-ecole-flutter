// GÉNÉRÉ par tool/figma_export/convert.py — écran 141 (nœud Figma 43:1935). Ne pas éditer à la main.
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

class G_141 extends ConsumerWidget {
  const G_141({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 134, 646.667, 216, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(269, 135, 644.667, 39, gBox(color: Color(0xFFF4F1F8), radii: [15, 15, 15, 15])),
      gP(284, 147, 25, 13, gText('Date', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(382.347, 147, 35, 13, gText('Libellé', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(591.333, 147, 29, 13, gText('Débit', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(689.68, 147, 33, 13, gText('Crédit', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(788.027, 147, 58, 13, gText('Rapproché', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(284, 188, 41, 15, gText('22 oct.', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(382.347, 188, 118, 15, gText('Encaissement #0142', 12, Color(0xFF4A4854), inter: true)),
      gP(591.333, 188, 12, 15, gText('—', 12, Color(0xFF4A4854), inter: true)),
      gP(689.68, 188, 41, 15, gText('25 000', 12, Color(0xFF4A4854), inter: true)),
      gP(788.027, 185, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(798.127, 189, 19, 13, gText('Oui', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 218, 622.667, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 232, 41, 15, gText('22 oct.', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(382.347, 232, 134, 15, gText('Commission plateforme', 12, Color(0xFF4A4854), inter: true)),
      gP(591.333, 232, 12, 15, gText('—', 12, Color(0xFF4A4854), inter: true)),
      gP(689.68, 232, 32, 15, gText('1 250', 12, Color(0xFF4A4854), inter: true)),
      gP(788.027, 229, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(798.127, 233, 19, 13, gText('Oui', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 262, 622.667, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 276, 41, 15, gText('22 oct.', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(382.347, 276, 125, 15, gText('Reversement vendeur', 12, Color(0xFF4A4854), inter: true)),
      gP(591.333, 276, 40, 15, gText('23 750', 12, Color(0xFF4A4854), inter: true)),
      gP(689.68, 276, 12, 15, gText('—', 12, Color(0xFF4A4854), inter: true)),
      gP(788.027, 273, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(798.127, 277, 19, 13, gText('Oui', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 306, 622.667, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 320, 39, 15, gText('21 oct.', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(382.347, 320, 118, 15, gText('Encaissement #0138', 12, Color(0xFF4A4854), inter: true)),
      gP(591.333, 320, 12, 15, gText('—', 12, Color(0xFF4A4854), inter: true)),
      gP(689.68, 320, 39, 15, gText('17 000', 12, Color(0xFF4A4854), inter: true)),
      gP(788.027, 317, 39.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(796.627, 321, 22, 13, gText('Non', 11, Color(0xFF8F5400), weight: 600, inter: true, align: TextAlign.center)),
      gP(928.667, 134, 323.333, 188, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(944.667, 148, 66, 17, gText('Synthèse', 14, Color(0xFF111015), weight: 700, inter: true)),
      gP(944.667, 182, 73, 15, gText('Total crédits', 12.5, Color(0xFF66636E), inter: true)),
      gP(1157, 182, 79, 15, gText('43 250 FCFA', 12.5, Color(0xFF111015), weight: 600, inter: true, align: TextAlign.right)),
      gP(944.667, 207, 291.333, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(944.667, 216, 70, 15, gText('Total débits', 12.5, Color(0xFF66636E), inter: true)),
      gP(1158, 216, 78, 15, gText('23 750 FCFA', 12.5, Color(0xFF111015), weight: 600, inter: true, align: TextAlign.right)),
      gP(944.667, 241, 291.333, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(944.667, 250, 34, 15, gText('Solde', 12.5, Color(0xFF66636E), inter: true)),
      gP(1158, 250, 78, 15, gText('19 500 FCFA', 12.5, Color(0xFF111015), weight: 700, inter: true, align: TextAlign.right)),
      gP(944.667, 275, 291.333, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(944.667, 284, 118, 15, gText('Lignes à rapprocher', 12.5, Color(0xFF66636E), inter: true)),
      gP(1229, 284, 7, 15, gText('1', 12.5, Color(0xFF111015), weight: 600, inter: true, align: TextAlign.right)),
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
      gP(12, 178, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(24, 185.75, 16, 18.5, gImg('assets/figma/v/b8b641560aad30.svg')),
      gP(26.5, 189.5, 11, 11, gImg('assets/figma/v/f82584207e62a2.svg')),
      gP(29, 188.562, 6, 12.875, gImg('assets/figma/v/084a5a2da19358.svg')),
      gP(52, 187, 98, 15, gText('Journal financier', 12, Color(0xFF111015), weight: 600, inter: true)),
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
      gP(268, 76, 192, 29, gText('Journal financier', 24, Color(0xFF18181B), weight: 500, inter: true)),
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
      gTap(40, 97, 232, 36, () { gOpen(context, '139'); }), // parcours 141 -> 139
      gTap(40, 137, 232, 36, () { gOpen(context, '140'); }), // parcours 141 -> 140
      gTap(40, 217, 232, 36, () { gOpen(context, '142'); }), // parcours 141 -> 142
      gTap(40, 289, 232, 36, () { gOpen(context, '145'); }), // parcours 141 -> 145
      gTap(40, 329, 232, 36, () { gOpen(context, '147_2'); }), // parcours 141 -> 147_2
      gTap(40, 369, 232, 36, () { gOpen(context, '147_1'); }), // parcours 141 -> 147_1
      gTap(40, 409, 232, 36, () { gOpen(context, '147_3'); }), // parcours 141 -> 147_3
    ]);
  }
}
