// GÉNÉRÉ par tool/figma_export/convert.py — écran 98 (nœud Figma 39:1172). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_98 extends ConsumerWidget {
  const G_98({super.key});

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
      gP(24, 70, 152, 26, gText('Collaborations', 21, Color(0xFF111015), weight: 700)),
      gP(38, 132, 82, 14, gText('Contrats actifs', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 152, 13, 25, gText('3', 20, Color(0xFF111015), weight: 800)),
      gP(150, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(156, 136.75, 16, 18.5, gImg('assets/figma/v/ff64e2b6a5eb10.svg')),
      gP(162.25, 136.75, 9.75, 9.75, gImg('assets/figma/v/3b2d5604a267d0.svg')),
      gP(214, 132, 44, 14, gText('À signer', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 152, 9, 25, gText('1', 20, Color(0xFF111015), weight: 800)),
      gP(214, 184, 83, 14, gText('Avant le 30 oct.', 11, Color(0xFF8F5400), weight: 600)),
      gP(326, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 136.744, 18.52, 18.506, gImg('assets/figma/v/f8d0b855809950.svg')),
      gP(36, 239, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 258.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(47.167, 248.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(58.833, 258.608, 8.5, 10.892, gImg('assets/figma/v/f73f5c2da1a756.svg')),
      gP(56.333, 248.608, 8.507, 12.458, gImg('assets/figma/v/385c8732cbe0ba.svg')),
      gP(88, 238, 172, 17, gText('Borne solaire · Team Innov’', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 260, 163, 14, gText('Contrat signé · 450 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(300, 248, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(313, 252, 26, 14, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 292, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 305, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 313.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 313.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 304, 182, 17, gText('Application CRM · Mariam E.', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 326, 102, 14, gText('Livraison le 02 nov.', 11.5, Color(0xFF66636E))),
      gP(280.8, 314, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 318, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 358, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 371, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 379.659, 22.693, 22.675, gImg('assets/figma/v/fbc13ecf693ae1.svg')),
      gP(88, 370, 188, 17, gText('Charte graphique · Aminata…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 392, 126, 14, gText('En attente de signature', 11.5, Color(0xFF66636E))),
      gP(280.8, 380, 71.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(294.9, 384, 43, 14, gText('À signer', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 438, 150, 19, gText('Suivi du contrat actif', 15, Color(0xFF111015), weight: 700)),
      gP(40, 490, 134, 16, gText('Avancement du projet', 12.5, Color(0xFF111015), weight: 600)),
      gP(323, 490, 27, 15, gText('65%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 512, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 512, 201.5, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 534, 116, 16, gText('Budget consommé', 12.5, Color(0xFF111015), weight: 600)),
      gP(322, 534, 28, 15, gText('48%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 556, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 556, 148.8, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
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
