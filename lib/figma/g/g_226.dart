// GÉNÉRÉ par tool/figma_export/convert.py — écran 226 (nœud Figma 87:629). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_226 extends ConsumerWidget {
  const G_226({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, color: Color(0xFF222222), children: [
      gP(0, 0, 390, 844, gBox(image: 'assets/figma/img/906aab77f069a2bc93c3049468e70ffe2accdb89.png', fit: BoxFit.cover)),
      gP(0, 0, 390, 844, gBox(color: Color(0x2E000000))),
      gClip(0, 420, 390, 260, null, [
gP(-63, -3, 516, 266, gImg('assets/figma/v/ffbbfde614079b.svg')),
gP(7, 37, 376, 181, gImg('assets/figma/v/c901e6036f3570.svg'))
]),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFFFFFFFF), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(44.325, 84.325, 15.35, 15.35, gImg('assets/figma/v/9dd0d5ae029e1f.svg')),
      gP(44.325, 84.325, 15.35, 15.35, gImg('assets/figma/v/4fa204624ffbf6.svg')),
      gP(140, 76, 93, 30, gBox(color: Color(0xE51F9D6B), radii: [100, 100, 100, 100])),
      gP(154, 84, 65, 14, gText('Sol détecté', 11.5, Color(0xFFFFFFFF), weight: 600)),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(327.987, 81.208, 20.025, 21.583, gImg('assets/figma/v/dc71fdaa4dee30.svg')),
      gP(110, 612, 170, 30, gBox(color: Color(0x59000000), layerBlur: 10, oval: true)),
      gP(125, 380, 140, 230, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x59403366), offset: Offset(0, 14), blurRadius: 22, spreadRadius: 0)], radii: [22, 22, 22, 22])),
      gP(111, 366, 168, 258, gImg('assets/figma/v/fead007312dd35.svg')),
      gP(104, 359, 12, 12, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(270, 359, 12, 12, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(270, 615, 12, 12, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(104, 615, 12, 12, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(147, 330, 105, 30, gBox(color: Color(0xE5FFFFFF), radii: [100, 100, 100, 100])),
      gP(161, 338, 77, 14, gText('Hauteur 42 cm', 11, Color(0xFF111015), weight: 600)),
      gP(16, 664, 358, 164, gBox(color: Color(0xB8FFFFFF), border: Color(0xFFFFFFFF), bw: 1, backBlur: 30, radii: [36, 36, 36, 36])),
      gP(30, 678, 56, 56, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [18, 18, 18, 18])),
      gP(98, 682, 151, 18, gText('Lampe en bois recyclé', 14, Color(0xFF111015), weight: 600)),
      gP(98, 704, 79, 16, gText('25 000 FCFA', 12.5, Color(0xFF5A3FE0), weight: 700)),
      gP(30, 748, 27, 14, gText('Taille', 11, Color(0xFF66636E), weight: 500)),
      gP(74, 753, 200, 4, gBox(color: Color(0xFFDAD7E0), radii: [2, 2, 2, 2])),
      gP(74, 753, 120, 4, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(186, 747, 16, 16, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x33403366), offset: Offset(0, 2), blurRadius: 6, spreadRadius: 0)], oval: true)),
      gP(299, 682, 48, 48, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(305, 688, 36, 36, gBox(color: Color(0xFF111015), oval: true)),
      gP(310, 693, 26, 26, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(30, 772, 224, 44, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(91, 786, 102, 16, gText('Ajouter au panier', 12.5, Color(0xFFFFFFFF), weight: 600)),
      gP(262, 772, 96, 44, gBox(color: Color(0xFFF1EEFB), radii: [100, 100, 100, 100])),
      gP(279.5, 787, 61, 14, gText('Réinitialiser', 11, Color(0xFF5A3FE0), weight: 600)),
    ]);
  }
}
