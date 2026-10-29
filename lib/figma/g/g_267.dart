// GÉNÉRÉ par tool/figma_export/convert.py — écran 267 (nœud Figma 190:576). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_267 extends ConsumerWidget {
  const G_267({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 24, color: Color(0xFFF7F6F4), children: [
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, gBox(color: Color(0xFFF4F3F1), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(254.375, 23.375, 10, 10, gImg('assets/figma/r/190_582.png')),
      gP(262.938, 31.938, 2.687, 2.687, gImg('assets/figma/r/190_583.png')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFF6A4DFF), Color(0xFFB46BFF)], stops: [0, 1]), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/fa3cac59b84f88.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(12, 98, 216, 34, gBox(color: Color(0xFFFFFFFF), radii: [10, 10, 10, 10])),
      gP(25.75, 108.75, 12.5, 12.5, gImg('assets/figma/r/190_598.png')),
      gP(25.75, 108.75, 12.5, 12.5, gImg('assets/figma/r/190_599.png')),
      gP(52, 107, 43, 15, gText('Réseau', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(25.75, 156.875, 8.75, 3.75, gImg('assets/figma/r/190_602.png')),
      gP(27.625, 149.375, 5, 5, gImg('assets/figma/r/190_603.png')),
      gP(52, 147, 86, 15, gText('Établissements', 12, Color(0xFF55524C), inter: true)),
      gP(27, 188.75, 10, 12.5, gImg('assets/figma/r/190_606.png')),
      gP(33.25, 188.75, 3.75, 3.75, gImg('assets/figma/r/190_607.png')),
      gP(52, 187, 107, 15, gText('Catalogue national', 12, Color(0xFF55524C), inter: true)),
      gP(26.375, 229.375, 11.25, 11.25, gImg('assets/figma/r/190_610.png')),
      gP(32.75, 230.125, 6, 11, gImg('assets/figma/v/b2867692617a9a.svg')),
      gP(29.625, 227.625, 6, 13.5, gImg('assets/figma/v/0d8c4702dd5e00.svg')),
      gP(26.5, 233.25, 6, 7.875, gImg('assets/figma/v/621e69cfea1f7e.svg')),
      gP(52, 227, 103, 15, gText('Défis intercampus', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 45, 14, gText('Compte', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 57, 11, gText('Boutik-École', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 250, 29, gText('Boutik-École Network', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 213, 15, gText('Portail du réseau des établissements.', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(970.125, 90.125, 9.75, 9.75, gImg('assets/figma/r/190_623.png')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1096.667, 91.75, 8.667, 6.5, gImg('assets/figma/r/190_627.png')),
      gP(1102.083, 90.667, 2.167, 2.167, gImg('assets/figma/r/190_628.png')),
      gP(1098.833, 93.917, 2.167, 2.167, gImg('assets/figma/r/190_629.png')),
      gP(1103.167, 97.167, 2.167, 2.167, gImg('assets/figma/r/190_630.png')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(268, 134, 443, 560, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(330.758, 170, 317.483, 470, gImg('assets/figma/r/190_633.png')),
      gP(731, 134, 521, 66, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(755, 150, 88, 16, gText('IUT de Douala', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(755, 172, 187, 13, gText('Catalogue partagé · étudiants actifs', 11, Color(0xFF66636E), inter: true)),
      gP(1174, 158, 54, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(1189, 162, 24, 13, gText('Actif', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(731, 210, 521, 66, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(755, 226, 104, 16, gText('IUT de Bandjoun', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(755, 248, 187, 13, gText('Catalogue partagé · étudiants actifs', 11, Color(0xFF66636E), inter: true)),
      gP(1174, 234, 54, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(1189, 238, 24, 13, gText('Actif', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(731, 286, 521, 66, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(755, 302, 122, 16, gText('IUT de Ngaoundéré', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(755, 324, 187, 13, gText('Catalogue partagé · étudiants actifs', 11, Color(0xFF66636E), inter: true)),
      gP(1174, 310, 54, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(1189, 314, 24, 13, gText('Actif', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(731, 362, 521, 66, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(755, 378, 145, 16, gText('Université partenaire A', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(755, 400, 187, 13, gText('Catalogue partagé · étudiants actifs', 11, Color(0xFF66636E), inter: true)),
      gP(1135.6, 386, 92.4, 22, gBox(color: Color(0xFFFFF1D6), radii: [11, 11, 11, 11])),
      gP(1154.3, 390, 55, 13, gText('Intégration', 10.5, Color(0xFFB26A00), weight: 500, inter: true)),
      gP(731, 450, 118.25, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(747, 464, 76, 13, gText('Établissements', 10.5, Color(0xFF66636E), inter: true)),
      gP(747, 484, 15, 27, gText('5', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(747, 514, 17, 13, gText('+ 2', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(865.25, 450, 118.25, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(881.25, 464, 82, 13, gText('Projets partagés', 10.5, Color(0xFF66636E), inter: true)),
      gP(881.25, 484, 40, 27, gText('312', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(881.25, 514, 17, 13, gText('+ 2', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(999.5, 450, 118.25, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(1015.5, 464, 70, 13, gText('Compétences', 10.5, Color(0xFF66636E), inter: true)),
      gP(1015.5, 484, 40, 27, gText('128', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(1015.5, 514, 17, 13, gText('+ 2', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(1133.75, 450, 118.25, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(1149.75, 464, 90, 13, gText('Défis intercampus', 10.5, Color(0xFF66636E), inter: true)),
      gP(1149.75, 484, 15, 27, gText('6', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(1149.75, 514, 17, 13, gText('+ 2', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(731, 560, 524, 17, gText('Chaque établissement choisit les contenus qu’il partage dans le catalogue national.', 11.5, Color(0xFF66636E), inter: true, lh: 17, wrap: true)),
    ]);
  }
}
