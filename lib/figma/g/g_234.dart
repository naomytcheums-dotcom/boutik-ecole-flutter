// GÉNÉRÉ par tool/figma_export/convert.py — écran 234 (nœud Figma 87:1341). Ne pas éditer à la main.
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
import '../live/docs.dart';
import '../live/kela.dart';
import '../live/chat.dart';
import '../live/share.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_234 extends ConsumerWidget {
  const G_234({super.key});

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
      gP(340, 72, 20, 20, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(338.667, 71.493, 21.84, 21.84, gImg('assets/figma/v/7a51bb41235e6d.svg')),
      gP(28, 140, 289, 38, gText('Le jalon 2 « Propositions de logo » est terminé. Montant à libérer : 72 000 FCFA.', 13, Color(0xFF111111), lh: 19, wrap: true)),
      gP(288, 180, 28, 13, gText('10:20', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(24, 216, 294, 84, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(30, 308, 134, 16, gText('Jalon 2 · 72 000 FCFA', 13, Color(0xFF111015), weight: 800)),
      gP(30, 330, 167, 14, gText('Paiement bloqué en séquestre', 11.5, Color(0xFF66636E))),
      gP(16, 372, 310, 40, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20]), tap: () => gToast(context, 'Démonstration : ✓  Valider et libérer')),
      gP(111.5, 383, 119, 16, gText('✓  Valider et libérer', 13, Color(0xFF128C7E), weight: 700, align: TextAlign.center)),
      gP(16, 418, 310, 40, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20]), tap: () => gToast(context, 'Démonstration : Demander une correction')),
      gP(90, 429, 162, 16, gText('Demander une correction', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(74, 476, 300, 49, gBox(color: Color(0xFFD9FDD3), shadows: [BoxShadow(color: Color(0x1A122640), offset: Offset(0, 1), blurRadius: 2, spreadRadius: 0)], radii: [14, 14, 14, 14])),
      gP(86, 486, 279, 19, gText('✓ Valider et libérer', 13, Color(0xFF111111), lh: 19, wrap: true)),
      gP(340, 507, 24, 13, gText('10:21', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(28, 545, 289, 38, gText('Merci ! 72 000 FCFA libérés. Le jalon 3 (livraison finale) démarre.', 13, Color(0xFF111111), lh: 19, wrap: true)),
      gP(292, 585, 24, 13, gText('10:21', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(10, 780, 300, 46, GField(hint: 'Message', size: 14, hintColor: Color(0xFF66636E), weight: 400, padL: 24)),
      gP(320, 780, 46, 46, gBox(color: Color(0xFF128C7E), oval: true)),
      gP(331.667, 791.667, 22.667, 22.667, gImg('assets/figma/v/37684f95055729.svg')),
      gP(339.167, 791.667, 15.167, 15.167, gImg('assets/figma/v/850ac0825ae325.svg')),
    ]);
  }
}
