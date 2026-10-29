// GÉNÉRÉ par tool/figma_export/convert.py — écran 162 (nœud Figma 60:906). Ne pas éditer à la main.
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

class G_162 extends ConsumerWidget {
  const G_162({super.key});

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
      gP(76, 70, 110, 26, gText('Inscription', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 120, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 128.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(30, 158, 28, 14, gText('Profil', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(125.667, 158, 38, 14, gText('Équipe', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(229.333, 158, 32, 14, gText('Projet', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(319.5, 158, 53, 14, gText('Validation', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 224, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(73.5, 198, 72, 16, gText('Individuelle', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(249, 198, 63, 16, gText('En équipe', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(220.65, 222, 119.7, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(24, 242, 99, 16, gText('Nom de l’équipe', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 262, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 262, 342, 48, GField(hint: '', initial: 'Team Innov’', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 285.25, 16.5, 10.5, gImg('assets/figma/v/9554e493730083.svg')),
      gP(39.75, 276.25, 12, 12, gImg('assets/figma/v/843504f34e5472.svg')),
      gP(50.25, 285.347, 8.25, 10.403, gImg('assets/figma/v/9ea8fbb18d7cc6.svg')),
      gP(48, 276.348, 8.256, 11.812, gImg('assets/figma/v/322707fcddf123.svg')),
      gP(24, 324, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 332, 50, 50, gBox(image: 'assets/figma/img/af86f2e539ad8f1844ccfbe19576723186ea4d78.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 336, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 358, 150, 14, gText('Capitaine · Développement', 11.5, Color(0xFF66636E))),
      gP(306.4, 346, 45.6, 22, gBox(color: Color(0xFFE1E7F0), radii: [11, 11, 11, 11])),
      gP(315.7, 350, 27, 14, gText('Vous', 11, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(98, 390, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 398, 50, 50, gBox(image: 'assets/figma/img/30bc9584eb2f9c6775e8e9cd07fa63239d9b4cc8.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 402, 102, 17, gText('Brice Ndoumbe', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 424, 129, 14, gText('IoT · Invitation acceptée', 11.5, Color(0xFF66636E))),
      gP(280.8, 412, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(291.4, 416, 50, 14, gText('Confirmé', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(98, 456, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 464, 50, 50, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 468, 90, 17, gText('Aminata Bello', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 490, 138, 14, gText('UI/UX · Invitation envoyée', 11.5, Color(0xFF66636E))),
      gP(268, 478, 84, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(282.5, 482, 55, 14, gText('En attente', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 536, 72, 16, gText('Thématique', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 556, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 556, 342, 48, GField(hint: '', initial: 'Inclusion financière', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(40.5, 569.5, 15, 15, gImg('assets/figma/v/a49ecdd3bef596.svg')),
      gP(42.75, 581.5, 10.5, 6, gImg('assets/figma/v/2e2c4a27235860.svg')),
      gP(43.5, 584.5, 9, 6, gImg('assets/figma/v/ab681c73d5c7eb.svg')),
      gP(334.5, 574.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 618, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 621.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(54, 619, 315, 18, gText('J’accepte le règlement du concours.', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Retour')),
      gP(82, 778, 47, 18, gText('Retour', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Valider l’inscription')),
      gP(217.5, 778, 134, 18, gText('Valider l’inscription', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
