// GÉNÉRÉ par tool/figma_export/convert.py — écran 246 (nœud Figma 152:191). Ne pas éditer à la main.
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

class G_246 extends ConsumerWidget {
  const G_246({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(174, 76, 42, 21, gText('Lives', 17, Color(0xFF111015), weight: 500)),
      gP(135.5, 100, 119, 15, gText('Sans seuil d’abonnés', 12, Color(0xFF66636E))),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(327.987, 81.208, 20.025, 17.688, gImg('assets/figma/v/6bb139378db42d.svg')),
      gP(333.675, 96.013, 8.649, 6.783, gImg('assets/figma/v/43da5b08e3da08.svg')),
      gP(24, 132, 149, 19, gText('En direct maintenant', 15, Color(0xFF111015), weight: 600)),
      gP(24, 158, 342, 200, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 12), blurRadius: 24, spreadRadius: 0)], radii: [36, 36, 36, 36])),
      gP(40, 172, 90, 25, gBox(color: Color(0xFFFF2D55), radii: [100, 100, 100, 100])),
      gP(52, 181, 7, 7, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(64, 178, 54, 13, gText('EN DIRECT', 10.5, Color(0xFF111015), weight: 600), fx: 'pulse'),
      gP(304, 172, 46, 25, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(316, 178, 22, 13, gText('1,2 k', 10.5, Color(0xFFFFFFFF), weight: 600)),
      gP(171, 234, 48, 48, gBox(color: Color(0x4DFFFFFF), oval: true)),
      gP(188.5, 248.25, 16.5, 19.5, gImg('assets/figma/v/3811e31ba08535.svg')),
      gP(24, 370, 38, 38, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [19, 19, 19, 19])),
      gP(72, 372, 207, 17, gText('Atelier : la lampe en bois recyclé', 13.5, Color(0xFF111015), weight: 600)),
      gP(72, 392, 110, 13, gText('Yannick M. · Génie civil', 10.5, Color(0xFF66636E))),
      gP(292, 376, 74, 26, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(304, 382, 50, 14, gText('Regarder', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 430, 107, 19, gText('Prochains lives', 15, Color(0xFF111015), weight: 600)),
      gP(24, 462, 64, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [22, 22, 22, 22])),
      gP(44, 476, 24, 14, gText('Ven.', 11, Color(0xFF66636E), weight: 500)),
      gP(42, 492, 28, 28, gText('24', 22, Color(0xFF111015), weight: 700)),
      gP(46, 520, 20, 13, gText('oct.', 10, Color(0xFF66636E))),
      gP(98, 462, 70, 76, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(180, 470, 189, 34, gText('Jus de bissap : de la cuisine au kiosque', 12.5, Color(0xFF111015), weight: 600, lh: 17, wrap: true)),
      gP(180, 512, 56, 13, gText('Équipe BTA', 10.5, Color(0xFF66636E))),
      gP(284, 508, 82, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(296, 514, 58, 13, gText('Me rappeler', 10, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 554, 64, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [22, 22, 22, 22])),
      gP(42.5, 568, 27, 14, gText('Sam.', 11, Color(0xFF66636E), weight: 500)),
      gP(42.5, 584, 27, 28, gText('25', 22, Color(0xFF111015), weight: 700)),
      gP(46, 612, 20, 13, gText('oct.', 10, Color(0xFF66636E))),
      gP(98, 554, 70, 76, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(180, 562, 189, 34, gText('Montage d’un kit solaire en direct', 12.5, Color(0xFF111015), weight: 600, lh: 17, wrap: true)),
      gP(180, 604, 39, 13, gText('Brice N.', 10.5, Color(0xFF66636E))),
      gP(284, 600, 82, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(296, 606, 58, 13, gText('Me rappeler', 10, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 646, 64, 76, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [22, 22, 22, 22])),
      gP(44.5, 660, 23, 14, gText('Lun.', 11, Color(0xFF66636E), weight: 500)),
      gP(43, 676, 26, 28, gText('27', 22, Color(0xFF111015), weight: 700)),
      gP(46, 704, 20, 13, gText('oct.', 10, Color(0xFF66636E))),
      gP(98, 646, 70, 76, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(180, 654, 189, 17, gText('Pitch : applis de suivi clients', 12.5, Color(0xFF111015), weight: 600, lh: 17, wrap: true)),
      gP(180, 696, 48, 13, gText('Mariam E.', 10.5, Color(0xFF66636E))),
      gP(284, 692, 82, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(296, 698, 58, 13, gText('Me rappeler', 10, Color(0xFF5A3FE0), weight: 600)),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '251')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '247')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '244')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(329, 83, 19, 19, () => gOpen(context, '254')),
      gTap(24, 158, 342, 200, () => gOpen(context, '222')),
      gTap(292, 376, 74, 26, () => gOpen(context, '222')),
    ]);
  }
}
