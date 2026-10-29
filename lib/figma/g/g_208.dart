// GÉNÉRÉ par tool/figma_export/convert.py — écran 208 (nœud Figma 83:1833). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_208 extends ConsumerWidget {
  const G_208({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 720, h: 1280, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-120, 80, 440, 440, gBox(color: Color(0x73FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(48, 44, 64, 58, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20])),
      gP(55, 49, 50, 48, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(128, 56, 181, 35, gText('Boutik-École', 28, Color(0xFF111015), weight: 600)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(520, 50, 68, 48, 'FR', 20, 600), GChip(596, 50, 68, 48, 'EN', 20, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 24)),
      gP(596, 50, 68, 48, gBox(color: Color(0xFFFFFFFF), radii: [24, 24, 24, 24])),
      gP(48, 140, 624, 440, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x2E403366), offset: Offset(0, 18), blurRadius: 34, spreadRadius: 0)], radii: [56, 56, 56, 56])),
      gP(72, 164, 128, 48, gBox(color: Color(0xFFFFFFFF), radii: [24, 24, 24, 24])),
      gP(84.75, 175.833, 22.5, 24.333, gImg('assets/figma/v/c39381e3f69bf5.svg')),
      gP(114, 175, 67, 24, gText('Boosté', 19, Color(0xFF111015), weight: 600)),
      gP(48, 600, 96, 96, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, border: Color(0xFF6A4DFF), bw: 4, radii: [28, 28, 28, 28])),
      gP(160, 600, 96, 96, gBox(image: 'assets/figma/img/e3a1b5107e8b2a5b3a542598c9ff80a2e1376935.png', fit: BoxFit.cover, radii: [28, 28, 28, 28])),
      gP(272, 600, 96, 96, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [28, 28, 28, 28])),
      gP(384, 600, 96, 96, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [28, 28, 28, 28])),
      gP(48, 716, 624, 370, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 10), blurRadius: 26, spreadRadius: 0)], radii: [48, 48, 48, 48])),
      gP(80, 744, 430, 50, gText('Lampe en bois recyclé', 40, Color(0xFF111015), weight: 600)),
      gP(77, 807, 26, 25, gImg('assets/figma/v/56eb5ae66b4825.svg')),
      gP(105, 807, 26, 25, gImg('assets/figma/v/56eb5ae66b4825.svg')),
      gP(133, 807, 26, 25, gImg('assets/figma/v/56eb5ae66b4825.svg')),
      gP(161, 807, 26, 25, gImg('assets/figma/v/56eb5ae66b4825.svg')),
      gP(189, 807, 26, 25, gImg('assets/figma/v/56eb5ae66b4825.svg')),
      gP(240, 810, 103, 25, gText('4,8 · 12 avis', 20, Color(0xFF66636E))),
      gP(426, 792, 214, 43, gText('25 000 FCFA', 34, Color(0xFF5A3FE0), weight: 700)),
      gP(80, 866, 560, 90, gBox(color: Color(0xFFF6F3FA), radii: [34, 34, 34, 34])),
      gP(92, 876, 70, 70, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [35, 35, 35, 35])),
      gP(180, 884, 124, 30, gText('Yannick M.', 24, Color(0xFF111015), weight: 600)),
      gP(180, 916, 193, 21, gText('Génie civil · Talent vérifié', 17, Color(0xFF66636E))),
      gP(80, 980, 360, 82, gBox(color: Color(0xFF111015), radii: [41, 41, 41, 41])),
      gP(119.5, 1005.5, 21, 31, gImg('assets/figma/v/d6e92e7a815044.svg')),
      gP(125.75, 1025.5, 8.5, 6, gImg('assets/figma/v/9950f56d62ea5b.svg')),
      gP(168, 1003, 218, 30, gText('Sur mon téléphone', 24, Color(0xFFFFFFFF), weight: 600)),
      gP(452, 980, 188, 82, gBox(color: Color(0xFFF1EEFB), radii: [41, 41, 41, 41])),
      gP(479, 1003, 134, 28, gText('Commander', 22, Color(0xFF5A3FE0), weight: 600)),
      gP(48, 1112, 624, 124, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 8), blurRadius: 24, spreadRadius: 0)], backBlur: 28, radii: [62, 62, 62, 62])),
      gP(108, 1142, 36, 36, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(109.5, 1142.03, 33, 34.47, gImg('assets/figma/v/591e7e13beabb7.svg')),
      gP(96, 1190, 60, 21, gText('Accueil', 17, Color(0xFF111015), weight: 500), tap: () => gOpen(context, '03')),
      gP(212, 1126, 140, 96, gBox(color: Color(0xFF111015), radii: [48, 48, 48, 48])),
      gP(264, 1142, 36, 36, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(265.5, 1143.5, 30, 30, gImg('assets/figma/v/0e0e8a6ca98696.svg')),
      gP(286.05, 1164.05, 12.45, 12.45, gImg('assets/figma/v/b24debd4c97b40.svg')),
      gP(247.5, 1190, 69, 21, gText('Explorer', 17, Color(0xFFFFFFFF), weight: 600)),
      gP(421.5, 1143.5, 16.5, 16.5, gImg('assets/figma/v/f071cd031085d5.svg')),
      gP(438, 1143.5, 16.5, 16.5, gImg('assets/figma/v/f071cd031085d5.svg')),
      gP(421.5, 1160, 16.5, 16.5, gImg('assets/figma/v/f071cd031085d5.svg')),
      gP(438, 1160, 15, 16.5, gImg('assets/figma/v/3270830e2cda0b.svg')),
      gP(405.5, 1190, 65, 21, gText('Mon QR', 17, Color(0xFF111015), weight: 500)),
      gP(576, 1142, 36, 36, gImg('assets/figma/v/9366c93bec9b55.svg')),
      gP(586.65, 1149.612, 14.7, 20.888, gImg('assets/figma/v/ea16a39cf97c64.svg')),
      gP(575, 1190, 38, 21, gText('Aide', 17, Color(0xFF111015), weight: 500)),
      gP(80, 980, 360, 82, const SizedBox.expand(), tap: () => gOpen(context, '209')),
      gTap(80, 980, 360, 82, () => gOpen(context, '209')),
    ]);
  }
}
