// GÉNÉRÉ par tool/figma_export/convert.py — écran 90 (nœud Figma 39:524). Ne pas éditer à la main.
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
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_90 extends ConsumerWidget {
  const G_90({super.key});

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
      gP(76, 70, 174, 26, gText('Publier un besoin', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(27, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(25.5, 158, 37, 14, gText('Besoin', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(129.667, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(124.667, 158, 40, 14, gText('Budget', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(221.833, 158, 47, 14, gText('Livrables', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(316, 158, 60, 14, gText('Publication', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 89, 16, gText('Titre du besoin', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 208, 342, 48, GField(hint: 'Ex. Application de suivi clients', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 48)),
      gP(37.5, 221.493, 21.024, 21.007, gImg('assets/figma/v/b644eb09a59fd6.svg')),
      gP(24, 270, 61, 16, gText('Catégorie', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 290, 342, 48, GField(hint: '', initial: 'Développement', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 304.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 304.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 312.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(38.25, 312.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(334.5, 308.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 352, 71, 16, gText('Description', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 372, 342, 96, GField(hint: 'Contexte, objectifs, contraintes…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 482, 89, 16, gText('Budget estimé', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 502, 342, 48, GField(hint: '', initial: '300 000 – 500 000 FCFA', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 516.25, 20.25, 15.75, gImg('assets/figma/v/a842b4c78dabfc.svg')),
      gP(38.25, 517.75, 19.5, 18, gImg('assets/figma/v/fbc7a9ade9c600.svg')),
      gP(334.5, 520.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 564, 65, 16, gText('Date limite', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 584, 342, 48, GField(hint: '', initial: '30 nov. 2026', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 599, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(48, 597.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(42, 597.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(38.25, 603.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(36, 659, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 678.5, 21, 11, gImg('assets/figma/v/446cc0970fc579.svg')),
      gP(48.833, 668.5, 14.333, 10.167, gImg('assets/figma/v/a73a032c82a1f2.svg')),
      gP(53, 668.5, 6, 16, gImg('assets/figma/v/2f7bb92e5f1a61.svg')),
      gP(88, 658, 186, 17, gText('Joindre le cahier des charges', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 680, 119, 14, gText('PDF, DOC · 10 Mo max', 11.5, Color(0xFF66636E))),
      gP(336.75, 671.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Brouillon')),
      gP(74.5, 778, 62, 18, gText('Brouillon', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Publier')),
      gP(260, 778, 49, 18, gText('Publier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
