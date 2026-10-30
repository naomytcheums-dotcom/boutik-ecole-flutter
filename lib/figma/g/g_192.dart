// GÉNÉRÉ par tool/figma_export/convert.py — écran 192 (nœud Figma 83:86). Ne pas éditer à la main.
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

class G_192 extends ConsumerWidget {
  const G_192({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 902, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 147.66, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 625.72, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 115, 26, gText('Votre devis', 21, Color(0xFF111015), weight: 700)),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 145.833, 22.667, 17.667, gImg('assets/figma/v/0b1915710c6b88.svg')),
      gP(49.667, 142.5, 12.667, 21, gImg('assets/figma/v/baf18a4f525e16.svg')),
      gP(88, 132, 157, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(missionProvider).kind, 13.5, Color(0xFF111015), weight: 600))),
      gP(88, 154, 166, 14, Consumer(builder: (context, ref, _) => gText('Brief ${ref.watch(missionProvider).id} · reçu le ${ref.watch(missionProvider).date}', 11.5, Color(0xFF66636E)))),
      gP(268, 142, 84, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(283, 146, 54, 14, gText('Devis prêt', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 200, 148, 19, gText('Étapes de validation', 15, Color(0xFF111015), weight: 700)),
      gP(33, 260, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 239, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 243.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 238, 175, 17, gText('Brief reçu', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 258, 175, 14, gText('12 oct. · 09:14', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 322, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 301, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 305.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 300, 175, 34, gText('Analysé par l’administrateur', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 320, 175, 14, gText('12 oct. · 11:40', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 384, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 363, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 367.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 362, 175, 34, gText('Équipe qualifiée sélectionnée', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 382, 175, 14, gText('13 oct. · MMI + TCO', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 425, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 424, 175, 17, gText('Devis envoyé', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 444, 175, 14, gText('14 oct. · à valider', 11.5, Color(0xFF66636E), wrap: true)),
      gP(40, 514, 38, 18, gText('Devis', 14, Color(0xFF111015), weight: 700)),
      gP(40, 548, 53, 16, gText('Livrables', 12.5, Color(0xFF66636E))),
      gP(191, 548, 159, 16, gText('Logo, charte, déclinaisons', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 573, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 582, 30, 16, gText('Délai', 12.5, Color(0xFF66636E))),
      gP(283, 582, 67, 16, gText('6 semaines', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 607, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 616, 43, 16, gText('Équipe', 12.5, Color(0xFF66636E))),
      gP(201, 616, 149, 16, gText('3 étudiants + 1 encadreur', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 641, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 650, 29, 16, gText('Total', 12.5, Color(0xFF66636E))),
      gP(124, 650, 226, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(missionProvider).total), 12.5, Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right))),
      gP(24, 702, 108.667, 76, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(140.667, 702, 108.667, 76, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(257.333, 702, 108.667, 76, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(0, 802, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 818, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27])),
      gP(38.5, 836, 134, 18, gText('Poser une question', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 818, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(224, 836, 121, 18, gText('Accepter le devis', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 888, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(203, 818, 163, 54, () { acceptQuote(ref, context); }),
      gTap(24, 818, 163, 54, () { gToast(context, 'Question envoyée à l’administrateur'); }),
      gTap(32, 506, 54, 34, () { gOpen(context, '190'); }), // parcours 192 -> 190
    ]);
  }
}
