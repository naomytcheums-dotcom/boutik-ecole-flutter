// GÉNÉRÉ par tool/figma_export/convert.py — écran 255 (nœud Figma 184:16). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_255 extends ConsumerWidget {
  const G_255({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1000, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(116, 76, 158, 21, gText('Suivi de publication', 17, Color(0xFF111015), weight: 500)),
      gP(131.5, 100, 127, 15, gText('Lampe en bois recyclé', 12, Color(0xFF66636E))),
      gP(24, 124, 342, 84, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 136, 60, 60, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [18, 18, 18, 18])),
      gP(108, 140, 151, 18, gText('Lampe en bois recyclé', 14, Color(0xFF111015), weight: 600)),
      gP(108, 162, 147, 14, gText('Génie civil · soumis le 22 oct.', 11, Color(0xFF66636E))),
      gP(108, 180, 90, 25, gBox(color: Color(0xFFFFF1D6), radii: [100, 100, 100, 100])),
      gP(120, 186, 66, 13, gText('Étape 5 sur 10', 10, Color(0xFFB26A00), weight: 600)),
      gP(24, 222, 342, 640, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(49, 274, 2, 32, gBox(color: Color(0xFF1F9D6B), radii: [1, 1, 1, 1])),
      gP(37, 245, 26, 26, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(42.667, 251.75, 14.667, 11.958, gImg('assets/figma/v/c2c3db2cc7ae5f.svg')),
      gP(76, 247, 40, 16, gText('Dépôt', 13, Color(0xFF111015), weight: 600)),
      gP(76, 267, 81, 13, gText('Terminé · 22 oct.', 10.5, Color(0xFF66636E))),
      gP(49, 334, 2, 32, gBox(color: Color(0xFF1F9D6B), radii: [1, 1, 1, 1])),
      gP(37, 305, 26, 26, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(42.667, 311.75, 14.667, 11.958, gImg('assets/figma/v/c2c3db2cc7ae5f.svg')),
      gP(76, 307, 153, 16, gText('Contrôles automatiques', 13, Color(0xFF111015), weight: 600)),
      gP(76, 327, 162, 13, gText('Terminé · 22 oct. · 12/12 contrôles', 10.5, Color(0xFF66636E))),
      gP(49, 394, 2, 32, gBox(color: Color(0xFF1F9D6B), radii: [1, 1, 1, 1])),
      gP(37, 365, 26, 26, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(42.667, 371.75, 14.667, 11.958, gImg('assets/figma/v/c2c3db2cc7ae5f.svg')),
      gP(76, 367, 168, 16, gText('Validation départementale', 13, Color(0xFF111015), weight: 600)),
      gP(76, 387, 139, 13, gText('Terminé · Dr Mbarga · 23 oct.', 10.5, Color(0xFF66636E))),
      gP(49, 454, 2, 32, gBox(color: Color(0xFF1F9D6B), radii: [1, 1, 1, 1])),
      gP(37, 425, 26, 26, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(42.667, 431.75, 14.667, 11.958, gImg('assets/figma/v/c2c3db2cc7ae5f.svg')),
      gP(76, 427, 126, 16, gText('Validation éditoriale', 13, Color(0xFF111015), weight: 600)),
      gP(76, 447, 150, 13, gText('Terminé · modératrice · 24 oct.', 10.5, Color(0xFF66636E))),
      gP(49, 514, 2, 32, gBox(color: Color(0xFFE4E1EA), radii: [1, 1, 1, 1])),
      gP(37, 485, 26, 26, gBox(color: Color(0xFF111015), oval: true)),
      gP(46.5, 491, 7, 14, gText('5', 11, Color(0xFFFFFFFF), weight: 700)),
      gP(76, 487, 160, 16, gText('Contrôles réglementaires', 13, Color(0xFF111015), weight: 600)),
      gP(76, 507, 114, 13, gText('En cours · checklist 3/5', 10.5, Color(0xFFB26A00))),
      gP(49, 574, 2, 32, gBox(color: Color(0xFFE4E1EA), radii: [1, 1, 1, 1])),
      gP(37, 545, 26, 26, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(46.5, 551, 7, 14, gText('6', 11, Color(0xFF66636E), weight: 700)),
      gP(76, 547, 77, 16, gText('Certification', 13, Color(0xFF66636E))),
      gP(76, 567, 140, 13, gText('À venir · certificat et ancrage', 10.5, Color(0xFF66636E))),
      gP(49, 634, 2, 32, gBox(color: Color(0xFFE4E1EA), radii: [1, 1, 1, 1])),
      gP(37, 605, 26, 26, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(46.5, 611, 7, 14, gText('7', 11, Color(0xFF66636E), weight: 700)),
      gP(76, 607, 70, 16, gText('Publication', 13, Color(0xFF66636E))),
      gP(76, 627, 33, 13, gText('À venir', 10.5, Color(0xFF66636E))),
      gP(49, 694, 2, 32, gBox(color: Color(0xFFE4E1EA), radii: [1, 1, 1, 1])),
      gP(37, 665, 26, 26, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(46.5, 671, 7, 14, gText('8', 11, Color(0xFF66636E), weight: 700)),
      gP(76, 667, 71, 16, gText('Transaction', 13, Color(0xFF66636E))),
      gP(76, 687, 208, 13, gText('À venir · commande, devis ou financement', 10.5, Color(0xFF66636E))),
      gP(49, 754, 2, 32, gBox(color: Color(0xFFE4E1EA), radii: [1, 1, 1, 1])),
      gP(37, 725, 26, 26, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(46.5, 731, 7, 14, gText('9', 11, Color(0xFF66636E), weight: 700)),
      gP(76, 727, 147, 16, gText('Préparation / réalisation', 13, Color(0xFF66636E))),
      gP(76, 747, 33, 13, gText('À venir', 10.5, Color(0xFF66636E))),
      gP(37, 785, 26, 26, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(43.5, 791, 13, 14, gText('10', 11, Color(0xFF66636E), weight: 700)),
      gP(76, 787, 47, 16, gText('Clôture', 13, Color(0xFF66636E))),
      gP(76, 807, 218, 13, gText('À venir · livraison, facture, revenus, archivage', 10.5, Color(0xFF66636E))),
      gP(24, 880, 342, 48, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x38403366), offset: Offset(0, 8), blurRadius: 18, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(40, 896, 310, 16, gText('Voir les contrôles automatiques et réglementaires', 13, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 880, 342, 48, const SizedBox.expand(), tap: () => gOpen(context, '256')),
      gTap(24, 880, 342, 48, () => gOpen(context, '256')),
    ]);
  }
}
