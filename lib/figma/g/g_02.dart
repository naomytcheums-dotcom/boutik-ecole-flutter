// GÉNÉRÉ par tool/figma_export/convert.py — écran 02 (nœud Figma 2:100). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_02 extends ConsumerWidget {
  const G_02({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 876, radius: 43.333, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 139.08, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 603.36, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(232, 208, 134, 126, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [30, 30, 30, 30])),
      gP(232, 72, 134, 124, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [30, 30, 30, 30])),
      gP(24, 72, 196, 262, gBox(image: 'assets/figma/img/46d80b349804afa588f99bc3738b28175881dec1.png', fit: BoxFit.cover, radii: [36, 36, 36, 36])),
      gP(141.306, 425.431, 111, 14, gText('BIENVENUE SUR', 10.833, Color(0xFF5B6B7F), weight: 500, ls: 2.2, align: TextAlign.center)),
      gP(176.042, 452.292, 45.139, 37.917, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(5.722, 499.972, 382.167, 87, gText('Des talents étudiants,\ndes créations uniques,\nun même espace.', 24.375, Color(0xFF111015), weight: 800, lh: 28.889, align: TextAlign.center, wrap: true)),
      gP(5.722, 600.333, 382.167, 56, gText('Découvrez, achetez et soutenez les produits,\nservices, compétences, projets et innovations\ndes étudiants de l’IUT de Douala.', 13.09, Color(0xFF4A4854), lh: 18.507, align: TextAlign.center, wrap: true)),
      gP(165.208, 681.597, 16.25, 4.514, gBox(color: Color(0xFF111015), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(190.486, 681.597, 14.444, 4.514, gBox(color: Color(0xFFE3E7EC), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(213.958, 681.597, 15.347, 4.514, gBox(color: Color(0xFFE3E7EC), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(58.681, 715.903, 278.056, 46.944, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x2E122640), offset: Offset(0, 6), blurRadius: 14, spreadRadius: 0)], radii: [23.472, 23.472, 23.472, 23.472]), tap: () => gOpen(context, '03')),
      gP(145.875, 730.875, 82, 17, gText('Commencer', 13.542, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(244.135, 736.375, 15.479, 6, gImg('assets/figma/v/16b62525eb5c56.svg')),
      gP(248.875, 731.635, 10.74, 15.479, gImg('assets/figma/v/eba8aeee09e9ea.svg')),
      gP(155.806, 781.028, 82, 16, gText('Se connecter', 12.639, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(130, 857.639, 130, 4.514, gBox(color: Color(0xFF111015), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(36, 294, 82, 28, gBox(color: Color(0xF0FFFFFF), radii: [14, 14, 14, 14])),
      gP(56, 300, 42, 15, gText('Talents', 12, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(244, 156, 90, 28, gBox(color: Color(0xF0FFFFFF), radii: [14, 14, 14, 14])),
      gP(263.5, 162, 51, 15, gText('Services', 12, Color(0xFF111015), weight: 700, align: TextAlign.center)),
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
      gTap(59, 716, 278, 47, () => gOpen(context, '03')),
    ]);
  }
}
