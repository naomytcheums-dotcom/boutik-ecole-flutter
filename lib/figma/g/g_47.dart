// GÉNÉRÉ par tool/figma_export/convert.py — écran 47 (nœud Figma 54:1007). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_47 extends ConsumerWidget {
  const G_47({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 221, 26, gText('Annuler la commande', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 109, 17, gText('#BE-2026-0141', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 140, 14, gText('Sac à dos design · 25 00…', 11.5, Color(0xFF66636E))),
      gP(242.4, 142, 109.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(258.2, 146, 78, 14, gText('En préparation', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 200, 150, 19, gText('Motif de l’annulation', 15, Color(0xFF111015), weight: 700)),
      gP(24, 238, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 241.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(54, 239, 315, 18, gText('Je me suis trompé de produit', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 274, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 275, 315, 18, gText('Délai de livraison trop long', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 310, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 311, 315, 18, gText('J’ai trouvé une meilleure offre', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 346, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 347, 315, 18, gText('Autre raison', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 382, 342, 154, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 396, 114, 18, gText('Remboursement', 14, Color(0xFF111015), weight: 700)),
      gP(40, 430, 118, 16, gText('Montant remboursé', 12.5, Color(0xFF66636E))),
      gP(271, 430, 79, 16, gText('25 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 455, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 464, 30, 16, gText('Délai', 12.5, Color(0xFF66636E))),
      gP(248, 464, 102, 16, gText('3 à 5 jours ouvrés', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 489, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 498, 35, 16, gText('Mode', 12.5, Color(0xFF66636E))),
      gP(265, 498, 85, 16, gText('Mobile Money', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 550, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 565, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 570.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(49, 578, 6, 8.833, gImg('assets/figma/v/9fc27387b9ffa1.svg')),
      gP(49, 575.167, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(76, 564, 277, 34, gText('Une commande déjà préparée peut ne plus être annulable.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Garder')),
      gP(80.5, 778, 50, 18, gText('Garder', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE5484D), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Annuler la commande')),
      gP(209, 778, 151, 18, gText('Annuler la commande', 14.5, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
