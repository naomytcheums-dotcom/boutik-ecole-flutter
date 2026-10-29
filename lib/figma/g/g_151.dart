// GÉNÉRÉ par tool/figma_export/convert.py — écran 151 (nœud Figma 60:2). Ne pas éditer à la main.
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

class G_151 extends ConsumerWidget {
  const G_151({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 870, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 137.1, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 598.2, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(24, 70, 140, 26, gText('Opportunités', 21, Color(0xFF111015), weight: 700)),
      gP(340.75, 69.833, 22.5, 19.75, gImg('assets/figma/v/c416ae6fb27d36.svg')),
      gP(347.442, 87.25, 9.117, 6.922, gImg('assets/figma/v/76ffe03c455014.svg')),
      gP(24, 120, 342, 144, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 138, 32, 32, gBox(color: Color(0xFF111015), oval: true)),
      gP(48.625, 143.5, 18.75, 18.375, gImg('assets/figma/v/d177b28382093d.svg')),
      gP(58, 153.25, 10.5, 10.5, gImg('assets/figma/v/6fd6a3c35cbbc1.svg')),
      gP(84, 137, 269, 18, gText('Assistant Opportunités', 14, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(84, 160, 269, 32, gText('L’IA analyse votre profil et vous alerte quand un dossier est incomplet.', 11.5, Color(0xFFE9E4F5), lh: 16, wrap: true)),
      gP(46.667, 205.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(70, 204, 283, 15, gText('3 offres très compatibles', 12, Color(0xFFFFFFFF), weight: 500, wrap: true)),
      gP(46.667, 229.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(70, 228, 283, 15, gText('2 dossiers à compléter', 12, Color(0xFFFFFFFF), weight: 500, wrap: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 278, 55.6, 34, 'Tout', 12.5, 600), GChip(87.6, 278, 70.4, 34, 'Stages', 12.5, 500), GChip(166, 278, 77.8, 34, 'Emplois', 12.5, 500), GChip(251.8, 278, 77.8, 34, 'Projets', 12.5, 500), GChip(337.6, 278, 63, 34, 'Défis', 12.5, 500), GChip(408.6, 278, 100, 34, 'Hackathons', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, onChanged: (i) { ref.read(oppHubTabProvider.notifier).set(i); })),
      gP(24, 326, 72, 19, gText('Pour vous', 15, Color(0xFF111015), weight: 700)),
      gP(301, 328, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 333, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 329.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 364, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 377, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 389.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 386.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg'), show: (ref.watch(visibleOpportunities151).length > 0)),
      gP(88, 376, 157, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 0 ? ref.watch(visibleOpportunities151)[0].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleOpportunities151).length > 0)),
      gP(88, 398, 190, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 0 ? ref.watch(visibleOpportunities151)[0].org : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleOpportunities151).length > 0)),
      gP(306.4, 386, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11]), show: (ref.watch(visibleOpportunities151).length > 0)),
      gP(315.7, 390, 27, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 0 ? (ref.watch(visibleOpportunities151)[0].kind == 'Stage' || ref.watch(visibleOpportunities151)[0].kind == 'Emploi' ? '${ref.watch(visibleOpportunities151)[0].score} %' : ref.watch(visibleOpportunities151)[0].kind) : '', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleOpportunities151).length > 0)),
      gP(88, 430, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 443, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 453.333, 9.333, 10.167, gImg('assets/figma/v/ff038cff524fea.svg')),
      gP(58, 453.333, 9.333, 10.167, gImg('assets/figma/v/6d7d6e6c277316.svg')),
      gP(46.333, 468.333, 19.333, 6, gImg('assets/figma/v/3035c903f4ca6a.svg')),
      gP(48, 451.667, 16, 16.833, gImg('assets/figma/v/ddb12173c17b9f.svg'), show: (ref.watch(visibleOpportunities151).length > 1)),
      gP(88, 442, 199, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 1 ? ref.watch(visibleOpportunities151)[1].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleOpportunities151).length > 1)),
      gP(88, 464, 154, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 1 ? ref.watch(visibleOpportunities151)[1].org : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleOpportunities151).length > 1)),
      gP(287.2, 452, 64.8, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11]), show: (ref.watch(visibleOpportunities151).length > 1)),
      gP(295.6, 456, 48, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 1 ? (ref.watch(visibleOpportunities151)[1].kind == 'Stage' || ref.watch(visibleOpportunities151)[1].kind == 'Emploi' ? '${ref.watch(visibleOpportunities151)[1].score} %' : ref.watch(visibleOpportunities151)[1].kind) : '', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleOpportunities151).length > 1)),
      gP(88, 496, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 509, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 517.667, 16, 16, gImg('assets/figma/v/f44e883cdba29a.svg')),
      gP(50.5, 531, 11, 6, gImg('assets/figma/v/c4124addb3c439.svg')),
      gP(51.333, 534.333, 9.333, 6, gImg('assets/figma/v/df31b3079c9886.svg'), show: (ref.watch(visibleOpportunities151).length > 2)),
      gP(88, 508, 195, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 2 ? ref.watch(visibleOpportunities151)[2].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleOpportunities151).length > 2)),
      gP(88, 530, 121, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 2 ? ref.watch(visibleOpportunities151)[2].org : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleOpportunities151).length > 2)),
      gP(306.4, 518, 45.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11]), show: (ref.watch(visibleOpportunities151).length > 2)),
      gP(318.2, 522, 22, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleOpportunities151).length > 2 ? (ref.watch(visibleOpportunities151)[2].kind == 'Stage' || ref.watch(visibleOpportunities151)[2].kind == 'Emploi' ? '${ref.watch(visibleOpportunities151)[2].score} %' : ref.watch(visibleOpportunities151)[2].kind) : '', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleOpportunities151).length > 2)),
      gP(24, 576, 157, 19, gText('Dates limites proches', 15, Color(0xFF111015), weight: 700)),
      gP(24, 614, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 627, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 635.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 639, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 626, 152, 17, gText('Stage marketing digital', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 648, 107, 14, gText('Clôture dans 2 jours', 11.5, Color(0xFF66636E))),
      gP(312.8, 636, 39.2, 22, gBox(color: Color(0xFFFDE6E7), radii: [11, 11, 11, 11])),
      gP(323.4, 640, 18, 14, gText('J-2', 11, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(88, 680, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 693, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 701.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 705, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 692, 214, 17, gText('Concours d’innovation étudiante', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 714, 108, 14, gText('Clôture dans 5 jours', 11.5, Color(0xFF66636E))),
      gP(312.8, 702, 39.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(323.4, 706, 18, 14, gText('J-5', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(125, 858, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 782, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 803.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 803.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 815.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 803.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 803.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 803.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 802.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 809.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 816.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 803.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 803.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 811.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 788, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 803, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 801.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(24, 370, 342, 62, () { final l = ref.read(visibleOpportunities151); if (l.length > 0) { applyDialog(context, ref, l[0]); } }),
      gTap(24, 436, 342, 62, () { final l = ref.read(visibleOpportunities151); if (l.length > 1) { applyDialog(context, ref, l[1]); } }),
      gTap(24, 502, 342, 62, () { final l = ref.read(visibleOpportunities151); if (l.length > 2) { applyDialog(context, ref, l[2]); } }),
    ]);
  }
}
