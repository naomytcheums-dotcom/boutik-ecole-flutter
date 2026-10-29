// GÉNÉRÉ par tool/figma_export/convert.py — écran 24 (nœud Figma 29:246). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_24 extends ConsumerWidget {
  const G_24({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(23.377, 68.788, 20.526, 20.526, const SizedBox.expand(), tap: () => gBack(context)),
      gP(24.654, 70.064, 11.987, 17.974, gImg('assets/figma/v/6e397023db5f6e.svg')),
      gP(24.654, 76.051, 17.974, 6, gImg('assets/figma/v/2ea5f4f7a32005.svg')),
      gP(283.377, 63.729, 34.211, 34.211, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1F122640), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], oval: true)),
      gP(290.816, 77.834, 19.333, 14.333, gImg('assets/figma/v/9c92298f9fd6b2.svg')),
      gP(294.149, 69.5, 12.667, 9.333, gImg('assets/figma/v/bb8ad3c4792df6.svg')),
      gP(297.482, 69.5, 6, 16.833, gImg('assets/figma/v/5bb53be308dfb1.svg')),
      gP(311.886, 58.393, 6.842, 6.842, gBox(color: Color(0xFFF04438), oval: true)),
      gP(335.263, 64.869, 31.93, 31.93, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1F122640), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], oval: true)),
      gP(342.099, 76.693, 8.281, 8.281, gImg('assets/figma/v/cbc01f1ce0d6b1.svg')),
      gP(347.088, 76.693, 8.281, 8.281, gImg('assets/figma/v/31cb1f2be4b685.svg')),
      gP(352.077, 76.693, 8.281, 8.281, gImg('assets/figma/v/31cb1f2be4b685.svg')),
      gP(9.123, 105.797, 366.053, 117.09, gBox(image: 'assets/figma/img/a30d4e56acc9216d03ba2d7972f7dfac533b78bf.png', fit: BoxFit.cover, radii: [34, 34, 0, 0])),
      gP(9.123, 219.915, 366.053, 166.423, gBox(color: Color(0xFFFFFFFF))),
      gP(19.956, 180.439, 100.351, 100.351, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1F122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], oval: true)),
      gP(24.518, 185, 91.228, 91.228, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, oval: true)),
      gP(131.711, 236.634, 153, 23, gText('Atelier Krea’Tech', 18.474, Color(0xFF111015), weight: 700)),
      gP(289.223, 239.629, 21.209, 21.203, gImg('assets/figma/v/29ca001164ff33.svg')),
      gP(294.553, 245.708, 10.561, 9.041, gImg('assets/figma/v/3f3aa7e88e58a9.svg')),
      gP(131.711, 271.946, 227, 15, gText('Étudiant · Génie informatique · IUT Douala', 11.54, Color(0xFF5A3FE0), weight: 500)),
      gP(20.526, 306.693, 351.228, 79.645, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x14122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(51.219, 321.317, 23, 29, gText('12', 22.807, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(35.219, 353.469, 55, 17, gText('Produits', 13.684, Color(0xFF66636E), align: TextAlign.center)),
      gP(137.254, 321.317, 14, 29, gText('3', 22.807, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(116.254, 353.469, 56, 17, gText('Services', 13.684, Color(0xFF66636E), align: TextAlign.center)),
      gP(216.579, 321.317, 15, 29, gText('5', 22.807, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(200.579, 353.469, 47, 17, gText('Projets', 13.684, Color(0xFF66636E), align: TextAlign.center)),
      gP(103.772, 326.901, 0.57, 41.606, gBox(color: Color(0xFFECE8F2))),
      gP(184.737, 326.901, 0.57, 41.606, gBox(color: Color(0xFFECE8F2))),
      gP(282.807, 325.713, 82.675, 41.606, gBox(color: Color(0xFF111015), radii: [19.956, 19.956, 19.956, 19.956])),
      gP(300.36, 337.016, 47, 19, gText('Suivre', 15.395, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(22.237, 410.707, 75.833, 34.473, 'Produits', 14.825, 600), GChip(108.904, 410.707, 76.974, 34.473, 'Services', 14.825, 500), GChip(196.14, 410.707, 75.263, 34.473, 'Projets', 14.825, 500), GChip(281.667, 410.707, 78.114, 34.473, 'À propos', 14.825, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 16.535)),
      gP(23.377, 472.314, 140, 23, gText('Produits phares', 18.246, Color(0xFF111015), weight: 700)),
      gP(286.667, 476.692, 60, 19, gText('Voir tout', 14.825, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.457, 483.192, 14.648, 6, gImg('assets/figma/v/65359442293145.svg')),
      gP(356.781, 478.868, 10.324, 14.648, gImg('assets/figma/v/8c6f45ed24c53c.svg')),
      gP(26.228, 512.938, 167.632, 142.054, gBox(image: 'assets/figma/img/cbf050b9f90ddf4164a56ebd171cee79dfa21141.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(163.07, 521.197, 25.088, 25.088, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(166.603, 525.331, 18.021, 16.819, gImg('assets/figma/v/51c4d0655963d1.svg')),
      gP(160.401, 518.528, 30.425, 30.425, GHeart()),
      gP(28.509, 665.511, 148, 17, gText('Lampe en bois recyclé', 13.684, Color(0xFF111015), weight: 700)),
      gP(28.509, 687.503, 87, 17, gText('25 000 FCFA', 13.684, Color(0xFF111015), weight: 600)),
      gP(24.558, 708.937, 19.304, 18.652, gImg('assets/figma/v/e093bb71f2a5e2.svg')),
      gP(44.474, 710.683, 23, 17, gText('4.8', 13.684, Color(0xFF111015), weight: 700)),
      gP(72, 710.683, 50, 17, gText('(24 avis)', 13.114, Color(0xFF66636E))),
      gP(209.825, 512.938, 161.93, 142.054, gBox(image: 'assets/figma/img/b49b6a241d16c8c01f026ab4fe2980adaae1b6f4.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(340.395, 521.197, 25.088, 25.088, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(343.928, 525.331, 18.021, 16.819, gImg('assets/figma/v/51c4d0655963d1.svg')),
      gP(337.726, 518.528, 30.425, 30.425, GHeart()),
      gP(212.105, 665.511, 127, 17, gText('Support téléphone', 13.684, Color(0xFF111015), weight: 700)),
      gP(212.105, 687.503, 79, 17, gText('8 000 FCFA', 13.684, Color(0xFF111015), weight: 600)),
      gP(208.155, 708.937, 19.304, 18.652, gImg('assets/figma/v/e093bb71f2a5e2.svg')),
      gP(228.07, 710.683, 22, 17, gText('4.7', 13.684, Color(0xFF111015), weight: 700)),
      gP(255.596, 710.683, 47, 17, gText('(18 avis)', 13.114, Color(0xFF66636E))),
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
