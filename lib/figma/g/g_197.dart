// GÉNÉRÉ par tool/figma_export/convert.py — écran 197 (nœud Figma 83:411). Ne pas éditer à la main.
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
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_197 extends ConsumerWidget {
  const G_197({super.key});

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
      gP(76, 70, 163, 26, Consumer(builder: (context, ref, _) => gText('Valider le jalon ${ref.watch(missionProvider).released + 1}', 21, Color(0xFF111015), weight: 700))),
      gP(24, 120, 342, 160, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 120, 342, 160, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 218, 309, 23, gText('Propositions de logo', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 248, 309, 15, gText('Envoyé par l’équipe aujourd’hui', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(24, 294, 108.667, 84, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 294, 108.667, 84, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 294, 108.667, 84, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(40, 406, 157, 18, gText('Libération du paiement', 14, Color(0xFF111015), weight: 700)),
      gP(40, 440, 31, 16, gText('Jalon', 12.5, Color(0xFF66636E))),
      gP(172, 440, 178, 16, Consumer(builder: (context, ref, _) => gText('${(ref.watch(missionProvider).released + 1).clamp(1, 3)} sur 3', 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(40, 465, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 474, 99, 16, gText('Montant à libérer', 12.5, Color(0xFF66636E))),
      gP(132, 474, 218, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(missionProvider).amountOf(ref.watch(missionProvider).released)), 12.5, Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right))),
      gP(40, 499, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 508, 123, 16, gText('Part étudiants (70 %)', 12.5, Color(0xFF66636E))),
      gP(130, 508, 220, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(missionProvider).amountOf(ref.watch(missionProvider).released) * 70 ~/ 100), 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(40, 533, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 542, 142, 16, gText('Fonds innovation (20 %)', 12.5, Color(0xFF66636E))),
      gP(134, 542, 216, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(missionProvider).amountOf(ref.watch(missionProvider).released) * 20 ~/ 100), 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(40, 567, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 576, 104, 16, gText('Plateforme (10 %)', 12.5, Color(0xFF66636E))),
      gP(141, 576, 209, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(missionProvider).amountOf(ref.watch(missionProvider).released) * 10 ~/ 100), 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(36, 651.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 657.443, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 663.083, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 642, 277, 51, gText('Vous pouvez demander une correction : le paiement reste bloqué tant que vous n’avez pas validé.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27])),
      gP(16, 778, 179, 18, gText('Demander une correction', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Valider et libérer')),
      gP(227.5, 778, 114, 18, gText('Valider et libérer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(203, 760, 163, 54, () { releaseMilestone(ref, context); }),
      gTap(24, 760, 163, 54, () { askCorrection(ref, context); }),
    ]);
  }
}
