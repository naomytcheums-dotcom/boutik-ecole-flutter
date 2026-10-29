// GÉNÉRÉ par tool/figma_export/convert.py — écran 08 (nœud Figma 14:205). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_08 extends ConsumerWidget {
  const G_08({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 147, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 624, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(42.73, 19.315, 30, 18, gText('9:41', 14.243, Color(0xFF111015), weight: 700)),
      gP(280.478, 27.315, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(285.478, 24.315, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(290.478, 21.315, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(295.478, 18.315, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(306.478, 20.256, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(311.878, 28.115, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(330.978, 19.815, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(332.978, 21.815, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(354.478, 23.315, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(27.13, 66.002, 21.704, 21.704, const SizedBox.expand(), tap: () => gBack(context)),
      gP(28.652, 67.524, 12.33, 18.661, gImg('assets/figma/v/20b2385b0d2955.svg')),
      gP(28.652, 73.854, 18.661, 6, gImg('assets/figma/v/7c4663a1ebdfe9.svg')),
      gP(71.217, 69.921, 97, 26, gText('Paiement', 21.026, Color(0xFF111015), weight: 700)),
      gP(25.096, 129.376, 144, 19, gText('Moyen de paiement', 14.922, Color(0xFF111015), weight: 700)),
      gP(22.383, 165.169, 344.557, 88.315, gBox(color: Color(0xFFF4F9FE), border: Color(0xFFA9C8EC), bw: 1.696, shadows: [BoxShadow(color: Color(0x14122640), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [18.991, 18.991, 18.991, 18.991])),
      gP(88.174, 182.697, 50.87, 53.258, gBox(image: 'assets/figma/img/c7764301f1686610d42f1dec67db0ef7e710852f.png', fit: BoxFit.cover, radii: [9.496, 9.496, 9.496, 9.496])),
      gP(153.287, 188.18, 92, 16, gText('Orange Money', 12.887, Color(0xFF111015), weight: 500)),
      gP(153.287, 214.124, 80, 14, gText('Compte IUT DFI', 10.852, Color(0xFF5A3FE0))),
      gP(334.383, 201.524, 16.278, 16.278, gBox(border: Color(0xFF6A4DFF), bw: 1.696, oval: true)),
      gP(338.113, 205.254, 8.817, 8.817, gBox(color: Color(0xFF6A4DFF), oval: true)),
      gP(24.417, 264.27, 342.522, 91.011, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F122640), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(88.174, 282.472, 50.87, 53.258, gBox(image: 'assets/figma/img/c64e9a62ce99f11990178c5744b4f94fa121876a.png', fit: BoxFit.cover, radii: [9.496, 9.496, 9.496, 9.496])),
      gP(153.287, 288.629, 130, 16, gText('Mobile Money (autre)', 12.887, Color(0xFF111015), weight: 500)),
      gP(153.287, 313.899, 118, 14, gText('MTN Money, Wave, etc.', 10.852, Color(0xFF66636E))),
      gP(334.383, 301.299, 16.278, 16.278, gBox(border: Color(0xFF6B6877), bw: 1.696, oval: true)),
      gP(24.417, 383.596, 341.843, 182.697, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(43.409, 399.039, 94, 19, gText('Récapitulatif', 14.922, Color(0xFF111015), weight: 700)),
      gP(43.409, 442.163, 61, 15, Consumer(builder: (context, ref, _) => gText('Articles (${ref.watch(totalsProvider).count})', 12.209, Color(0xFF66636E)))),
      gP(131.339, 442.163, 220, 15, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(totalsProvider).subtotal), 11.53, Color(0xFF5A3FE0), weight: 600, wrap: true, align: TextAlign.right))),
      gP(43.409, 475.197, 51, 15, gText('Livraison', 12.209, Color(0xFF66636E))),
      gP(145.339, 475.197, 206, 15, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(totalsProvider).fee), 11.53, Color(0xFF5A3FE0), weight: 600, wrap: true, align: TextAlign.right))),
      gP(42.052, 511.011, 309.287, 0.674, gBox(color: Color(0xFFECE8F2))),
      gP(43.409, 527.803, 36, 19, gText('Total', 14.922, Color(0xFF111015), weight: 700)),
      gP(77.339, 523.955, 274, 24, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(totalsProvider).total), 18.991, Color(0xFF5A3FE0), weight: 700, wrap: true, align: TextAlign.right))),
      gP(21.704, 585.169, 345.913, 87.64, gBox(color: Color(0xFFF2EFF6), radii: [18.991, 18.991, 18.991, 18.991])),
      gP(44.817, 611.714, 20.243, 14.704, gImg('assets/figma/v/81b4d0fd4381d5.svg')),
      gP(47.983, 604.593, 13.913, 13.122, gImg('assets/figma/v/de25b67eb8d42d.svg')),
      gP(82.07, 602.938, 91, 13, gText('Paiement sécurisé', 10.174, Color(0xFF111015), weight: 700)),
      gP(82.07, 624.798, 178, 34, gText('Vos informations sont protégées\net ne sont jamais partagées.', 11.53, Color(0xFF66636E), lh: 16.957)),
      gP(23.061, 713.258, 343.878, 58.652, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [29.843, 29.843, 29.843, 29.843]), tap: () => gOpen(context, '09')),
      gP(120.443, 739.917, 18.209, 13.461, gImg('assets/figma/v/315ff1a827be55.svg')),
      gP(123.157, 733.813, 12.783, 12.104, gImg('assets/figma/v/142954c25f755b.svg')),
      gP(146.504, 735.096, 114, 17, gText('Payer maintenant', 13.565, Color(0xFFFFFFFF), weight: 600)),
      gP(134.974, 881.798, 115.983, 2.697, gBox(color: Color(0xFF111015), radii: [2.035, 2.035, 2.035, 2.035])),
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
      gTap(27, 66, 22, 22, () => gOpen(context, '07')),
      gTap(23, 713, 344, 59, () { ref.read(ordersProvider.notifier).place(); gOpen(context, '257'); }),
      gTap(20, 790, 350, 50, () { ref.read(ordersProvider.notifier).place(); gOpen(context, '257'); }),
      gTap(22, 165, 345, 88, () { ref.read(payMethodProvider.notifier).set(0); gToast(context, 'Orange Money sélectionné'); }),
      gTap(24, 264, 343, 91, () { ref.read(payMethodProvider.notifier).set(1); gToast(context, 'Mobile Money sélectionné'); }),
    ]);
  }
}
