// GÉNÉRÉ par tool/figma_export/convert.py — écran 78 (nœud Figma 38:738). Ne pas éditer à la main.
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

class G_78 extends ConsumerWidget {
  const G_78({super.key});

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
      gP(76, 70, 176, 26, gText('Projets innovants', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 120, 100, 34, 'Prototypes', 12.5, 500), GChip(195.6, 120, 92.6, 34, 'Recherche', 12.5, 500), GChip(296.2, 120, 107.4, 34, 'Financement', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, onChanged: (i) { ref.read(projectTabProvider.notifier).set(i); })),
      gP(24, 168, 342, 170, gBox(image: 'assets/figma/img/fbb2092962d6dc7886c56df2e6f5a1cfb07c25bb.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 168, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 276, 309, 23, gText('Drone éducatif connecté', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 304, 309, 15, gText('Team Innov’ · Génie électrique', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(24, 352, 137, 19, gText('Projets à découvrir', 15, Color(0xFF111015), weight: 700)),
      gP(301, 354, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 359, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 355.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(36, 398, 50, 50, gBox(image: 'assets/figma/img/9e2ce90f4496911ea5fab01d09cc48a0c7a22b47.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleProjectsProvider).length > 0)),
      gP(98, 402, 169, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 0 ? ref.watch(visibleProjectsProvider)[0].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleProjectsProvider).length > 0)),
      gP(98, 424, 119, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 0 ? ref.watch(visibleProjectsProvider)[0].sub : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleProjectsProvider).length > 0)),
      gP(280.8, 412, 71.2, 22, gBox(color: (ref.watch(visibleProjectsProvider).length > 0 ? stageFill(ref.watch(visibleProjectsProvider)[0].stage) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleProjectsProvider).length > 0)),
      gP(293.9, 416, 45, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 0 ? ref.watch(visibleProjectsProvider)[0].stage : '', 11, (ref.watch(visibleProjectsProvider).length > 0 ? stageInk(ref.watch(visibleProjectsProvider)[0].stage) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleProjectsProvider).length > 0)),
      gP(98, 456, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 464, 50, 50, gBox(image: 'assets/figma/img/55fe764cd9b0e1fc03c630662e027fb0f9f7ade4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleProjectsProvider).length > 1)),
      gP(98, 468, 111, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 1 ? ref.watch(visibleProjectsProvider)[1].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleProjectsProvider).length > 1)),
      gP(98, 490, 96, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 1 ? ref.watch(visibleProjectsProvider)[1].sub : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleProjectsProvider).length > 1)),
      gP(261.6, 478, 90.4, 22, gBox(color: (ref.watch(visibleProjectsProvider).length > 1 ? stageFill(ref.watch(visibleProjectsProvider)[1].stage) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleProjectsProvider).length > 1)),
      gP(271.8, 482, 70, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 1 ? ref.watch(visibleProjectsProvider)[1].stage : '', 11, (ref.watch(visibleProjectsProvider).length > 1 ? stageInk(ref.watch(visibleProjectsProvider)[1].stage) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleProjectsProvider).length > 1)),
      gP(98, 522, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 530, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleProjectsProvider).length > 2)),
      gP(98, 534, 158, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 2 ? ref.watch(visibleProjectsProvider)[2].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleProjectsProvider).length > 2)),
      gP(98, 556, 112, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 2 ? ref.watch(visibleProjectsProvider)[2].sub : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleProjectsProvider).length > 2)),
      gP(287.2, 544, 64.8, 22, gBox(color: (ref.watch(visibleProjectsProvider).length > 2 ? stageFill(ref.watch(visibleProjectsProvider)[2].stage) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleProjectsProvider).length > 2)),
      gP(298.6, 548, 42, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 2 ? ref.watch(visibleProjectsProvider)[2].stage : '', 11, (ref.watch(visibleProjectsProvider).length > 2 ? stageInk(ref.watch(visibleProjectsProvider)[2].stage) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleProjectsProvider).length > 2)),
      gP(98, 588, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 596, 50, 50, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleProjectsProvider).length > 3)),
      gP(98, 600, 171, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 3 ? ref.watch(visibleProjectsProvider)[3].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleProjectsProvider).length > 3)),
      gP(98, 622, 127, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 3 ? ref.watch(visibleProjectsProvider)[3].sub : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleProjectsProvider).length > 3)),
      gP(274.4, 610, 77.6, 22, gBox(color: (ref.watch(visibleProjectsProvider).length > 3 ? stageFill(ref.watch(visibleProjectsProvider)[3].stage) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleProjectsProvider).length > 3)),
      gP(285.7, 614, 55, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleProjectsProvider).length > 3 ? ref.watch(visibleProjectsProvider)[3].stage : '', 11, (ref.watch(visibleProjectsProvider).length > 3 ? stageInk(ref.watch(visibleProjectsProvider)[3].stage) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleProjectsProvider).length > 3)),
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
      gTap(300, 66, 66, 34, () { gOpen(context, '80'); }),
      gTap(24, 392, 342, 62, () { final l = ref.read(visibleProjectsProvider); if (l.length > 0) { ref.read(selectedProjectProvider.notifier).set(l[0].title); gOpen(context, '79'); } }),
      gTap(24, 458, 342, 62, () { final l = ref.read(visibleProjectsProvider); if (l.length > 1) { ref.read(selectedProjectProvider.notifier).set(l[1].title); gOpen(context, '79'); } }),
      gTap(24, 524, 342, 62, () { final l = ref.read(visibleProjectsProvider); if (l.length > 2) { ref.read(selectedProjectProvider.notifier).set(l[2].title); gOpen(context, '79'); } }),
      gTap(24, 590, 342, 62, () { final l = ref.read(visibleProjectsProvider); if (l.length > 3) { ref.read(selectedProjectProvider.notifier).set(l[3].title); gOpen(context, '79'); } }),
    ]);
  }
}
