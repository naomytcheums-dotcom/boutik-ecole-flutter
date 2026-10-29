// GÉNÉRÉ par tool/figma_export/convert.py — écran 102 (nœud Figma 40:172). Ne pas éditer à la main.
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
import '../live/ops.dart';
import '../live/missions.dart';
import '../live/docs.dart';
import '../live/kela.dart';
import '../live/chat.dart';
import '../live/share.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_102 extends ConsumerWidget {
  const G_102({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 969, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 169.77, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 683.34, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 68, 26, gText('Vitrine', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 200, gBox(image: 'assets/figma/img/285ea8d512e6fd1079056dd514be7a2ebad70bf2.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 200, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 258, 309, 23, gText('Collection « Recyclé & Design »', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 286, 309, 15, gText('Lancement officiel le 24 octobre', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(68.5, 348, 25, 25, gText('24', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(62.5, 378, 37, 14, gText('Pièces', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(188.5, 348, 13, 25, gText('9', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(168, 378, 54, 14, gText('Créateurs', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 348, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(302.5, 348, 13, 25, gText('3', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(269, 378, 80, 14, gText('Départements', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 348, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 424, 133, 19, gText('Pièces à l’honneur', 15, Color(0xFF111015), weight: 700)),
      gP(28, 466, 157, 115.5, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(152, 473, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 477.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(150, 471, 30, 30, GHeart()),
      gP(36, 589.5, 136, 16, gText('Lampe en bois recyclé', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 607.5, 76, 15, gText('25 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 624.5, 51, 13, gText('Génie civil', 10.5, Color(0xFF5A3FE0))),
      gP(205, 466, 157, 115.5, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(329, 473, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 477.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(327, 471, 30, 30, GHeart()),
      gP(213, 589.5, 101, 16, gText('Sac à dos design', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 607.5, 76, 15, gText('25 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 624.5, 65, 13, gText('Design – MMI', 10.5, Color(0xFF5A3FE0))),
      gP(28, 663.5, 157, 115.5, gBox(image: 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(152, 670.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 675.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(150, 668.5, 30, 30, GHeart()),
      gP(36, 787, 107, 16, gText('Tableau décoratif', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 805, 74, 15, gText('18 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 822, 20, 13, gText('Arts', 10.5, Color(0xFF5A3FE0))),
      gP(205, 663.5, 157, 115.5, gBox(image: 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(329, 670.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 675.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(327, 668.5, 30, 30, GHeart()),
      gP(213, 787, 95, 16, gText('Pots connectés', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 805, 73, 15, gText('15 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 822, 56, 13, gText('Agronomie', 10.5, Color(0xFF5A3FE0))),
      gP(0, 869, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 885, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Voir la collection')),
      gP(137.5, 903, 115, 18, gText('Voir la collection', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 955, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
