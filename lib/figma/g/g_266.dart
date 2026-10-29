// GÉNÉRÉ par tool/figma_export/convert.py — écran 266 (nœud Figma 190:468). Ne pas éditer à la main.
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

class G_266 extends ConsumerWidget {
  const G_266({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 24, color: Color(0xFFF7F6F4), children: [
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, gBox(color: Color(0xFFF4F3F1), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(254.375, 23.375, 10, 10, gImg('assets/figma/r/190_474.png')),
      gP(262.938, 31.938, 2.687, 2.687, gImg('assets/figma/r/190_475.png')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFF6A4DFF), Color(0xFFB46BFF)], stops: [0, 1]), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/fa3cac59b84f88.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(26.375, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_489.png')),
      gP(33.25, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_490.png')),
      gP(33.25, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_491.png')),
      gP(26.375, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_492.png')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(12, 138, 216, 34, gBox(color: Color(0xFFFFFFFF), radii: [10, 10, 10, 10])),
      gP(25.75, 148.75, 12.5, 5, gImg('assets/figma/r/190_496.png')),
      gP(25.75, 156.25, 12.5, 5, gImg('assets/figma/r/190_497.png')),
      gP(52, 147, 85, 15, gText('État technique', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(27, 188.75, 10, 12.5, gImg('assets/figma/r/190_500.png')),
      gP(33.25, 188.75, 3.75, 3.75, gImg('assets/figma/r/190_501.png')),
      gP(52, 187, 74, 15, gText('Sauvegardes', 12, Color(0xFF55524C), inter: true)),
      gP(27, 228.75, 10, 12.5, gImg('assets/figma/r/190_504.png')),
      gP(33.25, 228.75, 3.75, 3.75, gImg('assets/figma/r/190_505.png')),
      gP(52, 227, 42, 15, gText('Journal', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 45, 14, gText('Compte', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 57, 11, gText('Boutik-École', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 167, 29, gText('État technique', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 239, 15, gText('Disponibilité des services et sauvegardes.', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(970.125, 90.125, 9.75, 9.75, gImg('assets/figma/r/190_515.png')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1096.667, 91.75, 8.667, 6.5, gImg('assets/figma/r/190_519.png')),
      gP(1102.083, 90.667, 2.167, 2.167, gImg('assets/figma/r/190_520.png')),
      gP(1098.833, 93.917, 2.167, 2.167, gImg('assets/figma/r/190_521.png')),
      gP(1103.167, 97.167, 2.167, 2.167, gImg('assets/figma/r/190_522.png')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(268, 134, 234, 100, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(284, 150, 18, 13, gText('API', 11, Color(0xFF66636E), inter: true)),
      gP(284, 170, 88, 27, gText('99,98 %', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(284, 204, 73.2, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(300.6, 208, 40, 13, gText('En ligne', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(518, 134, 234, 100, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(534, 150, 90, 13, gText('Base de données', 11, Color(0xFF66636E), inter: true)),
      gP(534, 170, 88, 27, gText('99,99 %', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(534, 204, 73.2, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(550.6, 208, 40, 13, gText('En ligne', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(768, 134, 234, 100, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(784, 150, 90, 13, gText('Stockage et CDN', 11, Color(0xFF66636E), inter: true)),
      gP(784, 170, 88, 27, gText('99,95 %', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(784, 204, 73.2, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(800.6, 208, 40, 13, gText('En ligne', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(1018, 134, 234, 100, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(1034, 150, 121, 13, gText('Passerelle de paiement', 11, Color(0xFF66636E), inter: true)),
      gP(1034, 170, 73, 27, gText('99,2 %', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(1034, 204, 66.8, 22, gBox(color: Color(0xFFFFF1D6), radii: [11, 11, 11, 11])),
      gP(1045.9, 208, 43, 13, gText('Dégradé', 10.5, Color(0xFFB26A00), weight: 500, inter: true)),
      gP(268, 254, 610, 272, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(290, 272, 83, 16, gText('Sauvegardes', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(282, 304, 582, 28, gBox(color: Color(0xFFF4F3F1), radii: [10, 10, 10, 10])),
      gP(290, 311, 58, 12, gText('Sauvegarde', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(498, 311, 23, 12, gText('Date', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(648, 311, 25, 12, gText('Taille', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(748, 311, 97, 12, gText('Test de restauration', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(290, 352, 54, 14, gText('Complète', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(498, 352, 79, 14, gText('27 oct. · 02:00', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(648, 352, 42, 14, gText('12,4 Go', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(748, 352, 36, 14, gText('Réussi', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 378, 582, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 396, 54, 14, gText('Complète', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(498, 396, 80, 14, gText('26 oct. · 02:00', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(648, 396, 42, 14, gText('12,3 Go', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 422, 582, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 440, 73, 14, gText('Incrémentale', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(498, 440, 78, 14, gText('26 oct. · 14:00', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(648, 440, 36, 14, gText('0,6 Go', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(748, 440, 12, 14, gText('—', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 466, 582, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 484, 54, 14, gText('Complète', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(498, 484, 80, 14, gText('25 oct. · 02:00', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(648, 484, 42, 14, gText('12,3 Go', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(748, 484, 36, 14, gText('Réussi', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(898, 254, 354, 260, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(920, 274, 178, 17, gText('Restaurer une sauvegarde', 14, Color(0xFF18181B), weight: 600, inter: true)),
      gP(920, 302, 313, 34, gText('Choisir un point de restauration, vérifier puis confirmer. L’action est journalisée.', 11.5, Color(0xFF66636E), inter: true, lh: 17, wrap: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(681, 380, 170, 38, 'Réussi', 11.5, 400), GChip(920, 380, 170, 38, 'Lancer la restauration', 11, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF3D3B37), radius: 19, inter: true)),
      gP(268, 560, 238, 14, gText('Version v1.8.2 · dernière migration le 24 oct.', 11.5, Color(0xFF66636E), inter: true)),
    ]);
  }
}
