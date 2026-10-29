// GÉNÉRÉ par tool/figma_export/convert.py — écran 186 (nœud Figma 61:1153). Ne pas éditer à la main.
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

class G_186 extends ConsumerWidget {
  const G_186({super.key});

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
      gP(76, 70, 132, 26, gText('Accessibilité', 21, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 63, 34, 'Petit', 12.5, 500), GChip(95, 120, 70.4, 34, 'Normal', 12.5, 500), GChip(173.4, 120, 63, 34, 'Grand', 12.5, 600), GChip(244.4, 120, 100, 34, 'Très grand', 12.5, 500)], selected: 2, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 180, 88, 17, gText('Texte agrandi', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 202, 94, 14, gText('Taille 18 px et plus', 11.5, Color(0xFF66636E))),
      gP(308, 189, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 234, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 246, 125, 17, gText('Contraste renforcé', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 268, 99, 14, gText('Textes plus lisibles', 11.5, Color(0xFF66636E))),
      gP(308, 255, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 300, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 312, 145, 17, gText('Réduire les animations', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 334, 129, 14, gText('Limiter les mouvements', 11.5, Color(0xFF66636E))),
      gP(308, 321, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(40, 366, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 378, 104, 17, gText('Lecteur d’écran', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 400, 102, 14, gText('Étiquettes vocales', 11.5, Color(0xFF66636E))),
      gP(308, 387, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(24, 446, 342, 154, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 460, 132, 18, gText('Normes appliquées', 14, Color(0xFF111015), weight: 700)),
      gP(40, 494, 145, 16, gText('Zones tactiles minimales', 12.5, Color(0xFF66636E))),
      gP(287, 494, 63, 16, gText('44 × 44 px', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 519, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 528, 111, 16, gText('Contraste du texte', 12.5, Color(0xFF66636E))),
      gP(304, 528, 46, 16, gText('≥ 4,5 : 1', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 553, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 562, 114, 16, gText('Taille de police min.', 12.5, Color(0xFF66636E))),
      gP(320, 562, 30, 16, gText('12 px', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 614, 342, 50, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [25, 25, 25, 25])),
      gP(116, 630, 183, 18, gText('Aperçu avec texte agrandi', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(89.417, 631.042, 20.167, 15.917, gImg('assets/figma/v/073897e05a984a.svg')),
      gP(94.375, 633.875, 10.25, 10.25, gImg('assets/figma/v/7a056701264e03.svg')),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
