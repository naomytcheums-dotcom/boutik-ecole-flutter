// GÉNÉRÉ par tool/figma_export/convert.py — écran 150-2 (nœud Figma 40:1018). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_150_2 extends ConsumerWidget {
  const G_150_2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF5F0E8), Color(0xFFEFE9F4), Color(0xFFF7E9DB)], stops: [0, 0.55, 1]), children: [
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
      gP(24, 70, 161, 26, gText('Session expirée', 21, Color(0xFF111015), weight: 700)),
      gP(22.5, 314, 345, 24, gText('Votre session a expiré', 19, Color(0xFF111015), weight: 800, align: TextAlign.center, wrap: true)),
      gP(42.5, 346, 305, 38, gText('Pour votre sécurité, veuillez vous reconnecter pour continuer.', 13, Color(0xFF66636E), lh: 19, align: TextAlign.center, wrap: true)),
      gP(54, 414, 282, 50, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [25, 25, 25, 25]), tap: () => gToast(context, 'Démonstration : Se reconnecter')),
      gP(141, 430, 108, 18, gText('Se reconnecter', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(24, 488, 154, 19, gText('Autres états système', 15, Color(0xFF111015), weight: 700)),
      gP(24, 526, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 539, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46, 549, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(45.5, 548.5, 19.333, 19.333, gImg('assets/figma/v/94aebfd05b72e8.svg')),
      gP(56.917, 559.917, 9.583, 9.583, gImg('assets/figma/v/8e33baf2fbbc49.svg')),
      gP(88, 538, 110, 17, gText('Page introuvable', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 560, 162, 14, gText('Erreur 404 · Le lien est invalide', 11.5, Color(0xFF66636E))),
      gP(88, 592, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 605, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 621.167, 21, 15.167, gImg('assets/figma/v/41aebd6adfdd32.svg')),
      gP(48.833, 613.667, 14.333, 13.5, gImg('assets/figma/v/b1facbf26d69c1.svg')),
      gP(88, 604, 85, 17, gText('Accès refusé', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 626, 162, 14, gText('Erreur 403 · Droits insuffisants', 11.5, Color(0xFF66636E))),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(163.65, 236.383, 75.9, 46.383, gImg('assets/figma/r/173_29.png')),
      gP(177.517, 195.433, 48.167, 43.95, gImg('assets/figma/v/642e331456d2e2.svg')),
    ]);
  }
}
