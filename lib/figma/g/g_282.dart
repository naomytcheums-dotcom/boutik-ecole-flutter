// GÉNÉRÉ par tool/figma_export/convert.py — écran 282 (nœud Figma 209:540). Ne pas éditer à la main.
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

class G_282 extends ConsumerWidget {
  const G_282({super.key});

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
      gP(132.5, 76, 125, 21, gText('QR de transfert', 17, Color(0xFF111015), weight: 500)),
      gP(126.5, 102, 137, 15, gText('Borne n°2 · Hall principal', 12, Color(0xFF66636E))),
      gP(95, 130, 200, 200, gBox(color: Color(0xFFFFFFFF), radii: [24, 24, 24, 24])),
      gP(138.125, 173.125, 113.75, 113.75, gImg('assets/figma/r/209_638.png')),
      gP(125, 344, 140, 20, gText('Expire dans 04:32', 16, Color(0xFF111015), weight: 700)),
      gP(83, 370, 224, 15, gText('Signé · valable 5 minutes · usage unique', 12, Color(0xFF66636E), weight: 500)),
      gP(24, 408, 342, 110, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 424, 56, 15, gText('Signature', 12, Color(0xFF66636E))),
      gP(210, 424, 136, 15, gText('HMAC-SHA256 vérifiée', 12, Color(0xFF111015), weight: 600)),
      gP(44, 450, 70, 15, gText('Réutilisation', 12, Color(0xFF66636E))),
      gP(203, 450, 143, 15, gText('Refusée après le 1er scan', 12, Color(0xFFB42318), weight: 600)),
      gP(44, 476, 50, 15, gText('Contenu', 12, Color(0xFF66636E))),
      gP(184, 476, 162, 15, gText('Panier + identifiant de borne', 12, Color(0xFF111015), weight: 600)),
      gP(24, 534, 342, 170, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 550, 223, 18, gText('Mode événement programmable', 14, Color(0xFF111015), weight: 600)),
      gP(44, 580, 65, 15, gText('Événement', 12, Color(0xFF66636E))),
      gP(213, 580, 133, 15, gText('Journée de l’innovation', 12, Color(0xFF111015), weight: 600)),
      gP(44, 606, 36, 15, gText('Début', 12, Color(0xFF66636E))),
      gP(237, 606, 109, 15, gText('12/11/2026 · 08:00', 12, Color(0xFF111015), weight: 600)),
      gP(44, 632, 17, 15, gText('Fin', 12, Color(0xFF66636E))),
      gP(241, 632, 105, 15, gText('12/11/2026 · 18:00', 12, Color(0xFF111015), weight: 600)),
      gP(44, 658, 121, 15, gText('Contenu mis en avant', 12, Color(0xFF66636E))),
      gP(226, 658, 120, 15, gText('Drops et projets MMI', 12, Color(0xFF111015), weight: 600)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Programmer l’événement')),
      gP(102.5, 788, 185, 19, gText('Programmer l’événement', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
