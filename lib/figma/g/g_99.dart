// GÉNÉRÉ par tool/figma_export/convert.py — écran 99 (nœud Figma 54:1352). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_99 extends ConsumerWidget {
  const G_99({super.key});

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
      gP(24, 70, 107, 26, gText('Historique', 21, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 77.8, 34, 'Besoins', 12.5, 600), GChip(109.8, 120, 63, 34, 'Devis', 12.5, 500), GChip(180.8, 120, 77.8, 34, 'Projets', 12.5, 500), GChip(266.6, 120, 70.4, 34, 'Stages', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 181, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 189.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 189.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 180, 172, 17, gText('Application de suivi clients', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 202, 176, 14, gText('Publié le 02 oct. · 23 propositio…', 11.5, Color(0xFF66636E))),
      gP(287.2, 190, 64.8, 22, gBox(color: Color(0xFFF2EFF6), radii: [11, 11, 11, 11])),
      gP(299.6, 194, 40, 14, gText('Clôturé', 11, Color(0xFF66636E), weight: 600, align: TextAlign.center)),
      gP(88, 234, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 247, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 255.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 255.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 246, 115, 17, gText('Charte graphique', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 268, 163, 14, gText('Publié le 18 sept. · 11 proposit…', 11.5, Color(0xFF66636E))),
      gP(280.8, 256, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(294.4, 260, 44, 14, gText('Attribué', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 300, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 313, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 321.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 321.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 312, 167, 17, gText('Borne de recharge solaire', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 334, 167, 14, gText('Publié le 05 sept. · 7 propositi…', 11.5, Color(0xFF66636E))),
      gP(280.8, 322, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 326, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 366, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 379, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 387.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 387.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 378, 146, 17, gText('Site vitrine partenaires', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 400, 176, 14, gText('Publié le 20 août · 15 propositio…', 11.5, Color(0xFF66636E))),
      gP(287.2, 388, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(298.6, 392, 42, 14, gText('Terminé', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 446, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 458, 87, 14, gText('Besoins publiés', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 478, 21, 25, gText('12', 20, Color(0xFF111015), weight: 800)),
      gP(150, 458, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(156, 462.75, 16, 18.5, gImg('assets/figma/v/ff64e2b6a5eb10.svg')),
      gP(162.25, 462.75, 9.75, 9.75, gImg('assets/figma/v/3b2d5604a267d0.svg')),
      gP(200, 446, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 458, 84, 14, gText('Projets réalisés', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 478, 13, 25, gText('5', 20, Color(0xFF111015), weight: 800)),
      gP(326, 458, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(332, 465.25, 16, 12.875, gImg('assets/figma/v/633fba394a419f.svg')),
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
