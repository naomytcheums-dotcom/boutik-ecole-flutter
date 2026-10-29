// GÉNÉRÉ par tool/figma_export/convert.py — écran 58 (nœud Figma 37:226). Ne pas éditer à la main.
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

class G_58 extends ConsumerWidget {
  const G_58({super.key});

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
      gP(76, 70, 171, 26, gText('Nouveau produit', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(27, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(30.5, 158, 27, 14, gText('Infos', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(129.667, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(125.667, 158, 38, 14, gText('Photos', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(235.333, 158, 20, 14, gText('Prix', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(316, 158, 60, 14, gText('Publication', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 201, 40, 40, gBox(color: Color(0xFFFDEFC8), radii: [13, 13, 13, 13])),
      gP(44.667, 211.333, 22.667, 19.333, gImg('assets/figma/v/b357168830edbf.svg')),
      gP(50.5, 216.333, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 200, 124, 17, gText('Ajouter des photos', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 222, 150, 14, gText('Jusqu’à 6 photos · JPG, PNG', 11.5, Color(0xFF66636E))),
      gP(336.75, 213.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 268, 92, 16, gText('Titre du produit', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 288, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 288, 342, 48, GField(hint: 'Ex. Lampe en bois recyclé', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 48, onChanged: (v) { ref.read(formProvider.notifier).put('np_title', v); })),
      errorText('np_title', 28, 338),
      gP(37.5, 301.5, 20.996, 20.996, gImg('assets/figma/v/5cb3a366ba37dc.svg')),
      gP(40.875, 304.875, 7.5, 7.5, gImg('assets/figma/v/af3b58bd7187b4.svg')),
      gP(24, 350, 61, 16, gText('Catégorie', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 370, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 370, 342, 48, GField(hint: '', initial: 'Maison et déco', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48, onChanged: (v) { ref.read(formProvider.notifier).put('np_cat', v); })),
      errorText('np_cat', 28, 420),
      gP(38.25, 384.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 384.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 392.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(38.25, 392.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(334.5, 388.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 432, 66, 16, gText('Prix (FCFA)', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 452, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      errorText('np_price', 28, 502),
      gP(72, 467, 49, 17, gText('25 000', 13.5, Color(0xFF111015), weight: 500)),
      gP(24, 514, 108, 16, gText('Quantité en stock', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 534, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 534, 342, 48, GField(hint: '', initial: '15', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48, onChanged: (v) { ref.read(formProvider.notifier).put('np_stock', v); })),
      errorText('np_stock', 28, 584),
      gP(38.25, 548.25, 19.5, 18.75, gImg('assets/figma/v/959bd6157e02d7.svg')),
      gP(38.25, 552, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(45, 554.25, 6, 9.75, gImg('assets/figma/v/0fc23fb9b18d78.svg')),
      gP(24, 596, 71, 16, gText('Description', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 616, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 616, 342, 96, GField(hint: 'Matériaux, dimensions, particularités…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, onChanged: (v) { ref.read(formProvider.notifier).put('np_desc', v); }, multiline: true, padT: 14)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Brouillon')),
      gP(74.5, 778, 62, 18, gText('Brouillon', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Publier')),
      gP(260, 778, 49, 18, gText('Publier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(37.5, 468.5, 21, 15, gImg('assets/figma/v/24162e31d4b858.svg')),
      gP(43.125, 471.125, 9.75, 9.75, gImg('assets/figma/v/b916ebbd5954b5.svg')),
      gP(40.5, 473, 15.007, 6, gImg('assets/figma/v/bc5c9bd2e55ecc.svg')),
      gP(316, 468, 34, 16, gText('FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gTap(24, 760, 163, 54, () { submitListing(ref, context, publish: false); }),
      gTap(203, 760, 163, 54, () { submitListing(ref, context, publish: true); }),
    ]);
  }
}
