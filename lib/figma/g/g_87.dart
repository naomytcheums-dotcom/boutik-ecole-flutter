// GÉNÉRÉ par tool/figma_export/convert.py — écran 87 (nœud Figma 39:255). Ne pas éditer à la main.
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
import '../live/hackathons.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_87 extends ConsumerWidget {
  const G_87({super.key});

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
      gP(76, 70, 249, 26, gText('Registre des innovations', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Rechercher une innovation', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(338.583, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(329.875, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(337, 141, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(329.875, 141, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(340.167, 147.333, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(329.875, 147.333, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(338.583, 133.083, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(333.833, 139.417, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(340.167, 145.75, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(24, 182, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 195, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 203.667, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(48.833, 212.742, 14.333, 13.592, gImg('assets/figma/v/9253f57ddf05f2.svg')),
      gP(88, 194, 150, 17, gText('Filtre à sable modulaire', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 216, 151, 14, gText('Dépôt OAPI · N° 2026-0145', 11.5, Color(0xFF66636E))),
      gP(293.6, 204, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(301.8, 208, 42, 14, gText('Déposé', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 248, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 261, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.658, 269.671, 22.672, 22.665, gImg('assets/figma/v/129b28be71ba2e.svg')),
      gP(50.5, 276.333, 11, 9.333, gImg('assets/figma/v/5fb65d78d14660.svg')),
      gP(88, 260, 111, 17, gText('Serre intelligente', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 282, 151, 14, gText('Certificat n° BE-CERT-0021', 11.5, Color(0xFF66636E))),
      gP(280.8, 270, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(296.4, 274, 40, 14, gText('Certifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 314, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 327, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 335.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 335.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 326, 163, 17, gText('Drone éducatif connecté', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 348, 124, 14, gText('Dossier en préparation', 11.5, Color(0xFF66636E))),
      gP(280.8, 336, 71.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(293.9, 340, 45, 14, gText('En cours', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(88, 380, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 393, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 401.666, 19.333, 22.669, gImg('assets/figma/v/863e78037260f9.svg')),
      gP(50.5, 408.333, 11, 9.333, gImg('assets/figma/v/5fb65d78d14660.svg')),
      gP(88, 392, 144, 17, gText('Support de téléphone', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 414, 123, 14, gText('Modèle déposé · 2025', 11.5, Color(0xFF66636E))),
      gP(293.6, 402, 58.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(301.8, 406, 42, 14, gText('Déposé', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 460, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 475, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 480.916, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 486.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 474, 277, 34, gText('La propriété intellectuelle reste à l’étudiant ; l’IUT conserve un droit d’usage pédagogique.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Déclarer une innovation')),
      gP(113, 778, 164, 18, gText('Déclarer une innovation', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
