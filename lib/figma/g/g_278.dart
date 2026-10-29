// GÉNÉRÉ par tool/figma_export/convert.py — écran 278 (nœud Figma 209:16). Ne pas éditer à la main.
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

class G_278 extends ConsumerWidget {
  const G_278({super.key});

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
      gP(104, 76, 182, 21, gText('Lampe en bois recyclé', 17, Color(0xFF111015), weight: 500)),
      gP(71.5, 102, 247, 15, gText('Fiche projet · liens et propriété intellectuelle', 12, Color(0xFF66636E))),
      gP(164.375, 139.375, 61.25, 61.25, gImg('assets/figma/r/209_113.png')),
      gP(24, 226, 342, 196, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 242, 99, 18, gText('Liens du projet', 14, Color(0xFF111015), weight: 600)),
      gP(44, 272, 45, 16, gText('GitHub', 13, Color(0xFF111015), weight: 600)),
      gP(44, 288, 206, 14, gText('github.com/mariam-essono/lampe-iot', 11, Color(0xFF66636E))),
      gP(340, 276, 10, 18, gText('↗', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(44, 308, 89, 16, gText('Démo en ligne', 13, Color(0xFF111015), weight: 600)),
      gP(44, 324, 162, 14, gText('lampe-demo.boutik-ecole.cm', 11, Color(0xFF66636E))),
      gP(340, 312, 10, 18, gText('↗', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(44, 344, 99, 16, gText('Documentation', 13, Color(0xFF111015), weight: 600)),
      gP(44, 360, 157, 14, gText('docs.boutik-ecole.cm/lampe', 11, Color(0xFF66636E))),
      gP(340, 348, 10, 18, gText('↗', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(44, 380, 140, 16, gText('Vidéo de présentation', 13, Color(0xFF111015), weight: 600)),
      gP(44, 396, 133, 14, gText('youtube.com/watch?v=…', 11, Color(0xFF66636E))),
      gP(340, 384, 10, 18, gText('↗', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(24, 438, 342, 200, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 454, 154, 18, gText('Propriété intellectuelle', 14, Color(0xFF111015), weight: 600)),
      gP(44, 484, 44, 15, gText('Auteurs', 12, Color(0xFF66636E))),
      gP(219, 484, 127, 15, gText('Mariam E. · Yannick M.', 12, Color(0xFF111015), weight: 600)),
      gP(44, 510, 59, 15, gText('Encadrant', 12, Color(0xFF66636E))),
      gP(223, 510, 123, 15, gText('Dr Ngono · Génie civil', 12, Color(0xFF111015), weight: 600)),
      gP(44, 536, 46, 15, gText('Licence', 12, Color(0xFF66636E))),
      gP(262, 536, 84, 15, gText('CC BY-NC 4.0', 12, Color(0xFF111015), weight: 600)),
      gP(44, 562, 35, 15, gText('Droits', 12, Color(0xFF66636E))),
      gP(208, 562, 138, 15, gText('Étudiants + IUT (50 / 50)', 12, Color(0xFF111015), weight: 600)),
      gP(44, 588, 68, 15, gText('Restrictions', 12, Color(0xFF66636E))),
      gP(174, 588, 172, 15, gText('Usage commercial sur accord', 12, Color(0xFF111015), weight: 600)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Enregistrer les informations')),
      gP(96, 788, 198, 19, gText('Enregistrer les informations', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
