// GÉNÉRÉ par tool/figma_export/convert.py — écran 272 (nœud Figma 200:16). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/decisions.dart';
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
import '../live/lots.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_272 extends ConsumerWidget {
  const G_272({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo', show: demoContent),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(100, 76, 190, 21, gText(gm('Vérification en 2 étapes', 'Vérification en 2 étapes'), 17, Color(0xFF111015), weight: 500)),
      gP(86.5, 102, 217, 15, gText(gm('Compte administrateur · IUT de Douala', ''), 12, Color(0xFF57545F))),
      gP(157, 144, 76, 91.999, gImg('assets/figma/r/200_114.png'), show: demoContent),
      gP(175, 174, 40, 32, gImg('assets/figma/r/200_115.png'), show: demoContent),
      gP(79.5, 262, 231, 28, gText('Saisissez le code reçu', 22, Color(0xFF111015), weight: 700), show: demoContent),
      gP(82.5, 296, 225, 16, gText(gm('Envoyé par SMS au +237 6 •• •• •• 42', ''), 13, Color(0xFF57545F)), show: demoContent),
      gP(30, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14]), show: demoContent),
      gP(49, 355, 16, 30, gText(gm('4', ''), 24, Color(0xFF111015), weight: 700), show: demoContent),
      gP(87, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14]), show: demoContent),
      gP(106, 355, 16, 30, gText(gm('8', ''), 24, Color(0xFF111015), weight: 700), show: demoContent),
      gP(144, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14]), show: demoContent),
      gP(163, 355, 10, 30, gText(gm('1', ''), 24, Color(0xFF111015), weight: 700), show: demoContent),
      gP(201, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFF111015), bw: 1.5, radii: [14, 14, 14, 14]), show: demoContent),
      gP(220, 355, 14, 30, gText(gm('7', ''), 24, Color(0xFF111015), weight: 700), show: demoContent),
      gP(258, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD8DF), bw: 1, radii: [14, 14, 14, 14]), show: demoContent),
      gP(315, 340, 48, 60, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD8DF), bw: 1, radii: [14, 14, 14, 14]), show: demoContent),
      gP(103.5, 420, 183, 16, gText(gm('Renvoyer le code dans 00:42', ''), 13, Color(0xFF5A3FE0), weight: 600), show: demoContent),
      gP(44, 486, 108, 16, gText('Autres méthodes', 13, Color(0xFF111015), weight: 600), show: demoContent),
      gP(44, 512, 194, 16, gText('Application d’authentification  ›', 13, Color(0xFF57545F), weight: 500), show: demoContent),
      gP(44, 536, 147, 16, gText(gm('Codes de secours (10)  ›', ''), 13, Color(0xFF57545F), weight: 500), show: demoContent),
      gP(24, 590, 22, 22, GCheck(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFFFFFFF), border: Color(0xFFCFCBD6), radius: 7), show: demoContent),
      gP(56, 592, 289, 16, gText(gm('Faire confiance à cet appareil pendant 30 jours', ''), 13, Color(0xFF111015), weight: 500), show: demoContent),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => twoFactorDialog(context, ref), show: demoContent),
      gP(169, 788, 52, 19, gText('Vérifier', 15, Color(0xFFFFFFFF), weight: 600), show: demoContent),
      if (!demoContent) gP(24, 125, 342, 620, const MfaPanel(width: 342)),
    ]);
  }
}
