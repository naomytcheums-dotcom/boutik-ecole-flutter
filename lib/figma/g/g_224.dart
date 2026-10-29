// GÉNÉRÉ par tool/figma_export/convert.py — écran 224 (nœud Figma 87:532). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_224 extends ConsumerWidget {
  const G_224({super.key});

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
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 196, 26, gText('Programmer un live', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 68, 16, gText('Titre du live', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 140, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 140, 342, 48, GField(hint: '', initial: 'Fabrication de la lampe en bois re…', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 153.5, 21.004, 21.004, gImg('assets/figma/v/463d6a4c8e1061.svg')),
      gP(24, 202, 81, 16, gText('Date et heure', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 222, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 222, 342, 48, GField(hint: '', initial: 'Jeudi 29 oct. · 16 h', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 237, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(48, 235.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(42, 235.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(38.25, 241.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(24, 284, 147, 19, gText('Produit mis en avant', 15, Color(0xFF111015), weight: 700)),
      gP(24, 322, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 330, 50, 50, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 334, 145, 17, gText('Lampe en bois recyclé', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 356, 135, 14, gText('25 000 FCFA · 6 en stock', 11.5, Color(0xFF66636E))),
      gP(312.8, 344, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(324.4, 348, 16, 14, gText('Lié', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 402, 117, 16, gText('Matériel nécessaire', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 422, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 422, 342, 96, GField(hint: 'Téléphone, trépied, bonne lumière', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 532, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 547, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 552.943, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 558.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 546, 277, 34, gText('Un référent du département valide le live et peut le rejoindre en modération.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Brouillon')),
      gP(74.5, 778, 62, 18, gText('Brouillon', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Planifier')),
      gP(256, 778, 57, 18, gText('Planifier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
