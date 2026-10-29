// GÉNÉRÉ par tool/figma_export/convert.py — écran 251 (nœud Figma 154:96). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_251 extends ConsumerWidget {
  const G_251({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 42, 114, 30, gText('Découvrir', 24, Color(0xFF111015), weight: 600)),
      gP(330, 36, 40, 40, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(340.625, 48.042, 18.75, 15.917, gImg('assets/figma/v/5fc2e1f97be34c.svg')),
      gP(24, 104, 342, 48, gBox(color: Color(0xB2FFFFFF), border: Color(0xFFFFFFFF), bw: 1, backBlur: 24, radii: [24, 24, 24, 24])),
      gP(24, 104, 342, 48, GField(hint: 'Rechercher un talent, un produit, un live', size: 12.5, hintColor: Color(0xFF66636E), weight: 400, padL: 48)),
      gP(38.625, 118.625, 17.333, 17.333, gImg('assets/figma/v/fc3dbed79a7c48.svg')),
      gP(48.329, 128.329, 9.046, 9.046, gImg('assets/figma/v/a4779ccb4d017c.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 166, 60, 32, 'Tout', 11.5, 500), GChip(92, 166, 52, 32, 'MMI', 11.5, 400), GChip(152, 166, 44, 32, 'GI', 11.5, 400), GChip(204, 166, 44, 32, 'GC', 11.5, 400), GChip(256, 166, 52, 32, 'TCO', 11.5, 400), GChip(316, 166, 60, 32, 'GEII', 11.5, 400)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 16)),
      gP(24, 214, 79, 19, gText('Tendances', 15, Color(0xFF111015), weight: 600)),
      gP(24, 242, 166, 236, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(200, 242, 166, 114, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [28, 28, 28, 28])),
      gP(200, 364, 166, 114, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [28, 28, 28, 28])),
      gP(34, 254, 49, 24, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(46, 260, 25, 12, gText('3,2 M', 9.5, Color(0xFFFFFFFF), weight: 600)),
      gP(313, 254, 43, 24, gBox(color: Color(0xFFFF2D55), radii: [100, 100, 100, 100])),
      gP(325, 260, 19, 12, gText('Live', 9.5, Color(0xFF111015), weight: 600), fx: 'pulse'),
      gP(24, 490, 110, 100, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(140, 490, 110, 100, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(256, 490, 110, 100, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(24, 606, 109, 19, gText('Talents à suivre', 15, Color(0xFF111015), weight: 600)),
      gP(24, 636, 80, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(44, 646, 40, 40, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(36.5, 690, 55, 13, gText('Aminata B.', 10.5, Color(0xFF111015), weight: 600)),
      gP(36, 712, 56, 20, gBox(color: Color(0xFF111015), radii: [10, 10, 10, 10])),
      gP(50, 716, 28, 11, gText('Suivre', 9, Color(0xFFFFFFFF), weight: 600)),
      gP(110, 636, 80, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(130, 646, 40, 40, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(130, 690, 40, 13, gText('Brice N.', 10.5, Color(0xFF111015), weight: 600)),
      gP(122, 712, 56, 20, gBox(color: Color(0xFF111015), radii: [10, 10, 10, 10])),
      gP(136, 716, 28, 11, gText('Suivre', 9, Color(0xFFFFFFFF), weight: 600)),
      gP(196, 636, 80, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(216, 646, 40, 40, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(212, 690, 48, 13, gText('Carine M.', 10.5, Color(0xFF111015), weight: 600)),
      gP(208, 712, 56, 20, gBox(color: Color(0xFF111015), radii: [10, 10, 10, 10])),
      gP(222, 716, 28, 11, gText('Suivre', 9, Color(0xFFFFFFFF), weight: 600)),
      gP(282, 636, 80, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(302, 646, 40, 40, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(297, 690, 50, 13, gText('Kouassi T.', 10.5, Color(0xFF111015), weight: 600)),
      gP(294, 712, 56, 20, gBox(color: Color(0xFF111015), radii: [10, 10, 10, 10])),
      gP(308, 716, 28, 11, gText('Suivre', 9, Color(0xFFFFFFFF), weight: 600)),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '247')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '244')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(24, 242, 166, 236, () => gOpen(context, '245')),
      gTap(200, 242, 166, 114, () => gOpen(context, '245')),
      gTap(200, 364, 166, 114, () => gOpen(context, '245')),
      gTap(24, 490, 110, 100, () => gOpen(context, '245')),
      gTap(140, 490, 110, 100, () => gOpen(context, '245')),
      gTap(256, 490, 110, 100, () => gOpen(context, '245')),
      gTap(24, 636, 80, 104, () => gOpen(context, '247')),
      gTap(110, 636, 80, 104, () => gOpen(context, '247')),
      gTap(196, 636, 80, 104, () => gOpen(context, '247')),
      gTap(282, 636, 80, 104, () => gOpen(context, '247')),
    ]);
  }
}
