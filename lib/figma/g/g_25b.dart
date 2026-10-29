// GÉNÉRÉ par tool/figma_export/convert.py — écran 25b (nœud Figma 36:385). Ne pas éditer à la main.
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

class G_25b extends ConsumerWidget {
  const G_25b({super.key});

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
      gP(76, 70, 160, 26, gText('Mes collections', 21, Color(0xFF111015), weight: 700)),
      gP(342.583, 79, 18.833, 6, gImg('assets/figma/v/6fe571ab77e960.svg')),
      gP(349, 72.583, 6, 18.833, gImg('assets/figma/v/87cbf4a9a18b64.svg')),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Rechercher dans mes listes', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(24, 182, 72, 19, gText('Mes listes', 15, Color(0xFF111015), weight: 700)),
      gP(317, 184, 33, 15, gText('Gérer', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 189, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 185.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 220, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 228, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 232, 100, 17, gText('Maison et déco', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 254, 95, 14, gText('12 articles · Privée', 11.5, Color(0xFF66636E))),
      gP(336.75, 245.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 286, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 294, 50, 50, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 298, 153, 17, gText('Cadeaux d’anniversaire', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 320, 107, 14, gText('5 articles · Partagée', 11.5, Color(0xFF66636E))),
      gP(336.75, 311.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 352, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 360, 50, 50, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 364, 167, 17, gText('Équipement informatique', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 386, 91, 14, gText('8 articles · Privée', 11.5, Color(0xFF66636E))),
      gP(336.75, 377.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 418, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 426, 50, 50, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 430, 98, 17, gText('Projets à suivre', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 452, 104, 14, gText('3 projets · Publique', 11.5, Color(0xFF66636E))),
      gP(336.75, 443.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 498, 342, 50, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [25, 25, 25, 25])),
      gP(137, 514, 141, 18, gText('Créer une collection', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(112.542, 520, 15.917, 6, gImg('assets/figma/v/253e5d47822704.svg')),
      gP(117.5, 515.042, 6, 15.917, gImg('assets/figma/v/2a781469bb9f84.svg')),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
