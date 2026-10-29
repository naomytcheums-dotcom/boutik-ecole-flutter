// GÉNÉRÉ par tool/figma_export/convert.py — écran 201 (nœud Figma 83:461). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_201 extends ConsumerWidget {
  const G_201({super.key});

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
      gP(24, 70, 135, 26, gText('Mes missions', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(74.5, 134, 13, 25, gText('3', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(57.5, 164, 47, 14, gText('En cours', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(168.5, 134, 53, 25, gText('245 k', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(173, 164, 44, 14, gText('Gagnés', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 134, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(292, 134, 34, 25, gText('4,9', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(295, 164, 28, 14, gText('Note', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 134, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 210, 85.2, 34, 'En cours', 12.5, 600), GChip(117.2, 210, 92.6, 34, 'À valider', 12.5, 500), GChip(217.8, 210, 92.6, 34, 'Terminées', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 258, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 266, 50, 50, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 270, 149, 17, gText('Identité visuelle Mbella', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 292, 73, 14, gText('Jalon 2 · 60 %', 11.5, Color(0xFF66636E))),
      gP(293.6, 280, 58.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(307.8, 284, 30, 14, gText('Livrer', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(98, 324, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 332, 50, 50, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 336, 165, 17, gText('Emballage savons Kamga', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 358, 69, 14, gText('Jalon 1 · 25 %', 11.5, Color(0xFF66636E))),
      gP(280.8, 346, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 350, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 390, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 398, 50, 50, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 402, 136, 17, gText('Spot promo parfums', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 424, 114, 14, gText('Attribuée aujourd’hui', 11.5, Color(0xFF66636E))),
      gP(287.2, 412, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(295.6, 416, 48, 14, gText('Nouveau', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 470, 342, 120, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 484, 85, 18, gText('Mes revenus', 14, Color(0xFF111015), weight: 700)),
      gP(40, 518, 146, 16, gText('Disponible au versement', 12.5, Color(0xFF66636E))),
      gP(270, 518, 80, 16, gText('50 400 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 543, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 552, 139, 16, gText('En attente de validation', 12.5, Color(0xFF66636E))),
      gP(272, 552, 78, 16, gText('72 000 FCFA', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
