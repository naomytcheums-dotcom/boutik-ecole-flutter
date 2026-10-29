// GÉNÉRÉ par tool/figma_export/convert.py — écran 274 (nœud Figma 200:253). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_274 extends ConsumerWidget {
  const G_274({super.key});

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
      gP(108, 76, 174, 21, gText('Conditions générales', 17, Color(0xFF111015), weight: 500)),
      gP(88, 102, 214, 15, gText('Version 2.1 · mise à jour le 02/09/2026', 12, Color(0xFF66636E))),
      gP(160.167, 137.833, 69.667, 84.333, gImg('assets/figma/r/200_351.png')),
      gP(174.833, 137.833, 55, 66, gImg('assets/figma/r/200_352.png')),
      gP(24, 250, 342, 300, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(44, 268, 223, 18, gText('CGU · Utilisation de la plateforme', 14, Color(0xFF111015), weight: 600)),
      gP(44, 292, 302, 20, gText('Comptes, contenus publiés, propriété intellectuelle des productions étudiantes, modération.', 12, Color(0xFF6B6877))),
      gP(44, 356, 164, 18, gText('CGV · Ventes et services', 14, Color(0xFF111015), weight: 600)),
      gP(44, 380, 302, 20, gText('Prix en FCFA, paiement Orange Money / MTN MoMo, ventilation 70 / 20 / 10, retours et remboursements.', 12, Color(0xFF6B6877))),
      gP(44, 444, 150, 18, gText('Données personnelles', 14, Color(0xFF111015), weight: 600)),
      gP(44, 468, 302, 20, gText('Hébergement, durée de conservation, vos droits d’accès et de suppression.', 12, Color(0xFF6B6877))),
      gP(24, 580, 22, 22, gBox(color: Color(0xFF111015), radii: [7, 7, 7, 7])),
      gP(56, 582, 162, 16, gText('J’ai lu et j’accepte les CGU', 13, Color(0xFF111015), weight: 500)),
      gP(24, 614, 22, 22, gBox(color: Color(0xFF111015), radii: [7, 7, 7, 7])),
      gP(56, 616, 162, 16, gText('J’ai lu et j’accepte les CGV', 13, Color(0xFF111015), weight: 500)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Accepter et continuer')),
      gP(115.5, 788, 159, 19, gText('Accepter et continuer', 15, Color(0xFFFFFFFF), weight: 600)),
      gP(30, 581.5, 13, 19, gText('✓', 15, Color(0xFFFFFFFF), weight: 700)),
      gP(30, 615.5, 13, 19, gText('✓', 15, Color(0xFFFFFFFF), weight: 700)),
    ]);
  }
}
