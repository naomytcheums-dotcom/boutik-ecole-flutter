// GÉNÉRÉ par tool/figma_export/convert.py — écran P1 (nœud Figma 94:210). Ne pas éditer à la main.
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

class G_P1 extends ConsumerWidget {
  const G_P1({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, color: Color(0xFFFFFFFF), children: [
      gP(18, 92, 114, 244, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(140, 92, 124, 244, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(272, 92, 114, 244, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(0, 92, 390, 250, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0xFFFFFFFF)], stops: [0, 0.55, 1]))),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(138, 273, 114, 114, gBox(color: Color(0xFF111015), oval: true)),
      gP(143, 278, 104, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1A403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], oval: true)),
      gP(149, 284, 92, 92, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [46, 46, 46, 46])),
      gP(119.5, 392, 151, 29, gText('Aminata Bello', 23, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(277, 396, 16, 16, gBox(color: Color(0xFF2F7DF6), oval: true)),
      gP(278.667, 398.5, 12.667, 10.583, gImg('assets/figma/v/ca53f14df8dcc8.svg')),
      gP(91, 426, 208, 16, gText('#Vidéaste   #Directrice   #Designer', 12.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(29, 448, 332, 34, gText('Étudiante en MMI. Je crée des identités visuelles et des vidéos\npour des marques locales, du logo à la campagne.', 11.5, Color(0xFF6F6D77), lh: 17, align: TextAlign.center)),
      gP(34, 496, 104, 30, gBox(color: Color(0xFFF4F3F6), radii: [15, 15, 15, 15])),
      gP(45.5, 503, 81, 14, gText('2 695 Abonnés', 11.5, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(146, 496, 92, 30, gBox(color: Color(0xFFF4F3F6), radii: [15, 15, 15, 15])),
      gP(164.5, 503, 55, 14, gText('369 Suivis', 11.5, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(246, 496, 104, 30, gBox(color: Color(0xFFF4F3F6), radii: [15, 15, 15, 15])),
      gP(266, 503, 64, 14, gText('38 Missions', 11.5, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(104, 542, 28, 28, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [14, 14, 14, 14])),
      gP(124, 542, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [14, 14, 14, 14])),
      gP(144, 542, 28, 28, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [14, 14, 14, 14])),
      gP(96.5, 576, 75, 13, gText('Amis qui suivent', 10, Color(0xFF66636E), align: TextAlign.center)),
      gP(20, 598, 228, 112, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(256, 598, 114, 112, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(20, 718, 112, 138, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(140, 718, 114, 138, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(262, 718, 108, 138, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(22, 762, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 783.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 795.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 783.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 782.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 789.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 796.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 783.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 791.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 768, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 783, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 781.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gP(165, 371, 60, 20, gBox(color: Color(0xFFFF2D55), border: Color(0xFFFFFFFF), bw: 2, radii: [10, 10, 10, 10])),
      gP(173, 375.5, 44, 11, gText('EN DIRECT', 8.5, Color(0xFFFFFFFF), weight: 700), fx: 'pulse'),
      gP(232, 538, 138, 34, gBox(color: Color(0xFFF4F3F6), radii: [17, 17, 17, 17])),
      gP(241.083, 546.583, 16.833, 16.292, gImg('assets/figma/v/e1794306169e1f.svg')),
      gP(268, 547, 73, 13, gText('Avis & réseaux', 10.5, Color(0xFF111015), weight: 600)),
      gP(349.292, 552, 12.417, 6, gImg('assets/figma/v/f9fe15b4508898.svg')),
      gP(352.958, 549.25, 8.75, 11.5, gImg('assets/figma/v/9762f448d03542.svg')),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gTap(138, 273, 114, 114, () => gOpen(context, 'P2')),
      gTap(232, 538, 138, 34, () => gOpen(context, 'P3')),
      gTap(37.5, 495, 97, 32, () { gOpen(context, 'p2'); }), // lien métier p1 -> p2
    ]);
  }
}
