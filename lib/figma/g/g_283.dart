// GÉNÉRÉ par tool/figma_export/convert.py — écran 283 (nœud Figma 209:660). Ne pas éditer à la main.
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

class G_283 extends ConsumerWidget {
  const G_283({super.key});

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
      gP(101, 76, 188, 21, gText('Registre des certificats', 17, Color(0xFF111015), weight: 500)),
      gP(90.5, 102, 209, 15, gText('Émission réservée aux rôles autorisés', 12, Color(0xFF66636E))),
      gP(175, 132, 40, 40, gImg('assets/figma/r/209_758.png')),
      gP(177.666, 161.332, 34.668, 29.335, gImg('assets/figma/r/209_759.png')),
      gP(24, 216, 342, 82, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 228, 221, 16, gText('BE-C-0412 · Lampe en bois recyclé', 13, Color(0xFF111015), weight: 600)),
      gP(318, 228, 28, 15, gText('Émis', 12, Color(0xFF0F7A52), weight: 700)),
      gP(44, 254, 155, 15, gText('Par Dr Ngono · 02/09/2026', 12, Color(0xFF66636E))),
      gP(44, 274, 201, 14, gText('Journalisé · empreinte SHA-256 ancrée', 11, Color(0xFF66636E))),
      gP(24, 308, 342, 82, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 320, 215, 16, gText('BE-C-0398 · Chaise ergonomique', 13, Color(0xFF111015), weight: 600)),
      gP(308, 320, 38, 15, gText('Vérifié', 12, Color(0xFF5A3FE0), weight: 700)),
      gP(44, 346, 146, 15, gText('Scan public · 29/08/2026', 12, Color(0xFF66636E))),
      gP(44, 366, 201, 14, gText('Journalisé · empreinte SHA-256 ancrée', 11, Color(0xFF66636E))),
      gP(24, 400, 342, 82, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 412, 197, 16, gText('BE-C-0377 · Panneau solaire V1', 13, Color(0xFF111015), weight: 600)),
      gP(287, 412, 59, 15, gText('Remplacé', 12, Color(0xFF8F5400), weight: 700)),
      gP(44, 438, 146, 15, gText('Remplacé par BE-C-0419', 12, Color(0xFF66636E))),
      gP(44, 458, 201, 14, gText('Journalisé · empreinte SHA-256 ancrée', 11, Color(0xFF66636E))),
      gP(24, 492, 342, 82, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 504, 186, 16, gText('BE-C-0351 · Prototype drone', 13, Color(0xFF111015), weight: 600)),
      gP(294, 504, 52, 15, gText('Révoqué', 12, Color(0xFFB42318), weight: 700)),
      gP(44, 530, 206, 15, gText('Motif : non-conformité · 14/08/2026', 12, Color(0xFF66636E))),
      gP(44, 550, 201, 14, gText('Journalisé · empreinte SHA-256 ancrée', 11, Color(0xFF66636E))),
      gP(24, 590, 342, 76, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 604, 126, 16, gText('Émission journalisée', 13, Color(0xFF111015), weight: 600)),
      gP(44, 626, 302, 20, gText('Chaque émission, remplacement ou révocation enregistre l’auteur, la date et le motif.', 11, Color(0xFF66636E))),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Émettre un certificat')),
      gP(120.5, 788, 149, 19, gText('Émettre un certificat', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
