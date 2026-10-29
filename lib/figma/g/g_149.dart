// GÉNÉRÉ par tool/figma_export/convert.py — écran 149 (nœud Figma 40:862). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_149 extends ConsumerWidget {
  const G_149({super.key});

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
      gP(76, 70, 202, 26, gText('Langue et affichage', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 54, 19, gText('Langue', 15, Color(0xFF111015), weight: 700)),
      gP(24, 158, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 170, 55, 17, gText('Français', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 192, 100, 14, gText('Langue par défaut', 11.5, Color(0xFF66636E))),
      gP(300, 180, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(313, 184, 26, 14, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(40, 224, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 236, 47, 17, gText('English', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 258, 107, 14, gText('English (Cameroon)', 11.5, Color(0xFF66636E))),
      gP(336.75, 249.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 304, 94, 19, gText('Accessibilité', 15, Color(0xFF111015), weight: 700)),
      gP(24, 342, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 354, 88, 17, gText('Texte agrandi', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 376, 159, 14, gText('Augmenter la taille des textes', 11.5, Color(0xFF66636E))),
      gP(308, 363, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(40, 408, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 420, 125, 17, gText('Contraste renforcé', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 442, 107, 14, gText('Améliorer la lisibilité', 11.5, Color(0xFF66636E))),
      gP(308, 429, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 474, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 486, 145, 17, gText('Réduire les animations', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 508, 129, 14, gText('Limiter les mouvements', 11.5, Color(0xFF66636E))),
      gP(308, 495, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(40, 540, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 552, 97, 17, gText('Lecture vocale', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 574, 150, 14, gText('Compatible lecteur d’écran', 11.5, Color(0xFF66636E))),
      gP(308, 561, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(24, 620, 100, 19, gText('Taille du texte', 15, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 658, 63, 34, 'Petit', 12.5, 500), GChip(95, 658, 70.4, 34, 'Normal', 12.5, 600), GChip(173.4, 658, 63, 34, 'Grand', 12.5, 500)], selected: 1, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
