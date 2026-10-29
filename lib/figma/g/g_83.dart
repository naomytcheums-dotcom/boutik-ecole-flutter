// GÉNÉRÉ par tool/figma_export/convert.py — écran 83 (nœud Figma 39:2). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_83 extends ConsumerWidget {
  const G_83({super.key});

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
      gP(76, 70, 186, 26, gText('Médias et preuves', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 108.667, 84, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 120, 108.667, 84, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 120, 108.667, 84, gBox(image: 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(24, 218, 108.667, 84, gBox(image: 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 218, 108.667, 84, gBox(image: 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 218, 108.667, 84, gBox(image: 'assets/figma/img/34e8344812f71c763e7e4b52e1acffce9319e372.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(24, 316, 85, 19, gText('Documents', 15, Color(0xFF111015), weight: 700)),
      gP(24, 354, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 367, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 375.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 375.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 366, 133, 17, gText('Fiche technique.pdf', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 388, 133, 14, gText('2,4 Mo · Ajouté le 08 oct.', 11.5, Color(0xFF66636E))),
      gP(293.6, 376, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(304.8, 380, 36, 14, gText('Ajouté', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 420, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 433, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 441.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 441.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 432, 152, 17, gText('Résultats des tests.xlsx', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 454, 131, 14, gText('860 Ko · Ajouté le 12 oct.', 11.5, Color(0xFF66636E))),
      gP(293.6, 442, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(304.8, 446, 36, 14, gText('Ajouté', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 486, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 499, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 508.5, 21, 21, gImg('assets/figma/v/ffe808ced2c9ec.svg')),
      gP(48.833, 511.833, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(48, 515.44, 18.5, 14.06, gImg('assets/figma/v/f51abb12c4fc4f.svg')),
      gP(88, 498, 158, 17, gText('Vidéo de démonstration', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 520, 154, 14, gText('En attente de téléversement', 11.5, Color(0xFF66636E))),
      gP(274.4, 508, 77.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(289.2, 512, 48, 14, gText('À ajouter', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 566, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 581, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 586.916, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 592.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 580, 277, 34, gText('Les preuves de réalisation sont examinées par le responsable de département.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Téléverser')),
      gP(159, 778, 72, 18, gText('Téléverser', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
