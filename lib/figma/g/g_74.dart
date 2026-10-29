// GÉNÉRÉ par tool/figma_export/convert.py — écran 74 (nœud Figma 213:119). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_74 extends ConsumerWidget {
  const G_74({super.key});

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
      gP(132.5, 76, 125, 21, gText('Talent Passport', 17, Color(0xFF111015), weight: 500)),
      gP(93.5, 102, 203, 15, gText('Mariam Essono · Génie informatique', 12, Color(0xFF66636E))),
      gP(42.5, 143.5, 35, 35, gImg('assets/figma/r/213_217.png')),
      gP(44.833, 169.166, 30.334, 25.668, gImg('assets/figma/r/213_218.png')),
      gP(100, 146, 145, 23, gText('Niveau Confirmé', 18, Color(0xFF111015), weight: 700)),
      gP(100, 172, 228, 14, gText('Passeport n° TP-2026-0187 · vérifié par l’IUT', 11, Color(0xFF66636E))),
      gP(24, 214, 342, 160, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 230, 158, 18, gText('Compétences vérifiées', 14, Color(0xFF111015), weight: 600)),
      gP(44, 262, 45, 16, gText('Python', 13, Color(0xFF111015), weight: 500)),
      gP(303, 262, 43, 15, gText('Avancé', 12, Color(0xFF66636E), weight: 600)),
      gP(44, 284, 302, 6, gBox(color: Color(0xFFE9E5F5), radii: [3, 3, 3, 3])),
      gP(44, 284, 271.8, 6, gBox(color: Color(0xFF5A3FE0), radii: [3, 3, 3, 3])),
      gP(44, 302, 37, 16, gText('React', 13, Color(0xFF111015), weight: 500)),
      gP(291, 302, 55, 15, gText('Confirmé', 12, Color(0xFF66636E), weight: 600)),
      gP(44, 324, 302, 6, gBox(color: Color(0xFFE9E5F5), radii: [3, 3, 3, 3])),
      gP(44, 324, 226.5, 6, gBox(color: Color(0xFF5A3FE0), radii: [3, 3, 3, 3])),
      gP(44, 342, 94, 16, gText('Mobile (Flutter)', 13, Color(0xFF111015), weight: 500)),
      gP(268, 342, 78, 15, gText('Intermédiaire', 12, Color(0xFF66636E), weight: 600)),
      gP(44, 364, 302, 6, gBox(color: Color(0xFFE9E5F5), radii: [3, 3, 3, 3])),
      gP(44, 364, 181.2, 6, gBox(color: Color(0xFF5A3FE0), radii: [3, 3, 3, 3])),
      gP(24, 390, 342, 112, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 406, 111, 18, gText('Badges obtenus', 14, Color(0xFF111015), weight: 600)),
      gP(44, 436, 96, 56, gBox(color: Color(0xFFF4EFE6), radii: [14, 14, 14, 14])),
      gP(52, 442, 80, 20, gText('Hackathon IUT 2026', 10, Color(0xFF111015), weight: 600)),
      gP(52, 474, 48, 14, gText('1re place', 11, Color(0xFF5A3FE0), weight: 700)),
      gP(148, 436, 96, 56, gBox(color: Color(0xFFF4EFE6), radii: [14, 14, 14, 14])),
      gP(156, 442, 80, 20, gText('Mentor étudiant', 10, Color(0xFF111015), weight: 600)),
      gP(156, 474, 20, 14, gText('12 h', 11, Color(0xFF5A3FE0), weight: 700)),
      gP(252, 436, 96, 56, gBox(color: Color(0xFFF4EFE6), radii: [14, 14, 14, 14])),
      gP(260, 442, 80, 20, gText('Vendeuse fiable', 10, Color(0xFF111015), weight: 600)),
      gP(260, 474, 34, 14, gText('4,9 / 5', 11, Color(0xFF5A3FE0), weight: 700)),
      gP(24, 518, 342, 120, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 534, 215, 18, gText('Certificats et recommandations', 14, Color(0xFF111015), weight: 600)),
      gP(44, 562, 237, 15, gText('BE-C-0412 · Lampe en bois recyclé · Émis', 12, Color(0xFF111015), weight: 500)),
      gP(44, 584, 238, 15, gText('BE-C-0377 · Application de stock · Vérifié', 12, Color(0xFF111015), weight: 500)),
      gP(44, 606, 306, 15, gText('2 recommandations d’entreprises · Orange Cameroun', 12, Color(0xFF66636E))),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Partager mon passport (QR / PDF)')),
      gP(73, 788, 244, 19, gText('Partager mon passport (QR / PDF)', 15, Color(0xFFFFFFFF), weight: 600)),
      gTap(30, 70, 44, 44, () => gOpen(context, '10')),
    ]);
  }
}
