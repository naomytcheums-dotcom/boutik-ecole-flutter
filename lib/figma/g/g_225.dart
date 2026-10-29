// GÉNÉRÉ par tool/figma_export/convert.py — écran 225 (nœud Figma 87:582). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_225 extends ConsumerWidget {
  const G_225({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFEEE9F8), Color(0xFFF4EEEA), Color(0xFFF6E7D8)], stops: [0, 0.5, 1]), children: [
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(151, 82, 88, 21, gText('Jumeau 3D', 17, Color(0xFF111015), weight: 500)),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(24, 128, 342, 372, gBox(color: Color(0x99FFFFFF), border: Color(0xFFFFFFFF), bw: 1, shadows: [BoxShadow(color: Color(0x14403366), offset: Offset(0, 10), blurRadius: 26, spreadRadius: 0)], radii: [44, 44, 44, 44])),
      gP(85, 190, 220, 220, gBox(color: Color(0x8CCDB2F2), layerBlur: 60, oval: true), fx: 'halo'),
      gP(42, 403, 306, 98, gImg('assets/figma/v/7e3a50b24384df.svg')),
      gP(42, 403, 306, 98, gImg('assets/figma/v/8a0a52a519aa8c.svg')),
      gP(109, 440, 172, 26, gBox(color: Color(0xFF111015), layerBlur: 8, oval: true)),
      gP(105, 182, 190, 250, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x4D403366), offset: Offset(0, 18), blurRadius: 28, spreadRadius: 0)], radii: [36, 36, 36, 36]), rot: 0.087),
      gP(314, 428, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(316.5, 430.5, 15, 10.5, gImg('assets/figma/v/80e3bf49b48989.svg')),
      gP(44, 148, 55, 30, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(58, 156, 27, 14, gText('360°', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(133, 472, 129, 29, gBox(color: Color(0xD9FFFFFF), radii: [100, 100, 100, 100])),
      gP(147, 480, 101, 13, gText('Glissez pour tourner', 10.5, Color(0xFF111015), weight: 600)),
      gP(24, 520, 47, 18, gText('Angles', 14, Color(0xFF111015), weight: 600)),
      gP(24, 546, 78, 78, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, border: Color(0xFF6A4DFF), bw: 2.5, radii: [22, 22, 22, 22])),
      gP(50.5, 630, 25, 13, gText('Face', 10.5, Color(0xFF5A3FE0), weight: 600)),
      gP(112, 546, 78, 78, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(138, 630, 26, 13, gText('Profil', 10.5, Color(0xFF66636E))),
      gP(200, 546, 78, 78, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(228.5, 630, 21, 13, gText('Dos', 10.5, Color(0xFF66636E))),
      gP(288, 546, 78, 78, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(312, 630, 30, 13, gText('Détail', 10.5, Color(0xFF66636E))),
      gP(24, 656, 342, 176, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 8), blurRadius: 22, spreadRadius: 0)], radii: [32, 32, 32, 32])),
      gP(44, 674, 172, 20, gText('Lampe en bois recyclé', 16, Color(0xFF111015), weight: 600)),
      gP(44, 704, 69, 29, gBox(color: Color(0xFFF1EEFB), radii: [100, 100, 100, 100])),
      gP(58, 712, 41, 13, gText('H 42 cm', 10.5, Color(0xFF5A3FE0), weight: 600)),
      gP(126, 704, 70, 29, gBox(color: Color(0xFFF1EEFB), radii: [100, 100, 100, 100])),
      gP(140, 712, 42, 13, gText('Ø 24 cm', 10.5, Color(0xFF5A3FE0), weight: 600)),
      gP(208, 704, 57, 29, gBox(color: Color(0xFFF1EEFB), radii: [100, 100, 100, 100])),
      gP(222, 712, 29, 13, gText('1,2 kg', 10.5, Color(0xFF5A3FE0), weight: 600)),
      gP(44, 746, 303, 28, gText('Bois de récupération, finition huile naturelle. Fabriquée par l’atelier Génie civil.', 11.5, Color(0xFF5B5963), wrap: true)),
      gP(44, 788, 302, 40, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(90.5, 800, 209, 16, gText('Voir chez moi en réalité augmentée', 12.5, Color(0xFFFFFFFF), weight: 600)),
      gP(328.333, 89, 19.333, 14.333, gImg('assets/figma/v/9c92298f9fd6b2.svg')),
      gP(331.667, 80.667, 12.667, 9.333, gImg('assets/figma/v/bb8ad3c4792df6.svg')),
      gP(335, 80.667, 6, 16.833, gImg('assets/figma/v/5bb53be308dfb1.svg')),
    ]);
  }
}
