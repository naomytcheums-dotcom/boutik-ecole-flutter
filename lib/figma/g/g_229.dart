// GÉNÉRÉ par tool/figma_export/convert.py — écran 229 (nœud Figma 87:1082). Ne pas éditer à la main.
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

class G_229 extends ConsumerWidget {
  const G_229({super.key});

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
      gP(24, 70, 154, 26, gText('Mariam Essono', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 170, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 120, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x000B2340), Color(0xE00B2340)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 228, 309, 46, gText('Développeuse web · Génie informatique', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 258, 309, 15, gText('Score 88 · Disponible · IUT de Douala', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(24, 304, 342, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(70.5, 318, 21, 25, gText('18', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(57.5, 348, 47, 14, gText('Missions', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(178, 318, 34, 25, gText('4,9', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(184, 348, 22, 14, gText('Avis', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 318, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(298.5, 318, 21, 25, gText('12', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(280, 348, 58, 14, gText('Certificats', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 318, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 394, 153, 19, gText('Réalisations vérifiées', 15, Color(0xFF111015), weight: 700)),
      gP(24, 432, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 440, 50, 50, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 444, 169, 17, gText('Site de la Mairie de Douala', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 466, 122, 14, gText('Mission client · avis 5,0', 11.5, Color(0xFF66636E))),
      gP(287.2, 454, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(302.6, 458, 34, 14, gText('Vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 498, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 506, 50, 50, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 510, 121, 17, gText('Application Boutik', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 532, 121, 14, gText('Projet d’équipe · 2026', 11.5, Color(0xFF66636E))),
      gP(287.2, 520, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(302.6, 524, 34, 14, gText('Vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 578, 78, 19, gText('Certificats', 15, Color(0xFF111015), weight: 700)),
      gP(24, 616, 101.2, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(40.6, 622, 68, 14, gText('React · Meta', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(133.2, 616, 101.2, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(151.8, 622, 64, 14, gText('Python · IUT', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(242.4, 616, 114.4, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13])),
      gP(258.6, 622, 82, 14, gText('UI/UX · Google', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Proposer un stage')),
      gP(42, 778, 127, 18, gText('Proposer un stage', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contacter')),
      gP(248.5, 778, 72, 18, gText('Contacter', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
