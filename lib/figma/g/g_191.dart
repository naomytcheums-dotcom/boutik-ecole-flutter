// GÉNÉRÉ par tool/figma_export/convert.py — écran 191 (nœud Figma 83:2). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_191 extends ConsumerWidget {
  const G_191({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1069, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 202.77, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 769.34, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 130, 26, gText('Votre besoin', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(27, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(25.5, 158, 37, 14, gText('Besoin', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(129.667, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(124.667, 158, 40, 14, gText('Budget', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(222.333, 158, 46, 14, gText('Garantie', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(331.5, 158, 29, 14, gText('Envoi', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 214, 19, gText('Que voulez-vous faire créer ?', 15, Color(0xFF111015), weight: 700)),
      gP(24, 226, 166, 104, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 226, 166, 104, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x1A111015), Color(0xB2111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(24, 226, 166, 104, gBox(border: Color(0xFF6A4DFF), bw: 3, radii: [24, 24, 24, 24])),
      gP(159, 235, 22, 22, gBox(color: Color(0xFF111015), oval: true)),
      gP(163.333, 240.25, 13.333, 11.042, gImg('assets/figma/v/9ad36130a811a4.svg')),
      gP(38, 286, 101, 16, gText('Identité visuelle', 13, Color(0xFFFFFFFF), weight: 800)),
      gP(38, 306, 64, 13, gText('Logo, charte', 10.5, Color(0xCCFFFFFF), weight: 500)),
      gP(200, 226, 166, 104, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(200, 226, 166, 104, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x1A111015), Color(0xB2111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(214, 286, 118, 16, gText('Savons et parfums', 13, Color(0xFFFFFFFF), weight: 800)),
      gP(214, 306, 116, 13, gText('Fabrication, emballage', 10.5, Color(0xCCFFFFFF), weight: 500)),
      gP(24, 340, 166, 104, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 340, 166, 104, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x1A111015), Color(0xB2111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(38, 400, 95, 16, gText('Vidéo et photo', 13, Color(0xFFFFFFFF), weight: 800)),
      gP(38, 420, 75, 13, gText('Spot, shooting', 10.5, Color(0xCCFFFFFF), weight: 500)),
      gP(200, 340, 166, 104, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(200, 340, 166, 104, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x1A111015), Color(0xB2111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(214, 400, 119, 16, gText('Site ou application', 13, Color(0xFFFFFFFF), weight: 800)),
      gP(214, 420, 64, 13, gText('Web, mobile', 10.5, Color(0xCCFFFFFF), weight: 500)),
      gP(24, 454, 166, 104, gBox(image: 'assets/figma/img/e3a1b5107e8b2a5b3a542598c9ff80a2e1376935.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 454, 166, 104, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x1A111015), Color(0xB2111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(38, 514, 66, 16, gText('Prototype', 13, Color(0xFFFFFFFF), weight: 800)),
      gP(38, 534, 91, 13, gText('Objet, mécanique', 10.5, Color(0xCCFFFFFF), weight: 500)),
      gP(200, 454, 166, 104, gBox(image: 'assets/figma/img/b69ab5f7f7665b6bb6d2143632c5ec64de915bea.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(200, 454, 166, 104, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x1A111015), Color(0xB2111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(214, 514, 92, 16, gText('Étude ou audit', 13, Color(0xFFFFFFFF), weight: 800)),
      gP(214, 534, 80, 13, gText('Marché, finance', 10.5, Color(0xCCFFFFFF), weight: 500)),
      gP(24, 572, 130, 16, gText('Décrivez votre besoin', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 592, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 606, 313, 40, gText('Ex. identité visuelle complète pour ma marque de parfums…', 13.5, Color(0xFF66636E), weight: 500, lh: 20, wrap: true)),
      gP(24, 702, 89, 16, gText('Budget estimé', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 722, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 722, 342, 48, GField(hint: '', initial: '150 000 – 300 000 FCFA', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 736.25, 20.25, 15.75, gImg('assets/figma/v/16ec94a7384869.svg')),
      gP(38.25, 737.75, 19.5, 18, gImg('assets/figma/v/fbc7a9ade9c600.svg')),
      gP(334.5, 740.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 784, 91, 16, gText('Date souhaitée', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 804, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 804, 342, 48, GField(hint: '', initial: '30 novembre 2026', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 819, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(48, 817.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(42, 817.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(38.25, 823.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(24, 866, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 889.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 895.443, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 901.083, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 880, 277, 51, gText('Paiement sécurisé par Boutik-École : votre argent est gardé en séquestre et libéré à chaque étape validée.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 969, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 985, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Envoyer mon besoin')),
      gP(124.5, 1003, 141, 18, gText('Envoyer mon besoin', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 1055, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
