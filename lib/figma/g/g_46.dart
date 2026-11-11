// GÉNÉRÉ par tool/figma_export/convert.py — écran 46 (nœud Figma 54:929). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/order_summary.dart';
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
import '../live/lots.dart';
import '../live/messages.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_46 extends ConsumerWidget {
  const G_46({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 854, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 131.82, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 584.44, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(21.98, 61.98, 40, 40, const GGlassCircle()),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 168, 26, gText('Suivi de livraison', 21, Color(0xFF111015), weight: 700)),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 143.333, 16, 17.667, gImg('assets/figma/v/4832049c28e839.svg')),
      gP(50.5, 155, 11, 6, gImg('assets/figma/v/f40c5534a6fd70.svg')),
      gP(54.667, 146.667, 12.667, 14.333, gImg('assets/figma/v/ffe0117573cb5a.svg')),
      gP(55.5, 153.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(47.167, 153.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(88, 132, 112, 17, gText(demoContent ? '#BE-2026-0142' : ref.watch(viewedOrderProvider).id, 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 154, 190, 14, Consumer(builder: (context, ref, _) => gText('Commande du ${ref.watch(viewedOrderProvider).date}', 11.5, Color(0xFF57545F)))),
      gP(252, 142, 100, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(252, 146, 100, 14, Consumer(builder: (context, ref, _) => gText(orderStatusLabel(ref.watch(viewedOrderProvider)), 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center))),
      gP(24, 200, 340, 248, const OrderTimeline()),
      gP(40, 470, 87, 16, gText('Point de retrait', 12.5, Color(0xFF57545F))),
      gP(228, 470, 122, 16, gText(gm('Kiosque IUT – Bloc A', ''), 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 495, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 504, 90, 16, gText('Code de retrait', 12.5, Color(0xFF57545F))),
      gP(303, 504, 47, 16, gText(demoContent ? '482 915' : '••• •••', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)), // code réel : bouton ci-dessous
      gP(0, 754, 390, 100, gBox(color: Color(0x00FFFFFF))),
      gP(24, 770, 163, 54, gBox(color: Color(0x00FFFFFF), border: Color(0xFFD9D3E6), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => contactOrderSeller(ref, context)),
      gP(31.5, 788, 148, 18, gText('Contacter le vendeur', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 770, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => showPickupCode(context, ref)),
      gP(210, 788, 149, 18, gText('Voir le code de retrait', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 840, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(48, 210, 102, 151, gImg('assets/figma/r/149_16.png'), show: false),
      gP(62.021, 320.665, 27.375, 11.277, gImg('assets/figma/v/74702652bc28de.svg'), show: false),
      gP(58.833, 323.542, 10, 10, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, oval: true), show: false),
      gP(82.583, 325.833, 10, 10, gBox(color: Color(0xFF120F14), border: Color(0xFFFFFFFF), bw: 2, oval: true), show: false),
      gP(194, 222, 36, 13, gText('Départ', 10.5, Color(0xFF57545F), weight: 500), show: false),
      gP(194, 238, 106, 18, gText('Douala · Littoral', 14, Color(0xFF120F14), weight: 600), show: false),
      gP(194, 272, 73, 13, gText('Arrivée prévue', 10.5, Color(0xFF57545F), weight: 500), show: false),
      gP(194, 288, 117, 18, gText('Yaoundé · Centre', 14, Color(0xFF120F14), weight: 600), show: false),
      gP(194, 322, 150, 30, gBox(color: Color(0xFFEDE8FF), radii: [15, 15, 15, 15]), show: false),
      gP(206, 330, 125, 13, gText(gm('235 km · 4 h 30 restantes', ''), 10.5, Color(0xFF5A3FE0), weight: 600), show: false),
    ]);
  }
}
