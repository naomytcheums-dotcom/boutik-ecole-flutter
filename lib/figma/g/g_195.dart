// GÉNÉRÉ par tool/figma_export/convert.py — écran 195 (nœud Figma 83:290). Ne pas éditer à la main.
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

class G_195 extends ConsumerWidget {
  const G_195({super.key});

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
      gP(76, 70, 193, 26, gText('Ajouter une preuve', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 141.667, 22.667, 14.333, gImg('assets/figma/v/8c9c6b229b6232.svg')),
      gP(44.667, 154.167, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(44.667, 150, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(88, 132, 135, 17, gText('Propositions de logo', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 154, 166, 14, gText('Jalon 2 · Identité visuelle Mbel…', 11.5, Color(0xFF66636E))),
      gP(280.8, 142, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(293.9, 146, 45, 14, gText('En cours', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(24, 200, 187, 19, gText('Photos ou vidéo du travail', 15, Color(0xFF111015), weight: 700)),
      gP(24, 238, 108.667, 92, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 238, 108.667, 92, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 238, 108.667, 92, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(24, 344, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 357, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 367.333, 22.667, 19.333, gImg('assets/figma/v/b357168830edbf.svg')),
      gP(50.5, 372.333, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 368, 121, 17, gText('Prendre une photo', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 369.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 410, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 423, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 442.5, 21, 11, gImg('assets/figma/v/446cc0970fc579.svg')),
      gP(48.833, 432.5, 14.333, 10.167, gImg('assets/figma/v/a73a032c82a1f2.svg')),
      gP(53, 432.5, 6, 16, gImg('assets/figma/v/2f7bb92e5f1a61.svg')),
      gP(88, 422, 124, 17, gText('Importer une vidéo', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 444, 107, 14, gText('2 minutes maximum', 11.5, Color(0xFF66636E))),
      gP(336.75, 435.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 490, 112, 16, gText('Ce qui a été réalisé', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 510, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 510, 342, 96, GField(hint: '', initial: 'Trois pistes de logo, déclinées en couleur et noir et blanc.', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 620, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 635, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 640.917, 18.75, 16.625, gImg('assets/figma/v/b2ae09d0fd46bb.svg')),
      gP(47.796, 654.375, 8.408, 6.712, gImg('assets/figma/v/f59da0513c0b4c.svg')),
      gP(76, 634, 277, 34, gText('Le client est notifié dès l’envoi et peut valider ou demander une correction.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Brouillon')),
      gP(74.5, 778, 62, 18, gText('Brouillon', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Envoyer pour validation')),
      gP(202.5, 778, 164, 18, gText('Envoyer pour validation', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
