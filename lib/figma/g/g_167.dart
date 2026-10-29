// GÉNÉRÉ par tool/figma_export/convert.py — écran 167 (nœud Figma 60:1254). Ne pas éditer à la main.
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

class G_167 extends ConsumerWidget {
  const G_167({super.key});

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
      gP(76, 70, 248, 26, gText('Noter : Serre intelligente', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 111, 17, gText('Serre intelligente', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 167, 14, gText('Équipe Agronomie · Pitch 5 min', 11.5, Color(0xFF66636E))),
      gP(24, 200, 342, 192, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 214, 64, 16, gText('Innovation', 12.5, Color(0xFF111015), weight: 600)),
      gP(319, 214, 31, 15, gText('8 / 10', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 236, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 236, 248, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(40, 258, 62, 16, gText('Faisabilité', 12.5, Color(0xFF111015), weight: 600)),
      gP(320, 258, 30, 15, gText('7 / 10', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 280, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 280, 217, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
      gP(40, 302, 81, 16, gText('Impact social', 12.5, Color(0xFF111015), weight: 600)),
      gP(319, 302, 31, 15, gText('9 / 10', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 324, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 324, 279, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(40, 346, 96, 16, gText('Qualité du pitch', 12.5, Color(0xFF111015), weight: 600)),
      gP(319, 346, 31, 15, gText('6 / 10', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 368, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 368, 186, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(24, 406, 342, 120, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 420, 64, 18, gText('Synthèse', 14, Color(0xFF111015), weight: 700)),
      gP(40, 454, 67, 16, gText('Note totale', 12.5, Color(0xFF66636E))),
      gP(305, 454, 45, 16, gText('30 / 40', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 479, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 488, 92, 16, gText('Rang provisoire', 12.5, Color(0xFF66636E))),
      gP(334, 488, 16, 16, gText('2e', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 540, 126, 16, gText('Commentaire du jury', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 560, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 560, 342, 96, GField(hint: 'Points forts et axes d’amélioration…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Enregistrer')),
      gP(66.5, 778, 78, 18, gText('Enregistrer', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Valider la note')),
      gP(235, 778, 99, 18, gText('Valider la note', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
