// GÉNÉRÉ par tool/figma_export/convert.py — écran 165 (nœud Figma 60:1122). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_165 extends ConsumerWidget {
  const G_165({super.key});

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
      gP(76, 70, 162, 26, gText('Dépôt du projet', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 84, 16, gText('Titre du projet', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 140, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 140, 342, 48, GField(hint: '', initial: 'Paiement mobile hors connexion', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(40.5, 153.5, 15, 15, gImg('assets/figma/v/a49ecdd3bef596.svg')),
      gP(42.75, 165.5, 10.5, 6, gImg('assets/figma/v/2e2c4a27235860.svg')),
      gP(43.5, 168.5, 9, 6, gImg('assets/figma/v/ab681c73d5c7eb.svg')),
      gP(24, 202, 135, 16, gText('Lien de démonstration', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 222, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 222, 342, 48, GField(hint: 'https://…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 48)),
      gP(43.5, 235.55, 14.958, 15.704, gImg('assets/figma/v/7b6505e6afcc56.svg')),
      gP(37.542, 240.746, 14.958, 15.704, gImg('assets/figma/v/bfdb4a351b8df0.svg')),
      gP(24, 284, 71, 16, gText('Description', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 304, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 318, 313, 20, gText('Problème, solution, impact attendu…', 13.5, Color(0xFF66636E), weight: 500, lh: 20, wrap: true)),
      gP(24, 414, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 427, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 446.5, 21, 11, gImg('assets/figma/v/446cc0970fc579.svg')),
      gP(48.833, 436.5, 14.333, 10.167, gImg('assets/figma/v/a73a032c82a1f2.svg')),
      gP(53, 436.5, 6, 16, gImg('assets/figma/v/2f7bb92e5f1a61.svg')),
      gP(88, 426, 123, 17, gText('Présentation (PDF)', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 448, 122, 14, gText('Pitch deck · 10 Mo max', 11.5, Color(0xFF66636E))),
      gP(336.75, 439.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 480, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 493, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 502.5, 17.667, 21, gImg('assets/figma/v/e8ee59089ca8c3.svg')),
      gP(88, 492, 158, 17, gText('Vidéo de démonstration', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 514, 107, 14, gText('2 minutes maximum', 11.5, Color(0xFF66636E))),
      gP(336.75, 505.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 560, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 563.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(54, 561, 315, 18, gText('Je certifie que le projet est original.', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 596, 342, 52, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 606, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 611.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(49, 614.75, 8.833, 11.667, gImg('assets/figma/v/3a93fa78124c31.svg')),
      gP(76, 613.5, 277, 17, gText('Dépôt possible jusqu’au 16 nov. à 12 h.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Enregistrer')),
      gP(66.5, 778, 78, 18, gText('Enregistrer', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Soumettre')),
      gP(246.5, 778, 76, 18, gText('Soumettre', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
