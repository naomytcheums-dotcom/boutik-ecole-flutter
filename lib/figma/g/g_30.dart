// GÉNÉRÉ par tool/figma_export/convert.py — écran 30 (nœud Figma 30:209). Ne pas éditer à la main.
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

class G_30 extends ConsumerWidget {
  const G_30({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(25.006, 73.264, 16.35, 16.35, const SizedBox.expand(), tap: () => gBack(context)),
      gP(25.412, 73.67, 10.769, 15.538, gImg('assets/figma/v/c5fe2620711652.svg')),
      gP(25.412, 78.439, 15.538, 6, gImg('assets/figma/v/c120b3472d891c.svg')),
      gP(95.145, 319.158, 205, 28, gText('Commande reçue !', 22.121, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(59.645, 379.27, 276, 44, gText('Votre commande #BE-2026-0142 a bien été\nreçue. Merci pour votre confiance !', 12.984, Color(0xFF5A3FE0), lh: 21.64, align: TextAlign.center)),
      gP(50.974, 473.825, 294.303, 57.007, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [19.236, 19.236, 19.236, 19.236]), tap: () => gToast(context, 'Démonstration : Évaluer la commande')),
      gP(131.626, 494.698, 133, 16, gText('Évaluer la commande', 12.984, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(50.974, 551.561, 294.303, 59.228, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28]), tap: () => gToast(context, 'Démonstration : Voir le détail')),
      gP(159.626, 573.175, 77, 16, gText('Voir le détail', 12.984, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(27.891, 672.142, 85, 15, gText('Un problème ?', 12.022, Color(0xFF111015), weight: 700)),
      gP(27.891, 702.756, 188, 13, gText('Signalez un souci pour obtenir de l’aide.', 10.099, Color(0xFF5A3FE0))),
      gP(31.739, 732.947, 331.813, 60.709, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28]), tap: () => gToast(context, 'Démonstration : Contacter le support')),
      gP(137.645, 755.802, 120, 15, gText('Contacter le support', 12.022, Color(0xFF5A3FE0), weight: 500, align: TextAlign.center)),
      gP(143.785, 820.309, 112.528, 3.702, gBox(color: Color(0xFF111015), radii: [1.443, 1.443, 1.443, 1.443])),
      gP(142.25, 151.507, 75.9, 84.063, gImg('assets/figma/r/173_37.png')),
      gP(140.515, 169.455, 79.37, 69.25, gImg('assets/figma/v/bb76d8c126fb13.svg')),
    ]);
  }
}
