// GÉNÉRÉ par tool/figma_export/convert.py — écran 51 (nœud Figma 36:574). Ne pas éditer à la main.
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

class G_51 extends ConsumerWidget {
  const G_51({super.key});

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
      gP(76, 70, 121, 26, gText('Notification', 21, Color(0xFF111015), weight: 700)),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 143.333, 16, 17.667, gImg('assets/figma/v/4832049c28e839.svg')),
      gP(50.5, 155, 11, 6, gImg('assets/figma/v/f40c5534a6fd70.svg')),
      gP(54.667, 146.667, 12.667, 14.333, gImg('assets/figma/v/ffe0117573cb5a.svg')),
      gP(55.5, 153.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(47.167, 153.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(88, 132, 141, 17, gText('Commande expédiée', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 154, 99, 14, gText('Aujourd’hui · 10:24', 11.5, Color(0xFF66636E))),
      gP(24, 200, 345, 61, gText('Votre commande #BE-2026-0142 a quitté l’atelier du vendeur. Elle sera disponible au point de retrait du Bloc A d’ici demain, 14 h.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(33, 297, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 276, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 280.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 275, 305, 17, gText('Confirmée', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 295, 305, 14, gText('22 oct. · 08:10', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 359, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 338, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 342.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 337, 305, 17, gText('Préparée', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 357, 305, 14, gText('22 oct. · 09:40', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 421, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 400, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 399, 305, 17, gText('Expédiée', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 419, 305, 14, gText('23 oct. · 10:24', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 462, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 461, 305, 17, gText('Prête au retrait', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 481, 305, 14, gText('24 oct. · 14:00', 11.5, Color(0xFF66636E), wrap: true)),
      gP(40, 549, 62, 16, gText('Référence', 12.5, Color(0xFF66636E))),
      gP(247, 549, 103, 16, gText('#BE-2026-0142', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 574, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 583, 87, 16, gText('Point de retrait', 12.5, Color(0xFF66636E))),
      gP(228, 583, 122, 16, gText('Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 608, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 617, 50, 16, gText('Montant', 12.5, Color(0xFF66636E))),
      gP(262, 617, 88, 16, gText('330 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contacter le vendeur')),
      gP(31.5, 778, 148, 18, gText('Contacter le vendeur', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Suivre ma commande')),
      gP(209, 778, 151, 18, gText('Suivre ma commande', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
