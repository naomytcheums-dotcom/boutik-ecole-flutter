// GÉNÉRÉ par tool/figma_export/convert.py — écran 80 (nœud Figma 38:883). Ne pas éditer à la main.
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

class G_80 extends ConsumerWidget {
  const G_80({super.key});

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
      gP(76, 70, 205, 26, gText('Soumettre un projet', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(27, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(32, 158, 24, 14, gText('Idée', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(129.667, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(125.667, 158, 38, 14, gText('Équipe', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(225.833, 158, 39, 14, gText('Médias', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(331.5, 158, 29, 14, gText('Envoi', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 84, 16, gText('Titre du projet', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 208, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 208, 342, 48, GField(hint: 'Ex. Serre intelligente', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 48)),
      gP(40.5, 221.5, 15, 15, gImg('assets/figma/v/a49ecdd3bef596.svg')),
      gP(42.75, 233.5, 10.5, 6, gImg('assets/figma/v/2e2c4a27235860.svg')),
      gP(43.5, 236.5, 9, 6, gImg('assets/figma/v/ab681c73d5c7eb.svg')),
      gP(24, 270, 82, 16, gText('Département', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 290, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 290, 342, 48, GField(hint: '', initial: 'Génie électrique', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 305.75, 21, 13.5, gImg('assets/figma/v/3db12df66b71b5.svg')),
      gP(40.5, 311, 15, 11.438, gImg('assets/figma/v/8ffb7368f57918.svg')),
      gP(334.5, 308.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 352, 127, 16, gText('Stade d’avancement', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 372, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 372, 342, 48, GField(hint: '', initial: 'Idée / Prototype / Réalisé', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 385.5, 21, 13.5, gImg('assets/figma/v/0370b51a77df29.svg')),
      gP(37.5, 396.75, 21, 9.75, gImg('assets/figma/v/46243080f34380.svg')),
      gP(37.5, 393, 21, 9.75, gImg('assets/figma/v/46243080f34380.svg')),
      gP(334.5, 390.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 434, 71, 16, gText('Description', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 454, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 468, 313, 20, gText('Problème résolu, solution, impact attendu…', 13.5, Color(0xFF66636E), weight: 500, lh: 20, wrap: true)),
      gP(24, 564, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 577, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 596.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(47.167, 586.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(58.833, 596.608, 8.5, 10.892, gImg('assets/figma/v/f73f5c2da1a756.svg')),
      gP(56.333, 586.608, 8.507, 12.458, gImg('assets/figma/v/385c8732cbe0ba.svg')),
      gP(88, 576, 140, 17, gText('Ajouter des membres', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 598, 199, 14, gText('Invitez votre équipe sur Boutik-École', 11.5, Color(0xFF66636E))),
      gP(336.75, 589.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Continuer')),
      gP(160, 778, 70, 18, gText('Continuer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
