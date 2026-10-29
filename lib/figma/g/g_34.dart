// GÉNÉRÉ par tool/figma_export/convert.py — écran 34 (nœud Figma 35:828). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_34 extends ConsumerWidget {
  const G_34({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 950, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 163.5, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 667, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 74, 26, gText('Galerie', 21, Color(0xFF111015), weight: 700)),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
      gP(24, 120, 342, 250, gBox(image: 'assets/figma/img/d26d49b962f8ef08068e61f071cd2e0f7f73c5be.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 384, 79.5, 70, gBox(image: 'assets/figma/img/8397f0465c777ec9d53e7683ddc72818ff961acd.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(111.5, 384, 79.5, 70, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(199, 384, 79.5, 70, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(286.5, 384, 79.5, 70, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(24, 468, 81, 19, gText('Photos (12)', 15, Color(0xFF111015), weight: 700)),
      gP(301, 470, 49, 15, gText('Tout voir', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 475, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 471.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 506, 108.667, 92, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 506, 108.667, 92, gBox(image: 'assets/figma/img/93dff03913a5b9f3a8ba8bc190862ebc295fc28d.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 506, 108.667, 92, gBox(image: 'assets/figma/img/cbf050b9f90ddf4164a56ebd171cee79dfa21141.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(24, 612, 108.667, 92, gBox(image: 'assets/figma/img/b49b6a241d16c8c01f026ab4fe2980adaae1b6f4.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 612, 108.667, 92, gBox(image: 'assets/figma/img/209b06d9669544abc2d1f3eb45ceb34026db6495.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 612, 108.667, 92, gBox(image: 'assets/figma/img/97b7907df36c390ae2383cc290f76358e22d2d7a.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(24, 718, 162, 19, gText('Vidéo de présentation', 15, Color(0xFF111015), weight: 700)),
      gP(24, 756, 342, 150, gBox(image: 'assets/figma/img/285ea8d512e6fd1079056dd514be7a2ebad70bf2.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 756, 342, 150, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 844, 309, 23, gText('Fabrication de la lampe', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 872, 309, 15, gText('Vidéo · 1 min 24', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(125, 936, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
