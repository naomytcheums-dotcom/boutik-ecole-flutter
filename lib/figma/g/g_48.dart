// GÉNÉRÉ par tool/figma_export/convert.py — écran 48 (nœud Figma 36:330). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_48 extends ConsumerWidget {
  const G_48({super.key});

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
      gP(76, 70, 128, 26, gText('Réclamation', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/55fe764cd9b0e1fc03c630662e027fb0f9f7ade4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 191, 17, gText('Commande #BE-2026-0138', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 143, 14, gText('18 oct. 2026 · 17 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(280.8, 142, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 146, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 200, 149, 19, gText('Motif de la demande', 15, Color(0xFF111015), weight: 700)),
      gP(24, 238, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 241.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(54, 239, 315, 18, gText('Article non reçu', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 274, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 275, 315, 18, gText('Article endommagé ou non conforme', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 310, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 311, 315, 18, gText('Annulation avant préparation', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 346, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 347, 315, 18, gText('Demande de remboursement', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 382, 133, 16, gText('Détails de la demande', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 402, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 402, 342, 96, GField(hint: 'Décrivez le problème rencontré…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 512, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 525, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 535.333, 22.667, 19.333, gImg('assets/figma/v/b357168830edbf.svg')),
      gP(50.5, 540.333, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 524, 124, 17, gText('Ajouter des photos', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 546, 157, 14, gText('Preuves du problème (3 max)', 11.5, Color(0xFF66636E))),
      gP(336.75, 537.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 592, 342, 52, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 602, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 607.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(49, 610.75, 8.833, 11.667, gImg('assets/figma/v/3a93fa78124c31.svg')),
      gP(76, 609.5, 277, 17, gText('Notre équipe vous répond sous 48 h ouvrées.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Envoyer la demande')),
      gP(124.5, 778, 141, 18, gText('Envoyer la demande', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
