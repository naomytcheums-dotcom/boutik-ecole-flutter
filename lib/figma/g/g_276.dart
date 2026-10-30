// GÉNÉRÉ par tool/figma_export/convert.py — écran 276 (nœud Figma 200:484). Ne pas éditer à la main.
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
import '../live/docs.dart';
import '../live/kela.dart';
import '../live/chat.dart';
import '../live/share.dart';
import '../live/pay.dart';
import '../live/engage.dart';
import '../live/lots.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_276 extends ConsumerWidget {
  const G_276({super.key});

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
      gP(139, 76, 112, 21, gText('Borne de l’IUT', 17, Color(0xFF111015), weight: 500)),
      gP(126.5, 102, 137, 15, gText('Hall principal · Borne n°2', 12, Color(0xFF66636E))),
      gP(147.083, 154.501, 95.833, 58.415, gImg('assets/figma/r/200_582.png')),
      gP(151.25, 146.25, 87.499, 87.499, gImg('assets/figma/r/200_583.png')),
      gP(24.5, 262, 341, 21, gText('Connexion momentanément indisponible', 17, Color(0xFF111015), weight: 700)),
      gP(74, 294, 242, 16, gText('Le catalogue est consultable hors ligne.', 13, Color(0xFF6B6877))),
      gP(44, 354, 140, 18, gText('Disponible hors ligne', 14, Color(0xFF111015), weight: 600)),
      gP(44, 380, 215, 16, gText('• 120 produits et services en vitrine', 13, Color(0xFF6B6877), weight: 500)),
      gP(44, 402, 185, 16, gText('• Cartes de visite et QR codes', 13, Color(0xFF6B6877), weight: 500)),
      gP(44, 424, 152, 16, gText('• Plan de l’IUT et horaires', 13, Color(0xFF6B6877), weight: 500)),
      gP(44, 452, 302, 14, gText('Paiements et commandes : reprise dès le retour du réseau.', 11, Color(0xFF6B6877))),
      gP(44, 522, 103, 18, gText('Besoin d’aide ?', 14, Color(0xFF111015), weight: 600)),
      gP(44, 546, 206, 15, gText('Adressez-vous à l’accueil · poste 214', 12, Color(0xFF6B6877))),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gOpen(context, '207')),
      gP(80, 788, 230, 19, gText('Parcourir le catalogue hors ligne', 15, Color(0xFFFFFFFF), weight: 600)),
      gP(114, 736, 162, 15, gText('Reconnexion automatique…', 12, Color(0xFF5A3FE0), weight: 600)),
    ]);
  }
}
