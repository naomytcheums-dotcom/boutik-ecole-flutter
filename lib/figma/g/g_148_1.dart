// GÉNÉRÉ par tool/figma_export/convert.py — écran 148-1 (nœud Figma 40:706). Ne pas éditer à la main.
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

class G_148_1 extends ConsumerWidget {
  const G_148_1({super.key});

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
      gP(76, 70, 118, 26, gText('Paramètres', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 150, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(159, 136, 72, 72, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [36, 36, 36, 36])),
      gP(22.5, 216, 345, 21, gText('Mariam Essono', 17, Color(0xFF111015), weight: 700, align: TextAlign.center, wrap: true)),
      gP(22.5, 240, 345, 15, gText('mariam@iut-douala.cm', 12, Color(0xFF66636E), align: TextAlign.center, wrap: true)),
      gP(24, 284, 342, 312, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 290, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46, 300, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(48.833, 299.5, 14.333, 14.333, gImg('assets/figma/v/89c36cb8c670bc.svg')),
      gP(46.333, 307.833, 19.333, 12.667, gImg('assets/figma/v/4e3ce9c030e64b.svg')),
      gP(88, 301, 170, 17, gText('Informations personnelles', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 302.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 336, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 342, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 350.667, 19.333, 22.667, gImg('assets/figma/v/e25472574b704c.svg')),
      gP(50.5, 354.833, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(88, 353, 61, 17, gText('Adresses', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 354.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 388, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 394, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 403.5, 21.833, 16.833, gImg('assets/figma/v/92f350858b638e.svg')),
      gP(45.5, 405.167, 21, 19.333, gImg('assets/figma/v/f6a87a84fa91d7.svg')),
      gP(88, 405, 136, 17, gText('Moyens de paiement', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 406.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 440, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 446, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 454.667, 21, 18.5, gImg('assets/figma/v/e2c8fe85d4329b.svg')),
      gP(51.583, 470.5, 8.833, 6.838, gImg('assets/figma/v/165eb123ea9a50.svg')),
      gP(88, 457, 84, 17, gText('Notifications', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 458.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 492, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 498, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 506.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(49.667, 506.667, 12.667, 22.667, gImg('assets/figma/v/60f10615a145da.svg')),
      gP(44.667, 515, 22.667, 6, gImg('assets/figma/v/a036c8587a1cff.svg')),
      gP(88, 509, 129, 17, gText('Langue et affichage', 13.5, Color(0xFF111015), weight: 600)),
      gP(295, 509, 55, 17, gText('Français', 13.5, Color(0xFF66636E), weight: 700, align: TextAlign.right)),
      gP(88, 544, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 550, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 558.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(50.575, 562.83, 10.858, 11.004, gImg('assets/figma/v/82b9c7e058d1c4.svg')),
      gP(53, 571.167, 6.008, 6, gImg('assets/figma/v/7a0aba9eeb97a7.svg')),
      gP(88, 561, 101, 17, gText('Aide et support', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 562.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 610, 342, 50, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE5484D), bw: 1.5, radii: [25, 25, 25, 25])),
      gP(151, 626, 113, 18, gText('Se déconnecter', 14.5, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(125.125, 625.625, 10.25, 18.75, gImg('assets/figma/v/9fe923cd01fc4e.svg')),
      gP(134.333, 628.458, 9.542, 13.083, gImg('assets/figma/v/ec3a284b9561d3.svg')),
      gP(129.375, 632, 14.5, 6, gImg('assets/figma/v/c9c5916be820f1.svg')),
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
