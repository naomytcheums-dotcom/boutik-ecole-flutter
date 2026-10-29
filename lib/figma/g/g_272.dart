// GÉNÉRÉ par tool/figma_export/convert.py — écran 272 (nœud Figma 200:16). Ne pas éditer à la main.
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

class G_272 extends ConsumerWidget {
  const G_272({super.key});

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
      gP(100, 76, 190, 21, gText('Vérification en 2 étapes', 17, Color(0xFF111015), weight: 500)),
      gP(86.5, 102, 217, 15, gText('Compte administrateur · IUT de Douala', 12, Color(0xFF66636E))),
      gP(157, 144, 76, 91.999, gImg('assets/figma/r/200_114.png')),
      gP(175, 174, 40, 32, gImg('assets/figma/r/200_115.png')),
      gP(79.5, 262, 231, 28, gText('Saisissez le code reçu', 22, Color(0xFF111015), weight: 700)),
      gP(82.5, 296, 225, 16, gText('Envoyé par SMS au +237 6 •• •• •• 42', 13, Color(0xFF6B6877))),
      gP(30, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(49, 355, 16, 30, gText('4', 24, Color(0xFF111015), weight: 700)),
      gP(87, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(106, 355, 16, 30, gText('8', 24, Color(0xFF111015), weight: 700)),
      gP(144, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(163, 355, 10, 30, gText('1', 24, Color(0xFF111015), weight: 700)),
      gP(201, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(220, 355, 14, 30, gText('7', 24, Color(0xFF111015), weight: 700)),
      gP(258, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD8DF), bw: 1, radii: [14, 14, 14, 14])),
      gP(315, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD8DF), bw: 1, radii: [14, 14, 14, 14])),
      gP(103.5, 420, 183, 16, gText('Renvoyer le code dans 00:42', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 470, 342, 92, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(44, 486, 108, 16, gText('Autres méthodes', 13, Color(0xFF111015), weight: 600)),
      gP(44, 512, 194, 16, gText('Application d’authentification  ›', 13, Color(0xFF6B6877), weight: 500)),
      gP(44, 536, 147, 16, gText('Codes de secours (10)  ›', 13, Color(0xFF6B6877), weight: 500)),
      gP(24, 590, 22, 22, gBox(color: Color(0xFF111015), radii: [7, 7, 7, 7])),
      gP(56, 592, 289, 16, gText('Faire confiance à cet appareil pendant 30 jours', 13, Color(0xFF111015), weight: 500)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Vérifier')),
      gP(169, 788, 52, 19, gText('Vérifier', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
