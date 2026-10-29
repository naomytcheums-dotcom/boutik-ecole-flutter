// GÉNÉRÉ par tool/figma_export/convert.py — écran 172 (nœud Figma 61:92). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_172 extends ConsumerWidget {
  const G_172({super.key});

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
      gP(76, 70, 224, 26, gText('Confiance du vendeur', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 182, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(159, 136, 72, 72, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [36, 36, 36, 36])),
      gP(22.5, 218, 345, 21, gText('Yannick Mouanga', 17, Color(0xFF111015), weight: 700, align: TextAlign.center, wrap: true)),
      gP(22.5, 242, 345, 15, gText('Génie civil · IUT de Douala', 12, Color(0xFF66636E), align: TextAlign.center, wrap: true)),
      gP(137, 268, 116, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(155, 272, 80, 14, gText('Vendeur vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 316, 154, 19, gText('Badges de confiance', 15, Color(0xFF111015), weight: 700)),
      gP(24, 354, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 367, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.658, 375.671, 22.672, 22.665, gImg('assets/figma/v/129b28be71ba2e.svg')),
      gP(50.5, 382.333, 11, 9.333, gImg('assets/figma/v/5fb65d78d14660.svg')),
      gP(88, 366, 103, 17, gText('Identité vérifiée', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 388, 154, 14, gText('Matricule et pièce confirmés', 11.5, Color(0xFF66636E))),
      gP(312.8, 376, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(322.9, 380, 19, 14, gText('Oui', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 420, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 433, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 444.167, 22.667, 14.333, gImg('assets/figma/v/081f49ef1bab2c.svg')),
      gP(48, 450, 16, 12.042, gImg('assets/figma/v/c9b26abe594987.svg')),
      gP(88, 432, 106, 17, gText('Étudiant de l’IUT', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 454, 152, 14, gText('Certificat de scolarité validé', 11.5, Color(0xFF66636E))),
      gP(312.8, 442, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(322.9, 446, 19, 14, gText('Oui', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 486, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 499, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 509.333, 16, 17.667, gImg('assets/figma/v/4832049c28e839.svg')),
      gP(50.5, 521, 11, 6, gImg('assets/figma/v/f40c5534a6fd70.svg')),
      gP(54.667, 512.667, 12.667, 14.333, gImg('assets/figma/v/ffe0117573cb5a.svg')),
      gP(55.5, 519.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(47.167, 519.333, 9.333, 9.333, gImg('assets/figma/v/87052a066968e5.svg')),
      gP(88, 498, 97, 17, gText('Livraison fiable', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 520, 198, 14, gText('98 % de commandes livrées à temps', 11.5, Color(0xFF66636E))),
      gP(306.4, 508, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(315.7, 512, 27, 14, gText('98 %', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 552, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 565, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 573.667, 22.667, 21.85, gImg('assets/figma/v/b091f911f7c021.svg')),
      gP(88, 564, 79, 17, gText('Avis positifs', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 586, 78, 14, gText('4,9 / 5 · 38 avis', 11.5, Color(0xFF66636E))),
      gP(312.8, 574, 39.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(323.4, 578, 18, 14, gText('4,9', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 632, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 655.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 661.417, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(49, 668.5, 6, 8.833, gImg('assets/figma/v/9fc27387b9ffa1.svg')),
      gP(49, 665.667, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(76, 646, 277, 51, gText('Un badge est retiré automatiquement si le compte est signalé ou si les documents expirent.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
