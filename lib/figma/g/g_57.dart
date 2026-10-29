// GÉNÉRÉ par tool/figma_export/convert.py — écran 57 (nœud Figma 37:114). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_57 extends ConsumerWidget {
  const G_57({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 846, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 129.18, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 577.56, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(24, 70, 164, 26, gText('Tableau de bord', 21, Color(0xFF111015), weight: 700)),
      gP(340.75, 69.833, 22.5, 19.75, gImg('assets/figma/v/c416ae6fb27d36.svg')),
      gP(347.442, 87.25, 9.117, 6.922, gImg('assets/figma/v/76ffe03c455014.svg')),
      gP(24, 96, 197, 15, gText('Bonjour Mariam, voici votre activité', 12, Color(0xFF66636E))),
      gP(24, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 132, 84, 14, gText('Ventes du mois', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 152, 95, 25, Consumer(builder: (context, ref, _) => gText(fcfa(1245000 + ref.watch(ordersProvider).fold<int>(0, (a, o) => a + o.total)).replaceAll(' FCFA', ''), 20, Color(0xFF111015), weight: 800))),
      gP(38, 184, 75, 14, gText('+12 % vs sept.', 11, Color(0xFF0F7A52), weight: 600)),
      gP(150, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(154.75, 139.875, 18.5, 12.25, gImg('assets/figma/v/b8aa2d550e4e95.svg')),
      gP(163.5, 139.875, 9.75, 9.75, gImg('assets/figma/v/bf4c9c3198e949.svg')),
      gP(200, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 132, 72, 14, gText('Commandes', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 152, 25, 25, Consumer(builder: (context, ref, _) => gText('${38 + ref.watch(ordersProvider).length}', 20, Color(0xFF111015), weight: 800))),
      gP(214, 184, 92, 14, gText('+5 cette semaine', 11, Color(0xFF0F7A52), weight: 600)),
      gP(326, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(332, 136.75, 16, 18.5, gImg('assets/figma/v/b8b641560aad30.svg')),
      gP(334.5, 140.5, 11, 11, gImg('assets/figma/v/f82584207e62a2.svg')),
      gP(337, 139.562, 6, 12.875, gImg('assets/figma/v/084a5a2da19358.svg')),
      gP(24, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 234, 87, 14, gText('Revenu attendu', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 254, 84, 25, gText('320 000', 20, Color(0xFF111015), weight: 800)),
      gP(38, 286, 122, 14, gText('4 paiements en attente', 11, Color(0xFF8F5400), weight: 600)),
      gP(150, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(155.375, 239.375, 17.875, 14.125, gImg('assets/figma/v/b45a94448c908a.svg')),
      gP(155.375, 240.625, 17.25, 16, gImg('assets/figma/v/942aaa660c45c9.svg')),
      gP(200, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 234, 97, 14, gText('Annonces actives', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 254, 22, 25, Consumer(builder: (context, ref, _) => gText('${ref.watch(listingsProvider).where((l) => l.published).length}', 20, Color(0xFF111015), weight: 800))),
      gP(214, 286, 76, 14, Consumer(builder: (context, ref, _) => gText('${ref.watch(listingsProvider).where((l) => !l.published).length} en brouillon', 11, Color(0xFF8F5400), weight: 600))),
      gP(326, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 238.75, 18.497, 18.497, gImg('assets/figma/v/5afb705c6d0234.svg')),
      gP(333.562, 241.562, 7.25, 7.25, gImg('assets/figma/v/b3357e76bf0786.svg')),
      gP(24, 328, 342, 210, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 342, 177, 18, gText('Ventes mensuelles (FCFA)', 14, Color(0xFF111015), weight: 700)),
      gP(315, 344, 35, 14, gText('7 mois', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.right)),
      gP(44, 382, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 443, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 504, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(53.707, 462.843, 23.729, 41.157, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(57.071, 512, 17, 13, gText('Avr', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(96.85, 454.024, 23.729, 49.976, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(99.714, 512, 18, 13, gText('Mai', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(139.993, 456.964, 23.729, 47.036, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(142.357, 512, 19, 13, gText('Juin', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(183.136, 436.386, 23.729, 67.614, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(187, 512, 16, 13, gText('Juil', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(226.279, 423.647, 23.729, 80.353, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(226.143, 512, 24, 13, gText('Août', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(269.421, 405.028, 23.729, 98.972, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(268.786, 512, 25, 13, gText('Sept', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(312.564, 382, 23.729, 122, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(314.429, 512, 20, 13, gText('Oct', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 552, 172, 19, gText('Commandes à préparer', 15, Color(0xFF111015), weight: 700)),
      gP(301, 554, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 559, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 555.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 590, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 598, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(sellerOrdersProvider).length > 0)),
      gP(98, 602, 183, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(sellerOrdersProvider).length > 0 ? '${ref.watch(sellerOrdersProvider)[0].id} · ${ref.watch(sellerOrdersProvider)[0].title}' : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(sellerOrdersProvider).length > 0)),
      gP(98, 624, 159, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(sellerOrdersProvider).length > 0 ? '${ref.watch(sellerOrdersProvider)[0].client} · ${fcfa(ref.watch(sellerOrdersProvider)[0].total)}' : '', 11.5, Color(0xFF66636E))), show: (ref.watch(sellerOrdersProvider).length > 0)),
      gP(268, 612, 84, 22, gBox(color: (sellerPillFill(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(sellerOrdersProvider)[0].id)))), radii: [11, 11, 11, 11]), show: (ref.watch(sellerOrdersProvider).length > 0)),
      gP(281.5, 616, 57, 14, Consumer(builder: (context, ref, _) => gText(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(sellerOrdersProvider)[0].id)), 11, (sellerPillInk(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(sellerOrdersProvider)[0].id)))), weight: 600, align: TextAlign.center)), show: (ref.watch(sellerOrdersProvider).length > 0)),
      gP(98, 656, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 664, 50, 50, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [12, 12, 12, 12]), show: (ref.watch(sellerOrdersProvider).length > 1)),
      gP(98, 668, 190, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(sellerOrdersProvider).length > 1 ? '${ref.watch(sellerOrdersProvider)[1].id} · ${ref.watch(sellerOrdersProvider)[1].title}' : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(sellerOrdersProvider).length > 1)),
      gP(98, 690, 128, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(sellerOrdersProvider).length > 1 ? '${ref.watch(sellerOrdersProvider)[1].client} · ${fcfa(ref.watch(sellerOrdersProvider)[1].total)}' : '', 11.5, Color(0xFF66636E))), show: (ref.watch(sellerOrdersProvider).length > 1)),
      gP(280.8, 678, 71.2, 22, gBox(color: (sellerPillFill(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(sellerOrdersProvider)[1].id)))), radii: [11, 11, 11, 11]), show: (ref.watch(sellerOrdersProvider).length > 1)),
      gP(292.9, 682, 47, 14, Consumer(builder: (context, ref, _) => gText(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(sellerOrdersProvider)[1].id)), 11, (sellerPillInk(sellerStatusLabel(statusOf(ref.watch(sellerStatusProvider), ref.watch(sellerOrdersProvider)[1].id)))), weight: 600, align: TextAlign.center)), show: (ref.watch(sellerOrdersProvider).length > 1)),
      gP(125, 834, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 758, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 779.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 779.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 791.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 779.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 779.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 779.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 778.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 785.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 792.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 779.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 779.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 787.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 764, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 779, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 777.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(301, 552, 49, 15, () { gOpen(context, '63'); }),
      gTap(24, 590, 342, 132, () { gOpen(context, '63'); }),
    ]);
  }
}
