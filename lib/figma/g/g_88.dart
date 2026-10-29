// GÉNÉRÉ par tool/figma_export/convert.py — écran 88 (nœud Figma 39:332). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_88 extends ConsumerWidget {
  const G_88({super.key});

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
      gP(24, 70, 185, 26, gText('Espace entreprise', 21, Color(0xFF111015), weight: 700)),
      gP(340.75, 69.833, 22.5, 19.75, gImg('assets/figma/v/c416ae6fb27d36.svg')),
      gP(347.442, 87.25, 9.117, 6.922, gImg('assets/figma/v/76ffe03c455014.svg')),
      gP(24, 96, 208, 15, gText('Orange Cameroun · Partenaire vérifié', 12, Color(0xFF66636E))),
      gP(24, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 132, 87, 14, gText('Besoins publiés', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 152, 13, 25, gText('6', 20, Color(0xFF111015), weight: 800)),
      gP(150, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(156, 136.75, 16, 18.5, gImg('assets/figma/v/ff64e2b6a5eb10.svg')),
      gP(162.25, 136.75, 9.75, 9.75, gImg('assets/figma/v/3b2d5604a267d0.svg')),
      gP(200, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 132, 110, 14, gText('Propositions reçues', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 152, 25, 25, gText('23', 20, Color(0xFF111015), weight: 800)),
      gP(214, 184, 92, 14, gText('+8 cette semaine', 11, Color(0xFF0F7A52), weight: 600)),
      gP(326, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 143, 18.5, 7.875, gImg('assets/figma/v/7200c2482969af.svg')),
      gP(330.75, 138, 18.5, 16, gImg('assets/figma/v/137742ca7afd1b.svg')),
      gP(24, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 234, 79, 14, gText('Devis en cours', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 254, 14, 25, gText('4', 20, Color(0xFF111015), weight: 800)),
      gP(38, 286, 53, 14, gText('2 à valider', 11, Color(0xFF8F5400), weight: 600)),
      gP(150, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(156, 238.75, 16, 18.5, gImg('assets/figma/v/b8b641560aad30.svg')),
      gP(158.5, 242.5, 11, 11, gImg('assets/figma/v/f82584207e62a2.svg')),
      gP(161, 241.562, 6, 12.875, gImg('assets/figma/v/084a5a2da19358.svg')),
      gP(200, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 234, 82, 14, gText('Collaborations', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 254, 13, 25, gText('3', 20, Color(0xFF111015), weight: 800)),
      gP(214, 286, 52, 14, gText('1 nouvelle', 11, Color(0xFF0F7A52), weight: 600)),
      gP(326, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 246.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(332.625, 239.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(341.375, 246.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(339.5, 239.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(24, 328, 342, 210, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 342, 197, 18, gText('Propositions reçues par mois', 14, Color(0xFF111015), weight: 700)),
      gP(314, 344, 36, 14, gText('6 mois', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.right)),
      gP(44, 382, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 443, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 504, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(55.325, 482.783, 27.683, 21.217, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(60.167, 512, 18, 13, gText('Mai', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(105.658, 466.87, 27.683, 37.13, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(110, 512, 19, 13, gText('Juin', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(155.992, 472.174, 27.683, 31.826, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(161.833, 512, 16, 13, gText('Juil', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(206.325, 445.652, 27.683, 58.348, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(208.167, 512, 24, 13, gText('Août', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(256.658, 424.435, 27.683, 79.565, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(258, 512, 25, 13, gText('Sept', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(306.992, 382, 27.683, 122, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(310.833, 512, 20, 13, gText('Oct', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 552, 186, 19, gText('Opportunités du moment', 15, Color(0xFF111015), weight: 700)),
      gP(301, 554, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 559, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 555.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 590, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 603, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 611.667, 16, 16, gImg('assets/figma/v/f44e883cdba29a.svg')),
      gP(50.5, 625, 11, 6, gImg('assets/figma/v/c4124addb3c439.svg')),
      gP(51.333, 628.333, 9.333, 6, gImg('assets/figma/v/df31b3079c9886.svg')),
      gP(88, 602, 191, 17, gText('Défi : application de paieme…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 624, 106, 14, gText('12 équipes inscrites', 11.5, Color(0xFF66636E))),
      gP(293.6, 612, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(303.8, 616, 38, 14, gText('Ouvert', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 656, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 669, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 681.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 678.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg')),
      gP(88, 668, 157, 17, gText('Stage développeur web', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 690, 82, 14, gText('8 candidatures', 11.5, Color(0xFF66636E))),
      gP(300, 678, 52, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(313, 682, 26, 14, gText('Actif', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
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
    ]);
  }
}
