// GÉNÉRÉ par tool/figma_export/convert.py — écran 203 (nœud Figma 83:609). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_203 extends ConsumerWidget {
  const G_203({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 890, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 143.7, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 615.4, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 190, 26, gText('Mes compétences', 21, Color(0xFF111015), weight: 700)),
      gP(68.5, 134, 25, 25, gText('82', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(46, 164, 70, 14, gText('Score global', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(184.5, 134, 21, 25, gText('18', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(162, 164, 66, 14, gText('Réalisations', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 134, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(292, 134, 34, 25, gText('4,9', 20, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(298, 164, 22, 14, gText('Avis', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 134, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 210, 142, 19, gText('Domaines maîtrisés', 15, Color(0xFF111015), weight: 700)),
      gP(40, 262, 95, 16, gText('Identité visuelle', 12.5, Color(0xFF111015), weight: 600)),
      gP(335, 262, 15, 15, gText('92', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 284, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 284, 285.2, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(40, 306, 154, 16, gText('Community management', 12.5, Color(0xFF111015), weight: 600)),
      gP(335, 306, 15, 15, gText('78', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 328, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 328, 241.8, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 350, 36, 16, gText('Vidéo', 12.5, Color(0xFF111015), weight: 600)),
      gP(335, 350, 15, 15, gText('64', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 372, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 372, 198.4, 7, gBox(color: Color(0xFF2F5D8A), radii: [4, 4, 4, 4])),
      gP(40, 394, 63, 16, gText('Rédaction', 12.5, Color(0xFF111015), weight: 600)),
      gP(335, 394, 15, 15, gText('55', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 416, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 416, 170.5, 7, gBox(color: Color(0xFF8FB4E8), radii: [4, 4, 4, 4])),
      gP(24, 454, 143, 19, gText('Pourquoi ce score ?', 15, Color(0xFF111015), weight: 700)),
      gP(36, 505, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(48, 513.667, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(48.833, 522.75, 14.333, 13.583, gImg('assets/figma/v/b22a24959a2f97.svg')),
      gP(88, 504, 111, 17, gText('Preuves vérifiées', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 526, 129, 14, gText('12 réalisations certifiées', 11.5, Color(0xFF66636E))),
      gP(312.8, 514, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(321.4, 518, 22, 14, gText('+30', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 558, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 571, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 579.667, 22.667, 21.917, gImg('assets/figma/v/0f00cc0c2b77d5.svg')),
      gP(88, 570, 99, 17, gText('Avis des clients', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 592, 78, 14, gText('38 avis · 4,9 / 5', 11.5, Color(0xFF66636E))),
      gP(312.8, 580, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(321.9, 584, 21, 14, gText('+24', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 624, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 637, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 645.667, 22.667, 22.667, gImg('assets/figma/v/fea5b000abca5c.svg')),
      gP(53, 649, 9.333, 12.667, gImg('assets/figma/v/abb8a0dfdd76de.svg')),
      gP(88, 636, 123, 17, gText('Respect des délais', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 658, 111, 14, gText('96 % dans les temps', 11.5, Color(0xFF66636E))),
      gP(312.8, 646, 39.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(322.9, 650, 19, 14, gText('+18', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 704, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 719, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.979, 724.917, 18.042, 17.688, gImg('assets/figma/v/e9085cf2b599c2.svg')),
      gP(76, 718, 277, 34, gText('Ce score aide l’administrateur à attribuer les besoins aux étudiants les plus qualifiés.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 878, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 802, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 823.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 823.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 835.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 823.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 823.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 823.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 822.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 829.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 836.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 823.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 823.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 831.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 808, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 823, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 821.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
