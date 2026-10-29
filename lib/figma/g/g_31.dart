// GÉNÉRÉ par tool/figma_export/convert.py — écran 31 (nœud Figma 30:236). Ne pas éditer à la main.
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

class G_31 extends ConsumerWidget {
  const G_31({super.key});

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
      gP(26.304, 75.06, 17.198, 17.198, const SizedBox.expand(), tap: () => gBack(context)),
      gP(26.887, 75.643, 11.016, 16.032, gImg('assets/figma/v/e14a47f2cbe2a2.svg')),
      gP(26.887, 80.66, 16.032, 6, gImg('assets/figma/v/e46b4e5f2cf982.svg')),
      gP(61.712, 71.179, 155, 22, gText('Avis et évaluations', 17.198, Color(0xFF111015), weight: 700)),
      gP(28.327, 142.858, 59, 43, gText('4.8', 34.397, Color(0xFF111015), weight: 800)),
      gP(83.969, 153.3, 26, 31, gText('/5', 24.28, Color(0xFF66636E))),
      gP(33.926, 202.634, 21.175, 20.432, gImg('assets/figma/v/f4c1ce0675c14d.svg')),
      gP(52.136, 202.634, 21.175, 20.432, gImg('assets/figma/v/f4c1ce0675c14d.svg')),
      gP(70.346, 202.634, 21.175, 20.432, gImg('assets/figma/v/f4c1ce0675c14d.svg')),
      gP(88.556, 202.634, 21.175, 20.432, gImg('assets/figma/v/f4c1ce0675c14d.svg')),
      gP(106.767, 202.634, 21.175, 20.432, gImg('assets/figma/v/f4c1ce0675c14d.svg')),
      gP(28.327, 241.998, 47, 15, gText('(24 avis)', 12.14, Color(0xFF66636E))),
      gP(162.374, 140.667, 0.506, 133.263, gBox(color: Color(0xFFF2EFF6))),
      gP(191.712, 136.868, 8, 15, gText('5', 12.14, Color(0xFF111015), weight: 600)),
      gP(204.224, 137.153, 14.431, 14.018, gImg('assets/figma/v/8504190087ab5c.svg')),
      gP(226.615, 139.186, 111.284, 10.365, gBox(color: Color(0xFFE9ECF1), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(226.615, 139.186, 65.759, 10.365, gBox(color: Color(0xFFF9B934), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(344.708, 138.868, 20, 11, gText('75%', 9.105, Color(0xFF66636E), align: TextAlign.right)),
      gP(191.712, 164.261, 8, 15, gText('4', 12.14, Color(0xFF111015), weight: 600)),
      gP(204.224, 164.546, 14.431, 14.018, gImg('assets/figma/v/8504190087ab5c.svg')),
      gP(226.615, 166.579, 111.284, 10.365, gBox(color: Color(0xFFE9ECF1), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(226.615, 166.579, 22.763, 10.365, gBox(color: Color(0xFFF9B934), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(346.708, 166.261, 18, 11, gText('15%', 9.105, Color(0xFF66636E), align: TextAlign.right)),
      gP(191.712, 191.654, 8, 15, gText('3', 12.14, Color(0xFF111015), weight: 600)),
      gP(204.224, 191.939, 14.431, 14.018, gImg('assets/figma/v/8504190087ab5c.svg')),
      gP(226.615, 193.972, 111.284, 10.365, gBox(color: Color(0xFFE9ECF1), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(226.615, 193.972, 9.105, 10.365, gBox(color: Color(0xFFF9B934), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(350.708, 193.654, 14, 11, gText('7%', 9.105, Color(0xFF66636E), align: TextAlign.right)),
      gP(191.712, 219.047, 8, 15, gText('2', 12.14, Color(0xFF111015), weight: 600)),
      gP(204.224, 219.332, 14.431, 14.018, gImg('assets/figma/v/8504190087ab5c.svg')),
      gP(226.615, 221.365, 111.284, 10.365, gBox(color: Color(0xFFE9ECF1), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(226.615, 221.365, 3.035, 10.365, gBox(color: Color(0xFFF9B934), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(349.708, 221.047, 15, 11, gText('3%', 9.105, Color(0xFF66636E), align: TextAlign.right)),
      gP(191.712, 246.44, 5, 15, gText('1', 12.14, Color(0xFF111015), weight: 600)),
      gP(204.224, 246.725, 14.431, 14.018, gImg('assets/figma/v/8504190087ab5c.svg')),
      gP(226.615, 248.758, 111.284, 10.365, gBox(color: Color(0xFFE9ECF1), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(226.615, 248.758, 2.023, 10.365, gBox(color: Color(0xFFF9B934), radii: [3.541, 3.541, 3.541, 3.541])),
      gP(348.708, 248.44, 16, 11, gText('0%', 9.105, Color(0xFF66636E), align: TextAlign.right)),
      gP(28.327, 324.898, 77, 18, gText('Avis clients', 14.163, Color(0xFF111015), weight: 700)),
      gP(27.315, 360.551, 337.393, 233.211, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(37.938, 378.816, 40.467, 40.467, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [20.233, 20.233, 20.233, 20.233])),
      gP(91.556, 377.223, 68, 17, gText('Aminata B.', 13.152, Color(0xFF111015), weight: 500)),
      gP(91.556, 404.395, 63, 13, gText('20 oct. 2026', 10.117, Color(0xFF66636E))),
      gP(330.817, 383.502, 22.257, 22.211, gBox(color: Color(0xFFFDF0D5), radii: [7.588, 7.588, 7.588, 7.588])),
      gP(333.446, 388.107, 17, 13, gText('5.0', 10.117, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(38.444, 438.998, 260, 43, gText('Produit de très bonne qualité ! Le design est\nvraiment original et bien fini.', 12.646, Color(0xFF4A4854), lh: 21.245)),
      gP(39.455, 516.102, 81.946, 54.63, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [9.105, 9.105, 9.105, 9.105])),
      gP(139.611, 516.102, 83.969, 54.63, gBox(image: 'assets/figma/img/752f5c71aed593a51d18b9662015d455f75b411b.png', fit: BoxFit.cover, radii: [9.105, 9.105, 9.105, 9.105])),
      gP(27.315, 614.491, 337.393, 140.667, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(37.938, 633.496, 40.467, 40.467, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [20.233, 20.233, 20.233, 20.233])),
      gP(91.556, 634.125, 62, 17, gText('Kouassi T.', 13.152, Color(0xFF111015), weight: 500)),
      gP(91.556, 659.816, 59, 13, gText('15 oct. 2026', 10.117, Color(0xFF66636E))),
      gP(330.817, 636.702, 22.257, 22.211, gBox(color: Color(0xFFFDF0D5), radii: [7.588, 7.588, 7.588, 7.588])),
      gP(332.946, 641.307, 18, 13, gText('4.0', 10.117, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(38.444, 694.419, 277, 43, gText('Très beau produit, mais la livraison a pris un peu\nplus de temps que prévu.', 12.646, Color(0xFF4A4854), lh: 21.245)),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
