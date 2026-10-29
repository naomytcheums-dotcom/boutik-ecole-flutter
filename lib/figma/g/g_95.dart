// GÉNÉRÉ par tool/figma_export/convert.py — écran 95 (nœud Figma 39:926). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_95 extends ConsumerWidget {
  const G_95({super.key});

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
      gP(24, 70, 219, 26, gText('Devis et négociations', 21, Color(0xFF111015), weight: 700)),
      gP(24, 156, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(54, 130, 54, 16, gText('En cours', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(41.1, 154, 79.8, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(164.5, 130, 61, 16, gText('Acceptés', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(284, 130, 50, 16, gText('Refusés', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 174, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 187, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 195.667, 19.333, 22.667, gImg('assets/figma/v/6b7ab80aa88481.svg')),
      gP(49.667, 200.667, 12.667, 12.667, gImg('assets/figma/v/3d81e69f675694.svg')),
      gP(53, 199.417, 6, 15.167, gImg('assets/figma/v/e321839520f3d3.svg')),
      gP(88, 186, 182, 17, gText('DEV-2026-014 · Borne sol…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 208, 152, 14, gText('Team Innov’ · 450 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(261.6, 196, 90.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(273.8, 200, 66, 14, gText('Négociation', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(88, 240, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 253, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 261.667, 19.333, 22.667, gImg('assets/figma/v/6b7ab80aa88481.svg')),
      gP(49.667, 266.667, 12.667, 12.667, gImg('assets/figma/v/3d81e69f675694.svg')),
      gP(53, 265.417, 6, 15.167, gImg('assets/figma/v/e321839520f3d3.svg')),
      gP(88, 252, 196, 17, gText('DEV-2026-012 · Application…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 274, 134, 14, gText('Mariam E. · 80 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(274.4, 262, 77.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(290.2, 266, 46, 14, gText('À valider', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 306, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 319, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 327.667, 19.333, 22.667, gImg('assets/figma/v/6b7ab80aa88481.svg')),
      gP(49.667, 332.667, 12.667, 12.667, gImg('assets/figma/v/3d81e69f675694.svg')),
      gP(53, 331.417, 6, 15.167, gImg('assets/figma/v/e321839520f3d3.svg')),
      gP(88, 318, 205, 17, gText('DEV-2026-009 · Logo et char…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 340, 138, 14, gText('Aminata B. · 65 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(287.2, 328, 64.8, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(296.6, 332, 46, 14, gText('Accepté', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 386, 120, 19, gText('Dernier échange', 15, Color(0xFF111015), weight: 700)),
      gP(24, 424, 246.24, 58, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28]), tap: () => gToast(context, 'Démonstration : Pouvez-vous livrer sous 10 jours pour 420 000 FCFA ?')),
      gP(38, 435, 221.24, 36, gText('Pouvez-vous livrer sous 10 jours pour 420 000 FCFA ?', 12.5, Color(0xFF111015), lh: 18, wrap: true)),
      gP(30, 486, 30, 13, gText('09:30', 10, Color(0xFF8793A5))),
      gP(119.76, 508, 246.24, 40, gBox(color: Color(0xFF111015), radii: [18, 18, 18, 18]), tap: () => gToast(context, 'Démonstration : Oui, à condition de démarrer lundi.')),
      gP(133.76, 519, 221.24, 18, gText('Oui, à condition de démarrer lundi.', 12.5, Color(0xFFFFFFFF), lh: 18, wrap: true)),
      gP(331, 552, 29, 13, gText('09:42', 10, Color(0xFF8793A5), align: TextAlign.right)),
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
