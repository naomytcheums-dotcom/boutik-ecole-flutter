// GÉNÉRÉ par tool/figma_export/convert.py — écran 182 (nœud Figma 61:884). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_182 extends ConsumerWidget {
  const G_182({super.key});

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
      gP(24, 70, 86, 26, gText('Explorer', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Rechercher un produit, service, t…', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(338.583, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(329.875, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(337, 141, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(329.875, 141, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(340.167, 147.333, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(329.875, 147.333, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(338.583, 133.083, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(333.833, 139.417, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(340.167, 145.75, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 182, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 182, 85.2, 34, 'Produits', 12.5, 500), GChip(180.8, 182, 85.2, 34, 'Services', 12.5, 500), GChip(274, 182, 77.8, 34, 'Talents', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 230, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 240, 46, 46, gBox(color: Color(0xFFE9EDF2), radii: [12, 12, 12, 12])),
      gP(94, 246, 171, 12, gBox(color: Color(0xFFE9EDF2), radii: [6, 6, 6, 6])),
      gP(94, 268, 109.44, 10, gBox(color: Color(0xFFF2EFF6), radii: [5, 5, 5, 5])),
      gP(24, 306, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 316, 46, 46, gBox(color: Color(0xFFE9EDF2), radii: [12, 12, 12, 12])),
      gP(94, 322, 171, 12, gBox(color: Color(0xFFE9EDF2), radii: [6, 6, 6, 6])),
      gP(94, 344, 109.44, 10, gBox(color: Color(0xFFF2EFF6), radii: [5, 5, 5, 5])),
      gP(24, 382, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 392, 46, 46, gBox(color: Color(0xFFE9EDF2), radii: [12, 12, 12, 12])),
      gP(94, 398, 171, 12, gBox(color: Color(0xFFE9EDF2), radii: [6, 6, 6, 6])),
      gP(94, 420, 109.44, 10, gBox(color: Color(0xFFF2EFF6), radii: [5, 5, 5, 5])),
      gP(24, 458, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 468, 46, 46, gBox(color: Color(0xFFE9EDF2), radii: [12, 12, 12, 12])),
      gP(94, 474, 171, 12, gBox(color: Color(0xFFE9EDF2), radii: [6, 6, 6, 6])),
      gP(94, 496, 109.44, 10, gBox(color: Color(0xFFF2EFF6), radii: [5, 5, 5, 5])),
      gP(24, 534, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 544, 46, 46, gBox(color: Color(0xFFE9EDF2), radii: [12, 12, 12, 12])),
      gP(94, 550, 171, 12, gBox(color: Color(0xFFE9EDF2), radii: [6, 6, 6, 6])),
      gP(94, 572, 109.44, 10, gBox(color: Color(0xFFF2EFF6), radii: [5, 5, 5, 5])),
      gP(24, 614, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 629, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 635.625, 18.75, 12.375, gImg('assets/figma/v/7a8746aa696a05.svg')),
      gP(51.833, 635.625, 9.542, 9.542, gImg('assets/figma/v/1bdada6d2922a2.svg')),
      gP(42.625, 642, 18.75, 12.375, gImg('assets/figma/v/4eac5b4499eb84.svg')),
      gP(42.625, 644.833, 9.542, 9.542, gImg('assets/figma/v/ff0a8029b488fe.svg')),
      gP(76, 628, 277, 34, gText('Chargement en cours… les contenus apparaissent progressivement.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
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
