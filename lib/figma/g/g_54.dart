// GÉNÉRÉ par tool/figma_export/convert.py — écran 54 (nœud Figma 54:1062). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_54 extends ConsumerWidget {
  const G_54({super.key});

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
      gP(76, 70, 299, 26, gText('Commande #BE-2026-0142', 21, Color(0xFF111015), weight: 700)),
      gP(76, 96, 151, 15, gText('Mouanga Yannick · En ligne', 12, Color(0xFF66636E))),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 145, 17, gText('Lampe en bois recyclé', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 160, 14, gText('Prête au retrait · 25 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(306.4, 142, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(318.7, 146, 21, 14, gText('Voir', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 200, 246.24, 58, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28]), tap: () => gToast(context, 'Démonstration : Votre commande est prête, vous pouvez la retirer au Bloc A.')),
      gP(38, 211, 221.24, 36, gText('Votre commande est prête, vous pouvez la retirer au Bloc A.', 12.5, Color(0xFF111015), lh: 18, wrap: true)),
      gP(30, 262, 24, 13, gText('10:12', 10, Color(0xFF8793A5))),
      gP(119.76, 284, 246.24, 40, gBox(color: Color(0xFF111015), radii: [18, 18, 18, 18]), tap: () => gToast(context, 'Démonstration : Merci ! Je passe cet après-midi.')),
      gP(133.76, 295, 221.24, 18, gText('Merci ! Je passe cet après-midi.', 12.5, Color(0xFFFFFFFF), lh: 18, wrap: true)),
      gP(336, 328, 24, 13, gText('10:14', 10, Color(0xFF8793A5), align: TextAlign.right)),
      gP(24, 488, 0, 16, gText('', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 748, 342, 56, gBox(color: Color(0xC7FFFFFF), border: Color(0xFFFFFFFF), bw: 1, shadows: [BoxShadow(color: Color(0x14403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], backBlur: 24, radii: [28, 28, 28, 28])),
      gP(24, 748, 342, 56, GField(hint: 'Écrire un message…', size: 13, hintColor: Color(0xFF66636E), weight: 400, padL: 56)),
      gP(33, 757, 38, 38, gBox(color: Color(0xFFF1EEFB), oval: true)),
      gP(41.036, 764.624, 21.406, 22.341, gImg('assets/figma/v/b9f90829d9eec8.svg')),
      gP(286.667, 766.333, 22.667, 19.333, gImg('assets/figma/v/b357168830edbf.svg')),
      gP(292.5, 771.333, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(318, 756, 40, 40, gBox(color: Color(0xFF111015), oval: true)),
      gP(328.5, 766.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(332.625, 765.083, 10.75, 15.5, gImg('assets/figma/v/ad77f88d6a6e8f.svg')),
      gP(329.458, 771.417, 17.083, 12.333, gImg('assets/figma/v/590a1cb98d88e9.svg')),
      gP(335, 777.75, 6, 9.167, gImg('assets/figma/v/6c8704a6160690.svg')),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
