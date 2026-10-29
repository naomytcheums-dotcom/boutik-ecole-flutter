// GÉNÉRÉ par tool/figma_export/convert.py — écran 36 (nœud Figma 35:870). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_36 extends ConsumerWidget {
  const G_36({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 956, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 165.48, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 672.16, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 169, 26, gText('Détail du service', 21, Color(0xFF111015), weight: 700)),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
      gP(24, 120, 342, 170, gBox(image: 'assets/figma/img/a30d4e56acc9216d03ba2d7972f7dfac533b78bf.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 228, 309, 23, gText('Développement web sur mesure', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 256, 309, 15, gText('Par Mariam Essono · Génie informatique', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(24, 304, 342, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(64, 318, 34, 25, gText('4.9', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(67, 348, 28, 14, gText('Note', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(182.5, 318, 25, 25, gText('38', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(171.5, 348, 47, 14, gText('Missions', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 318, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(288, 318, 42, 25, gText('48 h', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(275.5, 348, 67, 14, gText('Délai moyen', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 318, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 394, 68, 19, gText('Formules', 15, Color(0xFF111015), weight: 700)),
      gP(24, 432, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 445, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 453.667, 21, 22.667, gImg('assets/figma/v/3556935ad08d5d.svg')),
      gP(88, 444, 59, 17, gText('Essentiel', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 466, 78, 14, gText('1 page · 3 jours', 11.5, Color(0xFF66636E))),
      gP(263, 456, 87, 17, gText('30 000 FCFA', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(88, 498, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 511, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 519.667, 22.667, 14.333, gImg('assets/figma/v/8c9c6b229b6232.svg')),
      gP(44.667, 532.167, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(44.667, 528, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(88, 510, 61, 17, gText('Standard', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 532, 86, 14, gText('5 pages · 7 jours', 11.5, Color(0xFF66636E))),
      gP(263, 522, 87, 17, gText('80 000 FCFA', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(88, 564, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 577, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 585.667, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(48.833, 594.742, 14.333, 13.592, gImg('assets/figma/v/9253f57ddf05f2.svg')),
      gP(88, 576, 58, 17, gText('Premium', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 598, 118, 14, gText('Site complet · 14 jours', 11.5, Color(0xFF66636E))),
      gP(258, 588, 92, 17, gText('150 000 FCFA', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(24, 644, 342, 188, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 658, 162, 18, gText('Modalités de prestation', 14, Color(0xFF111015), weight: 700)),
      gP(40, 692, 35, 16, gText('Mode', 12.5, Color(0xFF66636E))),
      gP(197, 692, 153, 16, gText('À distance ou sur campus', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 717, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 726, 30, 16, gText('Délai', 12.5, Color(0xFF66636E))),
      gP(286, 726, 64, 16, gText('3 à 14 jours', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 751, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 760, 56, 16, gText('Révisions', 12.5, Color(0xFF66636E))),
      gP(291, 760, 59, 16, gText('2 incluses', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 785, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 794, 57, 16, gText('Paiement', 12.5, Color(0xFF66636E))),
      gP(265, 794, 85, 16, gText('Mobile Money', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(0, 856, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 872, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Demander un devis')),
      gP(38.5, 890, 134, 18, gText('Demander un devis', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 872, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Commander')),
      gP(240.5, 890, 88, 18, gText('Commander', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 942, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
