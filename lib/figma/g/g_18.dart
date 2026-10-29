// GÉNÉRÉ par tool/figma_export/convert.py — écran 18 (nœud Figma 22:276). Ne pas éditer à la main.
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

class G_18 extends ConsumerWidget {
  const G_18({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF5F0E8), Color(0xFFEFE9F4), Color(0xFFF7E9DB)], stops: [0, 0.55, 1]), children: [
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 73, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 74.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 81, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 71, 177, 26, gText('État de validation', 21, Color(0xFF111015), weight: 700)),
      gP(146, 262, 98, 28, gBox(color: Color(0xFFFDEFC8), radii: [14, 14, 14, 14])),
      gP(163.5, 268, 63, 16, gText('En attente', 12.5, Color(0xFFB26E00), weight: 700, align: TextAlign.center)),
      gP(45.5, 311, 299, 26, gText('Demande en cours d’examen', 21, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(62, 348, 266, 40, gText('Notre équipe vérifie vos informations.\nVous recevrez une réponse sous 24 à 48 h.', 13.5, Color(0xFF66636E), lh: 20, align: TextAlign.center)),
      gP(60, 426, 270, 2, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(60, 426, 135, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(43, 410, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(51, 419.5, 18, 14.25, gImg('assets/figma/v/3f716e341ea101.svg')),
      gP(178, 410, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(184.5, 416.5, 21, 21, gImg('assets/figma/v/259dd60b59fe7a.svg')),
      gP(192, 419.5, 9, 12, gImg('assets/figma/v/0d4116012f1e35.svg')),
      gP(313, 410, 34, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(35, 454.5, 50, 15, gText('Envoyée', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.center)),
      gP(153.5, 454.5, 83, 15, gText('En vérification', 12, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(304.5, 454.5, 51, 15, gText('Décision', 12, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 492, 342, 238, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(44, 511, 136, 18, gText('Résultats possibles', 14.5, Color(0xFF111015), weight: 700)),
      gP(49, 555, 38, 38, gBox(color: Color(0xFFDDF5EC), oval: true)),
      gP(59, 566.5, 18, 14.25, gImg('assets/figma/v/e8169edd9146cb.svg')),
      gP(100, 555, 68, 18, gText('Approuvé', 14, Color(0xFF111015), weight: 600)),
      gP(100, 577.5, 189, 15, gText('Votre compte vendeur est activé.', 12, Color(0xFF66636E))),
      gP(44, 606, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(49, 615, 38, 38, gBox(color: Color(0xFFFDE6E7), oval: true)),
      gP(60.5, 626.5, 15, 15, gImg('assets/figma/v/0f214096451e8a.svg')),
      gP(60.5, 626.5, 15, 15, gImg('assets/figma/v/191bab3339750c.svg')),
      gP(100, 615, 47, 18, gText('Refusé', 14, Color(0xFF111015), weight: 600)),
      gP(100, 637.5, 235, 15, gText('Votre demande n’a pas pu être acceptée.', 12, Color(0xFF66636E))),
      gP(44, 666, 302, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(49, 675, 38, 38, gBox(color: Color(0xFFEEE9FF), oval: true)),
      gP(57.487, 684.24, 21.012, 19.51, gImg('assets/figma/v/ef03886316d03a.svg')),
      gP(65, 688.75, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(65, 694.75, 6.008, 6, gImg('assets/figma/v/f943396fb20219.svg')),
      gP(100, 675, 67, 18, gText('À corriger', 14, Color(0xFF111015), weight: 600)),
      gP(100, 697.5, 198, 15, gText('Des informations sont à compléter.', 12, Color(0xFF66636E))),
      gP(24, 750, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Retour à l’accueil')),
      gP(129, 767, 132, 20, gText('Retour à l’accueil', 16, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(24, 818, 342, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contacter le support')),
      gP(119.5, 835.5, 151, 19, gText('Contacter le support', 15, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(159.433, 150.433, 84.333, 84.333, gImg('assets/figma/r/173_17.png')),
      gP(198.6, 164.3, 22.867, 39.733, gImg('assets/figma/v/b054b6abe60905.svg')),
    ]);
  }
}
