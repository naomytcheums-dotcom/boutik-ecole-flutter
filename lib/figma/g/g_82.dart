// GÉNÉRÉ par tool/figma_export/convert.py — écran 82 (nœud Figma 38:1016). Ne pas éditer à la main.
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

class G_82 extends ConsumerWidget {
  const G_82({super.key});

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
      gP(76, 70, 169, 26, gText('Journal du projet', 21, Color(0xFF111015), weight: 700)),
      gP(33, 142, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 121, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 125.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 120, 305, 17, gText('Cahier des charges validé', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 140, 305, 14, gText('03 sept. 2026 · Équipe complète', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 204, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 183, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 187.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 182, 305, 17, gText('Premier prototype', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 202, 305, 14, gText('21 sept. 2026 · Filtre à sable', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 266, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 245, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 249.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 244, 305, 17, gText('Tests en laboratoire', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 264, 305, 14, gText('08 oct. 2026 · Résultats positifs', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 328, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 307, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 306, 305, 17, gText('Tests terrain', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 326, 305, 14, gText('En cours · Quartier Ndokoti', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 369, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 368, 305, 17, gText('Présentation au jury', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 388, 305, 14, gText('Prévu le 20 nov. 2026', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 444, 108.667, 84, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 444, 108.667, 84, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 444, 108.667, 84, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Ajouter une étape')),
      gP(132.5, 778, 125, 18, gText('Ajouter une étape', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
