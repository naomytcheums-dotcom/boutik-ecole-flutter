// GÉNÉRÉ par tool/figma_export/convert.py — écran 212 (nœud Figma 83:911). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_212 extends ConsumerWidget {
  const G_212({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(24, 70, 201, 26, gText('Vérifier un certificat', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 133, 40, 40, gBox(color: Color(0xFFDDF5EC), radii: [13, 13, 13, 13])),
      gP(45.5, 142.5, 11.833, 11.833, gImg('assets/figma/v/f14cedcc4f021a.svg')),
      gP(54.667, 142.5, 11.833, 11.833, gImg('assets/figma/v/f14cedcc4f021a.svg')),
      gP(45.5, 151.667, 11.833, 11.833, gImg('assets/figma/v/f14cedcc4f021a.svg')),
      gP(54.667, 151.667, 11.833, 11, gImg('assets/figma/v/8e62817e02b741.svg')),
      gP(88, 132, 100, 17, gText('BE-CERT-0021', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 154, 95, 14, gText('Scanné à l’instant', 11.5, Color(0xFF66636E))),
      gP(261.6, 142, 90.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(273.8, 146, 66, 14, gText('Authentique', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 200, 342, 150, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 200, 342, 150, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 288, 309, 23, gText('Lampe en bois recyclé', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 318, 309, 15, gText('Émis par l’IUT de Douala · GC', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(24, 364, 342, 188, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 378, 171, 18, gText('Résultat de la vérification', 14, Color(0xFF111015), weight: 700)),
      gP(40, 412, 37, 16, gText('Statut', 12.5, Color(0xFF66636E))),
      gP(274, 412, 76, 16, gText('Émis · vérifié', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 437, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 446, 41, 16, gText('Émis le', 12.5, Color(0xFF66636E))),
      gP(276, 446, 74, 16, gText('12 oct. 2026', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 471, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 480, 62, 16, gText('Empreinte', 12.5, Color(0xFF66636E))),
      gP(286, 480, 64, 16, gText('a3f9…7c21', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 505, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 514, 53, 16, gText('Révoqué', 12.5, Color(0xFF66636E))),
      gP(325, 514, 25, 16, gText('Non', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 566, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 581, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.909, 586.92, 20.171, 20.165, gImg('assets/figma/v/e183fc825ad532.svg')),
      gP(46.875, 592.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 580, 277, 34, gText('Cette page est publique : n’importe qui peut vérifier l’authenticité en scannant le QR code.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(124, 778, 142, 18, gText('Scanner un autre QR', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 780, 342, 50, () => gOpen(context, '206')),
    ]);
  }
}
