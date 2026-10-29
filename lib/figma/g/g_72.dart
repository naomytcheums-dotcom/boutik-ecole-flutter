// GÉNÉRÉ par tool/figma_export/convert.py — écran 72 (nœud Figma 38:265). Ne pas éditer à la main.
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

class G_72 extends ConsumerWidget {
  const G_72({super.key});

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
      gP(76, 70, 199, 26, gText('Ajouter à mon profil', 21, Color(0xFF111015), weight: 700)),
      gP(24, 156, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(39, 130, 84, 16, gText('Compétence', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(159.5, 130, 71, 16, gText('Expérience', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(274, 130, 70, 16, gText('Réalisation', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(269.1, 154, 79.8, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(24, 174, 123, 16, gText('Titre de la réalisation', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 194, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 194, 342, 48, GField(hint: '', initial: 'Application mobile Boutik', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 207.493, 21.024, 21.007, gImg('assets/figma/v/b644eb09a59fd6.svg')),
      gP(24, 256, 61, 16, gText('Catégorie', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 276, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 276, 342, 48, GField(hint: '', initial: 'Développement', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 290.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 290.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 298.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(38.25, 298.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(334.5, 294.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 338, 29, 16, gText('Date', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 358, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 358, 342, 48, GField(hint: '', initial: 'Octobre 2026', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 373, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(48, 371.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(42, 371.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(38.25, 377.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(24, 420, 71, 16, gText('Description', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 440, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 440, 342, 96, GField(hint: 'Contexte, rôle, résultats obtenus…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 550, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 563, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 572.5, 21, 21, gImg('assets/figma/v/ffe808ced2c9ec.svg')),
      gP(48.833, 575.833, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(48, 579.44, 18.5, 14.06, gImg('assets/figma/v/f51abb12c4fc4f.svg')),
      gP(88, 562, 125, 17, gText('Ajouter des médias', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 584, 170, 14, gText('Photos, captures, vidéo (5 max)', 11.5, Color(0xFF66636E))),
      gP(336.75, 575.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Ajouter à mon portfolio')),
      gP(114.5, 778, 161, 18, gText('Ajouter à mon portfolio', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
