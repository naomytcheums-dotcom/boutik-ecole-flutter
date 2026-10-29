// GÉNÉRÉ par tool/figma_export/convert.py — écran 19 (nœud Figma 29:2). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_19 extends ConsumerWidget {
  const G_19({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(0, 0, 390, 520, gBox(image: 'assets/figma/img/11d6f0ec937d2eb34a8412cfbbfaeb4d99772a54.png', fit: BoxFit.cover)),
      gP(0, 0, 390, 520, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x590D0A14), Color(0xBF0D0A14)], stops: [0, 1]))),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFFFFFFFF), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/5bc0bea2e7c30c.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/e67087fc64b6f1.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/fb4f69fd85c479.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/bc01d8c03d85a3.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/5dbae9b71cc779.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/59c083d0e217a4.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/68460c4514fd64.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/ee52ace3f9b23e.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/b74e5eeeb297f7.svg')),
      gP(14.219, 58.33, 47.227, 43.45, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(312.225, 70, 23.52, 20.6, gImg('assets/figma/v/fd807ff2facf81.svg')),
      gP(319.33, 88.493, 9.309, 6.978, gImg('assets/figma/v/3fde3cb38434ae.svg')),
      gP(325.508, 66.854, 9.141, 9.141, gBox(color: Color(0xFFF04438), oval: true)),
      gP(350.391, 66.571, 34.023, 33.516, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [16.758, 16.758, 16.758, 16.758])),
      gP(25.898, 280.03, 216, 78, gRich([('Trouvez ce qui\n', 31.484, 700, Color(0xFFFFFFFF)), ('vous', 31.484, 700, Color(0xFFFFC72C)), (' inspire', 31.484, 700, Color(0xFFFFFFFF))], lh: 38.594)),
      gP(26.914, 370.834, 221, 69, gText('Produits, services, talents,\nprojets... explorez tout l’univers\nétudiant de l’IUT de Douala.', 14.727, Color(0xFFFFFFFF), weight: 500, lh: 22.852)),
      gP(0, 470.807, 390, 373.193, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), shadows: [BoxShadow(color: Color(0x14122640), offset: Offset(0, -4), blurRadius: 14, spreadRadius: 0)], radii: [30.469, 30.469, 30.469, 30.469])),
      gP(22.344, 472.592, 346.328, 123.207, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1F122640), offset: Offset(0, 4), blurRadius: 16, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(30.977, 480.925, 328.555, 48.212, gBox(color: Color(0xFFF2EFF6), radii: [20.312, 20.312, 20.312, 20.312])),
      gP(30.977, 480.925, 328.555, 48.212, GField(hint: 'Rechercher un produit, service, talent...', size: 13.711, hintColor: Color(0xFF66636E), weight: 400, padL: 44.18, onChanged: (v) { ref.read(searchQueryProvider.notifier).set(v); }, onSubmitted: (v) { ref.read(searchQueryProvider.notifier).set(v); gOpen(context, '22'); })),
      gP(43.164, 495.593, 18.281, 18.281, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(42.449, 494.878, 18.188, 18.188, gImg('assets/figma/v/9961637ab1d06e.svg')),
      gP(52.885, 505.314, 9.275, 9.275, gImg('assets/figma/v/789bfa36ccd2e1.svg')),
      gP(30.977, 542.231, 328.555, 49.402, gBox(color: Color(0xFFF2EFF6), radii: [20.312, 20.312, 20.312, 20.312])),
      gP(51.336, 558.136, 11.332, 6, gImg('assets/figma/v/729a3d6803c2bf.svg')),
      gP(42.957, 558.136, 11.332, 6, gImg('assets/figma/v/729a3d6803c2bf.svg')),
      gP(49.812, 564.23, 12.855, 6, gImg('assets/figma/v/269ba55906b757.svg')),
      gP(42.957, 564.23, 9.809, 6, gImg('assets/figma/v/d29c19db674215.svg')),
      gP(52.859, 570.324, 9.809, 6, gImg('assets/figma/v/d29c19db674215.svg')),
      gP(42.957, 570.324, 12.855, 6, gImg('assets/figma/v/269ba55906b757.svg')),
      gP(51.336, 556.613, 6, 9.047, gImg('assets/figma/v/1c79eab5eac900.svg')),
      gP(46.766, 562.706, 6, 9.047, gImg('assets/figma/v/1c79eab5eac900.svg')),
      gP(52.859, 568.8, 6, 9.047, gImg('assets/figma/v/1c79eab5eac900.svg')),
      gP(75.156, 558.23, 135, 18, gText('Recherche avancée', 14.219, Color(0xFF111015), weight: 600)),
      gP(338.25, 560.167, 10.062, 14.125, gImg('assets/figma/v/207e3f61a8f1f1.svg')),
      gP(25.391, 631.628, 49.766, 49.766, gBox(color: Color(0xFFFBE9C6), oval: true)),
      gP(66.016, 634.417, 6.094, 6.094, gBox(color: Color(0xFFFBC02D), oval: true)),
      gP(39.656, 645.893, 11.924, 11.924, gImg('assets/figma/v/2efa679fb51e59.svg')),
      gP(48.966, 645.893, 11.924, 11.924, gImg('assets/figma/v/2efa679fb51e59.svg')),
      gP(48.966, 655.203, 11.924, 11.924, gImg('assets/figma/v/2efa679fb51e59.svg')),
      gP(39.656, 655.203, 11.924, 11.924, gImg('assets/figma/v/2efa679fb51e59.svg')),
      gP(23.773, 696.722, 53, 16, gText('Produits', 12.695, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(120.352, 631.628, 49.766, 49.766, gBox(color: Color(0xFFD6EAFA), oval: true)),
      gP(160.977, 634.417, 6.094, 6.094, gBox(color: Color(0xFF7FB6D8), oval: true)),
      gP(133.771, 649.279, 22.927, 17.849, gImg('assets/figma/v/ec27f261d25ce6.svg')),
      gP(138.849, 645.893, 12.771, 21.234, gImg('assets/figma/v/7c853aac25a168.svg')),
      gP(118.734, 696.722, 53, 16, gText('Services', 12.695, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(215.82, 631.628, 49.766, 49.766, gBox(color: Color(0xFFE6CCF5), oval: true)),
      gP(256.445, 634.417, 6.094, 6.094, gBox(color: Color(0xFF7FB6D8), oval: true)),
      gP(230.547, 646.354, 20.312, 20.312, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(233.471, 645.893, 14.464, 14.464, gImg('assets/figma/v/9eca5d1f97dbf8.svg')),
      gP(230.932, 654.357, 19.542, 12.771, gImg('assets/figma/v/2e8d1491a0fd68.svg')),
      gP(219.203, 696.722, 43, 16, gText('Talents', 12.695, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(311.797, 631.628, 49.766, 49.766, gBox(color: Color(0xFFCFEDE0), oval: true)),
      gP(352.422, 634.417, 6.094, 6.094, gBox(color: Color(0xFF7FB6D8), oval: true)),
      gP(328.602, 645.047, 16.156, 16.156, gImg('assets/figma/v/881ce816a74e34.svg')),
      gP(331.141, 658.589, 11.078, 6, gImg('assets/figma/v/30492620a9cc7c.svg')),
      gP(331.987, 661.974, 9.385, 6, gImg('assets/figma/v/13a34658393e91.svg')),
      gP(314.68, 696.722, 44, 16, gText('Projets', 12.695, Color(0xFF111015), weight: 500, align: TextAlign.center)),
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
      gTap(31, 542, 329, 49, () { gOpen(context, '21'); }),
      gTap(20, 625, 75, 95, () { ref.read(searchQueryProvider.notifier).set(''); ref.read(categoryProvider.notifier).set(0); gOpen(context, '22'); }),
    ]);
  }
}
