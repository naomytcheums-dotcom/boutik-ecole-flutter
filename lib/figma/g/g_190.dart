// GÉNÉRÉ par tool/figma_export/convert.py — écran 190 (nœud Figma 61:1610). Ne pas éditer à la main.
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

class G_190 extends ConsumerWidget {
  const G_190({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 880, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 160, 984, 1, gBox(color: Color(0xFFECE8F2))),
      gP(404, 134, 56, 16, gText('En cours', 13, Color(0xFF111015), weight: 700, inter: true, align: TextAlign.center)),
      gP(317.2, 158, 229.6, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(730.5, 134, 59, 16, gText('Acceptés', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(1063, 134, 51, 16, gText('Refusés', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(268, 178, 984, 172, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(269, 179, 982, 39, gBox(color: Color(0xFFF4F1F8), radii: [15, 15, 15, 15])),
      gP(284, 191, 30, 13, gText('Devis', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(550.56, 191, 59, 13, gText('Prestataire', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(760, 191, 85, 13, gText('Montant (FCFA)', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(931.36, 191, 52, 13, gText('Mis à jour', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(1064.64, 191, 33, 13, gText('Statut', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(284, 232, 174, 15, gText('DEV-2026-014 · Borne solaire', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(550.56, 232, 68, 15, gText('Team Innov’', 12, Color(0xFF4A4854), inter: true)),
      gP(760, 232, 49, 15, gText('450 000', 12, Color(0xFF4A4854), inter: true)),
      gP(931.36, 232, 63, 15, gText('Aujourd’hui', 12, Color(0xFF4A4854), inter: true)),
      gP(1064.64, 229, 90.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(1077.84, 233, 65, 13, gText('Négociation', 11, Color(0xFF8F5400), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 262, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 276, 194, 15, gText('DEV-2026-012 · Application CRM', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(550.56, 276, 56, 15, gText('Mariam E.', 12, Color(0xFF4A4854), inter: true)),
      gP(760, 276, 41, 15, gText('80 000', 12, Color(0xFF4A4854), inter: true)),
      gP(931.36, 276, 24, 15, gText('Hier', 12, Color(0xFF4A4854), inter: true)),
      gP(1064.64, 273, 77.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(1080.44, 277, 47, 13, gText('À valider', 11, Color(0xFF5A3FE0), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 306, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 320, 184, 15, gText('DEV-2026-009 · Logo et charte', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(550.56, 320, 61, 15, gText('Aminata B.', 12, Color(0xFF4A4854), inter: true)),
      gP(760, 320, 41, 15, gText('65 000', 12, Color(0xFF4A4854), inter: true)),
      gP(931.36, 320, 40, 15, gText('20 oct.', 12, Color(0xFF4A4854), inter: true)),
      gP(1064.64, 317, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(1075.04, 321, 45, 13, gText('Accepté', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
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
      gP(0, 56, 240, 824, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(23.375, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(24, 145.75, 16, 18.5, gImg('assets/figma/v/ff64e2b6a5eb10.svg')),
      gP(30.25, 145.75, 9.75, 9.75, gImg('assets/figma/v/3b2d5604a267d0.svg')),
      gP(52, 147, 89, 15, gText('Besoins publiés', 12, Color(0xFF55524C), inter: true)),
      gP(24.5, 187.5, 15, 15, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(23.375, 186.375, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(31.938, 194.938, 8.687, 8.687, gImg('assets/figma/v/ee5ed5a7003f46.svg')),
      gP(52, 187, 121, 15, gText('Recherche de talents', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 232, 18.5, 7.875, gImg('assets/figma/v/7200c2482969af.svg')),
      gP(22.75, 227, 18.5, 16, gImg('assets/figma/v/137742ca7afd1b.svg')),
      gP(52, 227, 71, 15, gText('Propositions', 12, Color(0xFF55524C), inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(12, 290, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(24, 297.75, 16, 18.5, gImg('assets/figma/v/b8b641560aad30.svg')),
      gP(26.5, 301.5, 11, 11, gImg('assets/figma/v/f82584207e62a2.svg')),
      gP(29, 300.562, 6, 12.875, gImg('assets/figma/v/084a5a2da19358.svg')),
      gP(52, 299, 33, 15, gText('Devis', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(22.75, 345.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(24.625, 338.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(33.375, 345.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(31.5, 338.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(52, 339, 82, 15, gText('Collaborations', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 379, 8.5, 9.125, gImg('assets/figma/v/503a69516ca4d8.svg')),
      gP(32.75, 379, 8.5, 9.125, gImg('assets/figma/v/dc81bfdeec4c62.svg')),
      gP(24, 390.25, 16, 6, gImg('assets/figma/v/2993ac4df31426.svg')),
      gP(25.25, 377.75, 13.5, 14.125, gImg('assets/figma/v/3f9d72106d9de9.svg')),
      gP(52, 379, 114, 15, gText('Hackathons et défis', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 420.875, 18.5, 14.75, gImg('assets/figma/v/95b3663071ee25.svg')),
      gP(26.5, 418.375, 11, 17.25, gImg('assets/figma/v/4aa62e9dd5b95e.svg')),
      gP(52, 419, 73, 15, gText('Recrutement', 12, Color(0xFF55524C), inter: true)),
      gP(12, 804, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 814, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 817, 91, 14, gText('Mme Nguimfack', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 834, 82, 11, gText('Orange Cameroun', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 247, 29, gText('Devis et négociations', 24, Color(0xFF18181B), weight: 500, inter: true)),
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
