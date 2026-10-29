// GÉNÉRÉ par tool/figma_export/convert.py — écran 33 (nœud Figma 54:2). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_33 extends ConsumerWidget {
  const G_33({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1053, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 197.49, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 755.58, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 190, 26, gText('Histoire du produit', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 200, gBox(image: 'assets/figma/img/e48f8827338ec470670d1109125a15b7d0f21476.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 200, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 258, 309, 23, gText('De la chute de bois à la lumière', 18, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(42, 286, 309, 15, gText('Une lampe née d’un atelier de génie civil', 12, Color(0xFFE3ECF7), wrap: true)),
      gP(159, 350, 72, 72, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [36, 36, 36, 36])),
      gP(22.5, 432, 345, 21, gText('Mouanga Yannick', 17, Color(0xFF111015), weight: 700, align: TextAlign.center, wrap: true)),
      gP(22.5, 456, 345, 15, gText('Génie civil · IUT de Douala', 12, Color(0xFF66636E), align: TextAlign.center, wrap: true)),
      gP(133.8, 482, 122.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(154, 486, 82, 14, gText('Créateur vérifié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 530, 86, 19, gText('Son histoire', 15, Color(0xFF111015), weight: 700)),
      gP(24, 568, 345, 61, gText('Yannick récupère les chutes de bois des chantiers-écoles pour en faire des luminaires uniques. Chaque pièce est dessinée, découpée et assemblée à la main.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 643, 156, 19, gText('Étapes de fabrication', 15, Color(0xFF111015), weight: 700)),
      gP(33, 703, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 682, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 686.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 681, 305, 17, gText('Récupération des chutes', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 701, 305, 14, gText('Ateliers du département Génie civil', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 765, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 744, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 748.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 743, 305, 17, gText('Découpe et ponçage', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 763, 305, 14, gText('Lamelles de 3 mm', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 827, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 806, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 805, 305, 17, gText('Assemblage', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 825, 305, 14, gText('Structure en cage', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 868, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 867, 305, 17, gText('Finition et test', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 887, 305, 14, gText('Contrôle électrique', 11.5, Color(0xFF66636E), wrap: true)),
      gP(0, 953, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 969, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Contacter le créateur')),
      gP(120.5, 987, 149, 18, gText('Contacter le créateur', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 1039, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 426, 342, 70, () => gOpen(context, '10')),
    ]);
  }
}
