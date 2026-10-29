// GÉNÉRÉ par tool/figma_export/convert.py — écran 183 (nœud Figma 61:968). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_183 extends ConsumerWidget {
  const G_183({super.key});

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
      gP(24, 70, 174, 26, gText('Mes commandes', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 143.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 149.417, 20.167, 20.167, gImg('assets/figma/v/40366219467bb4.svg')),
      gP(46.521, 158.675, 10.958, 7.012, gImg('assets/figma/v/01a0133cdd5989.svg')),
      gP(41.917, 152.37, 8.954, 7.877, gImg('assets/figma/v/d37e1324d6e683.svg')),
      gP(48.051, 151.499, 14.033, 8.706, gImg('assets/figma/v/b08731205bbc2d.svg')),
      gP(44.042, 155.204, 9.662, 7.905, gImg('assets/figma/v/703e1a605a7fe0.svg')),
      gP(49, 162.167, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(76, 134, 277, 51, gText('Vous êtes hors ligne. Les données affichées sont celles de votre dernière synchronisation (aujourd’hui 10:24).', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(24, 213, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 221, 50, 50, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 225, 112, 17, gText('#BE-2026-0142', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 247, 111, 14, gText('Livrée · 32 500 FCFA', 11.5, Color(0xFF66636E))),
      gP(293.6, 235, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(306.3, 239, 33, 14, gText('Livrée', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 279, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 287, 50, 50, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 291, 112, 17, gText('#BE-2026-0138', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 313, 123, 14, gText('En cours · 17 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(280.8, 301, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 305, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 359, 342, 50, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [25, 25, 25, 25])),
      gP(126, 375, 163, 18, gText('Réessayer la connexion', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(100.125, 374.625, 18.75, 12.375, gImg('assets/figma/v/61c3463d3cf08b.svg')),
      gP(109.333, 374.625, 9.542, 9.542, gImg('assets/figma/v/381bf2cb0d6c1e.svg')),
      gP(100.125, 381, 18.75, 12.375, gImg('assets/figma/v/914ddfc40e4140.svg')),
      gP(100.125, 383.833, 9.542, 9.542, gImg('assets/figma/v/4d304b5791f186.svg')),
      gP(24, 423, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 438, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.918, 446.042, 20.165, 15.917, gImg('assets/figma/v/3009b5a49ade6b.svg')),
      gP(76, 437, 277, 34, gText('Vos actions (messages, favoris) seront envoyées dès le retour du réseau.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
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
