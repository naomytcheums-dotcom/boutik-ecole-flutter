// GÉNÉRÉ par tool/figma_export/convert.py — écran 202 (nœud Figma 83:533). Ne pas éditer à la main.
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

class G_202 extends ConsumerWidget {
  const G_202({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 948, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 162.84, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 665.28, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 283, 26, gText('Pack Lancement de marque', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 180, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 120, 342, 180, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 238, 309, 23, gText('Votre marque, de l’idée au produit', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 268, 309, 15, gText('4 filières, un seul interlocuteur', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(24, 314, 117, 19, gText('Ce qui est inclus', 15, Color(0xFF111015), weight: 700)),
      gP(24, 352, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 365, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 373.667, 22.667, 14.333, gImg('assets/figma/v/8c9c6b229b6232.svg')),
      gP(44.667, 386.167, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(44.667, 382, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(88, 364, 103, 17, gText('Identité visuelle', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 386, 106, 14, gText('MMI · logo et charte', 11.5, Color(0xFF66636E))),
      gP(312.8, 374, 39.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(320.9, 378, 23, 14, gText('MMI', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 418, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 431, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 440.5, 21, 20.167, gImg('assets/figma/v/3ce22d6edc53c9.svg')),
      gP(45.5, 444.667, 21, 6, gImg('assets/figma/v/dd90762ca86114.svg')),
      gP(88, 430, 145, 17, gText('Fabrication du produit', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 452, 134, 14, gText('BTA · formulation et tests', 11.5, Color(0xFF66636E))),
      gP(312.8, 440, 39.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(321.9, 444, 21, 14, gText('BTA', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 484, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 497, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 507.333, 22.667, 19.333, gImg('assets/figma/v/b357168830edbf.svg')),
      gP(50.5, 512.333, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 496, 95, 17, gText('Photo et vidéo', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 518, 135, 14, gText('TCO · spot de lancement', 11.5, Color(0xFF66636E))),
      gP(312.8, 506, 39.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(320.4, 510, 24, 14, gText('TCO', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 550, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 563, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 571.667, 22.672, 22.672, gImg('assets/figma/v/a73f12f517a069.svg')),
      gP(88, 562, 69, 17, gText('Emballage', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 584, 145, 14, gText('GMP · prototype et gabarit', 11.5, Color(0xFF66636E))),
      gP(312.8, 572, 39.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(319.4, 576, 26, 14, gText('GMP', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 630, 342, 118, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 642, 71, 16, gText('Prix du pack', 12.5, Color(0xFF66636E))),
      gP(262, 642, 88, 16, gText('420 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 667, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 676, 61, 16, gText('Économie', 12.5, Color(0xFF66636E))),
      gP(314, 676, 36, 16, gText('–15 %', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 701, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 710, 30, 16, gText('Délai', 12.5, Color(0xFF66636E))),
      gP(282, 710, 68, 16, gText('8 semaines', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 762, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 777, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.979, 782.917, 18.042, 17.688, gImg('assets/figma/v/e9085cf2b599c2.svg')),
      gP(76, 776, 277, 34, gText('L’administrateur coordonne les filières et vous suivez tout dans un seul dossier.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 848, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 864, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Personnaliser')),
      gP(58, 882, 95, 18, gText('Personnaliser', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 864, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Commander le pack')),
      gP(214, 882, 141, 18, gText('Commander le pack', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 934, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
