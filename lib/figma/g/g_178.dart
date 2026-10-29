// GÉNÉRÉ par tool/figma_export/convert.py — écran 178 (nœud Figma 61:466). Ne pas éditer à la main.
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

class G_178 extends ConsumerWidget {
  const G_178({super.key});

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
      gP(24, 70, 157, 26, gText('Bienvenue, jury', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 210, gBox(image: 'assets/figma/img/d26d49b962f8ef08068e61f071cd2e0f7f73c5be.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 210, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 268, 309, 23, gText('Évaluez les projets', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 296, 309, 15, gText('Notation claire et transparente', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(168, 344, 18, 6, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(186, 344, 8, 6, gBox(color: Color(0xFFE6E1EE), radii: [3, 3, 3, 3])),
      gP(204, 344, 8, 6, gBox(color: Color(0xFFE6E1EE), radii: [3, 3, 3, 3])),
      gP(24, 366, 345, 28, gText('Un espace de notation simple', 22, Color(0xFF111015), weight: 800, wrap: true)),
      gP(24, 398, 345, 38, gText('Consultez les projets, notez selon les critères et laissez des commentaires constructifs.', 13, Color(0xFF66636E), lh: 19, wrap: true)),
      gP(24, 450, 342, 156, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 456, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 464.667, 22.667, 14.333, gImg('assets/figma/v/8c9c6b229b6232.svg')),
      gP(44.667, 477.167, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(44.667, 473, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(88, 467, 119, 17, gText('Projets à examiner', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 468.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 502, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 508, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 516.667, 22.667, 21.85, gImg('assets/figma/v/b091f911f7c021.svg')),
      gP(88, 519, 130, 17, gText('Critères de notation', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 520.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 554, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 560, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46, 570, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(44.667, 569.493, 21.84, 21.84, gImg('assets/figma/v/c011934b9b1395.svg')),
      gP(88, 571, 142, 17, gText('Commentaires au jury', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 572.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Passer')),
      gP(82, 778, 47, 18, gText('Passer', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Commencer')),
      gP(240.5, 778, 88, 18, gText('Commencer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
