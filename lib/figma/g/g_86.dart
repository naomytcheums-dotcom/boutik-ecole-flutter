// GÉNÉRÉ par tool/figma_export/convert.py — écran 86 (nœud Figma 39:186). Ne pas éditer à la main.
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

class G_86 extends ConsumerWidget {
  const G_86({super.key});

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
      gP(76, 70, 239, 26, gText('Résultats de campagne', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 132, 77, 14, gText('Contributions', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 152, 26, 25, gText('48', 20, Color(0xFF111015), weight: 800)),
      gP(150, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(154.75, 144.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(156.625, 137.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(165.375, 144.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(163.5, 137.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(200, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 132, 87, 14, gText('Montant moyen', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 152, 126, 25, gText('26 000 FCFA', 20, Color(0xFF111015), weight: 800)),
      gP(326, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(331.375, 137.375, 17.875, 14.125, gImg('assets/figma/v/b45a94448c908a.svg')),
      gP(331.375, 138.625, 17.25, 16, gImg('assets/figma/v/942aaa660c45c9.svg')),
      gP(24, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 234, 105, 14, gText('Taux de conversion', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 254, 58, 25, gText('4,2 %', 20, Color(0xFF111015), weight: 800)),
      gP(38, 286, 40, 14, gText('+0,8 pt', 11, Color(0xFF0F7A52), weight: 600)),
      gP(150, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(156.625, 240.625, 14.75, 14.75, gImg('assets/figma/v/b3a3ae04257941.svg')),
      gP(156, 240, 9.125, 9.125, gImg('assets/figma/v/e8118c9116f61a.svg')),
      gP(162.875, 246.875, 9.125, 9.125, gImg('assets/figma/v/e8118c9116f61a.svg')),
      gP(200, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 234, 50, 14, gText('Partages', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 254, 33, 25, gText('312', 20, Color(0xFF111015), weight: 800)),
      gP(214, 286, 21, 14, gText('+64', 11, Color(0xFF0F7A52), weight: 600)),
      gP(326, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(24, 328, 342, 190, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 342, 180, 18, gText('Collecte cumulée (k FCFA)', 14, Color(0xFF111015), weight: 700)),
      gP(305, 344, 45, 14, gText('30 jours', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.right)),
      gP(44, 384, 302, 104, gImg('assets/figma/r/39_239.png')),
      gP(41, 381, 308, 110, gImg('assets/figma/v/9ba55a76269755.svg')),
      gP(341, 379, 10, 10, gBox(color: Color(0xFF111015), oval: true)),
      gP(24, 532, 164, 19, gText('Derniers contributeurs', 15, Color(0xFF111015), weight: 700)),
      gP(24, 570, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 578, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 582, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 604, 40, 14, gText('Il y a 2 h', 11.5, Color(0xFF66636E))),
      gP(301, 594, 49, 17, gText('50 000', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(98, 636, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 644, 50, 50, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 648, 102, 17, gText('Brice Ndoumbe', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 670, 23, 14, gText('Hier', 11.5, Color(0xFF66636E))),
      gP(302, 660, 48, 17, gText('25 000', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(330.333, 245, 19.333, 14.333, gImg('assets/figma/v/9c92298f9fd6b2.svg')),
      gP(333.667, 236.667, 12.667, 9.333, gImg('assets/figma/v/bb8ad3c4792df6.svg')),
      gP(337, 236.667, 6, 16.833, gImg('assets/figma/v/5bb53be308dfb1.svg')),
    ]);
  }
}
