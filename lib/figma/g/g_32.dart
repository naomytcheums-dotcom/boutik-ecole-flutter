// GÉNÉRÉ par tool/figma_export/convert.py — écran 32 (nœud Figma 36:140). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_32 extends ConsumerWidget {
  const G_32({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1016, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 185.28, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 723.76, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 171, 26, gText('Détail du produit', 21, Color(0xFF111015), weight: 700)),
      gP(339.833, 70.75, 24.333, 22.5, gImg('assets/figma/v/62244446006906.svg')),
      gP(333, 63, 38, 38, GHeart()),
      gP(303.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(307.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(311, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
      gP(24, 120, 342, 230, gBox(image: 'assets/figma/img/6baf8125049f662c1c5c4c23c6b514db2881910c.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 364, 345, 28, gText('Lampe en bois recyclé', 22, Color(0xFF111015), weight: 800, wrap: true)),
      gP(24, 396, 345, 19, gText('25 000 FCFA · En stock', 13, Color(0xFF66636E), lh: 19, wrap: true)),
      gP(24, 465, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(29.75, 439, 74, 16, gText('Description', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(36.825, 463, 59.85, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(130.75, 439, 43, 16, gText('Détails', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(225.25, 439, 25, 16, gText('Avis', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(295.75, 439, 55, 16, gText('Livraison', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 483, 345, 41, gText('Lampe décorative fabriquée à partir de bois recyclé. Écologique, design et idéale pour un intérieur moderne.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 538, 69, 19, gText('Variantes', 15, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 576, 122.2, 34, 'Chêne naturel', 12.5, 600), GChip(154.2, 576, 63, 34, 'Noyer', 12.5, 500), GChip(225.2, 576, 70.4, 34, 'Bambou', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(40, 638, 114, 18, gText('Caractéristiques', 14, Color(0xFF111015), weight: 700)),
      gP(40, 672, 52, 16, gText('Matériau', 12.5, Color(0xFF66636E))),
      gP(276, 672, 74, 16, gText('Bois recyclé', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 697, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 706, 70, 16, gText('Dimensions', 12.5, Color(0xFF66636E))),
      gP(286, 706, 64, 16, gText('28 × 22 cm', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 731, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 740, 56, 16, gText('Éclairage', 12.5, Color(0xFF66636E))),
      gP(257, 740, 93, 16, gText('LED E27 incluse', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 765, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 774, 52, 16, gText('Garantie', 12.5, Color(0xFF66636E))),
      gP(311, 774, 39, 16, gText('6 mois', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(36, 834, 50, 50, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 838, 114, 17, gText('Mouanga Yannick', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 860, 144, 14, gText('Génie civil · Vendeur vérifié', 11.5, Color(0xFF66636E))),
      gP(306.4, 848, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(318.7, 852, 21, 14, gText('Voir', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(0, 916, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 932, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Ajouter au panier')),
      gP(136, 950, 118, 18, gText('Ajouter au panier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 1002, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
