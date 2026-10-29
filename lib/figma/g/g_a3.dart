// GÉNÉRÉ par tool/figma_export/convert.py — écran A3 (nœud Figma 94:145). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_A3 extends ConsumerWidget {
  const G_A3({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFEEE8F6), Color(0xFFF3EAE4), Color(0xFFEFDCCD)], stops: [0, 0.5, 1]), children: [
      gP(-90, 100, 260, 260, gBox(color: Color(0x80CDB2F2), layerBlur: 90, oval: true), fx: 'halo'),
      gP(230, 390, 260, 260, gBox(color: Color(0x80F7C9A4), layerBlur: 90, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(143.5, 82, 103, 21, gText('Voix en texte', 17, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(328.767, 85.883, 18.467, 12.233, gImg('assets/figma/v/44747303a472e2.svg')),
      gP(150, 140, 216, 56, gBox(color: Color(0xFF111015), radii: [28, 28, 28, 28])),
      gP(162, 150, 36, 36, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(175, 159, 15.333, 18, gImg('assets/figma/v/000d96af5ca0a3.svg')),
      gP(208, 164, 3, 8, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(214.4, 161, 3, 14, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(220.8, 157, 3, 22, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(227.2, 162, 3, 12, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(233.6, 155, 3, 26, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(240, 160, 3, 16, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(246.4, 163, 3, 10, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(252.8, 156, 3, 24, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(259.2, 161, 3, 14, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(265.6, 164, 3, 8, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(272, 159, 3, 18, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(278.4, 162, 3, 12, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(284.8, 158, 3, 20, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(291.2, 163, 3, 10, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(297.6, 161, 3, 14, gBox(color: Color(0xFFFFFFFF), radii: [2, 2, 2, 2]), fx: 'wave'),
      gP(334, 160, 22, 14, gText('1:33', 11, Color(0xFFFFFFFF), weight: 500, align: TextAlign.right)),
      gP(341, 202, 25, 13, gText('16:43', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(22, 232, 36, 36, gBox(color: Color(0xFF111015), oval: true)),
      gP(24, 234, 32, 32, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(70, 226, 276, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 5), blurRadius: 16, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(88, 240, 245, 76, gText('Décris-moi ton parfum : cible, style et budget. Je prépare le brief et je contacte les étudiants de MMI et de TCO.', 13, Color(0xFF111015), weight: 500, lh: 19, wrap: true)),
      gP(70, 334, 25, 13, gText('16:43', 10, Color(0xFF66636E))),
      gP(226, 364, 140, 120, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [20, 20, 20, 20])),
      gP(340, 490, 26, 13, gText('16:44', 10, Color(0xFF66636E), align: TextAlign.right)),
      gP(214, 514, 152, 46, gBox(color: Color(0xFF111015), radii: [23, 23, 23, 23])),
      gP(232, 520, 90, 34, gText('Crée la mission\npour moi', 12.5, Color(0xFFFFFFFF), weight: 500, lh: 17)),
      gP(24, 590, 32, 32, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(70, 580, 276, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 5), blurRadius: 16, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(88, 594, 245, 57, gText('Compris ! Je lance ton brief : logo + affiche, budget d’environ 200 000 FCFA. Veux-tu aussi une vidéo teaser ?', 13, Color(0xFF111015), weight: 500, lh: 19, wrap: true)),
      gP(20, 688, 350, 62, gBox(color: Color(0xCCFFFFFF), border: Color(0xCCFFFFFF), bw: 1, backBlur: 28, radii: [31, 31, 31, 31])),
      gP(20, 688, 350, 62, GField(hint: 'Écris ou parle à Kéla…', size: 13, hintColor: Color(0xFF66636E), weight: 400, padL: 54)),
      gP(41.167, 716, 17.667, 6, gImg('assets/figma/v/a601ae14f144f2.svg')),
      gP(47, 710.167, 6, 17.667, gImg('assets/figma/v/148ccb346e3d02.svg')),
      gP(314, 697, 44, 44, GMic(child: gBox(color: Color(0xFF111015), oval: true))),
      gP(327, 710, 18, 18, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(330.75, 708.5, 10.5, 15, gImg('assets/figma/v/47bc9d3a14157f.svg')),
      gP(327.75, 714.5, 16.5, 12, gImg('assets/figma/v/0e220d66ee2ccc.svg')),
      gP(333, 720.5, 6, 9, gImg('assets/figma/v/ef0937d1ce4f60.svg')),
      gP(22, 762, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 783.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 795.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 783.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 782.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 789.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 796.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 783.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 783.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 791.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 768, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 783, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 781.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
    ]);
  }
}
