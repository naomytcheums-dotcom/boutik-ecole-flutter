// GÉNÉRÉ par tool/figma_export/convert.py — écran 22b (nœud Figma 34:52). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_22b extends ConsumerWidget {
  const G_22b({super.key});

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
      gP(76, 70, 235, 26, gText('Services et prestations', 21, Color(0xFF111015), weight: 700)),
      gP(341, 71, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(340.75, 70.75, 20.667, 20.667, gImg('assets/figma/v/eeff0eb6fd6e24.svg')),
      gP(353.308, 83.308, 9.942, 9.942, gImg('assets/figma/v/34172806399cca.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 55.6, 34, 'Tous', 12.5, 600), GChip(87.6, 120, 70.4, 34, 'Design', 12.5, 500), GChip(166, 120, 122.2, 34, 'Développement', 12.5, 500), GChip(296.2, 120, 77.8, 34, 'Tutorat', 12.5, 500), GChip(382, 120, 107.4, 34, 'Audiovisuel', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 83, 19, gText('46 services', 15, Color(0xFF111015), weight: 700)),
      gP(325, 170, 25, 15, gText('Trier', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(352.5, 175, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(356, 171.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg')),
      gP(24, 206, 342, 330, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 214, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 218, 211, 17, gText('Développement web sur mesure', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 240, 168, 14, gText('À partir de 30 000 FCFA · 4.9 ★', 11.5, Color(0xFF66636E))),
      gP(336.75, 231.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 272, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 280, 50, 50, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 284, 155, 17, gText('Logo et identité visuelle', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 306, 164, 14, gText('À partir de 15 000 FCFA · 4.8 ★', 11.5, Color(0xFF66636E))),
      gP(336.75, 297.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 338, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 346, 50, 50, gBox(image: 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 350, 172, 17, gText('Montage vidéo et création', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 372, 165, 14, gText('À partir de 10 000 FCFA · 4.7 ★', 11.5, Color(0xFF66636E))),
      gP(336.75, 363.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 404, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 412, 50, 50, gBox(image: 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 416, 171, 17, gText('Cours de soutien en maths', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 438, 161, 14, gText('À partir de 5 000 FCFA · 5.0 ★', 11.5, Color(0xFF66636E))),
      gP(336.75, 429.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(98, 470, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 478, 50, 50, gBox(image: 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 482, 123, 17, gText('Application mobile', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 504, 169, 14, gText('À partir de 50 000 FCFA · 4.8 ★', 11.5, Color(0xFF66636E))),
      gP(336.75, 495.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(24, 550, 342, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(222.36, 550, 143.64, 132, gBox(image: 'assets/figma/img/cbf050b9f90ddf4164a56ebd171cee79dfa21141.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(195, 550, 68.4, 132, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF1B3F6E), Color(0x001B3F6E)], stops: [0, 1]))),
      gP(42, 566, 174, 20, gText('Un service sur mesure ?', 15, Color(0xFFFFFFFF), weight: 700, lh: 20, wrap: true)),
      gP(42, 612, 160.32, 30, gText('Décrivez votre besoin, les étudiants vous répondent.', 11, Color(0xFFE9E4F5), lh: 15, wrap: true)),
      gP(42, 642, 149, 28, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(63.5, 648, 106, 14, gText('Demander un devis', 11.5, Color(0xFF120F14), weight: 600, align: TextAlign.center)),
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
