// GÉNÉRÉ par tool/figma_export/convert.py — écran 107 (nœud Figma 40:611). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_107 extends ConsumerWidget {
  const G_107({super.key});

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
      gP(76, 70, 122, 26, gText('Mon impact', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 132, 54, 14, gText('CO₂ évité', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 152, 54, 25, gText('48 kg', 20, Color(0xFF111015), weight: 800)),
      gP(38, 184, 72, 14, gText('+6 kg ce mois', 11, Color(0xFF0F7A52), weight: 600)),
      gP(150, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(155.987, 136.75, 16.638, 17.25, gImg('assets/figma/v/f15f44e39e3e89.svg')),
      gP(154.75, 143, 12.875, 11.625, gImg('assets/figma/v/8b2c664962e9f3.svg')),
      gP(200, 120, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 132, 77, 14, gText('Achats locaux', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 152, 146, 25, gText('12 commandes', 20, Color(0xFF111015), weight: 800)),
      gP(326, 132, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(332.5, 138.5, 15, 15, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(331.375, 136.75, 17.25, 17.875, gImg('assets/figma/v/7ec8dd9f6152b5.svg')),
      gP(335.125, 143, 9.75, 11.625, gImg('assets/figma/v/7bda9069bd9d90.svg')),
      gP(24, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(38, 234, 106, 14, gText('Étudiants soutenus', 11.5, Color(0xFF66636E), weight: 500)),
      gP(38, 254, 13, 25, gText('9', 20, Color(0xFF111015), weight: 800)),
      gP(150, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(154.75, 246.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(156.625, 239.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(165.375, 246.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(163.5, 239.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(200, 222, 166, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(214, 234, 98, 14, gText('Déchets valorisés', 11.5, Color(0xFF66636E), weight: 500)),
      gP(214, 254, 53, 25, gText('23 kg', 20, Color(0xFF111015), weight: 800)),
      gP(326, 234, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(330.75, 241.875, 18.5, 12.25, gImg('assets/figma/v/b8aa2d550e4e95.svg')),
      gP(339.5, 241.875, 9.75, 9.75, gImg('assets/figma/v/bf4c9c3198e949.svg')),
      gP(24, 328, 342, 210, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 342, 171, 18, gText('Impact par mois (kg CO₂)', 14, Color(0xFF111015), weight: 700)),
      gP(314, 344, 36, 14, gText('6 mois', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.right)),
      gP(44, 382, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 443, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(44, 504, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(55.325, 463.333, 27.683, 40.667, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(60.167, 512, 18, 13, gText('Mai', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(105.658, 443, 27.683, 61, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(110, 512, 19, 13, gText('Juin', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(155.992, 422.667, 27.683, 81.333, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(161.833, 512, 16, 13, gText('Juil', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(206.325, 436.222, 27.683, 67.778, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(208.167, 512, 24, 13, gText('Août', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(256.658, 409.111, 27.683, 94.889, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(258, 512, 25, 13, gText('Sept', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(306.992, 382, 27.683, 122, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(310.833, 512, 20, 13, gText('Oct', 10.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 552, 342, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 566, 116, 16, gText('Objectif de l’année', 12.5, Color(0xFF111015), weight: 600)),
      gP(286, 566, 64, 15, gText('64 / 100 kg', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 588, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 588, 198.4, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(40, 610, 130, 16, gText('Soutien aux étudiants', 12.5, Color(0xFF111015), weight: 600)),
      gP(322, 610, 28, 15, gText('45%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 632, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 632, 139.5, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
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
