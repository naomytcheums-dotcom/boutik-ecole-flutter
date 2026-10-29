// GÉNÉRÉ par tool/figma_export/convert.py — écran 84b (nœud Figma 39:63). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_84b extends ConsumerWidget {
  const G_84b({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 868, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 136.44, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 596.48, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 134, 26, gText('Financement', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 170, gBox(image: 'assets/figma/img/e48f8827338ec470670d1109125a15b7d0f21476.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 228, 309, 23, gText('Serre intelligente', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 256, 309, 15, gText('Projet Agronomie · Équipe de 3', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(24, 304, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 316, 48, 14, gText('Collecté', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 336, 114, 19, gText('1 250 000 FCFA', 15, Color(0xFF111015), weight: 800)),
      gP(200, 304, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 316, 47, 14, gText('Objectif', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 336, 120, 19, gText('2 000 000 FCFA', 15, Color(0xFF111015), weight: 800)),
      gP(24, 410, 342, 60, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 424, 148, 16, gText('62 % de l’objectif atteint', 12.5, Color(0xFF111015), weight: 600)),
      gP(323, 424, 27, 15, gText('62%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 446, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 446, 192.2, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(24, 484, 342, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(68, 498, 26, 25, gText('48', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(43, 528, 76, 14, gText('Contributeurs', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(184.5, 498, 21, 25, gText('21', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(157.5, 528, 75, 14, gText('Jours restants', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 498, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(284.5, 498, 49, 25, gText('62 %', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(287, 528, 44, 14, gText('Financé', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 498, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 574, 103, 19, gText('Contreparties', 15, Color(0xFF111015), weight: 700)),
      gP(24, 612, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 625, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 633.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 642, 6, 9.333, gImg('assets/figma/v/168c15d5e7cb66.svg')),
      gP(53, 638.667, 6.008, 6, gImg('assets/figma/v/7a0aba9eeb97a7.svg')),
      gP(88, 624, 97, 17, gText('Précommande', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 646, 138, 14, gText('Recevez la première série', 11.5, Color(0xFF66636E))),
      gP(302, 636, 48, 17, gText('25 000', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(88, 678, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 691, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 699.667, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(48.833, 708.742, 14.333, 13.592, gImg('assets/figma/v/9253f57ddf05f2.svg')),
      gP(88, 690, 107, 17, gText('Parrain du projet', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 712, 116, 14, gText('Votre nom sur la serre', 11.5, Color(0xFF66636E))),
      gP(301, 702, 49, 17, gText('50 000', 13.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(0, 768, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 784, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contribuer')),
      gP(156.5, 802, 77, 18, gText('Contribuer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 854, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
