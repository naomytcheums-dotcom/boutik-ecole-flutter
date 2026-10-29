// GÉNÉRÉ par tool/figma_export/convert.py — écran 227 (nœud Figma 87:673). Ne pas éditer à la main.
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

class G_227 extends ConsumerWidget {
  const G_227({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 914, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 151.62, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 636.04, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 146, 26, gText('Mon CV vivant', 21, Color(0xFF111015), weight: 700)),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 132, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 180, 14, gText('Génie informatique · mis à jour il …', 11.5, Color(0xFF66636E))),
      gP(306.4, 142, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(316.2, 146, 26, 14, gText('Auto', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(70.5, 214, 21, 25, gText('18', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(57.5, 244, 47, 14, gText('Missions', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(178, 214, 34, 25, gText('4,9', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(184, 244, 22, 14, gText('Avis', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 214, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(298.5, 214, 21, 25, gText('12', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(280, 244, 58, 14, gText('Certificats', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 214, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 290, 159, 19, gText('Se met à jour tout seul', 15, Color(0xFF111015), weight: 700)),
      gP(33, 350, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 329, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 333.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 328, 305, 17, gText('Mission livrée · Site Mairie', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 348, 305, 14, gText('Il y a 2 h · +1 mission, +1 avis', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 412, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 391, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 395.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 390, 305, 17, gText('Certificat obtenu · React', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 410, 305, 14, gText('Hier · ajouté et vérifié', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 453, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 457.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 452, 305, 17, gText('Duel gagné · Logo Mbella', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 472, 305, 14, gText('22 oct. · badge « Gagnante »', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 528, 177, 19, gText('Compétences prouvées', 15, Color(0xFF111015), weight: 700)),
      gP(40, 580, 128, 16, gText('Développement web', 12.5, Color(0xFF111015), weight: 600)),
      gP(335, 580, 15, 15, gText('92', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 602, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 602, 285.2, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(40, 624, 36, 16, gText('UI/UX', 12.5, Color(0xFF111015), weight: 600)),
      gP(335, 624, 15, 15, gText('78', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 646, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 646, 241.8, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 668, 106, 16, gText('Gestion de projet', 12.5, Color(0xFF111015), weight: 600)),
      gP(334, 668, 16, 15, gText('60', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 690, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 690, 186, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(24, 728, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 743, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.909, 748.92, 20.171, 20.165, gImg('assets/figma/v/e183fc825ad532.svg')),
      gP(46.875, 754.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 742, 277, 34, gText('Chaque ligne est liée à une preuve : mission, avis client ou certificat.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 902, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 826, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 847.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 847.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 859.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 847.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 847.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 847.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 846.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 853.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 860.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 847.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 847.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 855.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 832, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 847, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 845.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
