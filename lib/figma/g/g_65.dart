// GÉNÉRÉ par tool/figma_export/convert.py — écran 65 (nœud Figma 37:707). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_65 extends ConsumerWidget {
  const G_65({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 880, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140.4, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 606.8, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 239, 26, gText('Vente #BE-2026-0142', 21, Color(0xFF111015), weight: 700)),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/b49b6a241d16c8c01f026ab4fe2980adaae1b6f4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 145, 17, gText('Lampe en bois recyclé', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 113, 14, gText('Qté : 1 · 25 000 FCFA', 11.5, Color(0xFF66636E))),
      gP(268, 142, 84, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(281.5, 146, 57, 14, gText('À préparer', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(40, 214, 131, 18, gText('Résumé de la vente', 14, Color(0xFF111015), weight: 700)),
      gP(40, 248, 54, 16, gText('Acheteur', 12.5, Color(0xFF66636E))),
      gP(244, 248, 106, 16, gText('Yannick Mouanga', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 273, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 282, 29, 16, gText('Date', 12.5, Color(0xFF66636E))),
      gP(274, 282, 76, 16, gText('22 oct. 2026', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 307, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 316, 50, 16, gText('Montant', 12.5, Color(0xFF66636E))),
      gP(271, 316, 79, 16, gText('25 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 341, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 350, 106, 16, gText('Commission (5 %)', 12.5, Color(0xFF66636E))),
      gP(274, 350, 76, 16, gText('– 1 250 FCFA', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 375, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 384, 83, 16, gText('Vous recevrez', 12.5, Color(0xFF66636E))),
      gP(274, 384, 76, 16, gText('23 750 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 409, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 418, 40, 16, gText('Retrait', 12.5, Color(0xFF66636E))),
      gP(228, 418, 122, 16, gText('Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 470, 188, 19, gText('Historique des opérations', 15, Color(0xFF111015), weight: 700)),
      gP(33, 530, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 509, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 513.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 508, 305, 17, gText('Commande reçue', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 528, 305, 14, gText('22 oct. · 08:10', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 592, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 571, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 575.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 570, 305, 17, gText('Paiement confirmé', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 590, 305, 14, gText('22 oct. · 08:12', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 654, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 633, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 632, 305, 17, gText('Préparation', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 652, 305, 14, gText('En cours', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 695, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 694, 305, 17, gText('Remise au point de retrait', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 714, 305, 14, gText('', 11.5, Color(0xFF66636E), wrap: true)),
      gP(0, 780, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 796, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => advanceCurrentOrder(ref, context)),
      orderActionText(24, 814, 342),
      gP(125, 866, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
