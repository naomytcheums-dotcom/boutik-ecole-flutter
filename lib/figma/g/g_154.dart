// GÉNÉRÉ par tool/figma_export/convert.py — écran 154 (nœud Figma 60:298). Ne pas éditer à la main.
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
import '../live/chat.dart';
import '../live/share.dart';
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_154 extends ConsumerWidget {
  const G_154({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 856, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 132.48, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 586.16, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 125, 26, gText('Mon dossier', 21, Color(0xFF111015), weight: 700)),
      gP(38, 130, 100, 100, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF0E1A0B), Color(0xFF000000)], stops: [0, 1]), radii: [50, 50, 50, 50])),
      gP(38, 175, 100, 55, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x008DF03A), Color(0xBF8DF03A)], stops: [0, 1]))),
      gP(85, 128.5, 6, 14.5, gImg('assets/figma/v/bb3ffcce1ff37a.svg')),
      gP(88.49, 128.68, 6.74, 14.47, gImg('assets/figma/v/27471dd7fd42f6.svg')),
      gP(91.95, 129.24, 7.47, 14.37, gImg('assets/figma/v/d284dad05a7508.svg')),
      gP(95.35, 130.15, 8.2, 14.21, gImg('assets/figma/v/10517294c4483c.svg')),
      gP(98.68, 131.42, 8.91, 13.99, gImg('assets/figma/v/e1ea4c36d346f4.svg')),
      gP(101.9, 133.04, 9.6, 13.71, gImg('assets/figma/v/7fa6745da4f058.svg')),
      gP(105, 135, 10.25, 13.36, gImg('assets/figma/v/5d599dbbafa97d.svg')),
      gP(107.94, 137.27, 10.88, 12.96, gImg('assets/figma/v/54a80ea998f77f.svg')),
      gP(110.71, 139.85, 11.47, 12.51, gImg('assets/figma/v/63f1426b53fc09.svg')),
      gP(113.28, 142.71, 12.01, 12.01, gImg('assets/figma/v/737d55eec49986.svg')),
      gP(115.64, 145.82, 12.51, 11.47, gImg('assets/figma/v/214db4f131827e.svg')),
      gP(117.77, 149.18, 12.96, 10.88, gImg('assets/figma/v/65aef2437f5b54.svg')),
      gP(119.64, 152.75, 13.36, 10.25, gImg('assets/figma/v/272d8004580fa4.svg')),
      gP(121.25, 156.5, 13.71, 9.6, gImg('assets/figma/v/c51c76419add0b.svg')),
      gP(122.59, 160.41, 13.99, 8.91, gImg('assets/figma/v/7f037c7cf43dc9.svg')),
      gP(123.64, 164.45, 14.21, 8.2, gImg('assets/figma/v/11c8f3161b72d9.svg')),
      gP(124.39, 168.58, 14.37, 7.47, gImg('assets/figma/v/2ec4dd1998cc50.svg')),
      gP(124.85, 172.77, 14.47, 6.74, gImg('assets/figma/v/306f61194c19aa.svg')),
      gP(125, 177, 14.5, 6, gImg('assets/figma/v/dbfcf58eab0fa1.svg')),
      gP(124.85, 180.49, 14.47, 6.74, gImg('assets/figma/v/3d8c06ab69f6aa.svg')),
      gP(124.39, 183.95, 14.37, 7.47, gImg('assets/figma/v/fccc364045e04f.svg')),
      gP(123.64, 187.35, 14.21, 8.2, gImg('assets/figma/v/cf8a710f8e8599.svg')),
      gP(122.59, 190.68, 13.99, 8.91, gImg('assets/figma/v/e30dec620ab2ad.svg')),
      gP(121.25, 193.9, 13.71, 9.6, gImg('assets/figma/v/eff9e29824f079.svg')),
      gP(119.64, 197, 13.36, 10.25, gImg('assets/figma/v/ff94859845ea41.svg')),
      gP(117.77, 199.94, 12.96, 10.88, gImg('assets/figma/v/de96a23e2f5ab2.svg')),
      gP(115.64, 202.71, 12.51, 11.47, gImg('assets/figma/v/5bc145737308b4.svg')),
      gP(113.28, 205.28, 12.01, 12.01, gImg('assets/figma/v/0e79386414bb45.svg')),
      gP(110.71, 207.64, 11.47, 12.51, gImg('assets/figma/v/03ec7a382c1926.svg')),
      gP(107.94, 209.77, 10.88, 12.96, gImg('assets/figma/v/507e4c3daee336.svg')),
      gP(105, 211.64, 10.25, 13.36, gImg('assets/figma/v/65c370b128388d.svg')),
      gP(101.9, 213.25, 9.6, 13.71, gImg('assets/figma/v/1a5eca955ab25b.svg')),
      gP(98.68, 214.59, 8.91, 13.99, gImg('assets/figma/v/12385ed3d53fca.svg')),
      gP(95.35, 215.64, 8.2, 14.21, gImg('assets/figma/v/68e4b0b172c4d4.svg')),
      gP(91.95, 216.39, 7.47, 14.37, gImg('assets/figma/v/428c959da65038.svg')),
      gP(88.49, 216.85, 6.74, 14.47, gImg('assets/figma/v/c500eb012f7fea.svg')),
      gP(85, 217, 6, 14.5, gImg('assets/figma/v/aa756e6be2a18d.svg')),
      gP(80.77, 216.85, 6.74, 14.47, gImg('assets/figma/v/24b686e9f79325.svg')),
      gP(76.58, 216.39, 7.47, 14.37, gImg('assets/figma/v/ec438b825140ee.svg')),
      gP(72.45, 215.64, 8.2, 14.21, gImg('assets/figma/v/2f17e2a53b98ae.svg')),
      gP(68.41, 214.59, 8.91, 13.99, gImg('assets/figma/v/6e9292601b25ee.svg')),
      gP(64.5, 213.25, 9.6, 13.71, gImg('assets/figma/v/35b68d03e7b514.svg')),
      gP(60.75, 211.64, 10.25, 13.36, gImg('assets/figma/v/347263c84897ec.svg')),
      gP(57.18, 209.77, 10.88, 12.96, gImg('assets/figma/v/84bacbe0efd450.svg')),
      gP(53.82, 207.64, 11.47, 12.51, gImg('assets/figma/v/464570a76a441c.svg')),
      gP(50.71, 205.28, 12.01, 12.01, gImg('assets/figma/v/2577064d0aa798.svg')),
      gP(47.85, 202.71, 12.51, 11.47, gImg('assets/figma/v/297e504e57dd2b.svg')),
      gP(45.27, 199.94, 12.96, 10.88, gImg('assets/figma/v/f5c2e0ad5f5851.svg')),
      gP(43, 197, 13.36, 10.25, gImg('assets/figma/v/945eb72b8fb189.svg')),
      gP(41.04, 193.9, 13.71, 9.6, gImg('assets/figma/v/bc3a77af8349dc.svg')),
      gP(39.42, 190.68, 13.99, 8.91, gImg('assets/figma/v/c48dcfd61bcb16.svg')),
      gP(38.15, 187.35, 14.21, 8.2, gImg('assets/figma/v/5a56b1ca0f939e.svg')),
      gP(37.24, 183.95, 14.37, 7.47, gImg('assets/figma/v/292ec28bb150d1.svg')),
      gP(36.68, 180.49, 14.47, 6.74, gImg('assets/figma/v/68493056ed287d.svg')),
      gP(36.5, 177, 14.5, 6, gImg('assets/figma/v/35fdf7276720cd.svg')),
      gP(36.68, 172.77, 14.47, 6.74, gImg('assets/figma/v/11990715245205.svg')),
      gP(37.24, 168.58, 14.37, 7.47, gImg('assets/figma/v/01e303e178d25c.svg')),
      gP(38.15, 164.45, 14.21, 8.2, gImg('assets/figma/v/a413104b6380cf.svg')),
      gP(39.42, 160.41, 13.99, 8.91, gImg('assets/figma/v/366b663a9f7783.svg')),
      gP(41.04, 156.5, 13.71, 9.6, gImg('assets/figma/v/7167d05e94bb4b.svg')),
      gP(43, 152.75, 13.36, 10.25, gImg('assets/figma/v/e98ba674cae6aa.svg')),
      gP(45.27, 149.18, 12.96, 10.88, gImg('assets/figma/v/4e01e2214372e5.svg')),
      gP(47.85, 145.82, 12.51, 11.47, gImg('assets/figma/v/e211e02703dbeb.svg')),
      gP(50.71, 142.71, 12.01, 12.01, gImg('assets/figma/v/4536162728744c.svg')),
      gP(53.82, 139.85, 11.47, 12.51, gImg('assets/figma/v/49509e989beda2.svg')),
      gP(57.18, 137.27, 10.88, 12.96, gImg('assets/figma/v/abf6b11d9dd397.svg')),
      gP(60.75, 135, 10.25, 13.36, gImg('assets/figma/v/7840d8a8082e2d.svg')),
      gP(64.5, 133.04, 9.6, 13.71, gImg('assets/figma/v/361df34499eacf.svg')),
      gP(68.41, 131.42, 8.91, 13.99, gImg('assets/figma/v/aeeeada5022f5c.svg')),
      gP(72.45, 130.15, 8.2, 14.21, gImg('assets/figma/v/3e458cd27d3134.svg')),
      gP(76.58, 129.24, 7.47, 14.37, gImg('assets/figma/v/9eeba09b250050.svg')),
      gP(80.77, 128.68, 6.74, 14.47, gImg('assets/figma/v/4510aeb054463f.svg')),
      gP(80.667, 148.083, 14.667, 16.833, gImg('assets/figma/v/fb0d9d095f4d85.svg')),
      gP(61.5, 166, 53, 33, gText('78%', 27, Color(0xFF9BE88A), weight: 300, inter: true)),
      gP(154, 154, 199, 19, gText('Dossier complet à 78 %', 15, Color(0xFF111015), weight: 700, wrap: true)),
      gP(154, 180, 199, 34, gText('Encore 3 éléments pour postuler partout.', 12, Color(0xFF66636E), lh: 17, wrap: true)),
      gP(24, 254, 69, 19, gText('Checklist', 15, Color(0xFF111015), weight: 700)),
      gP(36, 305, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 313.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 313.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 304, 75, 17, gText('CV importé', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 326, 134, 14, gText('CV_Mariam_Essono.pdf', 11.5, Color(0xFF66636E))),
      gP(306.4, 314, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(319.2, 318, 20, 14, gText('Fait', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 358, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 371, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 379.667, 22.667, 14.333, gImg('assets/figma/v/8c9c6b229b6232.svg')),
      gP(44.667, 392.167, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(44.667, 388, 22.667, 10.167, gImg('assets/figma/v/9870aa4d1427a0.svg')),
      gP(88, 370, 185, 17, gText('Portfolio (3 réalisations min.)', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 392, 76, 14, gText('18 réalisations', 11.5, Color(0xFF66636E))),
      gP(306.4, 380, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(319.2, 384, 20, 14, gText('Fait', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 424, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 437, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 448.167, 22.667, 14.333, gImg('assets/figma/v/081f49ef1bab2c.svg')),
      gP(48, 454, 16, 12.042, gImg('assets/figma/v/c9b26abe594987.svg')),
      gP(88, 436, 141, 17, gText('Certificat de scolarité', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 458, 116, 14, gText('Document manquant', 11.5, Color(0xFF66636E))),
      gP(274.4, 446, 77.6, 22, gBox(color: Color(0xFFFDE6E7), radii: [11, 11, 11, 11])),
      gP(290.7, 450, 45, 14, gText('À fournir', 11, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(88, 490, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 503, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 511.659, 22.693, 22.675, gImg('assets/figma/v/fbc13ecf693ae1.svg')),
      gP(88, 502, 165, 17, gText('Lettre de motivation type', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 524, 116, 14, gText('Recommandé par l’IA', 11.5, Color(0xFF66636E))),
      gP(274.4, 512, 77.6, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(288.7, 516, 49, 14, gText('À rédiger', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(88, 556, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 569, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 578.5, 21.833, 16.833, gImg('assets/figma/v/92f350858b638e.svg')),
      gP(45.5, 580.167, 21, 19.333, gImg('assets/figma/v/f6a87a84fa91d7.svg')),
      gP(88, 568, 147, 17, gText('Numéro Mobile Money', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 590, 94, 14, gText('À vérifier par SMS', 11.5, Color(0xFF66636E))),
      gP(268, 578, 84, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(286.5, 582, 47, 14, gText('À vérifier', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(24, 636, 342, 96, gBox(gradient: LinearGradient(begin: Alignment(-1, 0), end: Alignment(1, 0), colors: [Color(0xFF0F2E4E), Color(0xFF1E4A80)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 654, 32, 32, gBox(color: Color(0xFF111015), oval: true)),
      gP(48.625, 659.5, 18.75, 18.375, gImg('assets/figma/v/d177b28382093d.svg')),
      gP(58, 669.25, 10.5, 10.5, gImg('assets/figma/v/6fd6a3c35cbbc1.svg')),
      gP(84, 653, 269, 18, gText('Conseil de l’IA', 14, Color(0xFFFFFFFF), weight: 700, wrap: true)),
      gP(84, 676, 269, 32, gText('Ajoutez 2 réalisations récentes pour augmenter vos chances de 30 %.', 11.5, Color(0xFFE9E4F5), lh: 16, wrap: true)),
      gP(0, 756, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 772, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gOpen(context, '18c')),
      gP(112.5, 790, 165, 18, gText('Compléter mon dossier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 842, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
