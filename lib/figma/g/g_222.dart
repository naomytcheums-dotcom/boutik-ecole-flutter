// GÉNÉRÉ par tool/figma_export/convert.py — écran 222 (nœud Figma 87:409). Ne pas éditer à la main.
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
import '../live/chat.dart';
import '../live/share.dart';
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_222 extends ConsumerWidget {
  const G_222({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(131, 82, 128, 21, gText('Atelier en direct', 17, Color(0xFF111015), weight: 500)),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(24, 128, 342, 352, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x2E403366), offset: Offset(0, 14), blurRadius: 28, spreadRadius: 0)], radii: [40, 40, 40, 40])),
      gP(40, 144, 94, 26, gBox(color: Color(0xFFFF2D55), radii: [100, 100, 100, 100])),
      gP(52, 153.5, 7, 7, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(65, 150, 57, 14, gText('EN DIRECT', 11, Color(0xFF111015), weight: 600), fx: 'pulse'),
      gP(284, 144, 66, 26, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(294.083, 150.208, 16.833, 13.583, gImg('assets/figma/v/1c64daa304e6b4.svg')),
      gP(297.875, 152.375, 9.25, 9.25, gImg('assets/figma/v/e735fd67e86253.svg')),
      gP(315, 150, 23, 14, gText('1,2 k', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(40, 436, 92, 26, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(50.083, 440.583, 16.833, 16.833, gImg('assets/figma/v/4ddf56cf4a1028.svg')),
      gP(55.5, 442.75, 8.167, 10.333, gImg('assets/figma/v/7a0261e0911ea1.svg')),
      gP(71, 442, 49, 14, gText('00:24:18', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(321, 313, 34, 34, gBox(color: Color(0xFFFFFFFF), oval: true), op: 0.85),
      gP(328.333, 321, 19.333, 18, gImg('assets/figma/v/e621166cee5ca8.svg')),
      gP(322, 314, 32, 32, GHeart()),
      gP(321, 267, 34, 34, gBox(color: Color(0xFFFFFFFF), oval: true), op: 0.65),
      gP(328.333, 274.333, 19.333, 18.667, gImg('assets/figma/v/88b41b8712be56.svg')),
      gP(321, 221, 34, 34, gBox(color: Color(0xFFFFFFFF), oval: true), op: 0.45),
      gP(328.333, 229, 19.333, 18, gImg('assets/figma/v/e621166cee5ca8.svg')),
      gP(322, 222, 32, 32, GHeart()),
      gP(38, 504, 48, 48, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(96, 507, 72, 18, gText('Yannick M.', 14, Color(0xFF111015), weight: 600)),
      gP(96, 528, 107, 14, gText('Génie civil · Atelier GI', 11, Color(0xFF66636E))),
      gP(270, 515, 82, 26, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(282, 521, 58, 14, gText('S’abonner', 11.5, Color(0xFFFFFFFF), weight: 600)),
      gP(36, 588, 80, 80, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(128, 590, 151, 18, gText('Lampe en bois recyclé', 14, Color(0xFF111015), weight: 600)),
      gP(126.417, 611.417, 15.167, 14.708, gImg('assets/figma/v/98397937042751.svg')),
      gP(140.417, 611.417, 15.167, 14.708, gImg('assets/figma/v/98397937042751.svg')),
      gP(154.417, 611.417, 15.167, 14.708, gImg('assets/figma/v/98397937042751.svg')),
      gP(168.417, 611.417, 15.167, 14.708, gImg('assets/figma/v/98397937042751.svg')),
      gP(182.417, 611.417, 15.167, 14.708, gImg('assets/figma/v/98397937042751.svg')),
      gP(204, 613, 18, 14, gText('4,8', 11, Color(0xFF66636E), weight: 500)),
      gP(128, 636, 89, 18, gText('25 000 FCFA', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(258, 628, 94, 26, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(270, 634, 70, 14, gText('Commander', 11.5, Color(0xFFFFFFFF), weight: 600)),
      gP(234, 610, 82, 25, gBox(color: Color(0xFFFFF1D6), radii: [100, 100, 100, 100])),
      gP(246, 616, 58, 13, gText('12 restantes', 10, Color(0xFFB26A00), weight: 600)),
      gP(24, 696, 260, 28, gBox(color: Color(0xB2FFFFFF), radii: [14, 14, 14, 14])),
      gP(28, 699, 22, 22, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [11, 11, 11, 11])),
      gP(56, 703, 38, 13, gText('Mariam', 10.5, Color(0xFF111015), weight: 600)),
      gP(100, 703, 132, 13, gText('Magnifique, quelle finition !', 10.5, Color(0xFF5B5963))),
      gP(24, 730, 260, 28, gBox(color: Color(0xB2FFFFFF), radii: [14, 14, 14, 14])),
      gP(28, 733, 22, 22, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [11, 11, 11, 11])),
      gP(56, 737, 40, 13, gText('Brice N.', 10.5, Color(0xFF111015), weight: 600)),
      gP(112, 737, 100, 13, gText('Livrable à Yaoundé ?', 10.5, Color(0xFF5B5963))),
      gP(24, 772, 342, 54, GField(hint: 'Écrire un commentaire…', size: 12.5, hintColor: Color(0xFF66636E), weight: 400, padL: 20)),
      gP(253, 782, 34, 34, gBox(color: Color(0xFFFFF0F3), oval: true)),
      gP(260.333, 790, 19.333, 18, gImg('assets/figma/v/e621166cee5ca8.svg')),
      gP(254, 783, 32, 32, GHeart()),
      gP(314, 779, 40, 40, gBox(color: Color(0xFF111015), oval: true)),
      gP(331, 791.042, 6, 15.917, gImg('assets/figma/v/fe79bf155ff58b.svg')),
      gP(326.042, 791.042, 15.917, 10.958, gImg('assets/figma/v/30e6667bf72525.svg')),
      gP(328.333, 89, 19.333, 14.333, gImg('assets/figma/v/9c92298f9fd6b2.svg')),
      gP(331.667, 80.667, 12.667, 9.333, gImg('assets/figma/v/bb8ad3c4792df6.svg')),
      gP(335, 80.667, 6, 16.833, gImg('assets/figma/v/5bb53be308dfb1.svg')),
    ]);
  }
}
