// GÉNÉRÉ par tool/figma_export/convert.py — écran 281 (nœud Figma 209:396). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_281 extends ConsumerWidget {
  const G_281({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(116, 76, 158, 21, gText('Rôles et périmètres', 17, Color(0xFF111015), weight: 500)),
      gP(124, 102, 142, 15, gText('Institution : IUT de Douala', 12, Color(0xFF66636E))),
      gP(173, 135.25, 27.5, 27.5, gImg('assets/figma/r/209_494.png')),
      gP(163.375, 136.625, 63.25, 49.5, gImg('assets/figma/r/209_495.png')),
      gP(24, 214, 342, 420, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 228, 24, 14, gText('Rôle', 11, Color(0xFF66636E), weight: 600)),
      gP(230, 228, 20, 14, gText('Lire', 11, Color(0xFF66636E), weight: 600)),
      gP(270, 228, 31, 14, gText('Écrire', 11, Color(0xFF66636E), weight: 600)),
      gP(316, 228, 37, 14, gText('Valider', 11, Color(0xFF66636E), weight: 600)),
      gP(44, 252, 44, 15, gText('Visiteur', 12, Color(0xFF111015), weight: 600)),
      gP(236, 252, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 252, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(330, 252, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(44, 292, 35, 15, gText('Client', 12, Color(0xFF111015), weight: 600)),
      gP(236, 292, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 292, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(330, 292, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(44, 332, 49, 15, gText('Étudiant', 12, Color(0xFF111015), weight: 600)),
      gP(236, 332, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 332, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(330, 332, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(44, 372, 155, 15, gText('Responsable département', 12, Color(0xFF111015), weight: 600)),
      gP(236, 372, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 372, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(330, 372, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(44, 412, 127, 15, gText('Référent de validation', 12, Color(0xFF111015), weight: 600)),
      gP(236, 412, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 412, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(330, 412, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(44, 452, 119, 15, gText('Modérateur éditorial', 12, Color(0xFF111015), weight: 600)),
      gP(236, 452, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 452, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(330, 452, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(44, 492, 64, 15, gText('Logisticien', 12, Color(0xFF111015), weight: 600)),
      gP(236, 492, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 492, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(330, 492, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(44, 532, 121, 15, gText('Responsable finance', 12, Color(0xFF111015), weight: 600)),
      gP(236, 532, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 532, 8, 15, gText('–', 12, Color(0xFFB3AFBB), weight: 700)),
      gP(330, 532, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(44, 572, 147, 15, gText('Administrateur institution', 12, Color(0xFF111015), weight: 600)),
      gP(236, 572, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(282, 572, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(330, 572, 12, 15, gText('●', 12, Color(0xFF111015), weight: 700)),
      gP(24, 650, 342, 100, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 664, 164, 18, gText('Isolation des institutions', 14, Color(0xFF111015), weight: 600)),
      gP(44, 688, 302, 20, gText('Chaque compte voit uniquement les données de son institution. Les actions sensibles sont journalisées.', 12, Color(0xFF66636E))),
    ]);
  }
}
