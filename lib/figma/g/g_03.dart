// GÉNÉRÉ par tool/figma_export/convert.py — écran 03 (nœud Figma 3:3). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_03 extends ConsumerWidget {
  const G_03({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 939, radius: 43.333, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 139.08, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 666.36, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(37.014, 20.792, 29, 18, gText('9:41', 14.444, Color(0xFF1B2430), weight: 600)),
      gP(285.722, 28.792, 9, 11, gImg('assets/figma/v/fea2de318bc933.svg')),
      gP(290.722, 25.792, 9, 14, gImg('assets/figma/v/78097c7c9d5492.svg')),
      gP(295.722, 22.792, 9, 17, gImg('assets/figma/v/ae1f2a46acea51.svg')),
      gP(300.722, 19.792, 9, 20, gImg('assets/figma/v/cc5b94f8741a79.svg')),
      gP(311.722, 21.733, 20, 12.259, gImg('assets/figma/v/5829a0465bd880.svg')),
      gP(317.122, 29.592, 9.2, 9.2, gImg('assets/figma/v/7834792aa6eeb1.svg')),
      gP(336.222, 21.292, 28, 17, gImg('assets/figma/v/b744a041c9b26f.svg')),
      gP(338.222, 23.292, 22, 13, gImg('assets/figma/v/0a1ead9f468035.svg')),
      gP(359.722, 24.792, 8, 10, gImg('assets/figma/v/c55261ef5c9f82.svg')),
      gP(15.347, 62.292, 45.139, 39.722, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(258.646, 69.965, 20.764, 20.764, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(258.241, 69.561, 19.843, 19.843, gImg('assets/figma/v/24c238585949ab.svg')),
      gP(270.094, 81.413, 9.72, 9.72, gImg('assets/figma/v/e06720259342ce.svg')),
      gP(303.38, 68.696, 21.573, 18.977, gImg('assets/figma/v/a20eafbb9e4256.svg')),
      gP(309.696, 85.134, 8.942, 6.87, gImg('assets/figma/v/a629a5aabb9ce8.svg')),
      gP(319.583, 67.708, 9.028, 9.028, gBox(color: Color(0xFFF04438), border: Color(0xFFFCFCFD), bw: 1.5, radii: [4.514, 4.514, 4.514, 4.514])),
      gP(346.667, 63.194, 34.306, 34.306, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [17.153, 17.153, 17.153, 17.153])),
      gP(18.056, 115.097, 117, 28, gText('Bienvenue', 22.569, Color(0xFF111015), weight: 800)),
      gP(18.056, 146.778, 165, 17, gText('Explorez le talent étudiant', 13.542, Color(0xFF4A4854))),
      gP(18.056, 181.458, 362.917, 41.528, gBox(color: Color(0xFFEFF1F4), radii: [20.764, 20.764, 20.764, 20.764])),
      gP(32.5, 193.194, 16.25, 16.25, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(31.531, 192.226, 16.833, 16.833, gImg('assets/figma/v/77841836149ddf.svg')),
      gP(40.807, 201.502, 8.911, 8.911, gImg('assets/figma/v/38a886aa441c16.svg')),
      gP(60.486, 193.819, 214, 15, gText('Rechercher un produit, service, talent…', 11.736, Color(0xFF66636E))),
      gP(355.854, 192.903, 10.74, 6, gImg('assets/figma/v/38fea02714a4a8.svg')),
      gP(348.406, 192.903, 10.74, 6, gImg('assets/figma/v/38fea02714a4a8.svg')),
      gP(354.5, 198.319, 12.094, 6, gImg('assets/figma/v/ffb42b3e404662.svg')),
      gP(348.406, 198.319, 9.385, 6, gImg('assets/figma/v/ccd9d31aef5caa.svg')),
      gP(357.208, 203.736, 9.385, 6, gImg('assets/figma/v/ccd9d31aef5caa.svg')),
      gP(348.406, 203.736, 12.094, 6, gImg('assets/figma/v/ffb42b3e404662.svg')),
      gP(355.854, 191.549, 6, 8.708, gImg('assets/figma/v/f692fed553b538.svg')),
      gP(351.792, 196.965, 6, 8.708, gImg('assets/figma/v/f692fed553b538.svg')),
      gP(357.208, 202.382, 6, 8.708, gImg('assets/figma/v/f692fed553b538.svg')),
      gP(18.056, 238.333, 57.778, 46.944, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x33122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [16.25, 16.25, 16.25, 16.25])),
      gP(36.497, 251.358, 11.793, 11.793, gImg('assets/figma/v/1489be1582fc30.svg')),
      gP(45.6, 251.358, 11.793, 11.793, gImg('assets/figma/v/1489be1582fc30.svg')),
      gP(45.6, 260.461, 11.793, 11.793, gImg('assets/figma/v/1489be1582fc30.svg')),
      gP(36.497, 260.461, 11.793, 11.793, gImg('assets/figma/v/1489be1582fc30.svg')),
      gP(35.444, 287.806, 23, 13, gText('Tous', 10.382, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(94.792, 238.333, 57.778, 46.944, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16.25, 16.25, 16.25, 16.25])),
      gP(113.233, 250.53, 20.896, 22.551, gImg('assets/figma/v/c8ddc691e4386f.svg')),
      gP(113.233, 253.84, 20.896, 6, gImg('assets/figma/v/75af8226f6be26.svg')),
      gP(117.37, 257.15, 12.62, 9.31, gImg('assets/figma/v/0fb8e801ac974d.svg')),
      gP(102.681, 287.806, 42, 13, gText('Produits', 10.382, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(171.528, 238.333, 57.778, 46.944, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16.25, 16.25, 16.25, 16.25])),
      gP(189.141, 254.668, 22.551, 17.586, gImg('assets/figma/v/dc1180b6112b2f.svg')),
      gP(194.106, 251.358, 12.62, 20.896, gImg('assets/figma/v/1a1eeaec24f790.svg')),
      gP(178.917, 287.806, 43, 13, gText('Services', 10.382, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(248.264, 238.333, 57.778, 46.944, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16.25, 16.25, 16.25, 16.25])),
      gP(267.222, 251.875, 19.861, 19.861, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(270.015, 251.358, 14.275, 14.275, gImg('assets/figma/v/fa6123b26c6cdd.svg')),
      gP(267.532, 259.633, 19.241, 12.62, gImg('assets/figma/v/b5c59f8332fa97.svg')),
      gP(259.153, 287.806, 36, 13, gText('Talents', 10.382, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(324.097, 238.333, 57.778, 46.944, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [16.25, 16.25, 16.25, 16.25])),
      gP(345.021, 250.53, 15.931, 15.931, gImg('assets/figma/v/23cbed4ccaa61f.svg')),
      gP(347.503, 263.771, 10.965, 6, gImg('assets/figma/v/c94e1e4a8135f4.svg')),
      gP(348.331, 267.081, 9.31, 6, gImg('assets/figma/v/188f8a4ee0e095.svg')),
      gP(334.986, 287.806, 36, 13, gText('Projets', 10.382, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(14.444, 322.292, 372.847, 185.069, gBox(image: 'assets/figma/img/6baf8125049f662c1c5c4c23c6b514db2881910c.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 6), blurRadius: 16, spreadRadius: 0)], radii: [18.056, 18.056, 18.056, 18.056])),
      gP(37.917, 346.667, 54.167, 18.056, gBox(color: Color(0xFF111015), radii: [9.028, 9.028, 9.028, 9.028])),
      gP(47.5, 349.694, 35, 12, gText('À la une', 9.479, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(37.917, 373.722, 187, 47, gText('L’innovation\nétudiante en action', 19.861, Color(0xFFFFFFFF), weight: 700, lh: 23.472)),
      gP(37.917, 425.153, 152, 29, gText('Des projets qui transforment\ndemain.', 11.285, Color(0xFFFFFFFF), lh: 14.444)),
      gP(37.917, 463.125, 30.694, 30.694, gBox(color: Color(0xFFFFFFFF), radii: [15.347, 15.347, 15.347, 15.347])),
      gP(45.788, 475.472, 14.953, 6, gImg('assets/figma/v/5e22db51bd766d.svg')),
      gP(50.264, 470.996, 10.476, 14.953, gImg('assets/figma/v/654dcf2191c5fb.svg')),
      gP(340.347, 486.597, 5.417, 5.417, gBox(color: Color(0xF2FFFFFF), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(350.278, 486.597, 5.417, 5.417, gBox(color: Color(0x8CFFFFFF), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(360.208, 486.597, 5.417, 5.417, gBox(color: Color(0x8CFFFFFF), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(17.153, 529.056, 134, 18, gText('Produits en vedette', 13.993, Color(0xFF111015), weight: 700)),
      gP(308.986, 531.958, 44, 14, gText('Voir tout', 10.833, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right)),
      gP(369.133, 535.958, 12.846, 6, gImg('assets/figma/v/92b236aeae97cb.svg')),
      gP(372.556, 532.535, 9.423, 12.846, gImg('assets/figma/v/337e7bc848e314.svg')),
      gP(14.444, 558.819, 177.847, 229.111, const SizedBox.expand(), tap: () => gOpen(context, '05')),
      gP(14.444, 558.819, 177.847, 163, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(161.597, 567.847, 21.667, 21.667, gBox(color: Color(0xFFFFFFFF), radii: [10.833, 10.833, 10.833, 10.833])),
      gP(164.541, 571.28, 15.78, 14.802, gImg('assets/figma/v/d9c8f50f0367c0.svg')),
      gP(158.562, 564.812, 27.736, 27.736, GHeartLive(title: 'Lampe en bois recyclé')),
      gP(21.667, 731.278, 122, 14, gText('Lampe en bois recyclé', 11.285, Color(0xFF111015), weight: 700)),
      gP(21.667, 749.833, 66, 13, gText('25 000 FCFA', 10.382, Color(0xFF111015), weight: 600)),
      gP(21.667, 768.389, 98, 12, gText('Ngoné M. – Génie civil', 9.479, Color(0xFF6B7A8C))),
      gP(204.931, 558.819, 177.847, 163, gBox(image: 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(352.083, 567.847, 21.667, 21.667, gBox(color: Color(0xFFFFFFFF), radii: [10.833, 10.833, 10.833, 10.833])),
      gP(355.027, 571.28, 15.78, 14.802, gImg('assets/figma/v/d9c8f50f0367c0.svg')),
      gP(349.049, 564.812, 27.736, 27.736, GHeartLive(title: 'Drone éducatif')),
      gP(212.153, 731.278, 83, 14, gText('Drone éducatif', 11.285, Color(0xFF111015), weight: 700)),
      gP(212.153, 749.833, 71, 13, gText('150 000 FCFA', 10.382, Color(0xFF111015), weight: 600)),
      gP(212.153, 768.389, 136, 12, gText('Team Innov’ – Génie électrique', 9.479, Color(0xFF6B7A8C))),
      gP(17.153, 803.306, 128, 18, gText('Talents à découvrir', 13.993, Color(0xFF111015), weight: 700)),
      gP(308.986, 806.208, 44, 14, gText('Voir tout', 10.833, Color(0xFFB8C2CE), weight: 500, align: TextAlign.right)),
      gP(369.133, 810.208, 12.846, 6, gImg('assets/figma/v/92b236aeae97cb.svg')),
      gP(372.556, 806.785, 9.423, 12.846, gImg('assets/figma/v/337e7bc848e314.svg')),
      gP(14.444, 896.972, 368.333, 27.083, gBox(image: 'assets/figma/img/e48f8827338ec470670d1109125a15b7d0f21476.png', fit: BoxFit.cover)),
      gP(133.611, 988.153, 130.903, 4.514, gBox(color: Color(0xFF111015), radii: [2.708, 2.708, 2.708, 2.708])),
      gP(22, 851, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 872.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 872.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 884.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 872.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 872.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 872.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 871.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 878.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 885.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 872.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 872.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 880.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 857, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true)),
      gP(183.75, 870.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gP(72, 70, 69, 31, gBox(color: Color(0xB2FFFFFF), border: Color(0xFFFFFFFF), bw: 1, shadows: [BoxShadow(color: Color(0x1A403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], backBlur: 20, radii: [100, 100, 100, 100])),
      gP(87, 78, 39, 15, gText('Cercle', 12, Color(0xFF111015), weight: 600)),
      gTap(14, 559, 178, 229, () { ref.read(selectedProductProvider.notifier).select('Lampe en bois recyclé'); gOpen(context, '05'); }),
      gTap(72, 70, 69, 31, () => gOpen(context, '244')),
      gTap(24, 180, 342, 48, () => gOpen(context, '19')),
      gTap(198, 559, 178, 229, () { ref.read(selectedProductProvider.notifier).select('Drone éducatif'); gOpen(context, '05'); }),
    ]);
  }
}
