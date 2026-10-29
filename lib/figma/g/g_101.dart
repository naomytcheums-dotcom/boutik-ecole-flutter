// GÉNÉRÉ par tool/figma_export/convert.py — écran 101 (nœud Figma 40:111). Ne pas éditer à la main.
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

class G_101 extends ConsumerWidget {
  const G_101({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 853, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 131.49, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 583.58, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 116, 26, gText('Événement', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 190, gBox(image: 'assets/figma/img/fbb2092962d6dc7886c56df2e6f5a1cfb07c25bb.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 190, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 248, 309, 23, gText('Exposition des innovations', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 276, 309, 15, gText('Samedi 24 octobre 2026 · Hall principal', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(24, 324, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 336, 27, 14, gText('Date', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 356, 124, 25, gText('24 oct. · 10 h', 20, Color(0xFF111015), weight: 800)),
      gP(150, 336, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(155.375, 342, 17.25, 17.25, gImg('assets/figma/v/acdac738c047b0.svg')),
      gP(163.5, 340.75, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(158.5, 340.75, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(155.375, 345.75, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(200, 324, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 336, 91, 14, gText('Places restantes', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 356, 78, 25, gText('86 / 150', 20, Color(0xFF111015), weight: 800)),
      gP(326, 336, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 348.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(332.625, 341.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(341.375, 348.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(339.5, 341.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(24, 430, 345, 61, gText('Découvrez les produits, services et prototypes réalisés par les étudiants de l’IUT de Douala. Démonstrations, ventes et rencontres avec les entreprises partenaires.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 505, 87, 19, gText('Programme', 15, Color(0xFF111015), weight: 700)),
      gP(33, 565, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 544, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 548.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 543, 305, 17, gText('10 h · Ouverture officielle', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 563, 305, 14, gText('Mot du directeur', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 627, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 606, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 605, 305, 17, gText('11 h · Démonstrations', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 625, 305, 14, gText('Prototypes et innovations', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 668, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 667, 305, 17, gText('14 h · Rencontres entreprises', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 687, 305, 14, gText('Espaces B2B', 11.5, Color(0xFF66636E), wrap: true)),
      gP(0, 753, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 769, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : S’inscrire')),
      gP(162, 787, 66, 18, gText('S’inscrire', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 839, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
