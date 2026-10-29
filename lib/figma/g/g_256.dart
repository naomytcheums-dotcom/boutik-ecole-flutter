// GÉNÉRÉ par tool/figma_export/convert.py — écran 256 (nœud Figma 184:90). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_256 extends ConsumerWidget {
  const G_256({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(111.5, 76, 167, 21, gText('Contrôles de la fiche', 17, Color(0xFF111015), weight: 500)),
      gP(122.5, 100, 145, 15, gText('Étapes 2 et 5 du workflow', 12, Color(0xFF66636E))),
      gP(24, 128, 176, 19, gText('Contrôles automatiques', 15, Color(0xFF111015), weight: 600)),
      gP(275, 124, 91, 25, gBox(color: Color(0xFFE8F7EE), radii: [100, 100, 100, 100])),
      gP(287, 130, 67, 13, gText('12 / 12 réussis', 10.5, Color(0xFF126B49), weight: 600)),
      gP(38, 180, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 184.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 182, 120, 15, gText('Champs obligatoires', 12, Color(0xFF111015), weight: 500)),
      gP(315, 183, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 214, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 218.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 216, 177, 15, gText('Photos : formats et dimensions', 12, Color(0xFF111015), weight: 500)),
      gP(315, 217, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 248, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 252.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 250, 71, 15, gText('Prix en FCFA', 12, Color(0xFF111015), weight: 500)),
      gP(315, 251, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 282, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 286.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 284, 139, 15, gText('Quantité et disponibilité', 12, Color(0xFF111015), weight: 500)),
      gP(315, 285, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 316, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 320.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 318, 125, 15, gText('Liens externes valides', 12, Color(0xFF111015), weight: 500)),
      gP(315, 319, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 350, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 354.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 352, 152, 15, gText('Fichiers sans contenu actif', 12, Color(0xFF111015), weight: 500)),
      gP(315, 353, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 384, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 388.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 386, 169, 15, gText('Titre et description (longueur)', 12, Color(0xFF111015), weight: 500)),
      gP(315, 387, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 418, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 422.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 420, 191, 15, gText('Auteurs et contributeurs déclarés', 12, Color(0xFF111015), weight: 500)),
      gP(315, 421, 33, 13, gText('Réussi', 10.5, Color(0xFF126B49), weight: 500)),
      gP(24, 480, 185, 19, gText('Contrôles réglementaires', 15, Color(0xFF111015), weight: 600)),
      gP(320, 476, 46, 25, gBox(color: Color(0xFFFFF1D6), radii: [100, 100, 100, 100])),
      gP(332, 482, 22, 13, gText('3 / 5', 10.5, Color(0xFFB26A00), weight: 600)),
      gP(38, 532, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 536.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 534, 233, 30, gText('Propriété intellectuelle : droits d’utilisation', 12, Color(0xFF111015), weight: 500, wrap: true)),
      gP(316, 535, 32, 13, gText('Validé', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 576, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 580.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 578, 233, 30, gText('Sécurité du produit (mécanique, électrique)', 12, Color(0xFF111015), weight: 500, wrap: true)),
      gP(316, 579, 32, 13, gText('Validé', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 620, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(41.333, 624.25, 13.333, 11.042, gImg('assets/figma/v/1841ce310c7a6d.svg')),
      gP(68, 622, 233, 15, gText('Alimentaire ou santé : non concerné', 12, Color(0xFF111015), weight: 500, wrap: true)),
      gP(316, 623, 32, 13, gText('Validé', 10.5, Color(0xFF126B49), weight: 500)),
      gP(38, 664, 20, 20, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(68, 666, 233, 15, gText('Données personnelles : non concerné', 12, Color(0xFF66636E), weight: 500, wrap: true)),
      gP(296, 667, 52, 13, gText('En attente', 10.5, Color(0xFFB26A00), weight: 500)),
      gP(38, 708, 20, 20, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(68, 710, 233, 15, gText('Visa du référent réglementaire', 12, Color(0xFF66636E), weight: 500, wrap: true)),
      gP(296, 711, 52, 13, gText('En attente', 10.5, Color(0xFFB26A00), weight: 500)),
      gP(24, 782, 345, 28, gText('Aucune publication n’est possible tant que l’étape 5 n’est pas validée.', 11, Color(0xFF66636E), wrap: true)),
      gP(24, 820, 342, 48, gBox(color: Color(0xBFFFFFFF), border: Color(0xFFFFFFFF), bw: 1, radii: [24, 24, 24, 24])),
      gP(150, 836, 90, 16, gText('Retour au suivi', 13, Color(0xFF111015), weight: 600)),
      gP(24, 820, 342, 48, const SizedBox.expand(), tap: () => gOpen(context, '255')),
      gTap(24, 820, 342, 48, () => gOpen(context, '255')),
    ]);
  }
}
