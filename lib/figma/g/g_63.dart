// GÉNÉRÉ par tool/figma_export/convert.py — écran 63 (nœud Figma 37:631). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_63 extends ConsumerWidget {
  const G_63({super.key});

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
      gP(24, 70, 205, 26, gText('Commandes reçues', 21, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 129.6, 34, 'À préparer (${ref.watch(sellerOrdersProvider).where((o) => statusOf(ref.watch(sellerStatusProvider), o.id) <= 1).length})', 12.5, 600), GChip(161.6, 120, 85.2, 34, 'En cours', 12.5, 500), GChip(254.8, 120, 70.4, 34, 'Prêtes', 12.5, 500), GChip(333.2, 120, 77.8, 34, 'Livrées', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, onChanged: (i) { ref.read(sellerOrderTabProvider.notifier).set(i); })),
      gP(24, 168, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 176, 50, 50, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleSellerOrdersProvider).length > 0)),
      gP(98, 180, 112, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 0 ? ref.watch(visibleSellerOrdersProvider)[0].id : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleSellerOrdersProvider).length > 0)),
      gP(98, 202, 162, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 0 ? '${ref.watch(visibleSellerOrdersProvider)[0].title} · ${ref.watch(visibleSellerOrdersProvider)[0].client}' : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleSellerOrdersProvider).length > 0)),
      gP(268, 190, 84, 22, gBox(color: (ref.watch(visibleSellerOrdersProvider).length > 0 ? sellerPillFill(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[0].id))) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleSellerOrdersProvider).length > 0)),
      gP(281.5, 194, 57, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 0 ? sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[0].id)) : '', 11, (ref.watch(visibleSellerOrdersProvider).length > 0 ? sellerPillInk(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[0].id))) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleSellerOrdersProvider).length > 0)),
      gP(98, 234, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 242, 50, 50, gBox(image: 'assets/figma/img/a76e4a9cacb04ffda33cfd8133809ed5cc5c402c.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleSellerOrdersProvider).length > 1)),
      gP(98, 246, 109, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 1 ? ref.watch(visibleSellerOrdersProvider)[1].id : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleSellerOrdersProvider).length > 1)),
      gP(98, 268, 170, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 1 ? '${ref.watch(visibleSellerOrdersProvider)[1].title} · ${ref.watch(visibleSellerOrdersProvider)[1].client}' : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleSellerOrdersProvider).length > 1)),
      gP(280.8, 256, 71.2, 22, gBox(color: (ref.watch(visibleSellerOrdersProvider).length > 1 ? sellerPillFill(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[1].id))) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleSellerOrdersProvider).length > 1)),
      gP(292.9, 260, 47, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 1 ? sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[1].id)) : '', 11, (ref.watch(visibleSellerOrdersProvider).length > 1 ? sellerPillInk(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[1].id))) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleSellerOrdersProvider).length > 1)),
      gP(98, 300, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 308, 50, 50, gBox(image: 'assets/figma/img/93dff03913a5b9f3a8ba8bc190862ebc295fc28d.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleSellerOrdersProvider).length > 2)),
      gP(98, 312, 111, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 2 ? ref.watch(visibleSellerOrdersProvider)[2].id : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleSellerOrdersProvider).length > 2)),
      gP(98, 334, 161, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 2 ? '${ref.watch(visibleSellerOrdersProvider)[2].title} · ${ref.watch(visibleSellerOrdersProvider)[2].client}' : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleSellerOrdersProvider).length > 2)),
      gP(268, 322, 84, 22, gBox(color: (ref.watch(visibleSellerOrdersProvider).length > 2 ? sellerPillFill(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[2].id))) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleSellerOrdersProvider).length > 2)),
      gP(281.5, 326, 57, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 2 ? sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[2].id)) : '', 11, (ref.watch(visibleSellerOrdersProvider).length > 2 ? sellerPillInk(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[2].id))) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleSellerOrdersProvider).length > 2)),
      gP(98, 366, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 374, 50, 50, gBox(image: 'assets/figma/img/cbf050b9f90ddf4164a56ebd171cee79dfa21141.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(visibleSellerOrdersProvider).length > 3)),
      gP(98, 378, 111, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 3 ? ref.watch(visibleSellerOrdersProvider)[3].id : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleSellerOrdersProvider).length > 3)),
      gP(98, 400, 165, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 3 ? '${ref.watch(visibleSellerOrdersProvider)[3].title} · ${ref.watch(visibleSellerOrdersProvider)[3].client}' : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleSellerOrdersProvider).length > 3)),
      gP(280.8, 388, 71.2, 22, gBox(color: (ref.watch(visibleSellerOrdersProvider).length > 3 ? sellerPillFill(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[3].id))) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleSellerOrdersProvider).length > 3)),
      gP(293.9, 392, 45, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleSellerOrdersProvider).length > 3 ? sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[3].id)) : '', 11, (ref.watch(visibleSellerOrdersProvider).length > 3 ? sellerPillInk(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(visibleSellerOrdersProvider)[3].id))) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleSellerOrdersProvider).length > 3)),
      gP(24, 446, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 461, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 466.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(49, 469.75, 8.833, 11.667, gImg('assets/figma/v/3a93fa78124c31.svg')),
      gP(76, 460, 277, 34, Consumer(builder: (context, ref, _) => gText('${ref.watch(sellerOrdersProvider).where((o) => statusOf(ref.watch(sellerStatusProvider), o.id) <= 1).length} commande(s) à préparer avant la remise.', 12, Color(0xFF4A4854), lh: 17, wrap: true))),
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
      gTap(24, 168, 342, 66, () { final l = ref.read(visibleSellerOrdersProvider); if (l.length > 0) { ref.read(selectedSellerOrderProvider.notifier).set(l[0].id); gOpen(context, '64'); } }),
      gTap(24, 234, 342, 66, () { final l = ref.read(visibleSellerOrdersProvider); if (l.length > 1) { ref.read(selectedSellerOrderProvider.notifier).set(l[1].id); gOpen(context, '64'); } }),
      gTap(24, 300, 342, 66, () { final l = ref.read(visibleSellerOrdersProvider); if (l.length > 2) { ref.read(selectedSellerOrderProvider.notifier).set(l[2].id); gOpen(context, '64'); } }),
      gTap(24, 366, 342, 66, () { final l = ref.read(visibleSellerOrdersProvider); if (l.length > 3) { ref.read(selectedSellerOrderProvider.notifier).set(l[3].id); gOpen(context, '64'); } }),
    ]);
  }
}
