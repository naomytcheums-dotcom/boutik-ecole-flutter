// GÉNÉRÉ par tool/figma_export/convert.py — écran 158 (nœud Figma 60:651). Ne pas éditer à la main.
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

class G_158 extends ConsumerWidget {
  const G_158({super.key});

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
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 231, 26, gText('Candidatures classées', 21, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 107.4, 34, 'Toutes (23)', 12.5, 500), GChip(139.4, 120, 151.8, 34, 'Très adaptées (6)', 12.5, 600), GChip(299.2, 120, 129.6, 34, 'À relancer (4)', 12.5, 500)], selected: 1, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(36, 176, 50, 50, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 180, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 202, 166, 14, gText('React, Python · Portfolio vérifié', 11.5, Color(0xFF66636E))),
      gP(306.4, 190, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(315.7, 194, 27, 14, gText('96 %', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 234, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 242, 50, 50, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 246, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 268, 129, 14, gText('UI/UX · Dossier complet', 11.5, Color(0xFF66636E))),
      gP(306.4, 256, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(315.7, 260, 27, 14, gText('93 %', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 300, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 308, 50, 50, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 312, 102, 17, gText('Brice Ndoumbe', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 334, 133, 14, gText('IoT · Certificat manquant', 11.5, Color(0xFF66636E))),
      gP(306.4, 322, 45.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(315.7, 326, 27, 14, gText('85 %', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(98, 366, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 374, 50, 50, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 378, 93, 17, gText('Kouassi Tagne', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 400, 169, 14, gText('Audiovisuel · Dossier incomplet', 11.5, Color(0xFF66636E))),
      gP(306.4, 388, 45.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(316.2, 392, 26, 14, gText('72 %', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 446, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 461, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.917, 466.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(49, 474, 6, 8.833, gImg('assets/figma/v/9fc27387b9ffa1.svg')),
      gP(49, 471.167, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(76, 460, 277, 34, gText('Le classement est une aide à la décision. La décision finale reste toujours humaine.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Comparer la sélection')),
      gP(118, 778, 154, 18, gText('Comparer la sélection', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
