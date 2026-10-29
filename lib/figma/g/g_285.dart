// GÉNÉRÉ par tool/figma_export/convert.py — écran 285 (nœud Figma 209:907). Ne pas éditer à la main.
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

class G_285 extends ConsumerWidget {
  const G_285({super.key});

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
      gP(138, 76, 114, 21, gText('Espace projet', 17, Color(0xFF111015), weight: 500)),
      gP(87, 102, 216, 15, gText('Mission : Identité visuelle · Mbella SARL', 12, Color(0xFF66636E))),
      gP(167, 134.667, 56, 50.667, gImg('assets/figma/r/209_1004.png')),
      gP(24, 212, 342, 210, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 228, 127, 18, gText('Contrat de mission', 14, Color(0xFF111015), weight: 600)),
      gP(44, 258, 48, 15, gText('Montant', 12, Color(0xFF66636E))),
      gP(253, 258, 93, 15, gText('1 200 000 FCFA', 12, Color(0xFF111015), weight: 600)),
      gP(44, 284, 36, 15, gText('Statut', 12, Color(0xFF66636E))),
      gP(224, 284, 122, 15, gText('Signé le 08/09/2026', 12, Color(0xFF0F7A52), weight: 600)),
      gP(44, 310, 50, 15, gText('Livraison', 12, Color(0xFF66636E))),
      gP(278, 310, 68, 15, gText('30/11/2026', 12, Color(0xFF111015), weight: 600)),
      gP(44, 336, 41, 15, gText('Équipe', 12, Color(0xFF66636E))),
      gP(254, 336, 92, 15, gText('4 étudiants MMI', 12, Color(0xFF111015), weight: 600)),
      gP(44, 372, 127, 15, gText('Voir le contrat (PDF)  ↗', 12, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 438, 342, 200, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 454, 42, 18, gText('Jalons', 14, Color(0xFF111015), weight: 600)),
      gP(44, 489, 10, 10, gBox(color: Color(0xFF0F7A52), oval: true)),
      gP(64, 486, 83, 16, gText('1 · Brief validé', 13, Color(0xFF111015), weight: 500)),
      gP(299, 486, 47, 15, gText('Terminé', 12, Color(0xFF0F7A52), weight: 700)),
      gP(44, 523, 10, 10, gBox(color: Color(0xFF0F7A52), oval: true)),
      gP(64, 520, 84, 16, gText('2 · Maquettes', 13, Color(0xFF111015), weight: 500)),
      gP(299, 520, 47, 15, gText('Terminé', 12, Color(0xFF0F7A52), weight: 700)),
      gP(44, 557, 10, 10, gBox(color: Color(0xFFA35F00), oval: true)),
      gP(64, 554, 99, 16, gText('3 · Version finale', 13, Color(0xFF111015), weight: 500)),
      gP(296, 554, 50, 15, gText('En cours', 12, Color(0xFF8F5400), weight: 700)),
      gP(44, 591, 10, 10, gBox(color: Color(0xFF66636E), oval: true)),
      gP(64, 588, 72, 16, gText('4 · Livraison', 13, Color(0xFF111015), weight: 500)),
      gP(306, 588, 40, 15, gText('À venir', 12, Color(0xFF66636E), weight: 700)),
      gP(24, 654, 342, 70, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 676, 278, 16, gText('Messagerie du projet · 3 nouveaux messages', 13, Color(0xFF111015), weight: 600)),
      gP(44, 696, 210, 14, gText('Historique des échanges et des versions', 11, Color(0xFF66636E))),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Valider le jalon 3')),
      gP(137.5, 788, 115, 19, gText('Valider le jalon 3', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
