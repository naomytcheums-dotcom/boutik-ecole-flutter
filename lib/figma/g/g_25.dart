// GÉNÉRÉ par tool/figma_export/convert.py — écran 25 (nœud Figma 29:347). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_25 extends ConsumerWidget {
  const G_25({super.key});

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
      gP(21.447, 70.675, 20.318, 20.318, const SizedBox.expand(), tap: () => gBack(context)),
      gP(22.68, 71.908, 11.926, 17.852, gImg('assets/figma/v/bed4925108d4f6.svg')),
      gP(22.68, 77.834, 17.852, 6, gImg('assets/figma/v/0093241f24fab2.svg')),
      gP(59.826, 66.834, 125, 28, gText('Mes favoris', 22.576, Color(0xFF111015), weight: 700)),
      gP(347.106, 70.675, 20.318, 20.318, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(346.645, 70.214, 19.546, 19.546, gImg('assets/figma/v/eaac3155ede28a.svg')),
      gP(358.244, 81.813, 9.64, 9.64, gImg('assets/figma/v/3c4d7466583ca9.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(21.447, 120.062, 56.44, 34.473, 'Tous', 15.239, 600), GChip(88.046, 120.062, 67.728, 34.473, 'Produits', 14.674, 500), GChip(165.933, 120.062, 68.857, 34.473, 'Services', 14.674, 500), GChip(246.078, 120.062, 65.47, 34.473, 'Talents', 14.674, 500), GChip(321.708, 120.062, 65.47, 34.473, 'Projets', 14.674, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 16.368)),
      gP(24.834, 179.499, 156, 124.817, gBox(image: 'assets/figma/img/209b06d9669544abc2d1f3eb45ceb34026db6495.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(196.834, 194.273, 105, 16, gText('Sac à dos design', 12.981, Color(0xFF111015), weight: 700)),
      gP(196.834, 219.237, 89, 18, gText('25 000 FCFA', 14.11, Color(0xFF111015), weight: 600)),
      gP(196.834, 245.794, 81, 16, gText('Design – MMI', 12.981, Color(0xFF5A3FE0))),
      gP(344.505, 194.095, 21.051, 19.546, gImg('assets/figma/v/f3ae776e2293c9.svg')),
      gP(338, 186.837, 34.061, 34.061, GHeart()),
      gP(349.326, 242.341, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(24.834, 317.986, 156, 126.006, gBox(image: 'assets/figma/img/97b7907df36c390ae2383cc290f76358e22d2d7a.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(196.834, 332.761, 147, 16, gText('Logo & identité visuelle', 12.981, Color(0xFF111015), weight: 700)),
      gP(196.834, 357.724, 86, 18, gText('15 000 FCFA', 14.11, Color(0xFF111015), weight: 600)),
      gP(196.834, 384.282, 108, 16, gText('Graphisme – TCO', 12.981, Color(0xFF5A3FE0))),
      gP(344.505, 332.582, 21.051, 19.546, gImg('assets/figma/v/f3ae776e2293c9.svg')),
      gP(338, 325.325, 34.061, 34.061, GHeart()),
      gP(349.326, 380.828, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(24.834, 457.662, 156, 126.6, gBox(image: 'assets/figma/img/8397f0465c777ec9d53e7683ddc72818ff961acd.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(196.834, 472.437, 166, 16, gText('Cours de soutien en maths', 12.981, Color(0xFF111015), weight: 700)),
      gP(196.834, 497.4, 88, 18, gText('10 000 FCFA', 14.11, Color(0xFF111015), weight: 600)),
      gP(196.834, 523.958, 80, 16, gText('Tutorat – Info', 12.981, Color(0xFF5A3FE0))),
      gP(344.505, 472.258, 21.051, 19.546, gImg('assets/figma/v/f3ae776e2293c9.svg')),
      gP(338, 465.001, 34.061, 34.061, GHeart()),
      gP(349.326, 520.504, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(24.834, 597.338, 156, 126.6, gBox(image: 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(196.834, 612.113, 95, 16, gText('Drone éducatif', 12.981, Color(0xFF111015), weight: 700)),
      gP(196.834, 637.076, 96, 18, gText('150 000 FCFA', 14.11, Color(0xFF111015), weight: 600)),
      gP(196.834, 663.634, 110, 16, gText('Électronique – GE', 12.981, Color(0xFF5A3FE0))),
      gP(344.505, 611.934, 21.051, 19.546, gImg('assets/figma/v/f3ae776e2293c9.svg')),
      gP(338, 604.677, 34.061, 34.061, GHeart()),
      gP(349.326, 660.18, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
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
