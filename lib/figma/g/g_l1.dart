// GÉNÉRÉ par tool/figma_export/convert.py — écran L1 (nœud Figma 101:223). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_L1 extends ConsumerWidget {
  const G_L1({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFFFE9E4), Color(0xFFF1ECF6), Color(0xFFF3E3D6)], stops: [0, 0.4, 1]), children: [
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(139.5, 82, 111, 21, gText('Aller en direct', 17, Color(0xFF111015), weight: 500)),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(328.767, 89, 18.467, 13.792, gImg('assets/figma/v/895539ee63d9c6.svg')),
      gP(331.883, 81.208, 12.233, 9.117, gImg('assets/figma/v/f647bd0695bc59.svg')),
      gP(335, 81.208, 6, 16.129, gImg('assets/figma/v/45c0f0a43fac31.svg')),
      gP(24, 128, 342, 330, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x33403366), offset: Offset(0, 14), blurRadius: 28, spreadRadius: 0)], radii: [40, 40, 40, 40])),
      gP(40, 144, 94, 26, gBox(color: Color(0xFFFF2D55), radii: [100, 100, 100, 100])),
      gP(52, 153.5, 7, 7, gBox(color: Color(0xFFFFFFFF), oval: true)),
      gP(65, 150, 57, 14, gText('EN DIRECT', 11, Color(0xFF111015), weight: 600), fx: 'pulse'),
      gP(268, 144, 82, 26, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(278.083, 150.208, 16.833, 13.583, gImg('assets/figma/v/1c64daa304e6b4.svg')),
      gP(281.875, 152.375, 9.25, 9.25, gImg('assets/figma/v/e735fd67e86253.svg')),
      gP(299, 150, 39, 14, gText('Aperçu', 11, Color(0xFFFFFFFF), weight: 600)),
      gP(108, 398, 174, 44, gBox(color: Color(0x4DFFFFFF), border: Color(0xFFFFFFFF), bw: 1, backBlur: 20, radii: [22, 22, 22, 22])),
      gP(123.875, 409.875, 20.25, 20.25, gImg('assets/figma/v/386cd2103449c2.svg')),
      gP(185.5, 410.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(189.625, 409.083, 10.75, 15.5, gImg('assets/figma/v/ad77f88d6a6e8f.svg')),
      gP(186.458, 415.417, 17.083, 12.333, gImg('assets/figma/v/590a1cb98d88e9.svg')),
      gP(192, 421.75, 6, 9.167, gImg('assets/figma/v/6c8704a6160690.svg')),
      gP(246.271, 409.083, 19.458, 19.062, gImg('assets/figma/v/0397ee56e7c9a4.svg')),
      gP(24, 470, 342, 50, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [24, 24, 24, 24]), tap: () => gToast(context, 'Démonstration : Atelier : fabrication de la lampe en bois recyclé')),
      gP(40, 486, 315, 16, gText('Atelier : fabrication de la lampe en bois recyclé', 12.5, Color(0xFF111015), weight: 500, wrap: true)),
      gP(24, 532, 342, 138, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 8), blurRadius: 22, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(44, 548, 146, 18, gText('Tu peux lancer ce live', 14.5, Color(0xFF111015), weight: 600)),
      gP(299, 544, 47, 26, gBox(color: Color(0xFFE8F7EE), radii: [100, 100, 100, 100])),
      gP(311, 550, 23, 14, gText('3 / 4', 11, Color(0xFF126B49), weight: 600)),
      gP(44, 586, 22, 22, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(48, 591, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(74, 590, 67, 15, gText('Profil vérifié', 12, Color(0xFF111015), weight: 500)),
      gP(202, 586, 22, 22, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(206, 591, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(232, 590, 84, 15, gText('1 mission livrée', 12, Color(0xFF111015), weight: 500)),
      gP(44, 624, 22, 22, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(48, 629, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(74, 628, 94, 15, gText('Note 4,0 ou plus', 12, Color(0xFF111015), weight: 500)),
      gP(202, 624, 22, 22, gBox(color: Color(0xFFE4E1EA), oval: true)),
      gP(232, 628, 97, 15, gText('Charte acceptée', 12, Color(0xFF66636E))),
      gP(44, 648, 202, 13, gText('Aucun seuil d’abonnés sur Boutik-École.', 10.5, Color(0xFF126B49), weight: 500)),
      gP(24, 682, 342, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 8), blurRadius: 22, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(44, 696, 106, 16, gText('Diffuser aussi sur', 13, Color(0xFF111015), weight: 600)),
      gP(40, 722, 152, 48, gBox(color: Color(0xFFF6F3FA), radii: [24, 24, 24, 24])),
      gP(48, 730, 32, 32, gBox(color: Color(0x24FF1F1F), radii: [11, 11, 11, 11])),
      gP(57.25, 737.375, 14.75, 17.25, gImg('assets/figma/v/525deb227c083d.svg')),
      gP(86, 729, 48, 14, gText('YouTube', 11.5, Color(0xFF111015), weight: 600)),
      gP(86, 746, 19, 12, gText('Prêt', 9.5, Color(0xFF126B49))),
      gP(202, 722, 152, 48, gBox(color: Color(0xFFF4F2F6), radii: [24, 24, 24, 24])),
      gP(210, 730, 32, 32, gBox(color: Color(0x14111015), radii: [11, 11, 11, 11])),
      gP(221.125, 737.375, 13.5, 15.375, gImg('assets/figma/v/a3c9387d5957aa.svg')),
      gP(217.375, 744.875, 9.75, 9.75, gImg('assets/figma/v/b8fee1f8bbbaf3.svg')),
      gP(224.875, 743.625, 9.75, 9.75, gImg('assets/figma/v/b8fee1f8bbbaf3.svg')),
      gP(248, 729, 35, 14, gText('TikTok', 11.5, Color(0xFFB5B2BC), weight: 600)),
      gP(248, 746, 54, 12, gText('Non éligible', 9.5, Color(0xFFB26A00))),
      gP(332.875, 742.542, 14.25, 11.042, gImg('assets/figma/v/2af36c9e23ec90.svg')),
      gP(334.708, 738.417, 10.583, 10.125, gImg('assets/figma/v/ba7c6cc74be2bd.svg')),
      gP(24, 792, 342, 44, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x40403366), offset: Offset(0, 8), blurRadius: 18, spreadRadius: 0)], radii: [22, 22, 22, 22]), tap: () => gToast(context, 'Démonstration : Lancer le live')),
      gP(153.5, 804, 83, 17, gText('Lancer le live', 13.5, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
