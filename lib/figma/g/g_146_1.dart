// GÉNÉRÉ par tool/figma_export/convert.py — écran 146-1 (nœud Figma 43:2280). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_146_1 extends ConsumerWidget {
  const G_146_1({super.key});

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
      gP(24, 70, 153, 26, gText('Kiosque Bloc A', 21, Color(0xFF111015), weight: 700)),
      gP(340.75, 69.833, 22.5, 19.75, gImg('assets/figma/v/c416ae6fb27d36.svg')),
      gP(347.442, 87.25, 9.117, 6.922, gImg('assets/figma/v/76ffe03c455014.svg')),
      gP(24, 96, 167, 15, gText('Gestionnaire · Service retraits', 12, Color(0xFF66636E))),
      gP(24, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 132, 82, 14, gText('Retraits du jour', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 152, 25, 25, gText('24', 20, Color(0xFF111015), weight: 800)),
      gP(150, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(155.375, 137.375, 17.25, 16.625, gImg('assets/figma/v/0e7bfe7735ff71.svg')),
      gP(155.375, 140.5, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(161, 142.375, 6, 9.125, gImg('assets/figma/v/43269c010b1817.svg')),
      gP(200, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 132, 59, 14, gText('À remettre', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 152, 13, 25, gText('9', 20, Color(0xFF111015), weight: 800)),
      gP(214, 184, 52, 14, gText('Avant 17 h', 11, Color(0xFF8F5400), weight: 600)),
      gP(326, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 136.75, 18.5, 18.5, gImg('assets/figma/v/273a872595c6ee.svg')),
      gP(337, 139.25, 8.5, 11, gImg('assets/figma/v/6dc3ac1ada1685.svg')),
      gP(24, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 234, 87, 14, gText('Colis en attente', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 254, 21, 25, gText('31', 20, Color(0xFF111015), weight: 800)),
      gP(150, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(154.75, 245, 18.5, 7.875, gImg('assets/figma/v/7200c2482969af.svg')),
      gP(154.75, 240, 18.5, 16, gImg('assets/figma/v/137742ca7afd1b.svg')),
      gP(200, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 234, 52, 14, gText('Incidents', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 254, 9, 25, gText('1', 20, Color(0xFF111015), weight: 800)),
      gP(214, 286, 87, 14, gText('Casier 12 bloqué', 11, Color(0xFFE5484D), weight: 600)),
      gP(326, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.739, 239.366, 18.51, 17.259, gImg('assets/figma/v/2adfe02c023131.svg')),
      gP(337, 243.125, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(337, 248.125, 6.006, 6, gImg('assets/figma/v/ea7a417c4e88fe.svg')),
      gP(24, 328, 173, 19, gText('Commandes à remettre', 15, Color(0xFF111015), weight: 700)),
      gP(301, 330, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 335, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 331.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 366, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 374, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 378, 112, 17, gText('#BE-2026-0142', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 400, 123, 14, gText('Y. Mouanga · Casier 04', 11.5, Color(0xFF66636E))),
      gP(306.4, 388, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(317.7, 392, 23, 14, gText('Prêt', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 432, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 440, 50, 50, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 444, 109, 17, gText('#BE-2026-0141', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 466, 100, 14, gText('A. Bello · Casier 07', 11.5, Color(0xFF66636E))),
      gP(306.4, 454, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(317.7, 458, 23, 14, gText('Prêt', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 498, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 506, 50, 50, gBox(image: 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 510, 111, 17, gText('#BE-2026-0139', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 532, 129, 14, gText('B. Ndoumbe · Casier 09', 11.5, Color(0xFF66636E))),
      gP(268, 520, 84, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(282.5, 524, 55, 14, gText('En attente', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
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
    ]);
  }
}
