// GÉNÉRÉ par tool/figma_export/convert.py — écran 38 (nœud Figma 54:606). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/vendeur_public.dart';
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
import '../live/chat.dart';
import '../live/share.dart';
import '../live/inert_actions.dart';
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_38 extends ConsumerWidget {
  const G_38({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 938, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 159.54, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 656.68, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(21.98, 61.98, 40, 40, const GGlassCircle()),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 114, 26, gText('Réputation', 21, Color(0xFF111015), weight: 700)),
      gP(159, 136, 72, 72, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [36, 36, 36, 36])),
      gP(22.5, 218, 345, 21, gText(gm('Yannick Mouanga', ''), 17, Color(0xFF111015), weight: 700, align: TextAlign.center, wrap: true), show: demoContent),
      gP(22.5, 242, 345, 15, gText(gm('Génie civil · Vendeur depuis 2025', ''), 12, Color(0xFF57545F), align: TextAlign.center, wrap: true), show: demoContent),
      gP(149.8, 268, 90.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11]), show: demoContent),
      gP(162, 272, 66, 14, gText('Top vendeur', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center), show: demoContent),
      gP(49, 406, 78, 30, gBox(color: Color(0xD98DF03A), layerBlur: 12, oval: true), show: demoContent),
      gP(38, 326, 100, 100, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF0E1A0B), Color(0xFF000000)], stops: [0, 1]), radii: [50, 50, 50, 50]), show: demoContent),
      gP(38, 371, 100, 55, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x008DF03A), Color(0xBF8DF03A)], stops: [0, 1])), show: demoContent),
      gP(85, 324.5, 6, 14.5, gImg('assets/figma/v/bb3ffcce1ff37a.svg'), show: demoContent),
      gP(88.49, 324.68, 6.74, 14.47, gImg('assets/figma/v/27471dd7fd42f6.svg'), show: demoContent),
      gP(91.95, 325.24, 7.47, 14.37, gImg('assets/figma/v/d284dad05a7508.svg'), show: demoContent),
      gP(95.35, 326.15, 8.2, 14.21, gImg('assets/figma/v/10517294c4483c.svg'), show: demoContent),
      gP(98.68, 327.42, 8.91, 13.99, gImg('assets/figma/v/e1ea4c36d346f4.svg'), show: demoContent),
      gP(101.9, 329.04, 9.6, 13.71, gImg('assets/figma/v/7fa6745da4f058.svg'), show: demoContent),
      gP(105, 331, 10.25, 13.36, gImg('assets/figma/v/5d599dbbafa97d.svg'), show: demoContent),
      gP(107.94, 333.27, 10.88, 12.96, gImg('assets/figma/v/54a80ea998f77f.svg'), show: demoContent),
      gP(110.71, 335.85, 11.47, 12.51, gImg('assets/figma/v/63f1426b53fc09.svg'), show: demoContent),
      gP(113.28, 338.71, 12.01, 12.01, gImg('assets/figma/v/737d55eec49986.svg'), show: demoContent),
      gP(115.64, 341.82, 12.51, 11.47, gImg('assets/figma/v/214db4f131827e.svg'), show: demoContent),
      gP(117.77, 345.18, 12.96, 10.88, gImg('assets/figma/v/65aef2437f5b54.svg'), show: demoContent),
      gP(119.64, 348.75, 13.36, 10.25, gImg('assets/figma/v/272d8004580fa4.svg'), show: demoContent),
      gP(121.25, 352.5, 13.71, 9.6, gImg('assets/figma/v/c51c76419add0b.svg'), show: demoContent),
      gP(122.59, 356.41, 13.99, 8.91, gImg('assets/figma/v/7f037c7cf43dc9.svg'), show: demoContent),
      gP(123.64, 360.45, 14.21, 8.2, gImg('assets/figma/v/11c8f3161b72d9.svg'), show: demoContent),
      gP(124.39, 364.58, 14.37, 7.47, gImg('assets/figma/v/2ec4dd1998cc50.svg'), show: demoContent),
      gP(124.85, 368.77, 14.47, 6.74, gImg('assets/figma/v/306f61194c19aa.svg'), show: demoContent),
      gP(125, 373, 14.5, 6, gImg('assets/figma/v/dbfcf58eab0fa1.svg'), show: demoContent),
      gP(124.85, 376.49, 14.47, 6.74, gImg('assets/figma/v/3d8c06ab69f6aa.svg'), show: demoContent),
      gP(124.39, 379.95, 14.37, 7.47, gImg('assets/figma/v/fccc364045e04f.svg'), show: demoContent),
      gP(123.64, 383.35, 14.21, 8.2, gImg('assets/figma/v/cf8a710f8e8599.svg'), show: demoContent),
      gP(122.59, 386.68, 13.99, 8.91, gImg('assets/figma/v/e30dec620ab2ad.svg'), show: demoContent),
      gP(121.25, 389.9, 13.71, 9.6, gImg('assets/figma/v/eff9e29824f079.svg'), show: demoContent),
      gP(119.64, 393, 13.36, 10.25, gImg('assets/figma/v/ff94859845ea41.svg'), show: demoContent),
      gP(117.77, 395.94, 12.96, 10.88, gImg('assets/figma/v/de96a23e2f5ab2.svg'), show: demoContent),
      gP(115.64, 398.71, 12.51, 11.47, gImg('assets/figma/v/5bc145737308b4.svg'), show: demoContent),
      gP(113.28, 401.28, 12.01, 12.01, gImg('assets/figma/v/0e79386414bb45.svg'), show: demoContent),
      gP(110.71, 403.64, 11.47, 12.51, gImg('assets/figma/v/03ec7a382c1926.svg'), show: demoContent),
      gP(107.94, 405.77, 10.88, 12.96, gImg('assets/figma/v/507e4c3daee336.svg'), show: demoContent),
      gP(105, 407.64, 10.25, 13.36, gImg('assets/figma/v/65c370b128388d.svg'), show: demoContent),
      gP(101.9, 409.25, 9.6, 13.71, gImg('assets/figma/v/1a5eca955ab25b.svg'), show: demoContent),
      gP(98.68, 410.59, 8.91, 13.99, gImg('assets/figma/v/12385ed3d53fca.svg'), show: demoContent),
      gP(95.35, 411.64, 8.2, 14.21, gImg('assets/figma/v/68e4b0b172c4d4.svg'), show: demoContent),
      gP(91.95, 412.39, 7.47, 14.37, gImg('assets/figma/v/428c959da65038.svg'), show: demoContent),
      gP(88.49, 412.85, 6.74, 14.47, gImg('assets/figma/v/c500eb012f7fea.svg'), show: demoContent),
      gP(85, 413, 6, 14.5, gImg('assets/figma/v/aa756e6be2a18d.svg'), show: demoContent),
      gP(80.77, 412.85, 6.74, 14.47, gImg('assets/figma/v/24b686e9f79325.svg'), show: demoContent),
      gP(76.58, 412.39, 7.47, 14.37, gImg('assets/figma/v/ec438b825140ee.svg'), show: demoContent),
      gP(72.45, 411.64, 8.2, 14.21, gImg('assets/figma/v/2f17e2a53b98ae.svg'), show: demoContent),
      gP(68.41, 410.59, 8.91, 13.99, gImg('assets/figma/v/6e9292601b25ee.svg'), show: demoContent),
      gP(64.5, 409.25, 9.6, 13.71, gImg('assets/figma/v/35b68d03e7b514.svg'), show: demoContent),
      gP(60.75, 407.64, 10.25, 13.36, gImg('assets/figma/v/347263c84897ec.svg'), show: demoContent),
      gP(57.18, 405.77, 10.88, 12.96, gImg('assets/figma/v/84bacbe0efd450.svg'), show: demoContent),
      gP(53.82, 403.64, 11.47, 12.51, gImg('assets/figma/v/464570a76a441c.svg'), show: demoContent),
      gP(50.71, 401.28, 12.01, 12.01, gImg('assets/figma/v/2577064d0aa798.svg'), show: demoContent),
      gP(47.85, 398.71, 12.51, 11.47, gImg('assets/figma/v/297e504e57dd2b.svg'), show: demoContent),
      gP(45.27, 395.94, 12.96, 10.88, gImg('assets/figma/v/f5c2e0ad5f5851.svg'), show: demoContent),
      gP(43, 393, 13.36, 10.25, gImg('assets/figma/v/945eb72b8fb189.svg'), show: demoContent),
      gP(41.04, 389.9, 13.71, 9.6, gImg('assets/figma/v/bc3a77af8349dc.svg'), show: demoContent),
      gP(39.42, 386.68, 13.99, 8.91, gImg('assets/figma/v/c48dcfd61bcb16.svg'), show: demoContent),
      gP(38.15, 383.35, 14.21, 8.2, gImg('assets/figma/v/5a56b1ca0f939e.svg'), show: demoContent),
      gP(37.24, 379.95, 14.37, 7.47, gImg('assets/figma/v/292ec28bb150d1.svg'), show: demoContent),
      gP(36.68, 376.49, 14.47, 6.74, gImg('assets/figma/v/68493056ed287d.svg'), show: demoContent),
      gP(36.5, 373, 14.5, 6, gImg('assets/figma/v/35fdf7276720cd.svg'), show: demoContent),
      gP(36.68, 368.77, 14.47, 6.74, gImg('assets/figma/v/11990715245205.svg'), show: demoContent),
      gP(37.24, 364.58, 14.37, 7.47, gImg('assets/figma/v/a0dcc25e7c405c.svg'), show: demoContent),
      gP(38.15, 360.45, 14.21, 8.2, gImg('assets/figma/v/66f4e6838a0cac.svg'), show: demoContent),
      gP(39.42, 356.41, 13.99, 8.91, gImg('assets/figma/v/3b5fbc60710f8b.svg'), show: demoContent),
      gP(41.04, 352.5, 13.71, 9.6, gImg('assets/figma/v/ac3d42508f4947.svg'), show: demoContent),
      gP(43, 348.75, 13.36, 10.25, gImg('assets/figma/v/06bb5c46c3c294.svg'), show: demoContent),
      gP(45.27, 345.18, 12.96, 10.88, gImg('assets/figma/v/e3b3d870137ebf.svg'), show: demoContent),
      gP(47.85, 341.82, 12.51, 11.47, gImg('assets/figma/v/0fdb6474e63090.svg'), show: demoContent),
      gP(50.71, 338.71, 12.01, 12.01, gImg('assets/figma/v/473aaca868a2d1.svg'), show: demoContent),
      gP(53.82, 335.85, 11.47, 12.51, gImg('assets/figma/v/12f945b4afe284.svg'), show: demoContent),
      gP(57.18, 333.27, 10.88, 12.96, gImg('assets/figma/v/425968aa6afa59.svg'), show: demoContent),
      gP(60.75, 331, 10.25, 13.36, gImg('assets/figma/v/7898f9d08e7f7e.svg'), show: demoContent),
      gP(64.5, 329.04, 9.6, 13.71, gImg('assets/figma/v/b15a0fb9ee3591.svg'), show: demoContent),
      gP(68.41, 327.42, 8.91, 13.99, gImg('assets/figma/v/bfa1b8455daa47.svg'), show: demoContent),
      gP(72.45, 326.15, 8.2, 14.21, gImg('assets/figma/v/3e458cd27d3134.svg'), show: demoContent),
      gP(76.58, 325.24, 7.47, 14.37, gImg('assets/figma/v/9eeba09b250050.svg'), show: demoContent),
      gP(80.77, 324.68, 6.74, 14.47, gImg('assets/figma/v/4510aeb054463f.svg'), show: demoContent),
      gP(80.667, 344.083, 14.667, 16.833, gImg('assets/figma/v/fb0d9d095f4d85.svg'), show: demoContent),
      gP(60.5, 362, 55, 33, gText(demoContent ? '96%' : '', 27, Color(0xFF9BE88A), weight: 300, inter: true), show: demoContent),
      gP(154, 350, 199, 19, gText(gm('4,9 / 5', ''), 15, Color(0xFF111015), weight: 700, wrap: true), show: demoContent),
      gP(154, 376, 199, 34, gText(demoContent ? '38 avis · 98 % de recommandations' : '', 12, Color(0xFF57545F), lh: 17, wrap: true), show: demoContent),
      gP(40, 464, 51, 16, gText('5 étoiles', 12.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(320, 464, 30, 15, gText(demoContent ? '88 %' : '', 12, Color(0xFF57545F), weight: 600, align: TextAlign.right), show: demoContent),
      gP(40, 486, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4]), show: demoContent),
      gP(40, 486, 272.8, 7, gBox(color: Color(0xFFF9B934), radii: [4, 4, 4, 4]), show: demoContent),
      gP(40, 508, 52, 16, gText('4 étoiles', 12.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(328, 508, 22, 15, gText(demoContent ? '9 %' : '', 12, Color(0xFF57545F), weight: 600, align: TextAlign.right), show: demoContent),
      gP(40, 530, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4]), show: demoContent),
      gP(40, 530, 27.9, 7, gBox(color: Color(0xFFF9B934), radii: [4, 4, 4, 4]), show: demoContent),
      gP(40, 552, 51, 16, gText('3 étoiles', 12.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(328, 552, 22, 15, gText(demoContent ? '3 %' : '', 12, Color(0xFF57545F), weight: 600, align: TextAlign.right), show: demoContent),
      gP(40, 574, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4]), show: demoContent),
      gP(40, 574, 9.3, 7, gBox(color: Color(0xFFF9B934), radii: [4, 4, 4, 4]), show: demoContent),
      gP(24, 612, 154, 19, gText('Badges de confiance', 15, Color(0xFF111015), weight: 700), show: demoContent),
      gP(24, 650, 127.6, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13]), show: demoContent),
      gP(44.3, 656, 87, 14, gText('Livraison rapide', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center), show: demoContent),
      gP(159.6, 650, 127.6, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13]), show: demoContent),
      gP(174.4, 656, 98, 14, gText('Produit conforme', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center), show: demoContent),
      gP(24, 684, 94.6, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13]), show: demoContent),
      gP(34.8, 690, 73, 14, gText('Bon échange', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center), show: demoContent),
      gP(126.6, 684, 94.6, 26, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1, radii: [13, 13, 13, 13]), show: demoContent),
      gP(146.9, 690, 54, 14, gText('Vérifié IUT', 11.5, Color(0xFF4A4854), weight: 500, align: TextAlign.center), show: demoContent),
      gP(24, 724, 93, 19, gText('Derniers avis', 15, Color(0xFF111015), weight: 700), show: demoContent),
      gP(301, 726, 49, 15, gText('Voir tout', 12, Color(0xFF5A3FE0), weight: 500, align: TextAlign.right), show: demoContent),
      gP(352.5, 731, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg'), show: demoContent),
      gP(356, 727.5, 9.5, 13, gImg('assets/figma/v/a365eb17b7a19f.svg'), show: demoContent),
      gP(36, 770, 50, 50, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [25, 25, 25, 25]), show: demoContent),
      gP(98, 774, 71, 17, gText(gm('Aminata B.', ''), 13.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(98, 796, 163, 14, gText('Produit de très bonne qualité !', 11.5, Color(0xFF57545F)), show: demoContent),
      gP(312.8, 784, 39.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11]), show: demoContent),
      gP(322.9, 788, 19, 14, gText(demoContent ? '5.0' : '', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center), show: demoContent),
      gP(98, 828, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 836, 50, 50, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 840, 64, 17, gText(gm('Kouassi T.', ''), 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 862, 192, 14, gText(gm('Très beau produit, livraison un peu …', ''), 11.5, Color(0xFF57545F))),
      gP(312.8, 850, 39.2, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(322.9, 854, 19, 14, gText(demoContent ? '4.0' : '', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(125, 924, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      if (demoContent) gTap(295.5, 718, 61, 32, () { gOpen(context, '31'); }), // audit 01/11 : « Voir tout » n'avait aucun effet
      if (!demoContent) gP(24, 205, 342, 570, const SellerReputationBlock(width: 342)),
    ]);
  }
}
