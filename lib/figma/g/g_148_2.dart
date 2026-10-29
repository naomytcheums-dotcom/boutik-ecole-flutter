// GÉNÉRÉ par tool/figma_export/convert.py — écran 148-2 (nœud Figma 22:339). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_148_2 extends ConsumerWidget {
  const G_148_2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 147, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 624, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 73, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 74.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 81, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 71, 189, 26, gText('Centre de sécurité', 21, Color(0xFF111015), weight: 700)),
      gP(24, 124, 342, 102, gBox(color: Color(0xFFF2FBF7), border: Color(0xFFBFE8D6), bw: 1.5, radii: [24, 24, 24, 24])),
      gP(44, 142, 48, 48, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(56.333, 152.166, 23.333, 27.67, gImg('assets/figma/v/629c49f7945fb3.svg')),
      gP(61.75, 160.833, 12.5, 10.333, gImg('assets/figma/v/0ec99ee32049a5.svg')),
      gP(108, 142, 168, 20, gText('Compte bien protégé', 16, Color(0xFF111015), weight: 700)),
      gP(108, 168, 149, 16, gText('Niveau de sécurité : Élevé', 12.5, Color(0xFF66636E))),
      gP(44, 202, 302, 6, gBox(color: Color(0xFFD6EEE3), radii: [3, 3, 3, 3])),
      gP(44, 202, 244, 6, gBox(color: Color(0xFF1F9D6B), radii: [3, 3, 3, 3])),
      gP(315, 182.5, 31, 15, gText('80 %', 12, Color(0xFF0F7A52), weight: 700, align: TextAlign.right)),
      gP(24, 244.5, 145, 19, gText('Accès et protection', 15, Color(0xFF111015), weight: 700)),
      gP(24, 274, 342, 168, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 288, 36, 36, gBox(color: Color(0xFFF1EEFB), radii: [12, 12, 12, 12])),
      gP(47.5, 301.5, 14.25, 14.25, gImg('assets/figma/v/8dc44dcd0da244.svg')),
      gP(54.55, 295.5, 13.2, 13.2, gImg('assets/figma/v/24df6db66bbc97.svg')),
      gP(57.625, 297, 10.875, 10.875, gImg('assets/figma/v/2608fe93d3793a.svg')),
      gP(90, 289.5, 160, 17, gText('Changer le mot de passe', 13.5, Color(0xFF111015), weight: 600)),
      gP(90, 309, 103, 14, gText('Modifié il y a 3 mois', 11.5, Color(0xFF66636E))),
      gP(336.75, 298.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(90, 332, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 340, 36, 36, gBox(color: Color(0xFFF1EEFB), radii: [12, 12, 12, 12])),
      gP(49, 347.5, 18, 21.003, gImg('assets/figma/v/9ef0225a8ac33c.svg')),
      gP(52.75, 353.5, 10.5, 9, gImg('assets/figma/v/437c9ab58b0839.svg')),
      gP(90, 341.5, 154, 17, gText('Double authentification', 13.5, Color(0xFF111015), weight: 600)),
      gP(90, 361, 169, 14, gText('Code SMS à chaque connexion', 11.5, Color(0xFF66636E))),
      gP(308, 346, 38, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(90, 384, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 392, 36, 36, gBox(color: Color(0xFFF1EEFB), radii: [12, 12, 12, 12])),
      gP(49.75, 399.5, 16.5, 21, gImg('assets/figma/v/f88bf1acb4da04.svg')),
      gP(55, 411.5, 6.008, 6, gImg('assets/figma/v/f943396fb20219.svg')),
      gP(90, 393.5, 111, 17, gText('Téléphone vérifié', 13.5, Color(0xFF111015), weight: 600)),
      gP(90, 413, 93, 14, gText('+237 6•• •• •• 42', 11.5, Color(0xFF66636E))),
      gP(323, 399, 22, 22, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(327, 404, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(24, 466.5, 153, 19, gText('Appareils et sessions', 15, Color(0xFF111015), weight: 700)),
      gP(322, 468, 44, 16, gText('2 actifs', 12.5, Color(0xFF66636E), weight: 500, align: TextAlign.right)),
      gP(24, 496, 342, 126, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 512, 36, 36, gBox(color: Color(0xFFF1EEFB), radii: [12, 12, 12, 12])),
      gP(49.75, 519.5, 16.5, 21, gImg('assets/figma/v/f88bf1acb4da04.svg')),
      gP(55, 531.5, 6.008, 6, gImg('assets/figma/v/f943396fb20219.svg')),
      gP(90, 512.5, 155, 17, gText('iPhone 14 • Cet appareil', 13.5, Color(0xFF111015), weight: 600)),
      gP(90, 533, 210, 14, gText('Douala, Cameroun • Active maintenant', 11.5, Color(0xFF66636E))),
      gP(341, 525, 10, 10, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(40, 561, 306, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 574, 36, 36, gBox(color: Color(0xFFF1EEFB), radii: [12, 12, 12, 12])),
      gP(48.25, 583, 19.5, 15, gImg('assets/figma/v/7ac1a80ccd1523.svg')),
      gP(47.5, 595, 21, 6, gImg('assets/figma/v/dd90762ca86114.svg')),
      gP(90, 574.5, 127, 17, gText('Chrome • Windows', 13.5, Color(0xFF111015), weight: 600)),
      gP(90, 595, 181, 14, gText('Yaoundé, Cameroun • Il y a 2 jours', 11.5, Color(0xFF66636E))),
      gP(276, 585, 74, 14, gText('Déconnecter', 11.5, Color(0xFFE5484D), weight: 600, align: TextAlign.right)),
      gP(24, 644, 342, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE5484D), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Se déconnecter de tous les appareils')),
      gP(62, 661.5, 266, 19, gText('Se déconnecter de tous les appareils', 15, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(125, 889, 140, 4, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 812, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 833.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 845.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 833.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 832.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 839.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 846.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 833.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 841.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 818, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 833, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 831.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
