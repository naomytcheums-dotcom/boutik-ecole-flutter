// GÉNÉRÉ par tool/figma_export/convert.py — écran 248 (nœud Figma 153:124). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_248 extends ConsumerWidget {
  const G_248({super.key});

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
      gP(119, 82, 152, 20, gText('Boutique d’Aminata', 16, Color(0xFF111015), weight: 500)),
      gP(152, 102, 86, 14, gText('8 articles · 4,9 ★', 11.5, Color(0xFF66636E))),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(327.987, 81.208, 20.025, 21.583, gImg('assets/figma/v/db754939a6b043.svg')),
      gP(327.987, 84.325, 20.025, 12.233, gImg('assets/figma/v/b1f8fe8dfa2b2f.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 130, 92.4, 34, 'Produits', 12, 500), GChip(124.4, 130, 92.4, 34, 'Services', 12, 400), GChip(224.8, 130, 162.6, 34, 'Offres de clients', 12, 400)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 17)),
      gP(24, 176, 342, 52, gBox(color: Color(0x99FFFFFF), border: Color(0xFF6A4DFF), bw: 1.5, radii: [26, 26, 26, 26])),
      gP(43, 187, 30, 30, gBox(color: Color(0xFFEEE9FF), oval: true)),
      gP(50.625, 199, 14.75, 6, gImg('assets/figma/v/4a21eafe2f996f.svg')),
      gP(55, 194.625, 6, 14.75, gImg('assets/figma/v/4c74d775e86184.svg')),
      gP(84, 186, 106, 16, gText('Ajouter un article', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(84, 206, 266, 13, gText('Produit, service ou offre : visible sur ton profil et dans le fil', 10, Color(0xFF66636E))),
      gP(24, 244, 166, 166, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(34, 254, 59, 24, gBox(color: Color(0xD9FFFFFF), radii: [100, 100, 100, 100])),
      gP(46, 260, 35, 12, gText('Service', 9.5, Color(0xFF111015), weight: 600)),
      gP(157, 251, 26, 26, gBox(color: Color(0xD9FFFFFF), oval: true)),
      gP(161.583, 256.125, 16.833, 15.75, gImg('assets/figma/v/e17963cdc7a85d.svg')),
      gP(155.5, 249.5, 29, 29, GHeart()),
      gP(28, 418, 103, 16, gText('Logo sur mesure', 13, Color(0xFF111015), weight: 600)),
      gP(28, 438, 116, 15, gText('À partir de 80 000 F', 12, Color(0xFF5A3FE0), weight: 700)),
      gP(28, 456, 104, 13, gText('★ 4,9 · 12 commandes', 10, Color(0xFF66636E))),
      gP(200, 244, 166, 166, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(210, 254, 59, 24, gBox(color: Color(0xD9FFFFFF), radii: [100, 100, 100, 100])),
      gP(222, 260, 35, 12, gText('Service', 9.5, Color(0xFF111015), weight: 600)),
      gP(333, 251, 26, 26, gBox(color: Color(0xD9FFFFFF), oval: true)),
      gP(337.583, 256.125, 16.833, 15.75, gImg('assets/figma/v/e17963cdc7a85d.svg')),
      gP(331.5, 249.5, 29, 29, GHeart()),
      gP(204, 418, 65, 16, gText('Affiche A3', 13, Color(0xFF111015), weight: 600)),
      gP(204, 438, 53, 15, gText('45 000 F', 12, Color(0xFF5A3FE0), weight: 700)),
      gP(204, 456, 104, 13, gText('★ 4,9 · 12 commandes', 10, Color(0xFF66636E))),
      gP(24, 480, 166, 166, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(34, 490, 59, 24, gBox(color: Color(0xD9FFFFFF), radii: [100, 100, 100, 100])),
      gP(46, 496, 35, 12, gText('Service', 9.5, Color(0xFF111015), weight: 600)),
      gP(157, 487, 26, 26, gBox(color: Color(0xD9FFFFFF), oval: true)),
      gP(161.583, 492.125, 16.833, 15.75, gImg('assets/figma/v/e17963cdc7a85d.svg')),
      gP(155.5, 485.5, 29, 29, GHeart()),
      gP(28, 654, 97, 16, gText('Spot vidéo 30 s', 13, Color(0xFF111015), weight: 600)),
      gP(28, 674, 58, 15, gText('180 000 F', 12, Color(0xFF5A3FE0), weight: 700)),
      gP(28, 692, 104, 13, gText('★ 4,9 · 12 commandes', 10, Color(0xFF66636E))),
      gP(200, 480, 166, 166, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 20, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(210, 490, 47, 24, gBox(color: Color(0xD9FFFFFF), radii: [100, 100, 100, 100])),
      gP(222, 496, 23, 12, gText('Pack', 9.5, Color(0xFF111015), weight: 600)),
      gP(333, 487, 26, 26, gBox(color: Color(0xD9FFFFFF), oval: true)),
      gP(337.583, 492.125, 16.833, 15.75, gImg('assets/figma/v/e17963cdc7a85d.svg')),
      gP(331.5, 485.5, 29, 29, GHeart()),
      gP(204, 654, 99, 16, gText('Identité visuelle', 13, Color(0xFF111015), weight: 600)),
      gP(204, 674, 60, 15, gText('250 000 F', 12, Color(0xFF5A3FE0), weight: 700)),
      gP(204, 692, 104, 13, gText('★ 4,9 · 12 commandes', 10, Color(0xFF66636E))),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '251')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '247')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '244')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(24, 176, 342, 52, () => gOpen(context, '249')),
    ]);
  }
}
