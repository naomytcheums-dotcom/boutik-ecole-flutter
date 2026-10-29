// GÉNÉRÉ par tool/figma_export/convert.py — écran 49 (nœud Figma 36:813). Ne pas éditer à la main.
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

class G_49 extends ConsumerWidget {
  const G_49({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 854, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 131.82, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 584.44, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 159, 26, gText('Aide et support', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Comment pouvons-nous vous aider ?', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(24, 182, 126, 19, gText('Sujets populaires', 15, Color(0xFF111015), weight: 700)),
      gP(24, 220, 342, 156, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 226, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 235.5, 21, 20.167, gImg('assets/figma/v/3ce22d6edc53c9.svg')),
      gP(45.5, 239.667, 21, 6, gImg('assets/figma/v/dd90762ca86114.svg')),
      gP(53, 242.167, 6, 10.167, gImg('assets/figma/v/d6ae5a001ef5e1.svg')),
      gP(88, 237, 164, 17, gText('Commandes et livraisons', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 238.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 272, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 278, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 287.5, 21.833, 16.833, gImg('assets/figma/v/92f350858b638e.svg')),
      gP(45.5, 289.167, 21, 19.333, gImg('assets/figma/v/f6a87a84fa91d7.svg')),
      gP(88, 289, 200, 17, gText('Paiements et remboursements', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 290.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(88, 324, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 330, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46, 340, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(48.833, 339.5, 14.333, 14.333, gImg('assets/figma/v/89c36cb8c670bc.svg')),
      gP(46.333, 347.833, 19.333, 12.667, gImg('assets/figma/v/4e3ce9c030e64b.svg')),
      gP(88, 341, 126, 17, gText('Compte et sécurité', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 342.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 390, 159, 19, gText('Questions fréquentes', 15, Color(0xFF111015), weight: 700)),
      gP(24, 428, 342, 156, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 445, 217, 17, gText('Comment suivre ma commande ?', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 446.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(40, 480, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 497, 183, 17, gText('Comment devenir vendeur ?', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 498.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(40, 532, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 549, 204, 17, gText('Quels sont les délais de retrait ?', 13.5, Color(0xFF111015), weight: 600)),
      gP(336.75, 550.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 598, 342, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(222.36, 598, 143.64, 132, gBox(image: 'assets/figma/img/93dff03913a5b9f3a8ba8bc190862ebc295fc28d.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(195, 598, 68.4, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF1B3F6E), Color(0x001B3F6E)], stops: [0, 1]))),
      gP(42, 614, 174, 20, gText('Besoin d’aide ?', 15, Color(0xFFFFFFFF), weight: 700, lh: 20, wrap: true)),
      gP(42, 660, 160.32, 30, gText('Notre équipe répond sous 24 h.', 11, Color(0xFFE9E4F5), lh: 15, wrap: true)),
      gP(42, 690, 170, 28, gBox(color: Color(0xFF111015), radii: [14, 14, 14, 14])),
      gP(69, 696, 116, 14, gText('Contacter le support', 11.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 842, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 766, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 787.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 787.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 799.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 787.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 787.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 787.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 786.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 793.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 800.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 787.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 787.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 795.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 772, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 787, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 785.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
