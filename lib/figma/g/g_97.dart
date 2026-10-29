// GÉNÉRÉ par tool/figma_export/convert.py — écran 97 (nœud Figma 39:1085). Ne pas éditer à la main.
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

class G_97 extends ConsumerWidget {
  const G_97({super.key});

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
      gP(76, 70, 134, 26, gText('Recrutement', 21, Color(0xFF111015), weight: 700)),
      gP(342.583, 79, 18.833, 6, gImg('assets/figma/v/6fe571ab77e960.svg')),
      gP(349, 72.583, 6, 18.833, gImg('assets/figma/v/87cbf4a9a18b64.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 70.4, 34, 'Stages', 12.5, 600), GChip(102.4, 120, 77.8, 34, 'Emplois', 12.5, 500), GChip(188.2, 120, 100, 34, 'Alternance', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 181, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 193.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 190.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg')),
      gP(88, 180, 157, 17, gText('Stage développeur web', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 202, 181, 14, gText('8 candidatures · Publiée le 10 oct.', 11.5, Color(0xFF66636E))),
      gP(300, 190, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(313, 194, 26, 14, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 234, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 247, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 259.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 256.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg')),
      gP(88, 246, 152, 17, gText('Stage marketing digital', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 268, 183, 14, gText('5 candidatures · Publiée le 02 oct.', 11.5, Color(0xFF66636E))),
      gP(300, 256, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(313, 260, 26, 14, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 300, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 313, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 325.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 322.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg')),
      gP(88, 312, 116, 17, gText('Technicien réseau', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 334, 137, 14, gText('2 candidatures · Brouillon', 11.5, Color(0xFF66636E))),
      gP(274.4, 322, 77.6, 22, gBox(color: Color(0xFFF2EFF6), radii: [11, 11, 11, 11])),
      gP(289.7, 326, 47, 14, gText('Brouillon', 11, Color(0xFF66636E), weight: 600, align: TextAlign.center)),
      gP(24, 380, 342, 50, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [25, 25, 25, 25])),
      gP(150, 396, 115, 18, gText('Publier une offre', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125.542, 402, 15.917, 6, gImg('assets/figma/v/53a47ecfc209e9.svg')),
      gP(130.5, 397.042, 6, 15.917, gImg('assets/figma/v/8e0fc17de3058a.svg')),
      gP(24, 444, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 459, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 464.916, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 470.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 458, 277, 34, gText('Les candidatures vous sont envoyées avec le portfolio vérifié de l’étudiant.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
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
