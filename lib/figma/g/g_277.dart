// GÉNÉRÉ par tool/figma_export/convert.py — écran 277 (nœud Figma 200:598). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_277 extends ConsumerWidget {
  const G_277({super.key});

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
      gP(100, 76, 190, 21, gText('Supervision des bornes', 17, Color(0xFF111015), weight: 500)),
      gP(113, 102, 164, 15, gText('Vue administrateur · 4 bornes', 12, Color(0xFF66636E))),
      gP(167, 144.667, 56, 50.666, gImg('assets/figma/r/200_695.png')),
      gP(24, 224, 342, 84, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(40, 240, 12, 12, gBox(color: Color(0xFF12B76A), oval: true)),
      gP(62, 236, 145, 18, gText('Borne 1 · Hall principal', 14, Color(0xFF111015), weight: 600)),
      gP(305, 236, 45, 15, gText('En ligne', 12, Color(0xFF027A48), weight: 700)),
      gP(62, 260, 124, 15, gText('Dernier signal il y a 12 s', 12, Color(0xFF6B6877))),
      gP(62, 282, 217, 14, gText('Redémarrer  ·  Journal  ·  Activer le secours', 11, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 320, 342, 84, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(40, 336, 12, 12, gBox(color: Color(0xFFD92D20), oval: true)),
      gP(62, 332, 149, 18, gText('Borne 2 · Bibliothèque', 14, Color(0xFF111015), weight: 600)),
      gP(292, 332, 58, 15, gText('Hors ligne', 12, Color(0xFFD92D20), weight: 700)),
      gP(62, 356, 183, 15, gText('Mode secours actif depuis 6 min', 12, Color(0xFF6B6877))),
      gP(62, 378, 217, 14, gText('Redémarrer  ·  Journal  ·  Activer le secours', 11, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 416, 342, 84, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(40, 432, 12, 12, gBox(color: Color(0xFF12B76A), oval: true)),
      gP(62, 428, 184, 18, gText('Borne 3 · Département MMI', 14, Color(0xFF111015), weight: 600)),
      gP(305, 428, 45, 15, gText('En ligne', 12, Color(0xFF027A48), weight: 700)),
      gP(62, 452, 120, 15, gText('Dernier signal il y a 8 s', 12, Color(0xFF6B6877))),
      gP(62, 474, 217, 14, gText('Redémarrer  ·  Journal  ·  Activer le secours', 11, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 512, 342, 84, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(40, 528, 12, 12, gBox(color: Color(0xFFF79009), oval: true)),
      gP(62, 524, 161, 18, gText('Borne 4 · Salle des profs', 14, Color(0xFF111015), weight: 600)),
      gP(289, 524, 61, 15, gText('Mise à jour', 12, Color(0xFFB54708), weight: 700)),
      gP(62, 548, 146, 15, gText('Version 1.8.2 → 1.8.3 (72 %)', 12, Color(0xFF6B6877))),
      gP(62, 570, 217, 14, gText('Redémarrer  ·  Journal  ·  Activer le secours', 11, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Voir les journaux d’incidents')),
      gP(94.5, 788, 201, 19, gText('Voir les journaux d’incidents', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
