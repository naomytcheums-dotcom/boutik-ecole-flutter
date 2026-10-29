// GÉNÉRÉ par tool/figma_export/convert.py — écran 23 (nœud Figma 29:185). Ne pas éditer à la main.
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

class G_23 extends ConsumerWidget {
  const G_23({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(5.769, 38.634, 384.231, 802.394, gBox(color: Color(0xFFFCFCFD), shadows: [BoxShadow(color: Color(0x14122640), offset: Offset(0, -2), blurRadius: 14, spreadRadius: 0)], radii: [32.308, 32.308, 32.308, 32.308])),
      gP(23.654, 62.768, 70, 29, gText('Filtres', 23.077, Color(0xFF111015), weight: 700)),
      gP(345.75, 70.57, 16.962, 16.962, gImg('assets/figma/v/4e63f0daac7a87.svg')),
      gP(345.75, 70.57, 16.962, 16.962, gImg('assets/figma/v/2c9d733a4a00d4.svg')),
      gP(23.654, 120.166, 95, 20, gText('Type d’offre', 16.154, Color(0xFF2B3F5C), weight: 500)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(23.077, 155.724, 99.231, 39.228, 'Tous', 15.577, 600), GChip(136.154, 155.724, 100.385, 39.228, 'Produits', 15, 500), GChip(252.692, 155.724, 109.615, 39.228, 'Services', 15, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 19.038)),
      gP(23.077, 205.056, 99.231, 39.228, gBox(color: Color(0xFFF2EFF6), radii: [19.038, 19.038, 19.038, 19.038])),
      gP(47.192, 215.17, 51, 19, gText('Talents', 15, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(137.308, 205.056, 99.231, 39.228, gBox(color: Color(0xFFF2EFF6), radii: [19.038, 19.038, 19.038, 19.038])),
      gP(160.923, 215.17, 52, 19, gText('Projets', 15, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(252.692, 205.056, 109.615, 39.228, gBox(color: Color(0xFFF2EFF6), radii: [19.038, 19.038, 19.038, 19.038]), tap: () => gToast(context, 'Démonstration : Innovations')),
      gP(266, 215.17, 83, 19, gText('Innovations', 15, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(23.654, 277.956, 122, 23, gText('Département', 18.462, Color(0xFF111015), weight: 700)),
      gP(23.077, 313.825, 341.538, 45.172, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.365, radii: [21.923, 21.923, 21.923, 21.923])),
      gP(38.077, 328.1, 162, 19, gText('Tous les départements', 15, Color(0xFF111015), weight: 500)),
      gP(339.692, 331.986, 14.077, 10.038, gImg('assets/figma/v/7a385ca7740320.svg')),
      gP(23.654, 391.48, 34, 23, gText('Prix', 18.462, Color(0xFF111015), weight: 700)),
      gP(23.077, 424.887, 51, 18, gText('0 FCFA', 14.423, Color(0xFF111015), weight: 600)),
      gP(238.769, 424.887, 112, 18, gText('500 000+ FCFA', 14.423, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(31.154, 459.445, 160.385, 3.566, gBox(color: Color(0xFF6A4DFF), radii: [1.731, 1.731, 1.731, 1.731])),
      gP(191.538, 459.445, 162.692, 3.566, gBox(color: Color(0xFF111015), radii: [1.731, 1.731, 1.731, 1.731])),
      gP(23.077, 453.151, 16.154, 16.154, gBox(color: Color(0xFF111015), oval: true)),
      gP(184.038, 453.728, 15, 15, gBox(color: Color(0xFF111015), border: Color(0xFF6A4DFF), bw: 2.231, oval: true)),
      gP(345.577, 452.574, 17.308, 17.308, gBox(color: Color(0xFF111015), oval: true)),
      gP(351.346, 458.344, 5.769, 5.769, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(23.654, 509.759, 114, 23, gText('Disponibilité', 18.462, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(23.077, 545.628, 75, 36.851, 'En stock', 13.846, 600), GChip(111.923, 545.628, 113.077, 36.851, 'Sur commande', 13.846, 500), GChip(240, 545.628, 126.923, 36.851, 'Disponible bientôt', 13.846, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17.885)),
      gP(23.654, 617.934, 91, 23, gText('Catégorie', 18.462, Color(0xFF111015), weight: 700)),
      gP(23.077, 653.803, 341.538, 45.172, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.365, radii: [21.923, 21.923, 21.923, 21.923])),
      gP(38.077, 668.077, 152, 19, gText('Toutes les catégories', 15, Color(0xFF111015), weight: 500)),
      gP(339.692, 671.964, 14.077, 10.038, gImg('assets/figma/v/7a385ca7740320.svg')),
      gP(5.769, 739.986, 384.231, 1.189, gBox(color: Color(0xFFF2EFF6))),
      gP(21.346, 760.789, 151.731, 52.304, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.365, radii: [25.385, 25.385, 25.385, 25.385]), tap: () => gToast(context, 'Démonstration : Réinitialiser')),
      gP(51.423, 776.941, 91, 20, gText('Réinitialiser', 16.154, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(186.923, 760.789, 182.308, 52.304, gBox(color: Color(0xFF111015), radii: [25.385, 25.385, 25.385, 25.385]), tap: () => gToast(context, 'Démonstration : Appliquer')),
      gP(237.577, 776.441, 81, 21, gText('Appliquer', 16.731, Color(0xFFFFFFFF), weight: 700, align: TextAlign.center)),
      gP(152.308, 830.924, 88.846, 2.972, gBox(color: Color(0xFF111015), radii: [1.731, 1.731, 1.731, 1.731])),
    ]);
  }
}
