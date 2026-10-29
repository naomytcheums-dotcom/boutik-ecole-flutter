// GÉNÉRÉ par tool/figma_export/convert.py — écran 84 (nœud Figma 54:1206). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_84 extends ConsumerWidget {
  const G_84({super.key});

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
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 204, 26, gText('Nouvelle campagne', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 120, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 128.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(28, 158, 32, 14, gText('Projet', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(121.667, 158, 46, 14, gText('Objectif', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(208.333, 158, 74, 14, gText('Contreparties', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(316, 158, 60, 14, gText('Publication', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 115, 16, gText('Type de campagne', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 208, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 208, 342, 48, GField(hint: '', initial: 'Financement participatif', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 221.5, 21, 13.5, gImg('assets/figma/v/0370b51a77df29.svg')),
      gP(37.5, 232.75, 21, 9.75, gImg('assets/figma/v/46243080f34380.svg')),
      gP(37.5, 229, 21, 9.75, gImg('assets/figma/v/46243080f34380.svg')),
      gP(334.5, 226.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 270, 97, 16, gText('Projet concerné', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 290, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 290, 342, 48, GField(hint: '', initial: 'Serre intelligente', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(40.5, 303.5, 15, 15, gImg('assets/figma/v/a49ecdd3bef596.svg')),
      gP(42.75, 315.5, 10.5, 6, gImg('assets/figma/v/2e2c4a27235860.svg')),
      gP(43.5, 318.5, 9, 6, gImg('assets/figma/v/ab681c73d5c7eb.svg')),
      gP(334.5, 308.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 352, 162, 16, gText('Objectif à atteindre (FCFA)', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 372, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 372, 342, 48, GField(hint: '', initial: '2 000 000', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(24, 434, 37, 16, gText('Durée', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 454, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 454, 342, 48, GField(hint: '', initial: '30 jours', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 469, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(48, 467.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(42, 467.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(38.25, 473.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(334.5, 472.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 516, 176, 16, gText('Présentation de la campagne', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 536, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 550, 313, 40, gText('Expliquez le projet, l’usage des fonds et l’impact…', 13.5, Color(0xFF66636E), weight: 500, lh: 20, wrap: true)),
      gP(24, 646, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 659, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 672.667, 21, 9.333, gImg('assets/figma/v/eabe15c7345bb6.svg')),
      gP(53, 672.667, 6, 16.833, gImg('assets/figma/v/5bb53be308dfb1.svg')),
      gP(47.167, 676, 17.667, 13.5, gImg('assets/figma/v/f3cf2f48603f83.svg')),
      gP(47.167, 668.5, 17.667, 10.167, gImg('assets/figma/v/9d6d12b5310167.svg')),
      gP(88, 658, 167, 17, gText('Ajouter des contreparties', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 680, 254, 14, gText('Précommandes, remerciements, accès antici…', 11.5, Color(0xFF66636E))),
      gP(336.75, 671.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Brouillon')),
      gP(74.5, 778, 62, 18, gText('Brouillon', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Continuer')),
      gP(249.5, 778, 70, 18, gText('Continuer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(37.5, 388.5, 21, 15, gImg('assets/figma/v/24162e31d4b858.svg')),
      gP(43.125, 391.125, 9.75, 9.75, gImg('assets/figma/v/b916ebbd5954b5.svg')),
      gP(40.5, 393, 15.007, 6, gImg('assets/figma/v/bc5c9bd2e55ecc.svg')),
    ]);
  }
}
