// GÉNÉRÉ par tool/figma_export/convert.py — écran 20 (nœud Figma 29:91). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_20 extends ConsumerWidget {
  const G_20({super.key});

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
      gP(18.997, 66.58, 18.997, 18.997, const SizedBox.expand(), tap: () => gBack(context)),
      gP(19.955, 67.538, 11.541, 17.082, gImg('assets/figma/v/f6fa21673ff638.svg')),
      gP(19.955, 73.079, 17.082, 6, gImg('assets/figma/v/2ac8074e1f73c6.svg')),
      gP(52.521, 57.059, 269.312, 39.228, gBox(color: Color(0xFFF2EFF6), radii: [18.438, 18.438, 18.438, 18.438])),
      gP(52.521, 57.059, 269.312, 39.228, GField(hint: '', initial: 'design', size: 15.086, hintColor: Color(0xFF44546A), weight: 500, padL: 39.112)),
      gP(62.02, 67.733, 17.88, 17.88, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(61.255, 66.968, 17.92, 17.92, gImg('assets/figma/v/09733bd88be228.svg')),
      gP(71.461, 77.175, 9.203, 9.203, gImg('assets/figma/v/fb9f2be96a2330.svg')),
      gP(334.126, 57.64, 36.877, 36.877, gBox(color: Color(0xFFF2EFF6), oval: true)),
      gP(351.054, 67.119, 11.215, 6, gImg('assets/figma/v/caba88e6f08d36.svg')),
      gP(342.86, 67.119, 11.215, 6, gImg('assets/figma/v/caba88e6f08d36.svg')),
      gP(349.564, 73.079, 12.705, 6, gImg('assets/figma/v/0e90dafec2509b.svg')),
      gP(342.86, 73.079, 9.725, 6, gImg('assets/figma/v/256fab80d73dbf.svg')),
      gP(352.544, 79.039, 9.725, 6, gImg('assets/figma/v/256fab80d73dbf.svg')),
      gP(342.86, 79.039, 12.705, 6, gImg('assets/figma/v/0e90dafec2509b.svg')),
      gP(351.054, 65.629, 6, 8.98, gImg('assets/figma/v/9754a656f51e20.svg')),
      gP(346.585, 71.589, 6, 8.98, gImg('assets/figma/v/9754a656f51e20.svg')),
      gP(352.544, 77.549, 6, 8.98, gImg('assets/figma/v/9754a656f51e20.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(20.115, 114.118, 55.874, 34.473, 'Tous', 15.086, 600), GChip(84.928, 114.118, 68.166, 34.473, 'Produits', 14.527, 500), GChip(163.152, 114.118, 69.284, 34.473, 'Services', 14.527, 500), GChip(242.493, 114.118, 65.931, 34.473, 'Talents', 14.527, 500), GChip(318.481, 114.118, 71.519, 34.473, 'Projets', 14.527, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 16.203)),
      gP(18.997, 175.037, 104, 22, gText('128 résultats', 17.321, Color(0xFF111015), weight: 600)),
      gP(24.026, 219.915, 160.917, 146.808, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(155.888, 227.237, 24.585, 24.585, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(159.29, 231.229, 17.78, 16.602, gImg('assets/figma/v/cee5332bab5d7e.svg')),
      gP(153.112, 224.462, 30.136, 30.136, GHeart()),
      gP(26.819, 380.31, 113, 18, gText('Sac à dos design', 13.968, Color(0xFF111015), weight: 700)),
      gP(26.819, 404.679, 88, 18, gText('25 000 FCFA', 13.968, Color(0xFF111015), weight: 600)),
      gP(26.819, 431.237, 80, 16, gText('Design – MMI', 12.851, Color(0xFF5A3FE0))),
      gP(208.41, 219.915, 162.034, 146.808, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(340.831, 227.237, 24.585, 24.585, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(344.233, 231.229, 17.78, 16.602, gImg('assets/figma/v/6fa11ee622414b.svg')),
      gP(338.055, 224.462, 30.136, 30.136, GHeart()),
      gP(211.203, 380.31, 158, 18, gText('Logo & identité visuelle', 13.968, Color(0xFF111015), weight: 700)),
      gP(211.203, 404.679, 85, 18, gText('15 000 FCFA', 13.968, Color(0xFF111015), weight: 600)),
      gP(211.203, 431.237, 107, 16, gText('Graphisme – TCO', 12.851, Color(0xFF5A3FE0))),
      gP(24.026, 479.654, 160.917, 146.808, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(156.447, 486.975, 24.585, 24.585, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(159.849, 490.967, 17.78, 16.602, gImg('assets/figma/v/6fa11ee622414b.svg')),
      gP(153.671, 484.2, 30.136, 30.136, GHeart()),
      gP(26.819, 640.048, 129, 18, gText('Application mobile', 13.968, Color(0xFF111015), weight: 700)),
      gP(26.819, 664.417, 90, 18, gText('50 000 FCFA', 13.968, Color(0xFF111015), weight: 600)),
      gP(26.819, 690.975, 136, 16, gText('Développement – Info', 12.851, Color(0xFF5A3FE0))),
      gP(208.41, 479.654, 162.034, 146.808, gBox(image: 'assets/figma/img/93dff03913a5b9f3a8ba8bc190862ebc295fc28d.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(340.831, 486.975, 24.585, 24.585, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(344.233, 490.967, 17.78, 16.602, gImg('assets/figma/v/cee5332bab5d7e.svg')),
      gP(338.055, 484.2, 30.136, 30.136, GHeart()),
      gP(211.203, 640.048, 119, 18, gText('Tableau décoratif', 13.968, Color(0xFF111015), weight: 700)),
      gP(211.203, 664.417, 86, 18, gText('18 000 FCFA', 13.968, Color(0xFF111015), weight: 600)),
      gP(211.203, 690.975, 98, 16, gText('Arts – Génie civil', 12.851, Color(0xFF5A3FE0))),
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
