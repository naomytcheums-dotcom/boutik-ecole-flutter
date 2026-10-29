// GÉNÉRÉ par tool/figma_export/convert.py — écran 22 (nœud Figma 35:307). Ne pas éditer à la main.
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

class G_22 extends ConsumerWidget {
  const G_22({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 910.5, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 150.465, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 633.03, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 229, 26, gText('Catalogue de produits', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 120, 70.4, 34, 'Maison', 12.5, 500), GChip(166, 120, 55.6, 34, 'Mode', 12.5, 500), GChip(229.6, 120, 55.6, 34, 'Tech', 12.5, 500), GChip(293.2, 120, 54, 34, 'Art', 12.5, 500), GChip(355.2, 120, 114.8, 34, 'Alimentation', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, onChanged: (i) { ref.read(categoryProvider.notifier).set(i); })),
      gP(24, 168, 90, 19, Consumer(builder: (context, ref, _) => gText(ref.watch(searchQueryProvider).trim().isEmpty ? '${ref.watch(filteredProductsProvider).length} produits' : '${ref.watch(filteredProductsProvider).length} résultat${ref.watch(filteredProductsProvider).length > 1 ? "s" : ""} pour « ${ref.watch(searchQueryProvider).trim()} »', 15, Color(0xFF111015), weight: 700))),
      gP(325, 170, 25, 15, gText('Trier', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 175, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 171.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(28, 210, 157, 115.5, gBox(image: (ref.watch(filteredProductsProvider).length > 0 ? ref.watch(filteredProductsProvider)[0].image : ''), fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(152, 217, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(156.167, 221.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg'), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(150, 215, 30, 30, GHeartLive(title: ref.watch(filteredProductsProvider).length > 0 ? ref.watch(filteredProductsProvider)[0].title : ''), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(36, 333.5, 136, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 0 ? ref.watch(filteredProductsProvider)[0].title : '', 12.5, Color(0xFF111015), weight: 700)), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(36, 351.5, 76, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 0 ? fcfa(ref.watch(filteredProductsProvider)[0].price) : '', 12, Color(0xFF111015), weight: 600)), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(36, 368.5, 51, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 0 ? ref.watch(filteredProductsProvider)[0].department : '', 10.5, Color(0xFF5A3FE0))), show: (ref.watch(filteredProductsProvider).length > 0)),
      gP(205, 210, 157, 115.5, gBox(image: (ref.watch(filteredProductsProvider).length > 1 ? ref.watch(filteredProductsProvider)[1].image : ''), fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(329, 217, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(333.167, 221.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg'), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(327, 215, 30, 30, GHeartLive(title: ref.watch(filteredProductsProvider).length > 1 ? ref.watch(filteredProductsProvider)[1].title : ''), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(213, 333.5, 91, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 1 ? ref.watch(filteredProductsProvider)[1].title : '', 12.5, Color(0xFF111015), weight: 700)), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(213, 351.5, 82, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 1 ? fcfa(ref.watch(filteredProductsProvider)[1].price) : '', 12, Color(0xFF111015), weight: 600)), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(213, 368.5, 83, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 1 ? ref.watch(filteredProductsProvider)[1].department : '', 10.5, Color(0xFF5A3FE0))), show: (ref.watch(filteredProductsProvider).length > 1)),
      gP(28, 407.5, 157, 115.5, gBox(image: (ref.watch(filteredProductsProvider).length > 2 ? ref.watch(filteredProductsProvider)[2].image : ''), fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(152, 414.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(156.167, 419.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg'), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(150, 412.5, 30, 30, GHeartLive(title: ref.watch(filteredProductsProvider).length > 2 ? ref.watch(filteredProductsProvider)[2].title : ''), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(36, 531, 101, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 2 ? ref.watch(filteredProductsProvider)[2].title : '', 12.5, Color(0xFF111015), weight: 700)), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(36, 549, 76, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 2 ? fcfa(ref.watch(filteredProductsProvider)[2].price) : '', 12, Color(0xFF111015), weight: 600)), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(36, 566, 65, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 2 ? ref.watch(filteredProductsProvider)[2].department : '', 10.5, Color(0xFF5A3FE0))), show: (ref.watch(filteredProductsProvider).length > 2)),
      gP(205, 407.5, 157, 115.5, gBox(image: (ref.watch(filteredProductsProvider).length > 3 ? ref.watch(filteredProductsProvider)[3].image : ''), fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(329, 414.5, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(333.167, 419.25, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg'), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(327, 412.5, 30, 30, GHeartLive(title: ref.watch(filteredProductsProvider).length > 3 ? ref.watch(filteredProductsProvider)[3].title : ''), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(213, 531, 95, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 3 ? ref.watch(filteredProductsProvider)[3].title : '', 12.5, Color(0xFF111015), weight: 700)), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(213, 549, 73, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 3 ? fcfa(ref.watch(filteredProductsProvider)[3].price) : '', 12, Color(0xFF111015), weight: 600)), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(213, 566, 56, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 3 ? ref.watch(filteredProductsProvider)[3].department : '', 10.5, Color(0xFF5A3FE0))), show: (ref.watch(filteredProductsProvider).length > 3)),
      gP(28, 605, 157, 115.5, gBox(image: (ref.watch(filteredProductsProvider).length > 4 ? ref.watch(filteredProductsProvider)[4].image : ''), fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(152, 612, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(156.167, 616.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg'), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(150, 610, 30, 30, GHeartLive(title: ref.watch(filteredProductsProvider).length > 4 ? ref.watch(filteredProductsProvider)[4].title : ''), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(36, 728.5, 116, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 4 ? ref.watch(filteredProductsProvider)[4].title : '', 12.5, Color(0xFF111015), weight: 700)), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(36, 746.5, 69, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 4 ? fcfa(ref.watch(filteredProductsProvider)[4].price) : '', 12, Color(0xFF111015), weight: 600)), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(36, 763.5, 78, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 4 ? ref.watch(filteredProductsProvider)[4].department : '', 10.5, Color(0xFF5A3FE0))), show: (ref.watch(filteredProductsProvider).length > 4)),
      gP(205, 605, 157, 115.5, gBox(image: (ref.watch(filteredProductsProvider).length > 5 ? ref.watch(filteredProductsProvider)[5].image : ''), fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(329, 612, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(333.167, 616.75, 17.667, 16.5, gImg('assets/figma/v/3a9ae4331031d0.svg'), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(327, 610, 30, 30, GHeartLive(title: ref.watch(filteredProductsProvider).length > 5 ? ref.watch(filteredProductsProvider)[5].title : ''), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(213, 728.5, 107, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 5 ? ref.watch(filteredProductsProvider)[5].title : '', 12.5, Color(0xFF111015), weight: 700)), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(213, 746.5, 74, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 5 ? fcfa(ref.watch(filteredProductsProvider)[5].price) : '', 12, Color(0xFF111015), weight: 600)), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(213, 763.5, 81, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(filteredProductsProvider).length > 5 ? ref.watch(filteredProductsProvider)[5].department : '', 10.5, Color(0xFF5A3FE0))), show: (ref.watch(filteredProductsProvider).length > 5)),
      gP(125, 898.5, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 822.5, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 844, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 843.625, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 855.613, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 844, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 843.618, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 844, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 842.75, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 849.75, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 856.75, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 844, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 843.625, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 852.375, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 828.5, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 843.5, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 842.352, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(24, 206, 132, 186, () { final l = ref.read(filteredProductsProvider); if (l.length > 0) { ref.read(selectedProductProvider.notifier).select(l[0].title); gOpen(context, '05'); } }),
      gTap(24, 254, 165, 138, () { final l = ref.read(filteredProductsProvider); if (l.length > 0) { ref.read(selectedProductProvider.notifier).select(l[0].title); gOpen(context, '05'); } }),
      gTap(201, 206, 132, 186, () { final l = ref.read(filteredProductsProvider); if (l.length > 1) { ref.read(selectedProductProvider.notifier).select(l[1].title); gOpen(context, '05'); } }),
      gTap(201, 254, 165, 138, () { final l = ref.read(filteredProductsProvider); if (l.length > 1) { ref.read(selectedProductProvider.notifier).select(l[1].title); gOpen(context, '05'); } }),
      gTap(24, 404, 132, 186, () { final l = ref.read(filteredProductsProvider); if (l.length > 2) { ref.read(selectedProductProvider.notifier).select(l[2].title); gOpen(context, '05'); } }),
      gTap(24, 452, 165, 138, () { final l = ref.read(filteredProductsProvider); if (l.length > 2) { ref.read(selectedProductProvider.notifier).select(l[2].title); gOpen(context, '05'); } }),
      gTap(201, 404, 132, 186, () { final l = ref.read(filteredProductsProvider); if (l.length > 3) { ref.read(selectedProductProvider.notifier).select(l[3].title); gOpen(context, '05'); } }),
      gTap(201, 452, 165, 138, () { final l = ref.read(filteredProductsProvider); if (l.length > 3) { ref.read(selectedProductProvider.notifier).select(l[3].title); gOpen(context, '05'); } }),
      gTap(24, 601, 132, 186, () { final l = ref.read(filteredProductsProvider); if (l.length > 4) { ref.read(selectedProductProvider.notifier).select(l[4].title); gOpen(context, '05'); } }),
      gTap(24, 649, 165, 138, () { final l = ref.read(filteredProductsProvider); if (l.length > 4) { ref.read(selectedProductProvider.notifier).select(l[4].title); gOpen(context, '05'); } }),
      gTap(201, 601, 132, 186, () { final l = ref.read(filteredProductsProvider); if (l.length > 5) { ref.read(selectedProductProvider.notifier).select(l[5].title); gOpen(context, '05'); } }),
      gTap(201, 649, 165, 138, () { final l = ref.read(filteredProductsProvider); if (l.length > 5) { ref.read(selectedProductProvider.notifier).select(l[5].title); gOpen(context, '05'); } }),
    ]);
  }
}
