// GÉNÉRÉ par tool/figma_export/convert.py — écran 242 (nœud Figma 126:2). Ne pas éditer à la main.
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

class G_242 extends ConsumerWidget {
  const G_242({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(140.5, 76, 109, 21, gText('Kit à partager', 17, Color(0xFF111015), weight: 500)),
      gP(98, 100, 194, 15, gText('Poste, fais connaître l’appli, gagne', 12, Color(0xFF66636E))),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(328.767, 89, 18.467, 13.792, gImg('assets/figma/v/895539ee63d9c6.svg')),
      gP(331.883, 81.208, 12.233, 9.117, gImg('assets/figma/v/f647bd0695bc59.svg')),
      gP(335, 81.208, 6, 16.129, gImg('assets/figma/v/45c0f0a43fac31.svg')),
      gP(24, 128, 166, 150, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(87, 183, 40, 40, gBox(color: Color(0x66FFFFFF), oval: true)),
      gP(101, 194, 15.333, 18, gImg('assets/figma/v/38181151ecb2ef.svg')),
      gP(38, 298, 143, 15, gText('Story en 30 s', 12, Color(0xFF111015), weight: 600, wrap: true)),
      gP(38, 320, 61, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(43.5, 320, 50, 24, '+ 500 F', 10, 600), GChip(128, 320, 50, 24, 'Poster', 9.5, 600), GChip(219.5, 320, 50, 24, '+ 800 F', 10, 600), GChip(304, 320, 50, 24, 'Poster', 9.5, 600)], selected: 1, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF5A3FE0), radius: 12)),
      gP(200, 128, 166, 150, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(263, 183, 40, 40, gBox(color: Color(0x66FFFFFF), oval: true)),
      gP(277, 194, 15.333, 18, gImg('assets/figma/v/38181151ecb2ef.svg')),
      gP(214, 298, 143, 15, gText('Vidéo témoignage', 12, Color(0xFF111015), weight: 600, wrap: true)),
      gP(214, 320, 61, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(304, 320, 50, 24, gBox(color: Color(0xFF111015), radii: [12, 12, 12, 12])),
      gP(24, 360, 166, 150, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(38, 530, 143, 15, gText('Affiche du concours', 12, Color(0xFF111015), weight: 600, wrap: true)),
      gP(38, 552, 61, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(43.5, 552, 50, 24, '+ 300 F', 10, 600), GChip(128, 552, 50, 24, 'Poster', 9.5, 600), GChip(219.5, 552, 50, 24, '+ 400 F', 10, 600), GChip(304, 552, 50, 24, 'Poster', 9.5, 600)], selected: 1, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF5A3FE0), radius: 12)),
      gP(200, 360, 166, 150, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(214, 530, 143, 15, gText('Avant / après', 12, Color(0xFF111015), weight: 600, wrap: true)),
      gP(214, 552, 61, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(304, 552, 50, 24, gBox(color: Color(0xFF111015), radii: [12, 12, 12, 12])),
      gP(24, 596, 342, 128, gBox(gradient: LinearGradient(begin: Alignment(-1.24, -0.68), end: Alignment(0.36, 0.52), colors: [Color(0xFF1B1630), Color(0xFF4A38B8)], stops: [0, 1]), radii: [30, 30, 30, 30])),
      gP(44, 612, 240, 18, gText('Gagne à chaque publication validée', 14, Color(0xFFFFFFFF), weight: 600)),
      gP(44, 636, 303, 45, gText('Poste le visuel sur tes réseaux, ajoute ton lien de parrainage, puis envoie la preuve. Le paiement arrive sur ton Mobile Money.', 10.5, Color(0xFFFFFFFF), lh: 15, wrap: true)),
      gP(44, 686, 220, 25, gBox(color: Color(0x2EFFFFFF), radii: [100, 100, 100, 100])),
      gP(56, 692, 196, 13, gText('Preuve = capture ou lien de la publication', 10, Color(0xFFFFFFFF), weight: 600)),
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
