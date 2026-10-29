// GÉNÉRÉ par tool/figma_export/convert.py — écran 219 (nœud Figma 87:222). Ne pas éditer à la main.
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

class G_219 extends ConsumerWidget {
  const G_219({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 891, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 144.03, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 616.26, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 140, 26, gText('Nouveau duel', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 120, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 128.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(25.5, 158, 37, 14, gText('Besoin', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(132.167, 158, 25, 14, gText('Duel', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(235.333, 158, 20, 14, gText('Prix', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(316, 158, 60, 14, gText('Lancement', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 77, 16, gText('Votre besoin', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 208, 342, 48, GField(hint: '', initial: 'Logo pour ma marque de parfums', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 225.25, 21, 16.5, gImg('assets/figma/v/ac757bdc89629a.svg')),
      gP(42, 222.25, 12, 19.5, gImg('assets/figma/v/cf16d6836ecbbe.svg')),
      gP(24, 270, 197, 19, gText('Combien de propositions ?', 15, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 308, 107.4, 34, '3 étudiants', 12.5, 600), GChip(139.4, 308, 107.4, 34, '5 étudiants', 12.5, 500), GChip(254.8, 308, 107.4, 34, '8 étudiants', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 356, 119, 16, gText('Prix pour le gagnant', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 376, 342, 48, GField(hint: '', initial: '60 000 FCFA', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 391, 9, 9.75, gImg('assets/figma/v/d3a1b40bd4dbe5.svg')),
      gP(49.5, 391, 9, 9.75, gImg('assets/figma/v/d53c036a672d8b.svg')),
      gP(39, 404.5, 18, 6, gImg('assets/figma/v/7317aca1f3cfd0.svg')),
      gP(40.5, 389.5, 15, 15.75, gImg('assets/figma/v/8b173b41fcfba8.svg')),
      gP(24, 438, 83, 16, gText('Durée du duel', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 458, 342, 48, GField(hint: '', initial: '48 h', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 471.5, 21, 21, gImg('assets/figma/v/8283e962773df2.svg')),
      gP(45, 474.5, 9, 12, gImg('assets/figma/v/ed425c4c4b79bb.svg')),
      gP(334.5, 476.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(40, 534, 65, 18, gText('Paiement', 14, Color(0xFF111015), weight: 700)),
      gP(40, 568, 91, 16, gText('Prix du gagnant', 12.5, Color(0xFF66636E))),
      gP(270, 568, 80, 16, gText('60 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 593, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 602, 184, 16, gText('Prime de participation (chacun)', 12.5, Color(0xFF66636E))),
      gP(278, 602, 72, 16, gText('5 000 FCFA', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 627, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 636, 153, 16, gText('Total bloqué en séquestre', 12.5, Color(0xFF66636E))),
      gP(272, 636, 78, 16, gText('75 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(36, 711.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 717.443, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 723.083, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 702, 277, 51, gText('Le duel est modéré par l’administrateur ; seuls des étudiants qualifiés de la filière peuvent participer.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 791, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 807, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Lancer le duel')),
      gP(147, 825, 96, 18, gText('Lancer le duel', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 877, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
