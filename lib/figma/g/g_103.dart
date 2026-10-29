// GÉNÉRÉ par tool/figma_export/convert.py — écran 103 (nœud Figma 40:242). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_103 extends ConsumerWidget {
  const G_103({super.key});

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
      gP(76, 70, 140, 26, gText('Communauté', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 77.8, 34, 'Anciens', 12.5, 600), GChip(109.8, 120, 77.8, 34, 'Mentors', 12.5, 500), GChip(195.6, 120, 77.8, 34, 'Groupes', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 176, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 180, 100, 17, gText('Rodrigue Fotso', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 202, 169, 14, gText('Promo 2021 · Orange Camero…', 11.5, Color(0xFF66636E))),
      gP(255.2, 190, 96.8, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(267.6, 194, 72, 14, gText('Se connecter', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 234, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 242, 50, 50, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 246, 96, 17, gText('Carine Mbarga', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 268, 150, 14, gText('Promo 2022 · Studio Kreatif', 11.5, Color(0xFF66636E))),
      gP(255.2, 256, 96.8, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(267.6, 260, 72, 14, gText('Se connecter', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(98, 300, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 308, 50, 50, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 312, 107, 17, gText('Landry Essomba', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 334, 127, 14, gText('Promo 2020 · Camlight', 11.5, Color(0xFF66636E))),
      gP(280.8, 322, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(289.4, 326, 54, 14, gText('Connecté', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 380, 342, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(222.36, 380, 143.64, 132, gBox(image: 'assets/figma/img/b49b6a241d16c8c01f026ab4fe2980adaae1b6f4.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(195, 380, 68.4, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF1B3F6E), Color(0x001B3F6E)], stops: [0, 1]))),
      gP(42, 396, 174, 20, gText('Rejoignez un groupe', 15, Color(0xFFFFFFFF), weight: 700, lh: 20, wrap: true)),
      gP(42, 442, 160.32, 30, gText('Échangez avec les anciens de votre filière.', 11, Color(0xFFE9E4F5), lh: 15, wrap: true)),
      gP(42, 472, 86, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(61.5, 478, 47, 14, gText('Explorer', 11.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(24, 526, 144, 19, gText('Groupes populaires', 15, Color(0xFF111015), weight: 700)),
      gP(24, 564, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 577, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 596.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(47.167, 586.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(58.833, 596.608, 8.5, 10.892, gImg('assets/figma/v/f73f5c2da1a756.svg')),
      gP(56.333, 586.608, 8.507, 12.458, gImg('assets/figma/v/385c8732cbe0ba.svg')),
      gP(88, 576, 144, 17, gText('Entrepreneurs de l’IUT', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 598, 73, 14, gText('124 membres', 11.5, Color(0xFF66636E))),
      gP(336.75, 589.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 630, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 643, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 651.667, 16, 16, gImg('assets/figma/v/f44e883cdba29a.svg')),
      gP(50.5, 665, 11, 6, gImg('assets/figma/v/c4124addb3c439.svg')),
      gP(51.333, 668.333, 9.333, 6, gImg('assets/figma/v/df31b3079c9886.svg')),
      gP(88, 642, 162, 17, gText('Innovation et prototypes', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 664, 69, 14, gText('86 membres', 11.5, Color(0xFF66636E))),
      gP(336.75, 655.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
