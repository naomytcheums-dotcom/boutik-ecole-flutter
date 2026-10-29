// GÉNÉRÉ par tool/figma_export/convert.py — écran 240 (nœud Figma 125:3). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_240 extends ConsumerWidget {
  const G_240({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(118, 76, 154, 21, gText('Parrainer et gagner', 17, Color(0xFF111015), weight: 500)),
      gP(133, 100, 124, 15, gText('Invite, partage, gagne', 12, Color(0xFF66636E))),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(24, 124, 342, 190, gBox(gradient: LinearGradient(begin: Alignment(-1.24, -0.68), end: Alignment(0.36, 0.52), colors: [Color(0xFF1B1630), Color(0xFF4A38B8)], stops: [0, 1]), shadows: [BoxShadow(color: Color(0x40403366), offset: Offset(0, 12), blurRadius: 26, spreadRadius: 0)], radii: [36, 36, 36, 36])),
      gP(156, 127, 210, 190, gBox(image: 'assets/figma/img/dcc189ec3061c0a7f846c33f817967caebc73f00.png', fit: BoxFit.contain, shadows: [BoxShadow(color: Color(0x66403366), offset: Offset(0, 16), blurRadius: 24, spreadRadius: 0)])),
      gP(44, 146, 203, 56, gText('Invite, partage,\ngagne.', 22, Color(0xFFFFFFFF), weight: 600, lh: 28, wrap: true)),
      gP(44, 218, 153, 32, gText('Chaque ami inscrit te rapporte des FCFA.', 11.5, Color(0xFFFFFFFF), lh: 16, wrap: true)),
      gP(44, 266, 170, 32, gBox(color: Color(0x29FFFFFF), radii: [16, 16, 16, 16])),
      gP(66, 274, 126, 14, gText('Mes gains · 12 500 FCFA', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(44, 344, 109, 15, gText('Ton lien d’invitation', 12, Color(0xFF66636E), weight: 500)),
      gP(44, 366, 222, 40, GField(hint: '', initial: 'boutik-ecole.cm/r/mariam24', size: 12, hintColor: Color(0xFF111015), weight: 500, padL: 14)),
      gP(274, 366, 74, 40, gBox(color: Color(0xFF111015), radii: [20, 20, 20, 20])),
      gP(287.375, 381.375, 13.042, 13.042, gImg('assets/figma/v/a5ad75fcb14e8a.svg')),
      gP(283.583, 377.583, 13.042, 13.042, gImg('assets/figma/v/872da465016e01.svg')),
      gP(304.5, 377, 37, 14, gText('Copier', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 438, 81, 18, gText('Partager via', 14, Color(0xFF111015), weight: 600)),
      gP(26, 458, 52, 52, gImg('assets/figma/v/41d92aae39217a.svg')),
      gP(41.824, 474.292, 20.456, 19.427, gImg('assets/figma/v/cc055366194d41.svg')),
      gP(34.697, 466.625, 34.606, 34.75, gImg('assets/figma/v/ae41431402bd9a.svg')),
      gP(27.5, 514, 49, 12, gText('WhatsApp', 9.5, Color(0xFF111015), weight: 500)),
      gP(83.4, 458, 52, 52, gImg('assets/figma/v/79ba193cd7b391.svg')),
      gP(99.117, 467.775, 20.95, 35.517, gImg('assets/figma/v/783d3b2476a4b6.svg')),
      gP(85.9, 514, 47, 12, gText('Facebook', 9.5, Color(0xFF111015), weight: 500)),
      gP(143.8, 461, 46, 46, gImg('assets/figma/r/165_179.png')),
      gP(152.3, 469.5, 29, 29, gImg('assets/figma/v/447497e7004aa0.svg')),
      gP(158.433, 475.633, 16.733, 16.733, gImg('assets/figma/v/52b9abe723ab5e.svg')),
      gP(168.879, 472.279, 9.642, 9.642, gImg('assets/figma/v/3844ecb637519d.svg')),
      gP(143.8, 514, 46, 12, gText('Instagram', 9.5, Color(0xFF111015), weight: 500)),
      gP(198.2, 458, 52, 52, gImg('assets/figma/v/e2f6fed8d0ae36.svg')),
      gP(207.903, 465.068, 30.917, 34.768, gImg('assets/figma/v/e24ae93b7a8c2f.svg')),
      gP(209.58, 466.266, 30.917, 34.768, gImg('assets/figma/v/3e32d15483106c.svg')),
      gP(208.742, 465.667, 30.917, 34.768, gImg('assets/figma/v/ab1d5753aa51d4.svg')),
      gP(209.7, 514, 29, 12, gText('TikTok', 9.5, Color(0xFF111015), weight: 500)),
      gP(257.6, 460, 48, 48, gBox(color: Color(0x246A4DFF), oval: true)),
      gP(271.1, 473.5, 21, 21, gImg('assets/figma/v/75f5a695259a06.svg')),
      gP(271.1, 514, 21, 12, gText('SMS', 9.5, Color(0xFF111015), weight: 500)),
      gP(315, 460, 48, 48, gBox(color: Color(0x24FF7A1A), oval: true)),
      gP(327.667, 483.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(330.167, 473.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(339.333, 473.583, 11, 20.917, gImg('assets/figma/v/d84ac38e1914fb.svg')),
      gP(317.5, 514, 43, 12, gText('Contacts', 9.5, Color(0xFF111015), weight: 500)),
      gP(44, 558, 102, 19, gText('Niveau Argent', 15, Color(0xFF111015), weight: 600)),
      gP(280, 554, 66, 26, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(292, 560, 42, 14, gText('7 filleuls', 11, Color(0xFF5A3FE0), weight: 600)),
      gP(44, 584, 178, 14, gText('Plus que 13 filleuls pour passer Or', 11.5, Color(0xFF66636E))),
      gP(44, 606, 302, 10, gBox(color: Color(0xFFECE8F6), radii: [5, 5, 5, 5])),
      gP(44, 606, 106, 10, gBox(gradient: LinearGradient(begin: Alignment(-1.24, -0.68), end: Alignment(0.36, 0.52), colors: [Color(0xFF9B7BFF), Color(0xFF6A4DFF)], stops: [0, 1]), radii: [5, 5, 5, 5])),
      gP(44, 636, 96, 88, gBox(color: Color(0xFFF6F3FA), radii: [22, 22, 22, 22])),
      gP(71.5, 646, 41, 15, gText('Bronze', 12, Color(0xFF111015), weight: 600)),
      gP(71.5, 664, 41, 12, gText('1 à 4 amis', 9.5, Color(0xFF66636E))),
      gP(77, 682, 30, 13, gText('500 F', 10.5, Color(0xFF111015), weight: 700)),
      gP(71, 698, 42, 11, gText('par inscrit', 9, Color(0xFF66636E))),
      gP(148, 636, 96, 88, gBox(color: Color(0xFFEEE9FF), radii: [22, 22, 22, 22])),
      gP(176, 646, 40, 15, gText('Argent', 12, Color(0xFF5A3FE0), weight: 600)),
      gP(172.5, 664, 47, 12, gText('5 à 19 amis', 9.5, Color(0xFF66636E))),
      gP(167, 682, 58, 13, gText('750 F + 2 %', 10.5, Color(0xFF111015), weight: 700)),
      gP(172.5, 698, 47, 11, gText('des ventes', 9, Color(0xFF66636E))),
      gP(252, 636, 96, 88, gBox(color: Color(0xFFF6F3FA), radii: [22, 22, 22, 22])),
      gP(292.5, 646, 15, 15, gText('Or', 12, Color(0xFF111015), weight: 600)),
      gP(273, 664, 54, 12, gText('20 et + amis', 9.5, Color(0xFF66636E))),
      gP(266.5, 682, 67, 13, gText('1 000 F + 3 %', 10.5, Color(0xFF111015), weight: 700)),
      gP(276.5, 698, 47, 11, gText('des ventes', 9, Color(0xFF66636E))),
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
      gP(328.817, 89.15, 18.667, 13.917, gImg('assets/figma/v/e486edd57af1c1.svg')),
      gP(331.983, 81.233, 12.333, 9.167, gImg('assets/figma/v/838f21166f81b6.svg')),
      gP(335.15, 81.233, 6, 16.292, gImg('assets/figma/v/d9aa0c7d61ed0e.svg')),
    ]);
  }
}
