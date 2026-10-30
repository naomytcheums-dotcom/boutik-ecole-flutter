// GÉNÉRÉ par tool/figma_export/convert.py — écran 61 (nœud Figma 37:426). Ne pas éditer à la main.
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
import '../live/seller_edit.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_61 extends ConsumerWidget {
  const G_61({super.key});

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
      gP(24, 70, 153, 26, gText('Mon catalogue', 21, Color(0xFF111015), weight: 700)),
      gP(342.583, 79, 18.833, 6, gImg('assets/figma/v/6fe571ab77e960.svg')),
      gP(349, 72.583, 6, 18.833, gImg('assets/figma/v/87cbf4a9a18b64.svg')),
      gP(24, 120, 342, 48, GField(hint: 'Rechercher une annonce', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46, onChanged: (v) { ref.read(sellerQueryProvider.notifier).set(v); })),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gTab(context, '19')),
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
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 182, 92.6, 34, 'Tous (${ref.watch(listingsProvider).length})', 12.5, 600), GChip(124.6, 182, 77.8, 34, 'Publiés', 12.5, 500), GChip(210.4, 182, 100, 34, 'Brouillons', 12.5, 500), GChip(318.4, 182, 77.8, 34, 'Rupture', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, onChanged: (i) { ref.read(sellerFilterProvider.notifier).set(i); })),
      gP(36, 238, 50, 50, gBox(image: 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleListingsProvider).length > 0)),
      gP(98, 242, 145, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 0 ? ref.watch(visibleListingsProvider)[0].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleListingsProvider).length > 0)),
      gP(98, 264, 140, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 0 ? (ref.watch(visibleListingsProvider)[0].published ? '${fcfa(ref.watch(visibleListingsProvider)[0].price)} · ${ref.watch(visibleListingsProvider)[0].stock} en stock' : '${fcfa(ref.watch(visibleListingsProvider)[0].price)} · Brouillon') : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleListingsProvider).length > 0)),
      gP(293.6, 252, 58.4, 22, gBox(color: (ref.watch(visibleListingsProvider).length > 0 ? listingPillFill(ref.watch(visibleListingsProvider)[0].label) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleListingsProvider).length > 0)),
      gP(305.8, 256, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 0 ? ref.watch(visibleListingsProvider)[0].label : '', 11, (ref.watch(visibleListingsProvider).length > 0 ? listingPillInk(ref.watch(visibleListingsProvider)[0].label) : const Color(0xFF66636E)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleListingsProvider).length > 0)),
      gP(98, 296, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 304, 50, 50, gBox(image: 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleListingsProvider).length > 1)),
      gP(98, 308, 109, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 1 ? ref.watch(visibleListingsProvider)[1].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleListingsProvider).length > 1)),
      gP(98, 330, 136, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 1 ? (ref.watch(visibleListingsProvider)[1].published ? '${fcfa(ref.watch(visibleListingsProvider)[1].price)} · ${ref.watch(visibleListingsProvider)[1].stock} en stock' : '${fcfa(ref.watch(visibleListingsProvider)[1].price)} · Brouillon') : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleListingsProvider).length > 1)),
      gP(293.6, 318, 58.4, 22, gBox(color: (ref.watch(visibleListingsProvider).length > 1 ? listingPillFill(ref.watch(visibleListingsProvider)[1].label) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleListingsProvider).length > 1)),
      gP(305.8, 322, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 1 ? ref.watch(visibleListingsProvider)[1].label : '', 11, (ref.watch(visibleListingsProvider).length > 1 ? listingPillInk(ref.watch(visibleListingsProvider)[1].label) : const Color(0xFF66636E)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleListingsProvider).length > 1)),
      gP(98, 362, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 370, 50, 50, gBox(image: 'assets/figma/img/34e8344812f71c763e7e4b52e1acffce9319e372.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleListingsProvider).length > 2)),
      gP(98, 374, 124, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 2 ? ref.watch(visibleListingsProvider)[2].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleListingsProvider).length > 2)),
      gP(98, 396, 129, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 2 ? (ref.watch(visibleListingsProvider)[2].published ? '${fcfa(ref.watch(visibleListingsProvider)[2].price)} · ${ref.watch(visibleListingsProvider)[2].stock} en stock' : '${fcfa(ref.watch(visibleListingsProvider)[2].price)} · Brouillon') : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleListingsProvider).length > 2)),
      gP(274.4, 384, 77.6, 22, gBox(color: (ref.watch(visibleListingsProvider).length > 2 ? listingPillFill(ref.watch(visibleListingsProvider)[2].label) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleListingsProvider).length > 2)),
      gP(286.7, 388, 53, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 2 ? ref.watch(visibleListingsProvider)[2].label : '', 11, (ref.watch(visibleListingsProvider).length > 2 ? listingPillInk(ref.watch(visibleListingsProvider)[2].label) : const Color(0xFF66636E)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleListingsProvider).length > 2)),
      gP(98, 428, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 436, 50, 50, gBox(image: 'assets/figma/img/9e2ce90f4496911ea5fab01d09cc48a0c7a22b47.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleListingsProvider).length > 3)),
      gP(98, 440, 114, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 3 ? ref.watch(visibleListingsProvider)[3].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleListingsProvider).length > 3)),
      gP(98, 462, 134, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 3 ? (ref.watch(visibleListingsProvider)[3].published ? '${fcfa(ref.watch(visibleListingsProvider)[3].price)} · ${ref.watch(visibleListingsProvider)[3].stock} en stock' : '${fcfa(ref.watch(visibleListingsProvider)[3].price)} · Brouillon') : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleListingsProvider).length > 3)),
      gP(287.2, 450, 64.8, 22, gBox(color: (ref.watch(visibleListingsProvider).length > 3 ? listingPillFill(ref.watch(visibleListingsProvider)[3].label) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleListingsProvider).length > 3)),
      gP(298.1, 454, 43, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 3 ? ref.watch(visibleListingsProvider)[3].label : '', 11, (ref.watch(visibleListingsProvider).length > 3 ? listingPillInk(ref.watch(visibleListingsProvider)[3].label) : const Color(0xFF66636E)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleListingsProvider).length > 3)),
      gP(98, 494, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 502, 50, 50, gBox(image: 'assets/figma/img/55fe764cd9b0e1fc03c630662e027fb0f9f7ade4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleListingsProvider).length > 4)),
      gP(98, 506, 102, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 4 ? ref.watch(visibleListingsProvider)[4].title : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleListingsProvider).length > 4)),
      gP(98, 528, 125, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 4 ? (ref.watch(visibleListingsProvider)[4].published ? '${fcfa(ref.watch(visibleListingsProvider)[4].price)} · ${ref.watch(visibleListingsProvider)[4].stock} en stock' : '${fcfa(ref.watch(visibleListingsProvider)[4].price)} · Brouillon') : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleListingsProvider).length > 4)),
      gP(274.4, 516, 77.6, 22, gBox(color: (ref.watch(visibleListingsProvider).length > 4 ? listingPillFill(ref.watch(visibleListingsProvider)[4].label) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleListingsProvider).length > 4)),
      gP(289.7, 520, 47, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleListingsProvider).length > 4 ? ref.watch(visibleListingsProvider)[4].label : '', 11, (ref.watch(visibleListingsProvider).length > 4 ? listingPillInk(ref.watch(visibleListingsProvider)[4].label) : const Color(0xFF66636E)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleListingsProvider).length > 4)),
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
      gTap(300, 66, 66, 34, () { gOpen(context, '58'); }),
      gTap(24, 228, 342, 62, () => openListingRow(ref, context, 0)),
      gTap(24, 294, 342, 62, () => openListingRow(ref, context, 1)),
      gTap(24, 360, 342, 62, () => openListingRow(ref, context, 2)),
      gTap(24, 426, 342, 62, () => openListingRow(ref, context, 3)),
      gTap(24, 492, 342, 62, () => openListingRow(ref, context, 4)),
    ]);
  }
}
