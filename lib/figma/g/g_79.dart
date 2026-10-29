// GÉNÉRÉ par tool/figma_export/convert.py — écran 79 (nœud Figma 38:819). Ne pas éditer à la main.
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

class G_79 extends ConsumerWidget {
  const G_79({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 915, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 151.95, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 636.9, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 62, 26, gText('Projet', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 180, gBox(image: 'assets/figma/img/285ea8d512e6fd1079056dd514be7a2ebad70bf2.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 180, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 238, 309, 23, gText('Système de filtration d’eau', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 266, 309, 15, gText('Département Génie chimique', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(24, 314, 342, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(74, 328, 14, 25, gText('4', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(43, 358, 76, 14, gText('Contributeurs', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(170.5, 328, 49, 25, gText('72 %', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(160.5, 358, 69, 14, gText('Avancement', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 328, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(302.5, 328, 13, 25, gText('3', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(292, 358, 34, 14, gText('Jalons', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 328, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 404, 342, 148, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 418, 117, 16, gText('Avancement global', 12.5, Color(0xFF111015), weight: 600)),
      gP(323, 418, 27, 15, gText('72%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 440, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 440, 223.2, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 462, 62, 16, gText('Prototype', 12.5, Color(0xFF111015), weight: 600)),
      gP(304, 462, 46, 15, gText('Terminé', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 484, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 484, 310, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(40, 506, 73, 16, gText('Tests terrain', 12.5, Color(0xFF111015), weight: 600)),
      gP(321, 506, 29, 15, gText('40%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 528, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 528, 124, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
      gP(24, 566, 345, 41, gText('Un système de filtration à faible coût pour rendre l’eau de puits potable dans les quartiers de Douala.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 621, 51, 19, gText('Équipe', 15, Color(0xFF111015), weight: 700)),
      gP(24, 659, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 667, 50, 50, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 671, 102, 17, gText('Brice Ndoumbe', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 693, 80, 14, gText('Chef de projet', 11.5, Color(0xFF66636E))),
      gP(336.75, 684.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 725, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 733, 50, 50, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 737, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 759, 66, 14, gText('Conception', 11.5, Color(0xFF66636E))),
      gP(336.75, 750.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 815, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 831, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Soutenir le projet')),
      gP(135, 849, 120, 18, gText('Soutenir le projet', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 901, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
