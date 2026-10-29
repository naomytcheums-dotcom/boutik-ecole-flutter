// GÉNÉRÉ par tool/figma_export/convert.py — écran 230 (nœud Figma 106:89). Ne pas éditer à la main.
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

class G_230 extends ConsumerWidget {
  const G_230({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF1EEE6), Color(0xFFEBE6EA), Color(0xFFE5DAEE)], stops: [0, 0.55, 1]), children: [
      gP(200, 180, 300, 300, gBox(color: Color(0x99CDB2F2), layerBlur: 90, oval: true), fx: 'halo'),
      gP(-130, 630, 300, 300, gBox(color: Color(0x8CF4C6B0), layerBlur: 90, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(104.5, 72, 181, 21, gText('Assistante vocale Kéla', 17, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(161, 98, 68, 16, gText('À l’écoute…', 12.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(328.767, 85.883, 18.467, 12.233, gImg('assets/figma/v/44747303a472e2.svg')),
      gP(95, 240, 200, 200, gBox(color: Color(0x59FFB36B), layerBlur: 90, oval: true), fx: 'halo'),
      gP(70, 205, 250, 250, gBox(image: 'assets/figma/img/2b51b5d6469cca917952ac344a2ddf9cc1440830.png', fit: BoxFit.contain, shadows: [BoxShadow(color: Color(0x47FF731A), offset: Offset(0, 18), blurRadius: 28, spreadRadius: 0)])),
      gP(34, 484, 329, 68, gText('Peux-tu m’aider à créer un logo et une affiche', 26, Color(0x52111015), weight: 500, lh: 34, wrap: true)),
      gP(34, 552, 329, 68, gText('pour mon parfum, avant fin novembre ?', 26, Color(0xFF111015), weight: 500, lh: 34, wrap: true)),
      gP(168, 655, 4, 10, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(178, 651, 4, 18, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(188, 645, 4, 30, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(198, 651, 4, 18, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(208, 643, 4, 34, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(218, 651, 4, 18, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(228, 655, 4, 10, gBox(color: Color(0xFF8E7BFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(50, 724, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(66, 738, 12, 15, gText('IA', 12, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(153, 704, 84, 84, GMic(child: gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 12), blurRadius: 26, spreadRadius: 0)], oval: true))),
      gP(188.25, 730.5, 13.5, 21, gImg('assets/figma/v/2d0fe55c8faa41.svg')),
      gP(183.25, 740.5, 23.5, 16, gImg('assets/figma/v/e0998b9bdd25ce.svg')),
      gP(192, 750.5, 6, 11, gImg('assets/figma/v/170c9f72b8a8fd.svg')),
      gP(296, 724, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(310.325, 738.325, 15.35, 15.35, gImg('assets/figma/v/95a3a562ff2257.svg')),
      gP(310.325, 738.325, 15.35, 15.35, gImg('assets/figma/v/dacf8ca54f8b22.svg')),
    ]);
  }
}
