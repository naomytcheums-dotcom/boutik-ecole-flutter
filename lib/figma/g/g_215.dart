// GÉNÉRÉ par tool/figma_export/convert.py — écran 215 (nœud Figma 83:1094). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_215 extends ConsumerWidget {
  const G_215({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 938, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 159.54, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 656.68, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 236, 26, gText('Génie Informatique · GI', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 170, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 120, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 228, 309, 23, gText('Sites, applications et logiciels', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 258, 309, 15, gText('MTIN · 248 étudiants · 137 offres', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(24, 304, 342, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(65, 318, 32, 25, gText('137', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(63, 348, 36, 14, gText('Offres', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(178, 318, 34, 25, gText('4,8', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(181, 348, 28, 14, gText('Note', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 318, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(296.5, 318, 25, 25, gText('32', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(285.5, 348, 47, 14, gText('Missions', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 318, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 394, 172, 19, gText('Ce que nous proposons', 15, Color(0xFF111015), weight: 700)),
      gP(24, 432, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 445, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 453.667, 22.667, 14.333, gImg('assets/figma/v/8c9c6b229b6232.svg')),
      gP(44.667, 466.167, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(44.667, 462, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(88, 444, 223, 17, gText('Site web et application sur mesure', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 466, 161, 14, gText('Dès 80 000 FCFA · 7 à 21 jours', 11.5, Color(0xFF66636E))),
      gP(336.75, 457.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 498, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 511, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 519.667, 16, 16, gImg('assets/figma/v/f44e883cdba29a.svg')),
      gP(50.5, 533, 11, 6, gImg('assets/figma/v/c4124addb3c439.svg')),
      gP(51.333, 536.333, 9.333, 6, gImg('assets/figma/v/df31b3079c9886.svg')),
      gP(88, 510, 113, 17, gText('MVP pour startup', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 532, 182, 14, gText('Dès 150 000 FCFA · mentor inclus', 11.5, Color(0xFF66636E))),
      gP(336.75, 523.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 564, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 577, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 585.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 585.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 576, 123, 17, gText('Logiciel de gestion', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 598, 203, 14, gText('Dès 120 000 FCFA · formation incluse', 11.5, Color(0xFF66636E))),
      gP(336.75, 589.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 644, 126, 19, gText('Étudiants à la une', 15, Color(0xFF111015), weight: 700)),
      gP(24, 682, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 690, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 694, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 716, 131, 14, gText('React, Python · score 88', 11.5, Color(0xFF66636E))),
      gP(306.4, 704, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(318.7, 708, 21, 14, gText('Voir', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 748, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 756, 50, 50, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 760, 96, 17, gText('Carine Mbarga', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 782, 93, 14, gText('IA, data · score 81', 11.5, Color(0xFF66636E))),
      gP(306.4, 770, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(318.7, 774, 21, 14, gText('Voir', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(0, 838, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 854, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Déposer un brief au département')),
      gP(79.5, 872, 231, 18, gText('Déposer un brief au département', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 924, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
