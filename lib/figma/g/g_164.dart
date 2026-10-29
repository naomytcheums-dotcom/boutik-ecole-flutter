// GÉNÉRÉ par tool/figma_export/convert.py — écran 164 (nœud Figma 60:1053). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_164 extends ConsumerWidget {
  const G_164({super.key});

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
      gP(76, 70, 122, 26, gText('Team Innov’', 21, Color(0xFF111015), weight: 700)),
      gP(76, 96, 168, 15, gText('Orange Digital Challenge · J-2', 12, Color(0xFF66636E))),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 120, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 128.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(32, 158, 24, 14, gText('Idée', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(117.167, 158, 55, 14, gText('Prototype', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(231.833, 158, 27, 14, gText('Pitch', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(329, 158, 34, 14, gText('Dépôt', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 342, 148, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 202, 159, 16, gText('Avancement du prototype', 12.5, Color(0xFF111015), weight: 600)),
      gP(323, 202, 27, 15, gText('65%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 224, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 224, 201.5, 7, gBox(color: Color(0xFF6A4DFF), radii: [4, 4, 4, 4])),
      gP(40, 246, 120, 16, gText('Présentation (pitch)', 12.5, Color(0xFF111015), weight: 600)),
      gP(321, 246, 29, 15, gText('30%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 268, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 268, 93, 7, gBox(color: Color(0xFF1E4A80), radii: [4, 4, 4, 4])),
      gP(40, 290, 95, 16, gText('Documentation', 12.5, Color(0xFF111015), weight: 600)),
      gP(322, 290, 28, 15, gText('45%', 12, Color(0xFF66636E), weight: 600, align: TextAlign.right)),
      gP(40, 312, 310, 7, gBox(color: Color(0xFFF2EFF6), radii: [4, 4, 4, 4])),
      gP(40, 312, 139.5, 7, gBox(color: Color(0xFF1F9D6B), radii: [4, 4, 4, 4])),
      gP(24, 350, 136, 19, gText('Tâches de l’équipe', 15, Color(0xFF111015), weight: 700)),
      gP(33, 410, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 389, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 393.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 388, 305, 17, gText('Maquettes validées', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 408, 305, 14, gText('Aminata · Terminé', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 472, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 451, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 450, 305, 17, gText('API de paiement', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 470, 305, 14, gText('Mariam · En cours', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 513, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 512, 305, 17, gText('Capteurs IoT', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 532, 305, 14, gText('Brice · À démarrer', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 588, 53, 19, gText('Mentor', 15, Color(0xFF111015), weight: 700)),
      gP(24, 626, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 634, 50, 50, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [25, 25, 25, 25])),
      gP(98, 638, 104, 17, gText('Dr Paul Tchoupo', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 660, 121, 14, gText('Mentor · Génie logiciel', 11.5, Color(0xFF66636E))),
      gP(287.2, 648, 64.8, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(295.6, 652, 48, 14, gText('Message', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Discussion d’équipe')),
      gP(34.5, 778, 142, 18, gText('Discussion d’équipe', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Déposer le projet')),
      gP(224, 778, 121, 18, gText('Déposer le projet', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
