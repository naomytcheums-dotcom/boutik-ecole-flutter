// GÉNÉRÉ par tool/figma_export/convert.py — écran 193 (nœud Figma 83:154). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_193 extends ConsumerWidget {
  const G_193({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 913, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 151.29, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 635.18, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 187, 26, gText('Paiement sécurisé', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 154, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 134, 88, 18, gText('Récapitulatif', 14, Color(0xFF111015), weight: 700)),
      gP(40, 168, 45, 16, gText('Mission', 12.5, Color(0xFF66636E))),
      gP(255, 168, 95, 16, gText('Identité visuelle', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 193, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 202, 29, 16, gText('Total', 12.5, Color(0xFF66636E))),
      gP(264, 202, 86, 16, gText('180 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 227, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 236, 133, 16, gText('Frais plateforme inclus', 12.5, Color(0xFF66636E))),
      gP(273, 236, 77, 16, gText('18 000 FCFA', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 288, 126, 19, gText('Réparti par jalons', 15, Color(0xFF111015), weight: 700)),
      gP(33, 348, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 327, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 326, 175, 17, gText('Jalon 1 · Brief validé', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 346, 175, 14, gText('30 % · 54 000 FCFA', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 410, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 389, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 388, 175, 17, gText('Jalon 2 · Propositions', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 408, 175, 14, gText('40 % · 72 000 FCFA', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 451, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 450, 175, 17, gText('Jalon 3 · Livraison finale', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 470, 175, 14, gText('30 % · 54 000 FCFA', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 526, 145, 19, gText('Moyen de paiement', 15, Color(0xFF111015), weight: 700)),
      gP(24, 564, 342, 132, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 577, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 586.5, 21.833, 16.833, gImg('assets/figma/v/9c1483ca7848e1.svg')),
      gP(45.5, 588.167, 21, 19.333, gImg('assets/figma/v/f6a87a84fa91d7.svg')),
      gP(88, 576, 97, 17, gText('Orange Money', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 598, 109, 14, gText('Paiement marchand', 11.5, Color(0xFF66636E))),
      gP(293.6, 586, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(305.8, 590, 34, 14, gText('Choisi', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 630, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 643, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 652.5, 21.833, 16.833, gImg('assets/figma/v/9c1483ca7848e1.svg')),
      gP(45.5, 654.167, 21, 19.333, gImg('assets/figma/v/f6a87a84fa91d7.svg')),
      gP(88, 642, 73, 17, gText('MTN MoMo', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 664, 109, 14, gText('Paiement marchand', 11.5, Color(0xFF66636E))),
      gP(336.75, 655.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 710, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 733.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 745.792, 18.75, 13.792, gImg('assets/figma/v/98eafa7aa487dc.svg')),
      gP(45.458, 739.417, 13.083, 12.375, gImg('assets/figma/v/cbd17bba51f32b.svg')),
      gP(76, 724, 277, 51, gText('L’argent est bloqué par Boutik-École et versé aux étudiants uniquement après votre validation de chaque jalon.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 813, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 829, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Payer 54 000 FCFA')),
      gP(128, 847, 134, 18, gText('Payer 54 000 FCFA', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 899, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
