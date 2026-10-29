// GÉNÉRÉ par tool/figma_export/convert.py — écran 284 (nœud Figma 209:785). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_284 extends ConsumerWidget {
  const G_284({super.key});

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
      gP(124, 76, 142, 21, gText('Registre financier', 17, Color(0xFF111015), weight: 500)),
      gP(111.5, 102, 167, 15, gText('Commande #BE-2026-0142', 12, Color(0xFF66636E))),
      gP(167, 132, 40, 40, gImg('assets/figma/r/209_883.png')),
      gP(177.667, 140, 45.333, 40, gImg('assets/figma/r/209_884.png')),
      gP(24, 214, 342, 300, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 232, 80, 16, gText('Montant brut', 13, Color(0xFF66636E))),
      gP(254, 232, 92, 16, gText('330 000 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 266, 151, 16, gText('Frais de paiement (1,5 %)', 13, Color(0xFF66636E))),
      gP(263, 266, 83, 16, gText('− 4 950 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 300, 116, 16, gText('Taxes (TVA 19,25 %)', 13, Color(0xFF66636E))),
      gP(256, 300, 90, 16, gText('− 53 280 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 334, 111, 16, gText('Remboursements', 13, Color(0xFF66636E))),
      gP(300, 334, 46, 16, gText('0 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 368, 68, 16, gText('Net réparti', 13, Color(0xFF111015), weight: 600)),
      gP(264, 368, 82, 16, gText('271 770 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 402, 188, 16, gText('Commission plateforme (10 %)', 13, Color(0xFF66636E))),
      gP(273, 402, 73, 16, gText('27 177 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 436, 152, 16, gText('Part département (20 %)', 13, Color(0xFF66636E))),
      gP(267, 436, 79, 16, gText('54 354 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(44, 470, 127, 16, gText('Part étudiants (70 %)', 13, Color(0xFF66636E))),
      gP(262, 470, 84, 16, gText('190 239 FCFA', 13, Color(0xFF111015), weight: 600)),
      gP(24, 530, 342, 92, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 546, 153, 16, gText('Répartition configurable', 13, Color(0xFF111015), weight: 600)),
      gP(44, 568, 302, 20, gText('70 / 20 / 10 par défaut · modifiable par l’administrateur global, avec historique.', 11, Color(0xFF66636E))),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Exporter le registre (CSV)')),
      gP(103.5, 788, 183, 19, gText('Exporter le registre (CSV)', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
