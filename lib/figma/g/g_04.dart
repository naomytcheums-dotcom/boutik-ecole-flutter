// GÉNÉRÉ par tool/figma_export/convert.py — écran 04 (nœud Figma 18:167). Ne pas éditer à la main.
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

class G_04 extends ConsumerWidget {
  const G_04({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1018, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 185.94, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 725.48, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(36.033, 18.967, 32, 20, gText('9:41', 15.543, Color(0xFF111015), weight: 700)),
      gP(292.63, 27.967, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(297.63, 24.967, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(302.63, 21.967, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(307.63, 18.967, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(318.63, 20.909, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(324.03, 28.767, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(343.13, 20.467, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(345.13, 22.467, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(366.63, 23.967, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(20.489, 64.293, 22.609, 22.609, const SizedBox.expand(), tap: () => gBack(context)),
      gP(22.199, 66.004, 12.594, 19.188, gImg('assets/figma/v/d9a6c70bc2ec95.svg')),
      gP(22.199, 72.598, 19.188, 6, gImg('assets/figma/v/04d0536a5eee71.svg')),
      gP(66.413, 62.598, 84, 26, gText('Explorer', 20.489, Color(0xFF111015), weight: 700)),
      gP(348.315, 64.293, 22.609, 22.609, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(348.141, 64.12, 21.072, 21.072, gImg('assets/figma/v/bc071aaa26d332.svg')),
      gP(361.047, 77.025, 10.051, 10.051, gImg('assets/figma/v/cf2d5b01cff302.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(18.37, 119.402, 61.467, 33.913, 'Tous', 13.424, 700), GChip(86.902, 119.402, 75.598, 33.913, 'Produits', 13.424, 500), GChip(168.859, 119.402, 75.598, 33.913, 'Services', 13.424, 500), GChip(252.228, 119.402, 66.413, 33.913, 'Talents', 13.424, 500), GChip(325.707, 119.402, 67.12, 33.913, 'Projets', 13.424, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 16.957)),
      gP(18.37, 185.815, 171.685, 268.478, const SizedBox.expand(), tap: () => gOpen(context, '05')),
      gP(19.783, 187.228, 168.859, 162.5, gBox(image: 'assets/figma/img/b49b6a241d16c8c01f026ab4fe2980adaae1b6f4.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(156.848, 193.587, 25.435, 25.435, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(160.678, 198.005, 17.775, 16.598, gImg('assets/figma/v/2b12c20ee1d37c.svg')),
      gP(154.5, 191.239, 30.13, 30.13, GHeart()),
      gP(24.022, 330.652, 70.652, 19.783, gBox(color: Color(0xFFFFFFFF), radii: [9.891, 9.891, 9.891, 9.891])),
      gP(29.029, 333.54, 14.007, 14.007, gImg('assets/figma/v/abbc45070a1369.svg')),
      gP(31.932, 336.442, 8.202, 8.202, gImg('assets/figma/v/03ad1fd81128c4.svg')),
      gP(45.924, 333.543, 40, 14, gText('Produit', 11.304, Color(0xFF111015), weight: 500)),
      gP(28.967, 363.522, 121, 36, gText('Pots connectés pour\nl’agriculture urbaine', 12.1, Color(0xFF111015), weight: 600, lh: 17.663)),
      gP(28.967, 406.728, 78, 16, gText('15 000 FCFA', 12.717, Color(0xFF111015), weight: 600)),
      gP(28.967, 429.424, 131, 13, gText('Département : Agronomie', 10.598, Color(0xFF66636E))),
      gP(207.717, 187.228, 166.033, 162.5, gBox(image: 'assets/figma/img/209b06d9669544abc2d1f3eb45ceb34026db6495.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(341.957, 193.587, 25.435, 25.435, gBox(color: Color(0x8CFFFFFF), oval: true)),
      gP(345.786, 198.005, 17.775, 16.598, gImg('assets/figma/v/3c86e00b06e768.svg')),
      gP(339.609, 191.239, 30.13, 30.13, GHeart()),
      gP(211.25, 313.696, 62.88, 22.609, gBox(color: Color(0xFF19C3E6), radii: [11.304, 11.304, 11.304, 11.304])),
      gP(220.337, 317.5, 44, 15, gText('Service', 12.011, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(216.902, 363.522, 124, 36, gText('Développement web\nsur mesure', 12.1, Color(0xFF111015), weight: 600, lh: 17.663)),
      gP(216.902, 406.728, 147, 16, gText('À partir de 30 000 FCFA', 12.717, Color(0xFF111015), weight: 600)),
      gP(216.902, 429.424, 140, 13, gText('Département : Informatique', 10.598, Color(0xFF66636E))),
      gP(19.783, 474.076, 168.859, 162.5, gBox(image: 'assets/figma/img/97b7907df36c390ae2383cc290f76358e22d2d7a.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(156.848, 480.435, 25.435, 25.435, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(160.678, 484.853, 17.775, 16.598, gImg('assets/figma/v/2b12c20ee1d37c.svg')),
      gP(154.5, 478.087, 30.13, 30.13, GHeart()),
      gP(23.315, 600.543, 50.87, 22.609, gBox(color: Color(0xFF19B7DE), radii: [11.304, 11.304, 11.304, 11.304])),
      gP(30.75, 604.348, 36, 15, gText('Projet', 12.011, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(28.967, 637.652, 121, 36, gText('Système de filtration\nd’eau innovant', 12.1, Color(0xFF111015), weight: 600, lh: 17.663)),
      gP(28.967, 682.359, 154, 13, gText('Département : Génie chimique', 10.598, Color(0xFF66636E))),
      gP(207.717, 474.076, 166.033, 162.5, gBox(image: 'assets/figma/img/8397f0465c777ec9d53e7683ddc72818ff961acd.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(341.957, 480.435, 25.435, 25.435, gBox(color: Color(0x8CFFFFFF), oval: true)),
      gP(345.786, 484.853, 17.775, 16.598, gImg('assets/figma/v/3c86e00b06e768.svg')),
      gP(339.609, 478.087, 30.13, 30.13, GHeart()),
      gP(211.25, 600.543, 55.815, 22.609, gBox(color: Color(0xFF8B7CF6), radii: [11.304, 11.304, 11.304, 11.304])),
      gP(222.011, 604.348, 35, 15, gText('Talent', 12.011, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(216.902, 637.652, 151, 36, gText('Montage vidéo & création\nde contenu', 12.1, Color(0xFF111015), weight: 600, lh: 17.663)),
      gP(216.902, 680.152, 144, 16, gText('À partir de 10 000 FCFA', 12.717, Color(0xFF111015), weight: 600)),
      gP(216.902, 702.848, 133, 13, gText('Département : Audiovisuel', 10.598, Color(0xFF66636E))),
      gP(18.37, 753.152, 354.674, 151.902, gBox(image: 'assets/figma/img/8f6ca1bb4903a4a383d533c9719e840c10c65c71.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 5), blurRadius: 14, spreadRadius: 0)], radii: [18.37, 18.37, 18.37, 18.37])),
      gP(18.37, 753.152, 354.674, 151.902, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xD1120F1A), Color(0x33120F1A)], stops: [0, 1]), radii: [18.37, 18.37, 18.37, 18.37])),
      gP(36.739, 779.891, 206, 20, gRich([('Vous êtes ', 16.25, 700, Color(0xFFFFFFFF)), ('une entreprise ?', 16.25, 700, Color(0xFFFBC02D))])),
      gP(36.739, 807.217, 184, 36, gText('Découvrez les talents et projets\nqui peuvent vous intéresser.', 12.364, Color(0xFFFFFFFF), lh: 17.663)),
      gP(36.739, 856.304, 110.217, 29.674, gBox(color: Color(0xFF111015), radii: [14.837, 14.837, 14.837, 14.837])),
      gP(50.87, 864.141, 73, 14, gText('En savoir plus', 11.304, Color(0xFFFFFFFF), weight: 600)),
      gP(124.91, 868.141, 13.006, 6, gImg('assets/figma/v/243355d11635f3.svg')),
      gP(128.413, 864.638, 9.503, 13.006, gImg('assets/figma/v/bcffd14c4cbbcd.svg')),
      gP(124.348, 1001.848, 142.011, 3.533, gBox(color: Color(0xFF111015), radii: [2.12, 2.12, 2.12, 2.12])),
      gP(22, 930, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 951.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 951.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 963.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 951.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 951.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 951.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 950.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 957.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 964.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 951.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 951.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 959.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 936, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 951, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 949.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(18, 186, 172, 268, () => gOpen(context, '05')),
    ]);
  }
}
