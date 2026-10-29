// GÉNÉRÉ par tool/figma_export/convert.py — écran 171 (nœud Figma 61:47). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_171 extends ConsumerWidget {
  const G_171({super.key});

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
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 187, 26, gText('Paiement sécurisé', 21, Color(0xFF111015), weight: 700)),
      gP(22.5, 270, 345, 24, gText('Vérifiez avant de payer', 19, Color(0xFF111015), weight: 800, align: TextAlign.center, wrap: true)),
      gP(42.5, 302, 305, 38, gText('Ce vendeur demande un paiement en dehors de Boutik-École.', 13, Color(0xFF66636E), lh: 19, align: TextAlign.center, wrap: true)),
      gP(24, 374, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 397.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 403.416, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 409.083, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 388, 277, 51, gText('Ne communiquez jamais votre code secret et ne payez qu’au numéro marchand officiel affiché dans l’application.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(24, 467, 342, 154, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 481, 92, 18, gText('Comparaison', 14, Color(0xFF111015), weight: 700)),
      gP(40, 515, 91, 16, gText('Numéro officiel', 12.5, Color(0xFF66636E))),
      gP(268, 515, 82, 16, gText('6 9X XX XX XX', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 540, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 549, 193, 16, gText('Numéro demandé par le vendeur', 12.5, Color(0xFF66636E))),
      gP(270, 549, 80, 16, gText('6 7X XX XX XX', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 574, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 583, 37, 16, gText('Statut', 12.5, Color(0xFF66636E))),
      gP(273, 583, 77, 16, gText('Non reconnu', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Annuler le paiement')),
      gP(36.5, 778, 138, 18, gText('Annuler le paiement', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Continuer en sécurité')),
      gP(209.5, 778, 150, 18, gText('Continuer en sécurité', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(167.867, 154.433, 67.467, 84.333, gImg('assets/figma/r/173_26.png')),
      gP(198.6, 176.733, 6.042, 39.733, gImg('assets/figma/v/0d7d3f9c852d67.svg')),
    ]);
  }
}
