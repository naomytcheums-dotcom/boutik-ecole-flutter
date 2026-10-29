// GÉNÉRÉ par tool/figma_export/convert.py — écran 235 (nœud Figma 87:1385). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_235 extends ConsumerWidget {
  const G_235({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(0, 0, 390, 110, gBox(color: Color(0xFF111015))),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFFFFFFFF), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/5bc0bea2e7c30c.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/e67087fc64b6f1.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/fb4f69fd85c479.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/bc01d8c03d85a3.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/31720a2012fcda.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/59c083d0e217a4.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/59809e380aafb6.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/ee52ace3f9b23e.svg')),
      gP(19, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(20.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/ecea702ec10ecc.svg')),
      gP(20.583, 79, 18.833, 6, gImg('assets/figma/v/5578fefc9b3904.svg')),
      gP(54, 62, 40, 40, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(58, 66, 32, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(106, 66, 98, 19, gText('Boutik-École', 15, Color(0xFFFFFFFF), weight: 700)),
      gP(106, 87, 165, 14, gText('Compte professionnel · en ligne', 11, Color(0xBFFFFFFF))),
      gP(340, 72, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(338.667, 71.493, 21.84, 21.84, gImg('assets/figma/v/7a51bb41235e6d.svg')),
      gP(16, 130, 310, 68, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1A122640), offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(28, 140, 289, 38, gText('Pour démarrer la mission, payez le jalon 1 : 54 000 FCFA par Orange Money.', 13, Color(0xFF111111), lh: 19, wrap: true)),
      gP(286, 180, 30, 13, gText('09:40', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(16, 208, 310, 176, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(16, 208, 310, 48, gBox(color: Color(0xFFFFF3E6), radii: [14, 14, 14, 14])),
      gP(30, 223, 116, 16, gText('Paiement sécurisé', 13, Color(0xFF111015), weight: 800)),
      gP(291, 228.333, 18, 13.333, gImg('assets/figma/v/4b620eedcc4d0b.svg')),
      gP(293.667, 222.333, 12.667, 12, gImg('assets/figma/v/85f602a8445644.svg')),
      gP(30, 270, 46, 14, gText('Montant', 11.5, Color(0xFF66636E))),
      gP(30, 288, 140, 28, gText('54 000 FCFA', 22, Color(0xFF111015), weight: 800)),
      gP(30, 320, 126, 14, gText('Séquestre · jalon 1 sur 3', 11.5, Color(0xFF66636E), weight: 500)),
      gP(30, 342, 282, 32, gBox(color: Color(0xFFFF7900), radii: [16, 16, 16, 16])),
      gP(91, 349, 160, 16, gText('Payer avec Orange Money', 12.5, Color(0xFFFFFFFF), weight: 800, align: TextAlign.center)),
      gP(74, 398, 300, 49, gBox(color: Color(0xFFD9FDD3), shadows: [BoxShadow(color: Color(0x1A122640), offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0)], radii: [14, 14, 14, 14])),
      gP(86, 408, 279, 19, gText('Paiement effectué ✓', 13, Color(0xFF111111), lh: 19, wrap: true)),
      gP(335, 429, 29, 13, gText('09:42', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(16, 457, 310, 68, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1A122640), offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(28, 467, 289, 38, gText('Merci ! 54 000 FCFA reçus et bloqués en séquestre. Reçu : boutik-ecole.cm/r/8841', 13, Color(0xFF111111), lh: 19, wrap: true)),
      gP(287, 507, 29, 13, gText('09:42', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(10, 780, 300, 46, gBox(color: Color(0xFFFFFFFF), radii: [23, 23, 23, 23])),
      gP(10, 780, 300, 46, GField(hint: 'Message', size: 14, hintColor: Color(0xFF66636E), weight: 400, padL: 24)),
      gP(320, 780, 46, 46, gBox(color: Color(0xFF128C7E), oval: true)),
      gP(331.667, 791.667, 22.667, 22.667, gImg('assets/figma/v/37684f95055729.svg')),
      gP(339.167, 791.667, 15.167, 15.167, gImg('assets/figma/v/850ac0825ae325.svg')),
    ]);
  }
}
