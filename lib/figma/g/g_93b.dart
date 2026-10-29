// GÉNÉRÉ par tool/figma_export/convert.py — écran 93b (nœud Figma 39:816). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_93b extends ConsumerWidget {
  const G_93b({super.key});

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
      gP(76, 70, 120, 26, gText('Proposition', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 132, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 142, 14, gText('Génie informatique · 4.9 ★', 11.5, Color(0xFF66636E))),
      gP(261.6, 142, 90.4, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(281.3, 146, 51, 14, gText('Voir profil', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 200, 342, 188, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 214, 38, 18, gText('Offre', 14, Color(0xFF111015), weight: 700)),
      gP(40, 248, 50, 16, gText('Montant', 12.5, Color(0xFF66636E))),
      gP(269, 248, 81, 16, gText('80 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 273, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 282, 30, 16, gText('Délai', 12.5, Color(0xFF66636E))),
      gP(311, 282, 39, 16, gText('7 jours', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 307, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 316, 56, 16, gText('Révisions', 12.5, Color(0xFF66636E))),
      gP(291, 316, 59, 16, gText('2 incluses', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 341, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 350, 91, 16, gText('Début possible', 12.5, Color(0xFF66636E))),
      gP(272, 350, 78, 16, gText('Lundi 26 oct.', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 402, 345, 61, gText('Je propose de concevoir et développer votre application de suivi clients avec une interface mobile, un tableau de bord et un export des données.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 477, 66, 19, gText('Livrables', 15, Color(0xFF111015), weight: 700)),
      gP(33, 537, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 516, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 520.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 515, 305, 17, gText('Maquettes validées', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 535, 305, 14, gText('Jour 2', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 599, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 578, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 577, 305, 17, gText('Développement', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 597, 305, 14, gText('Jours 3 à 6', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 640, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 639, 305, 17, gText('Tests et livraison', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 659, 305, 14, gText('Jour 7', 11.5, Color(0xFF66636E), wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE5484D), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Refuser')),
      gP(78.5, 778, 54, 18, gText('Refuser', 14.5, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Accepter')),
      gP(251.5, 778, 66, 18, gText('Accepter', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
