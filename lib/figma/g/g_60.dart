// GÉNÉRÉ par tool/figma_export/convert.py — écran 60 (nœud Figma 37:373). Ne pas éditer à la main.
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

class G_60 extends ConsumerWidget {
  const G_60({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 866, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 135.78, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 594.76, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 192, 26, gText('Modifier l’annonce', 21, Color(0xFF111015), weight: 700)),
      gP(24, 156, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(83.5, 130, 52, 16, gText('Modifier', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(240.5, 130, 80, 16, gText('Prévisualiser', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(220.65, 154, 119.7, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(24, 174, 342, 200, gBox(image: 'assets/figma/img/8f6ca1bb4903a4a383d533c9719e840c10c65c71.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 388, 345, 28, gText('Lampe en bois recyclé', 22, Color(0xFF111015), weight: 800, wrap: true)),
      gP(24, 420, 345, 19, gText('25 000 FCFA · Aperçu client', 13, Color(0xFF66636E), lh: 19, wrap: true)),
      gP(24, 453, 88, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(36, 459, 64, 14, gText('Écologique', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(120, 453, 81.4, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(136.2, 459, 49, 14, gText('Fait main', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(209.4, 453, 41.8, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(219.3, 459, 22, 14, gText('LED', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(259.2, 453, 101.2, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(275.8, 459, 68, 14, gText('Bois recyclé', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(24, 493, 345, 41, gText('Lampe décorative fabriquée à partir de bois recyclé. Écologique, design et idéale pour un intérieur moderne.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 548, 342, 118, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 560, 36, 16, gText('Stock', 12.5, Color(0xFF66636E))),
      gP(298, 560, 52, 16, gText('15 unités', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 585, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 594, 40, 16, gText('Retrait', 12.5, Color(0xFF66636E))),
      gP(228, 594, 122, 16, gText('Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 619, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 628, 37, 16, gText('Statut', 12.5, Color(0xFF66636E))),
      gP(296, 628, 54, 16, gText('Brouillon', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 680, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 695, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 703.042, 20.167, 15.917, gImg('assets/figma/v/073897e05a984a.svg')),
      gP(46.875, 705.875, 10.25, 10.25, gImg('assets/figma/v/7a056701264e03.svg')),
      gP(76, 694, 277, 34, gText('Aperçu tel qu’il apparaîtra aux clients de la marketplace.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 766, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 782, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Modifier')),
      gP(76, 800, 59, 18, gText('Modifier', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 782, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Publier')),
      gP(260, 800, 49, 18, gText('Publier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 852, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
