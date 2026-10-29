// GÉNÉRÉ par tool/figma_export/convert.py — écran 46 (nœud Figma 54:929). Ne pas éditer à la main.
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
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 168, 26, gText('Suivi de livraison', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 143.333, 16, 17.667, gImg('assets/figma/v/4832049c28e839.svg')),
      gP(50.5, 155, 11, 6, gImg('assets/figma/v/f40c5534a6fd70.svg')),
      gP(54.667, 146.667, 12.667, 14.333, gImg('assets/figma/v/ffe0117573cb5a.svg')),
      gP(55.5, 153.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(47.167, 153.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(88, 132, 112, 17, gText('#BE-2026-0142', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 154, 149, 14, gText('Arrivée prévue demain · 14 h', 11.5, Color(0xFF66636E))),
      gP(280.8, 142, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(294.4, 146, 44, 14, gText('En route', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 200, 342, 170, gBox(color: Color(0xB2FFFFFF), radii: [28, 28, 28, 28])),
      gP(33, 406, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 385, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 389.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 384, 305, 17, gText('Commande confirmée', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 404, 305, 14, gText('22 oct. · 08:12', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 468, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 447, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 451.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 446, 305, 17, gText('Remise au transporteur', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 466, 305, 14, gText('23 oct. · 10:24', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 530, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 509, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 508, 305, 17, gText('En route vers le kiosque', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 528, 305, 14, gText('En cours', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 571, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 570, 305, 17, gText('Prête au retrait · Bloc A', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 590, 305, 14, gText('Demain · 14 h', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 646, 342, 84, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 658, 87, 16, gText('Point de retrait', 12.5, Color(0xFF66636E))),
      gP(228, 658, 122, 16, gText('Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 683, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 692, 90, 16, gText('Code de retrait', 12.5, Color(0xFF66636E))),
      gP(303, 692, 47, 16, gText('482 915', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(0, 754, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 770, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contacter le vendeur')),
      gP(31.5, 788, 148, 18, gText('Contacter le vendeur', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 770, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Voir le code de retrait')),
      gP(210, 788, 149, 18, gText('Voir le code de retrait', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 840, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(48, 210, 102, 151, gImg('assets/figma/r/149_16.png')),
      gP(62.021, 320.665, 27.375, 11.277, gImg('assets/figma/v/74702652bc28de.svg')),
      gP(58.833, 323.542, 10, 10, gBox(color: Color(0xFFFF7A1A), border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(82.583, 325.833, 10, 10, gBox(color: Color(0xFF120F14), border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(194, 222, 36, 13, gText('Départ', 10.5, Color(0xFF66636E), weight: 500)),
      gP(194, 238, 106, 18, gText('Douala · Littoral', 14, Color(0xFF120F14), weight: 600)),
      gP(194, 272, 73, 13, gText('Arrivée prévue', 10.5, Color(0xFF66636E), weight: 500)),
      gP(194, 288, 117, 18, gText('Yaoundé · Centre', 14, Color(0xFF120F14), weight: 600)),
      gP(194, 322, 150, 30, gBox(color: Color(0xFFEDE8FF), radii: [15, 15, 15, 15])),
      gP(206, 330, 125, 13, gText('235 km · 4 h 30 restantes', 10.5, Color(0xFF5A3FE0), weight: 600)),
    ]);
  }
}
