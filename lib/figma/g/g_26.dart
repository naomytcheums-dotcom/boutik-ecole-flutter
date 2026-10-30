// GÉNÉRÉ par tool/figma_export/convert.py — écran 26 (nœud Figma 29:432). Ne pas éditer à la main.
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

class G_26 extends ConsumerWidget {
  const G_26({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(21.858, 69.291, 20.708, 20.708, const SizedBox.expand(), tap: () => gBack(context)),
      gP(23.173, 70.605, 12.04, 18.08, gImg('assets/figma/v/d05cf247dc0965.svg')),
      gP(23.173, 76.645, 18.08, 6, gImg('assets/figma/v/e039016b8fa2b9.svg')),
      gP(60.973, 65.456, 209, 26, gText('Comparer des offres', 20.708, Color(0xFF111015), weight: 700)),
      gP(348.584, 70.461, 19.558, 19.558, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(348.029, 69.905, 19.038, 19.038, gImg('assets/figma/v/24ff960311e305.svg')),
      gP(359.193, 81.069, 9.504, 9.504, gImg('assets/figma/v/a93d084de4cf49.svg')),
      gP(194.425, 136.704, 0.575, 219.915, gBox(color: Color(0xFFF2EFF6))),
      gP(31.637, 137.113, 127.699, 131.726, gBox(image: 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', fit: BoxFit.cover, radii: [12.655, 12.655, 12.655, 12.655])),
      gP(228.363, 137.113, 127.124, 131.726, gBox(image: 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', fit: BoxFit.cover, radii: [12.655, 12.655, 12.655, 12.655])),
      gP(169.115, 239.183, 50.619, 50.619, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x26122640), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], oval: true)),
      gP(182.425, 253.493, 24, 22, gText('VS', 17.257, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(32.212, 293.438, 112, 17, gText('Sac à dos design', 13.805, Color(0xFF111015), weight: 700)),
      gP(32.212, 315.024, 95, 19, gText('25 000 FCFA', 14.956, Color(0xFF111015), weight: 600)),
      gP(32.212, 340.299, 79, 16, gText('Design – MMI', 12.655, Color(0xFF5A3FE0))),
      gP(235.265, 293.438, 71, 17, gText('Sac urbain', 13.805, Color(0xFF111015), weight: 700)),
      gP(235.265, 315.024, 94, 19, gText('32 000 FCFA', 14.956, Color(0xFF111015), weight: 600)),
      gP(235.265, 340.299, 79, 16, gText('Design – MMI', 12.655, Color(0xFF5A3FE0))),
      gP(32.212, 418.255, 59, 17, gText('Matériau', 13.805, Color(0xFF111015), weight: 600)),
      gP(146.106, 418.255, 80, 17, gText('Tissu recyclé', 13.23, Color(0xFF4A4854))),
      gP(263.451, 418.255, 103, 17, gText('Cuir synthétique', 13.23, Color(0xFF4A4854))),
      gP(32.212, 453.501, 325.575, 0.594, gBox(color: Color(0xFFF2EFF6))),
      gP(32.212, 472.342, 62, 17, gText('Capacité', 13.805, Color(0xFF111015), weight: 600)),
      gP(146.106, 472.342, 27, 17, gText('20 L', 13.23, Color(0xFF4A4854))),
      gP(263.451, 472.342, 26, 17, gText('25 L', 13.23, Color(0xFF4A4854))),
      gP(32.212, 507.589, 325.575, 0.594, gBox(color: Color(0xFFF2EFF6))),
      gP(32.212, 527.618, 60, 17, gText('Couleurs', 13.805, Color(0xFF111015), weight: 600)),
      gP(32.212, 562.865, 325.575, 0.594, gBox(color: Color(0xFFF2EFF6))),
      gP(32.212, 584.083, 58, 17, gText('Garantie', 13.805, Color(0xFF111015), weight: 600)),
      gP(146.106, 584.083, 41, 17, gText('6 mois', 13.23, Color(0xFF4A4854))),
      gP(263.451, 584.083, 23, 17, gText('1 an', 13.23, Color(0xFF4A4854))),
      gP(32.212, 619.33, 325.575, 0.594, gBox(color: Color(0xFFF2EFF6))),
      gP(32.212, 642.331, 59, 17, gText('Livraison', 13.805, Color(0xFF111015), weight: 600)),
      gP(146.106, 642.331, 57, 17, gText('2-5 jours', 13.23, Color(0xFF4A4854))),
      gP(263.451, 642.331, 57, 17, gText('2-5 jours', 13.23, Color(0xFF4A4854))),
      gP(146.681, 527.49, 17.257, 17.257, gBox(color: Color(0xFF2E8B7A), oval: true)),
      gP(170.265, 527.49, 17.257, 17.257, gBox(color: Color(0xFF111015), oval: true)),
      gP(193.85, 527.49, 17.257, 17.257, gBox(color: Color(0xFFE5533D), oval: true)),
      gP(264.027, 527.49, 17.257, 17.257, gBox(color: Color(0xFFB03AA8), oval: true)),
      gP(288.186, 527.49, 17.257, 17.257, gBox(color: Color(0xFF2F7BE5), oval: true)),
      gP(28.186, 726.315, 334.779, 51.115, gBox(color: Color(0xFF111015), radii: [25.31, 25.31, 25.31, 25.31]), tap: () => gOpen(context, '05')),
      gP(140.075, 741.873, 111, 20, gText('Voir les détails', 16.106, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(128.85, 832.113, 135.752, 2.972, gBox(color: Color(0xFF111015), radii: [1.726, 1.726, 1.726, 1.726])),
    ]);
  }
}
