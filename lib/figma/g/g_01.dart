// GÉNÉRÉ par tool/figma_export/convert.py — écran 01 (nœud Figma 1:29). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_01 extends ConsumerWidget {
  const G_01({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 876, radius: 43.333, color: Color(0xFF120F1A), children: [
      gP(0, 0, 390, 876, gBox(image: 'assets/figma/img/b896412c022a294df9eb3c04f2396e17da24d53c.png', fit: BoxFit.cover)),
      gP(0, 0, 390, 876, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x40120F1F), Color(0x33120F1F), Color(0xB2120F1F)], stops: [0, 0.5, 1]))),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFFFFFFFF), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/5bc0bea2e7c30c.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/e67087fc64b6f1.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/fb4f69fd85c479.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/bc01d8c03d85a3.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/ad194a6dd260d1.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/59c083d0e217a4.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/c62e5bd2b4bab1.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/ee52ace3f9b23e.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/b74e5eeeb297f7.svg')),
      gP(145, 318, 100, 100, gBox(color: Color(0xEBFFFFFF), shadows: [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 12), blurRadius: 30, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(160, 335.8, 70, 64.4, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(97.5, 456, 195, 38, gText('Boutik-École', 30, Color(0xFFFFFFFF), weight: 700)),
      gP(72, 500, 246, 42, gText('La marketplace de l’expertise\net des productions de l’IUT de Douala', 14, Color(0xE5FFFFFF), lh: 21, align: TextAlign.center)),
      gP(85, 804, 220, 4, gBox(color: Color(0x4DFFFFFF), radii: [2, 2, 2, 2])),
      gP(85, 804, 0, 4, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2])),
      gP(157.5, 820, 75, 14, gText('Chargement…', 11, Color(0xBFFFFFFF), weight: 500)),
      gTap(0, 0, 390, 876, () => gOpen(context, '02')),
    ]);
  }
}
