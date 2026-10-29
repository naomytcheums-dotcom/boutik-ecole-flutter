// GÉNÉRÉ par tool/figma_export/convert.py — écran 40 (nœud Figma 36:752). Ne pas éditer à la main.
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

class G_40 extends ConsumerWidget {
  const G_40({super.key});

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
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 189, 26, gText('Demande de devis', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 132, 98, 17, gText('Mariam Essono', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 177, 14, gText('Développement web sur mesure', 11.5, Color(0xFF66636E))),
      gP(24, 200, 127, 16, gText('Objet de la demande', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 220, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 220, 342, 48, GField(hint: '', initial: 'Site vitrine pour mon association', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 233.5, 20.996, 20.996, gImg('assets/figma/v/5cb3a366ba37dc.svg')),
      gP(40.875, 236.875, 7.5, 7.5, gImg('assets/figma/v/af3b58bd7187b4.svg')),
      gP(24, 282, 132, 16, gText('Description du besoin', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 302, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 302, 342, 96, GField(hint: 'Décrivez votre projet, vos attentes et vos contraintes…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 412, 89, 16, gText('Budget estimé', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 432, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 432, 342, 48, GField(hint: '', initial: '50 000 – 80 000 FCFA', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 446.25, 20.25, 15.75, gImg('assets/figma/v/a842b4c78dabfc.svg')),
      gP(38.25, 447.75, 19.5, 18, gImg('assets/figma/v/fbc7a9ade9c600.svg')),
      gP(334.5, 450.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 494, 85, 16, gText('Délai souhaité', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 514, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 514, 342, 48, GField(hint: '', initial: 'Dans 2 semaines', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 529, 19.5, 19.5, gImg('assets/figma/v/99b18d1a251e8c.svg')),
      gP(48, 527.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(42, 527.5, 6, 9, gImg('assets/figma/v/4d0c4aa2d5e373.svg')),
      gP(38.25, 533.5, 19.5, 6, gImg('assets/figma/v/40b22babe144e0.svg')),
      gP(334.5, 532.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 576, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 589, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 608.5, 21, 11, gImg('assets/figma/v/446cc0970fc579.svg')),
      gP(48.833, 598.5, 14.333, 10.167, gImg('assets/figma/v/a73a032c82a1f2.svg')),
      gP(53, 598.5, 6, 16, gImg('assets/figma/v/2f7bb92e5f1a61.svg')),
      gP(88, 588, 191, 17, gText('Joindre un cahier des charges', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 610, 113, 14, gText('PDF, DOC · 5 Mo max', 11.5, Color(0xFF66636E))),
      gP(336.75, 601.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(124.5, 778, 141, 18, gText('Envoyer la demande', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 760, 342, 54, () => gOpen(context, '06')),
    ]);
  }
}
