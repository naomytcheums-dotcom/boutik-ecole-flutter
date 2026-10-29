// GÉNÉRÉ par tool/figma_export/convert.py — écran 252 (nœud Figma 154:171). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_252 extends ConsumerWidget {
  const G_252({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(109.5, 82, 171, 20, gText('Lampe en bois recyclé', 16, Color(0xFF111015), weight: 500)),
      gP(156.5, 102, 77, 14, gText('par Yannick M.', 11.5, Color(0xFF66636E))),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(334.065, 82.611, 7.87, 7.87, gImg('assets/figma/v/9506a00c1513fb.svg')),
      gP(334.065, 88.065, 7.87, 7.87, gImg('assets/figma/v/e40a15d66d7ea5.svg')),
      gP(334.065, 93.519, 7.87, 7.87, gImg('assets/figma/v/007a7dbd4c5258.svg')),
      gP(24, 128, 64, 64, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(100, 134, 89, 18, gText('25 000 FCFA', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(100, 160, 130, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(112, 166, 106, 13, gText('Voir dans la boutique', 10.5, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 206, 342, 40, gBox(color: Color(0xB2FFFFFF), radii: [20, 20, 20, 20])),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(28, 210, 166, 32, 'Commentaires (31)', 11.5, 600), GChip(198, 210, 166, 32, 'Avis (12)', 11.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 16)),
      gP(24, 262, 50, 38, gText('4,8', 30, Color(0xFF111015), weight: 700)),
      gP(90.417, 268.417, 20.167, 19.458, gImg('assets/figma/v/4e395e86b249a2.svg')),
      gP(110.417, 268.417, 20.167, 19.458, gImg('assets/figma/v/4e395e86b249a2.svg')),
      gP(130.417, 268.417, 20.167, 19.458, gImg('assets/figma/v/4e395e86b249a2.svg')),
      gP(150.417, 268.417, 20.167, 19.458, gImg('assets/figma/v/4e395e86b249a2.svg')),
      gP(170.417, 268.417, 20.167, 19.458, gImg('assets/figma/v/4e395e86b249a2.svg')),
      gP(92, 292, 69, 13, gText('12 avis vérifiés', 10.5, Color(0xFF66636E))),
      gP(254, 272, 112, 26, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(266, 278, 88, 14, gText('Donner mon avis', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 326, 38, 38, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [19, 19, 19, 19])),
      gP(74, 327, 75, 16, gText('Mbella SARL', 12.5, Color(0xFF111015), weight: 600)),
      gP(163.2, 329, 14, 13, gText('2 h', 10, Color(0xFF66636E))),
      gP(74, 346, 253, 34, gText('Très belle finition, livrée à temps. Je recommande !', 12, Color(0xFF5B5963), lh: 17, wrap: true)),
      gP(338.75, 325.375, 18.5, 17.25, gImg('assets/figma/v/dbb07b49642bdc.svg')),
      gP(332.5, 318.5, 31, 31, GHeart()),
      gP(343, 348, 10, 12, gText('12', 9.5, Color(0xFF66636E), weight: 500)),
      gP(24, 410, 38, 38, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [19, 19, 19, 19])),
      gP(74, 411, 89, 16, gText('Carine Mbarga', 12.5, Color(0xFF111015), weight: 600)),
      gP(177.6, 413, 12, 13, gText('1 h', 10, Color(0xFF66636E))),
      gP(74, 430, 253, 17, gText('Magnifique. Tu fais aussi sur mesure ?', 12, Color(0xFF5B5963), lh: 17, wrap: true)),
      gP(338.75, 409.375, 18.5, 17.25, gImg('assets/figma/v/dbb07b49642bdc.svg')),
      gP(332.5, 402.5, 31, 31, GHeart()),
      gP(344.5, 432, 7, 12, gText('4', 9.5, Color(0xFF66636E), weight: 500)),
      gP(24, 494, 38, 38, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [19, 19, 19, 19])),
      gP(74, 495, 65, 16, gText('Yannick M.', 12.5, Color(0xFF111015), weight: 600)),
      gP(156, 497, 32, 13, gText('45 min', 10, Color(0xFF66636E))),
      gP(74, 514, 253, 34, gRich([('@Carine', 12, 600, Color(0xFF6A4DFF)), (' Oui ! Écris-moi en message privé pour un devis.', 12, 400, Color(0xFF5B5963))], lh: 17, wrap: true)),
      gP(338.75, 493.375, 18.5, 17.25, gImg('assets/figma/v/dbb07b49642bdc.svg')),
      gP(332.5, 486.5, 31, 31, GHeart()),
      gP(345, 516, 6, 12, gText('2', 9.5, Color(0xFF66636E), weight: 500)),
      gP(24, 578, 38, 38, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [19, 19, 19, 19])),
      gP(74, 579, 86, 16, gText('Kouassi Tagne', 12.5, Color(0xFF111015), weight: 600)),
      gP(177.6, 581, 33, 13, gText('20 min', 10, Color(0xFF66636E))),
      gP(74, 598, 253, 17, gText('Bravo l’équipe Génie civil 👏', 12, Color(0xFF5B5963), lh: 17, wrap: true)),
      gP(338.75, 577.375, 18.5, 17.25, gImg('assets/figma/v/dbb07b49642bdc.svg')),
      gP(332.5, 570.5, 31, 31, GHeart()),
      gP(346, 600, 4, 12, gText('1', 9.5, Color(0xFF66636E), weight: 500)),
      gP(24, 748, 342, 56, gBox(color: Color(0xC7FFFFFF), border: Color(0xFFFFFFFF), bw: 1, shadows: [BoxShadow(color: Color(0x14403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], backBlur: 24, radii: [28, 28, 28, 28])),
      gP(33, 757, 38, 38, gBox(color: Color(0xFFF1EEFB), oval: true)),
      gP(41.036, 764.624, 21.406, 22.341, gImg('assets/figma/v/b9f90829d9eec8.svg')),
      gP(80, 767, 240, 16, gText('Ajouter un commentaire… (@ pour citer)', 13, Color(0xFF66636E))),
      gP(318, 756, 40, 40, gBox(color: Color(0xFF111015), oval: true)),
      gP(328.5, 766.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(332.625, 765.083, 10.75, 15.5, gImg('assets/figma/v/ad77f88d6a6e8f.svg')),
      gP(329.458, 771.417, 17.083, 12.333, gImg('assets/figma/v/590a1cb98d88e9.svg')),
      gP(335, 777.75, 6, 9.167, gImg('assets/figma/v/6c8704a6160690.svg')),
      gP(276, 752, 34, 34, gBox(color: Color(0xFFEDE7FF), oval: true)),
      gP(286, 758, 16, 21, gText('@', 17, Color(0xFF5A3FE0), weight: 700)),
    ]);
  }
}
