// GÉNÉRÉ par tool/figma_export/convert.py — écran 216 (nœud Figma 87:2). Ne pas éditer à la main.
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

class G_216 extends ConsumerWidget {
  const G_216({super.key});

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
      gP(24, 70, 181, 26, gText('Marché des vœux', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      gP(24, 120, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 143.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.979, 149.417, 18.042, 17.688, gImg('assets/figma/v/e9085cf2b599c2.svg')),
      gP(76, 134, 277, 51, gText('Voici les produits que les étudiants veulent fabriquer. Précommandez : la production démarre quand le seuil est atteint.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 213, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 213, 144.4, 34, 'Presque atteints', 12.5, 500), GChip(240, 213, 85.2, 34, 'Nouveaux', 12.5, 500), GChip(333.2, 213, 144.4, 34, 'Mes précommandes', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 261, 342, 140, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(34, 271, 112, 120, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(158, 275, 199, 18, gText('Lampe en bois recyclé', 14, Color(0xFF111015), weight: 800, wrap: true)),
      gP(158, 295, 112, 14, gText('par Mouanga Yannick', 11, Color(0xFF66636E), weight: 500)),
      gP(158, 321, 192, 8, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(158, 321, 149.76, 8, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(158, 335, 136, 14, gText('156 / 200 précommandes', 11, Color(0xFF111015), weight: 600)),
      gP(158, 365, 89, 18, gText('25 000 FCFA', 14, Color(0xFFF5A81E), weight: 800)),
      gP(268, 359, 84, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(270, 365, 80, 13, gText('Précommander', 10.5, Color(0xFFFFFFFF), weight: 800, align: TextAlign.center)),
      gP(24, 413, 342, 140, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(34, 423, 112, 120, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(158, 427, 199, 18, gText('Jus de bissap bio', 14, Color(0xFF111015), weight: 800, wrap: true)),
      gP(158, 447, 79, 14, gText('par Équipe BTA', 11, Color(0xFF66636E), weight: 500)),
      gP(158, 473, 192, 8, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(158, 473, 81.92, 8, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(158, 487, 129, 14, gText('64 / 150 précommandes', 11, Color(0xFF111015), weight: 600)),
      gP(158, 517, 76, 18, gText('1 500 FCFA', 14, Color(0xFFF5A81E), weight: 800)),
      gP(268, 511, 84, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(270, 517, 80, 13, gText('Précommander', 10.5, Color(0xFFFFFFFF), weight: 800, align: TextAlign.center)),
      gP(24, 565, 342, 140, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(34, 575, 112, 120, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(158, 579, 199, 18, gText('Kit solaire de poche', 14, Color(0xFF111015), weight: 800, wrap: true)),
      gP(158, 599, 103, 14, gText('par Brice Ndoumbe', 11, Color(0xFF66636E), weight: 500)),
      gP(158, 625, 192, 8, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(158, 625, 53.76, 8, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(158, 639, 130, 14, gText('28 / 100 précommandes', 11, Color(0xFF111015), weight: 600)),
      gP(158, 669, 86, 18, gText('18 000 FCFA', 14, Color(0xFFF5A81E), weight: 800)),
      gP(268, 663, 84, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(270, 669, 80, 13, gText('Précommander', 10.5, Color(0xFFFFFFFF), weight: 800, align: TextAlign.center)),
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
