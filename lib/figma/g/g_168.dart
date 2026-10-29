// GÉNÉRÉ par tool/figma_export/convert.py — écran 168 (nœud Figma 60:1306). Ne pas éditer à la main.
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

class G_168 extends ConsumerWidget {
  const G_168({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 134, 107, 15, gText('Titre du concours', 12.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(268, 154, 485, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(268, 154, 485, 48, GField(hint: '', initial: 'Orange Digital Challenge 2026', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48, inter: true)),
      gP(281.5, 169, 9, 9.75, gImg('assets/figma/v/d3a1b40bd4dbe5.svg')),
      gP(293.5, 169, 9, 9.75, gImg('assets/figma/v/d53c036a672d8b.svg')),
      gP(283, 182.5, 18, 6, gImg('assets/figma/v/7317aca1f3cfd0.svg')),
      gP(284.5, 167.5, 15, 15.75, gImg('assets/figma/v/8b173b41fcfba8.svg')),
      gP(767, 134, 143, 15, gText('Date limite d’inscription', 12.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(767, 154, 485, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(767, 154, 485, 48, GField(hint: '', initial: '05 nov. 2026', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48, inter: true)),
      gP(781.25, 169, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(791, 167.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(785, 167.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(781.25, 173.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(268, 216, 26, 15, gText('Lieu', 12.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(268, 236, 485, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(268, 236, 485, 48, GField(hint: '', initial: 'Douala · Orange Digital Center', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48, inter: true)),
      gP(283, 249.5, 18, 21, gImg('assets/figma/v/32cd8858f7ce88.svg')),
      gP(286.75, 253.25, 10.5, 10.5, gImg('assets/figma/v/f34fbbf4909aff.svg')),
      gP(767, 216, 97, 15, gText('Dotation (FCFA)', 12.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(767, 236, 485, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(767, 236, 485, 48, GField(hint: '', initial: '5 000 000', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48, inter: true)),
      gP(781.25, 250.25, 20.25, 15.75, gImg('assets/figma/v/a842b4c78dabfc.svg')),
      gP(781.25, 251.75, 19.5, 18, gImg('assets/figma/v/fbc7a9ade9c600.svg')),
      gP(268, 298, 150, 15, gText('Description et règlement', 12.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(268, 318, 984, 96, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(284, 332, 955, 20, gText('Thématique, critères d’évaluation, conditions de participation…', 13.5, Color(0xFF66636E), weight: 500, inter: true, lh: 20, wrap: true)),
      gP(268, 428, 485, 132, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(280, 436, 50, 50, gBox(image: 'assets/figma/img/af86f2e539ad8f1844ccfbe19576723186ea4d78.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(342, 440, 107, 16, gText('Dr Paul Tchoupo', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(342, 462, 106, 14, gText('Jury · Génie logiciel', 11.5, Color(0xFF66636E), inter: true)),
      gP(680.6, 450, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(694.8, 454, 30, 13, gText('Invité', 11, Color(0xFF5A3FE0), weight: 600, inter: true, align: TextAlign.center)),
      gP(342, 494, 399, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(280, 502, 50, 50, gBox(image: 'assets/figma/img/30bc9584eb2f9c6775e8e9cd07fa63239d9b4cc8.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(342, 506, 74, 16, gText('Mme Etoga', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(342, 528, 119, 14, gText('Jury · Communication', 11.5, Color(0xFF66636E), inter: true)),
      gP(667.8, 516, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(678.4, 520, 50, 13, gText('Confirmé', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(767, 428, 485, 52, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(779, 438, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(786.333, 443.916, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(789.875, 449.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(819, 445.5, 420, 17, gText('Un concours publié est relu par l’IUT avant sa diffusion aux étudiants.', 12, Color(0xFF4A4854), inter: true, lh: 17, wrap: true)),
      gP(268, 574, 265, 50, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [25, 25, 25, 25])),
      gP(322.75, 590, 182, 18, gText('Soumettre pour validation', 14.5, Color(0xFFFFFFFF), weight: 600, inter: true, align: TextAlign.center)),
      gP(294.917, 587.667, 22.667, 22.667, gImg('assets/figma/v/37684f95055729.svg')),
      gP(302.417, 587.667, 15.167, 15.167, gImg('assets/figma/v/850ac0825ae325.svg')),
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
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(23.375, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(12, 138, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(22.75, 147, 8.5, 9.125, gImg('assets/figma/v/503a69516ca4d8.svg')),
      gP(32.75, 147, 8.5, 9.125, gImg('assets/figma/v/dc81bfdeec4c62.svg')),
      gP(24, 158.25, 16, 6, gImg('assets/figma/v/2993ac4df31426.svg')),
      gP(25.25, 145.75, 13.5, 14.125, gImg('assets/figma/v/3f9d72106d9de9.svg')),
      gP(52, 147, 82, 15, gText('Mes concours', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(22.75, 193.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(24.625, 186.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(33.375, 193.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(31.5, 186.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(52, 187, 66, 15, gText('Inscriptions', 12, Color(0xFF55524C), inter: true)),
      gP(25.25, 225.75, 13.5, 13.5, gImg('assets/figma/v/c741934f1ce95f.svg')),
      gP(25.875, 232.556, 12.25, 11.694, gImg('assets/figma/v/1fd18b4a4a1f32.svg')),
      gP(52, 227, 90, 15, gText('Jury et mentors', 12, Color(0xFF55524C), inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 298.375, 17.25, 17.25, gImg('assets/figma/v/0e8e9b6945f1c7.svg')),
      gP(32.75, 302.125, 6, 11, gImg('assets/figma/v/4b7c01062373f8.svg')),
      gP(29.625, 299.625, 6, 13.5, gImg('assets/figma/v/9e3bcb7e9c574c.svg')),
      gP(26.5, 305.25, 6, 7.875, gImg('assets/figma/v/5eccc4607ecf23.svg')),
      gP(52, 299, 53, 15, gText('Résultats', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 339, 18.5, 16, gImg('assets/figma/v/e1d196eb6236c9.svg')),
      gP(22.75, 340.875, 18.5, 10.375, gImg('assets/figma/v/4a77c5a18dd747.svg')),
      gP(52, 339, 89, 15, gText('Communication', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 121, 14, gText('Orange Digital Center', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 107, 11, gText('Organisateur partenaire', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 229, 29, gText('Publier un concours', 24, Color(0xFF18181B), weight: 500, inter: true)),
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
