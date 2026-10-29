// GÉNÉRÉ par tool/figma_export/convert.py — écran 105 (nœud Figma 40:433). Ne pas éditer à la main.
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

class G_105 extends ConsumerWidget {
  const G_105({super.key});

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
      gP(76, 70, 218, 26, gText('Inter-établissements', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 120, 100, 34, 'IUT Douala', 12.5, 500), GChip(195.6, 120, 114.8, 34, 'IUT Bandjoun', 12.5, 500), GChip(318.4, 120, 129.6, 34, 'IUT Ngaoundéré', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 176, 19, gText('Créations des autres IUT', 15, Color(0xFF111015), weight: 700)),
      gP(28, 210, 157, 115.5, gBox(image: 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(152, 217, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 221.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(150, 215, 30, 30, GHeart()),
      gP(36, 333.5, 94, 16, gText('Tablette solaire', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 351.5, 77, 15, gText('45 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 368.5, 65, 13, gText('IUT Bandjoun', 10.5, Color(0xFF5A3FE0))),
      gP(205, 210, 157, 115.5, gBox(image: 'assets/figma/img/34e8344812f71c763e7e4b52e1acffce9319e372.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(329, 217, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 221.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(327, 215, 30, 30, GHeart()),
      gP(213, 333.5, 91, 16, gText('Séchoir à fruits', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 351.5, 77, 15, gText('30 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 368.5, 81, 13, gText('IUT Ngaoundéré', 10.5, Color(0xFF5A3FE0))),
      gP(28, 407.5, 157, 115.5, gBox(image: 'assets/figma/img/9e2ce90f4496911ea5fab01d09cc48a0c7a22b47.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(152, 414.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(156.167, 419.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(150, 412.5, 30, 30, GHeart()),
      gP(36, 531, 99, 16, gText('Pagne connecté', 12.5, Color(0xFF111015), weight: 700)),
      gP(36, 549, 74, 15, gText('18 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(36, 566, 65, 13, gText('IUT Bandjoun', 10.5, Color(0xFF5A3FE0))),
      gP(205, 407.5, 157, 115.5, gBox(image: 'assets/figma/img/55fe764cd9b0e1fc03c630662e027fb0f9f7ade4.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(329, 414.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(333.167, 419.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg')),
      gP(327, 412.5, 30, 30, GHeart()),
      gP(213, 531, 105, 16, gText('Radio à manivelle', 12.5, Color(0xFF111015), weight: 700)),
      gP(213, 549, 73, 15, gText('12 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(213, 566, 53, 13, gText('IUT Douala', 10.5, Color(0xFF5A3FE0))),
      gP(24, 603, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 618, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 625.333, 14.5, 15.917, gImg('assets/figma/v/6bea033be66ff5.svg')),
      gP(46.875, 635.25, 10.25, 6, gImg('assets/figma/v/1a8bffcb39d50d.svg')),
      gP(50.417, 628.167, 11.667, 13.083, gImg('assets/figma/v/d712451a4778a6.svg')),
      gP(51.125, 633.833, 8.833, 8.833, gImg('assets/figma/v/483dcfc435b4df.svg')),
      gP(44.042, 633.833, 8.833, 8.833, gImg('assets/figma/v/483dcfc435b4df.svg')),
      gP(76, 617, 277, 34, gText('La livraison inter-établissements prend de 3 à 7 jours.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
