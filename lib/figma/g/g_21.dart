// GÉNÉRÉ par tool/figma_export/convert.py — écran 21 (nœud Figma 54:502). Ne pas éditer à la main.
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

class G_21 extends ConsumerWidget {
  const G_21({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 946, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 162.18, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 663.56, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 201, 26, gText('Recherche avancée', 21, Color(0xFF111015), weight: 700)),
      gP(350.833, 71.667, 12.417, 6, gImg('assets/figma/v/03a765f5fab6c0.svg')),
      gP(340.75, 71.667, 12.417, 6, gImg('assets/figma/v/03a765f5fab6c0.svg')),
      gP(349, 79, 14.25, 6, gImg('assets/figma/v/658b7de571167d.svg')),
      gP(340.75, 79, 10.583, 6, gImg('assets/figma/v/fc9bd872b877c1.svg')),
      gP(352.667, 86.333, 10.583, 6, gImg('assets/figma/v/fc9bd872b877c1.svg')),
      gP(340.75, 86.333, 14.25, 6, gImg('assets/figma/v/658b7de571167d.svg')),
      gP(350.833, 69.833, 6, 9.667, gImg('assets/figma/v/c267f7a32a398f.svg')),
      gP(345.333, 77.167, 6, 9.667, gImg('assets/figma/v/c267f7a32a398f.svg')),
      gP(352.667, 84.5, 6, 9.667, gImg('assets/figma/v/c267f7a32a398f.svg')),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Mot-clé, nom, compétence…', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(24, 218, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(42.75, 192, 48, 14, gText('Produits', 11.5, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(36.825, 216, 59.85, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(128.25, 192, 48, 14, gText('Services', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(218.25, 192, 39, 14, gText('Talents', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(303.25, 192, 40, 14, gText('Projets', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 236, 82, 16, gText('Département', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 256, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 256, 342, 48, GField(hint: '', initial: 'Tous les départements', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 283.75, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(39.75, 270.25, 16.5, 19.5, gImg('assets/figma/v/9da510320c2d7b.svg')),
      gP(42.75, 279.25, 10.5, 10.5, gImg('assets/figma/v/79c4b172cb37e4.svg')),
      gP(334.5, 274.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 318, 46, 16, gText('Budget', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 338, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 338, 342, 48, GField(hint: '', initial: '0 – 500 000 FCFA', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 352.25, 20.25, 15.75, gImg('assets/figma/v/a842b4c78dabfc.svg')),
      gP(38.25, 353.75, 19.5, 18, gImg('assets/figma/v/fbc7a9ade9c600.svg')),
      gP(334.5, 356.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 400, 61, 16, gText('Catégorie', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 420, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 420, 342, 48, GField(hint: '', initial: 'Toutes les catégories', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 434.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 434.25, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(46.5, 442.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(38.25, 442.5, 11.25, 11.25, gImg('assets/figma/v/4aa41d01b63de8.svg')),
      gP(334.5, 438.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 482, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 494, 151, 17, gText('Disponible uniquement', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 516, 146, 14, gText('En stock ou sur commande', 11.5, Color(0xFF66636E))),
      gP(308, 503, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 548, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 560, 112, 17, gText('Vendeurs vérifiés', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 582, 111, 14, gText('Badge de confiance', 11.5, Color(0xFF66636E))),
      gP(308, 569, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(24, 628, 155, 19, gText('Recherches récentes', 15, Color(0xFF111015), weight: 700)),
      gP(24, 666, 342, 156, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 672, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 680.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 684, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 683, 101, 17, gText('lampe recyclée', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 684.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 718, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 724, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 732.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 736, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 735, 116, 17, gText('développeur web', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 736.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 770, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 776, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 784.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 788, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 787, 97, 17, gText('drone éducatif', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 788.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 846, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 862, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Réinitialiser')),
      gP(65, 880, 81, 18, gText('Réinitialiser', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 862, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Rechercher')),
      gP(244, 880, 81, 18, gText('Rechercher', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 932, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
