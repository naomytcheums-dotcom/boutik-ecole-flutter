// GÉNÉRÉ par tool/figma_export/convert.py — écran 06 (nœud Figma 14:2). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_06 extends ConsumerWidget {
  const G_06({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      ...liveCart(context, ref),
      gP(35.087, 19.421, 29, 18, gText('9:41', 14.17, Color(0xFF111015), weight: 700)),
      gP(283.336, 27.421, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(288.336, 24.421, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(293.336, 21.421, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(298.336, 18.421, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(309.336, 20.362, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(314.736, 28.221, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(333.836, 19.921, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(335.836, 21.921, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(357.336, 23.421, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(24.291, 77.174, 21.592, 21.592, const SizedBox.expand(), tap: () => gOpen(context, '05')),
      gP(25.789, 78.672, 12.298, 18.595, gImg('assets/figma/v/ade208fa1ee3f1.svg')),
      gP(25.789, 84.97, 18.595, 6, gImg('assets/figma/v/12688bd81c8c1e.svg')),
      gP(66.125, 74.97, 113, 26, gText('Mon panier', 20.917, Color(0xFF111015), weight: 700)),
      gP(306.336, 79.97, 56, 16, Consumer(builder: (context, ref, _) => gText('${ref.watch(totalsProvider).count} article${ref.watch(totalsProvider).count > 1 ? "s" : ""}', 12.82, Color(0xFF6B6877), weight: 500, align: TextAlign.right))),
      gP(137.647, 884.436, 115.381, 2.707, gBox(color: Color(0xFF111015), radii: [2.024, 2.024, 2.024, 2.024])),
      gP(22, 812, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 833.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 845.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 833.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 832.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 839.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 846.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 833.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 833.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 841.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 818, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 833, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 831.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(24, 77, 22, 22, () => gOpen(context, '05')),
    ]);
  }
}
