// GÉNÉRÉ par tool/figma_export/convert.py — écran 122 (nœud Figma 42:729). Ne pas éditer à la main.
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

class G_122 extends ConsumerWidget {
  const G_122({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 880, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 160, 984, 1, gBox(color: Color(0xFFECE8F2))),
      gP(330, 134, 122, 16, gText('Annonces produits', 13, Color(0xFF111015), weight: 700, inter: true, align: TextAlign.center)),
      gP(304.9, 158, 172.2, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(610, 134, 54, 16, gText('Services', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(860.5, 134, 44, 16, gText('Projets', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(1098.5, 134, 60, 16, gText('Vendeurs', 13, Color(0xFF66636E), weight: 500, inter: true, align: TextAlign.center)),
      gP(277, 200, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(268, 179, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(271.333, 183.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(300, 178, 448, 16, gText('1. Soumission par l’étudiant', 13.5, Color(0xFF111015), weight: 600, inter: true, wrap: true)),
      gP(300, 198, 448, 14, gText('Brouillon → À valider', 11.5, Color(0xFF66636E), inter: true, wrap: true)),
      gP(277, 262, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(268, 241, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(300, 240, 448, 16, gText('2. Contrôle du département', 13.5, Color(0xFF111015), weight: 600, inter: true, wrap: true)),
      gP(300, 260, 448, 14, gText('Responsable de département · 48 h max', 11.5, Color(0xFF66636E), inter: true, wrap: true)),
      gP(268, 303, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(300, 302, 448, 16, gText('3. Validation institutionnelle', 13.5, Color(0xFF111015), weight: 600, inter: true, wrap: true)),
      gP(300, 322, 448, 14, gText('Si montant > 100 000 FCFA', 11.5, Color(0xFF66636E), inter: true, wrap: true)),
      gP(767, 178, 485, 198, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(783, 190, 266, 16, gText('Validation automatique sous 5 000 FCFA', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(783, 212, 144, 14, gText('Sans intervention humaine', 11.5, Color(0xFF66636E), inter: true)),
      gP(1194, 199, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(783, 244, 457, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(783, 256, 283, 16, gText('Double validation au-delà de 100 000 FCFA', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(783, 278, 140, 14, gText('Département + institution', 11.5, Color(0xFF66636E), inter: true)),
      gP(1194, 265, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(783, 310, 457, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(783, 322, 160, 16, gText('Notification de l’étudiant', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(783, 344, 100, 14, gText('À chaque décision', 11.5, Color(0xFF66636E), inter: true)),
      gP(1194, 331, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(268, 390, 984, 52, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(280, 400, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(285.917, 405.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(293, 413, 6, 8.833, gImg('assets/figma/v/9fc27387b9ffa1.svg')),
      gP(293, 410.167, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(320, 407.5, 919, 17, gText('Les délais et seuils sont des paramètres configurables, à confirmer avec l’IUT avant mise en production.', 12, Color(0xFF4A4854), inter: true, lh: 17, wrap: true)),
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
      gP(23.375, 157.625, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(24.625, 146.375, 14.75, 17.25, gImg('assets/figma/v/b3da102be08062.svg')),
      gP(27.125, 153.875, 9.75, 9.75, gImg('assets/figma/v/c0732433837967.svg')),
      gP(52, 147, 80, 15, gText('Établissement', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 185.75, 18.5, 12.25, gImg('assets/figma/v/a8962ce588a956.svg')),
      gP(22.75, 195.125, 18.5, 9.125, gImg('assets/figma/v/24a45f8b5f58fe.svg')),
      gP(22.75, 192, 18.5, 9.125, gImg('assets/figma/v/24a45f8b5f58fe.svg')),
      gP(52, 187, 81, 15, gText('Départements', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 233.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(24.625, 226.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(33.375, 233.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(31.5, 226.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(52, 227, 64, 15, gText('Utilisateurs', 12, Color(0xFF55524C), inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(25.25, 297.75, 13.5, 13.5, gImg('assets/figma/v/c741934f1ce95f.svg')),
      gP(25.875, 304.556, 12.25, 11.694, gImg('assets/figma/v/1fd18b4a4a1f32.svg')),
      gP(52, 299, 79, 15, gText('Responsables', 12, Color(0xFF55524C), inter: true)),
      gP(12, 330, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(24, 337.75, 16, 18.502, gImg('assets/figma/v/eb1ca16ae0995f.svg')),
      gP(27.125, 342.75, 9.75, 8.5, gImg('assets/figma/v/67b1d949f5166f.svg')),
      gP(52, 339, 123, 15, gText('Circuits de validation', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(22.75, 380.875, 18.5, 12.25, gImg('assets/figma/v/b8aa2d550e4e95.svg')),
      gP(31.5, 380.875, 9.75, 9.75, gImg('assets/figma/v/bf4c9c3198e949.svg')),
      gP(52, 379, 99, 15, gText('Activité et ventes', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 419, 17.25, 17.25, gImg('assets/figma/v/acdac738c047b0.svg')),
      gP(31.5, 417.75, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(26.5, 417.75, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(23.375, 422.75, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(52, 419, 70, 15, gText('Événements', 12, Color(0xFF55524C), inter: true)),
      gP(24, 457.75, 16, 18.5, gImg('assets/figma/v/ff64e2b6a5eb10.svg')),
      gP(30.25, 457.75, 9.75, 9.75, gImg('assets/figma/v/3b2d5604a267d0.svg')),
      gP(52, 459, 52, 15, gText('Rapports', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 498.38, 17.25, 17.25, gImg('assets/figma/v/a50cd9410c0076.svg')),
      gP(23.375, 498.375, 9.125, 9.125, gImg('assets/figma/v/3ad9c2af89ef3b.svg')),
      gP(29, 500.875, 8.5, 10.375, gImg('assets/figma/v/23a92abb65788c.svg')),
      gP(52, 499, 83, 15, gText('Journal d’audit', 12, Color(0xFF55524C), inter: true)),
      gP(12, 804, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 814, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 817, 51, 14, gText('Direction', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 834, 64, 11, gText('IUT de Douala', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 241, 29, gText('Circuits de validation', 24, Color(0xFF18181B), weight: 500, inter: true)),
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
