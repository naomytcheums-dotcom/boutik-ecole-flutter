// GÉNÉRÉ par tool/figma_export/convert.py — écran 76 (nœud Figma 38:581). Ne pas éditer à la main.
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

class G_76 extends ConsumerWidget {
  const G_76({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 846, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 129.18, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 577.56, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 160, 26, gText('Ma candidature', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 145.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 142.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg')),
      gP(88, 132, 156, 17, gText('Technicien électronique', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 154, 138, 14, gText('Camlight · Douala · 6 mois', 11.5, Color(0xFF66636E))),
      gP(280.8, 142, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 146, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(60, 214, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 200, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 208.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(21, 238, 46, 14, gText('Envoyée', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 214, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 198, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(118.667, 238, 52, 14, gText('Examinée', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 214, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 200, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(220.833, 238, 49, 14, gText('Entretien', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 200, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(323, 238, 46, 14, gText('Décision', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 268, 35, 19, gText('Suivi', 15, Color(0xFF111015), weight: 700)),
      gP(33, 328, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 307, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 311.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 306, 305, 17, gText('Candidature envoyée', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 326, 305, 14, gText('12 oct. 2026', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 390, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 369, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 373.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 368, 305, 17, gText('Dossier examiné', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 388, 305, 14, gText('14 oct. 2026', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 452, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 431, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 430, 305, 17, gText('Entretien à planifier', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 450, 305, 14, gText('En attente de l’entreprise', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 493, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 492, 305, 17, gText('Décision finale', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 512, 305, 14, gText('', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 568, 342, 154, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 582, 87, 18, gText('Informations', 14, Color(0xFF111015), weight: 700)),
      gP(40, 616, 46, 16, gText('Contrat', 12.5, Color(0xFF66636E))),
      gP(254, 616, 96, 16, gText('Stage de 6 mois', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 641, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 650, 38, 16, gText('Début', 12.5, Color(0xFF66636E))),
      gP(275, 650, 75, 16, gText('Janvier 2027', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 675, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 684, 104, 16, gText('Documents joints', 12.5, Color(0xFF66636E))),
      gP(293, 684, 57, 16, gText('CV, lettre', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(0, 746, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 762, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE5484D), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Retirer')),
      gP(82, 780, 47, 18, gText('Retirer', 14.5, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(203, 762, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contacter')),
      gP(248.5, 780, 72, 18, gText('Contacter', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
