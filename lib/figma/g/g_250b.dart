// GÉNÉRÉ par tool/figma_export/convert.py — écran 250b (nœud Figma 197:23). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_250b extends ConsumerWidget {
  const G_250b({super.key});

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
      gP(44.325, 84.325, 15.35, 15.35, gImg('assets/figma/v/95a3a562ff2257.svg')),
      gP(44.325, 84.325, 15.35, 15.35, gImg('assets/figma/v/dacf8ca54f8b22.svg')),
      gP(111.5, 82, 167, 21, gText('Nouvelle publication', 17, Color(0xFF111015), weight: 500)),
      gP(301, 78, 65, 27, gBox(color: Color(0xFF111015), radii: [100, 100, 100, 100])),
      gP(313, 84, 41, 15, gText('Publier', 12, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 130, 342, 210, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 12), blurRadius: 24, spreadRadius: 0)], radii: [34, 34, 34, 34])),
      gP(40, 144, 67, 25, gBox(color: Color(0xD9FFFFFF), radii: [100, 100, 100, 100])),
      gP(52, 150, 43, 13, gText('Modifier', 10.5, Color(0xFF111015), weight: 600)),
      gP(268, 144, 82, 25, gBox(color: Color(0xB2111015), radii: [100, 100, 100, 100])),
      gP(280, 150, 58, 13, gText('Couverture', 10.5, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 352, 342, 70, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], radii: [24, 24, 24, 24])),
      gP(40, 364, 313, 36, gRich([('Spot promo pour le parfum Mbella : tournage, montage et étalonnage. #vidéo ', 12.5, 400, Color(0xFF111015)), ('@mb', 12.5, 400, Color(0xFF6A4DFF))], lh: 18, wrap: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 434, 109.6, 30, 'Publication', 11, 500), GChip(139.6, 434, 56.4, 30, 'Reel', 11, 400), GChip(202, 434, 56.4, 30, 'Live', 11, 400), GChip(264.4, 434, 86.8, 30, 'Boutique', 11, 400)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 15)),
      gP(24, 482, 194, 18, gText('Publier aussi sur mes réseaux', 14, Color(0xFF111015), weight: 600)),
      gP(24, 512, 342, 46, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0A403366), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [23, 23, 23, 23])),
      gP(36, 520, 30, 30, gImg('assets/figma/r/197_54.png')),
      gP(40.5, 524.5, 21, 21, gImg('assets/figma/v/b14e2f419ebe3d.svg')),
      gP(44.5, 528.5, 13, 13, gImg('assets/figma/v/3bdc73b9b73329.svg')),
      gP(51.312, 526.312, 8.375, 8.375, gImg('assets/figma/v/503986dde1f68d.svg')),
      gP(78, 520, 61, 16, gText('Instagram', 12.5, Color(0xFF111015), weight: 600)),
      gP(78, 538, 86, 13, gText('@aminata.creates', 10, Color(0xFF66636E))),
      gP(306, 523, 44, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(24, 566, 342, 46, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0A403366), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [23, 23, 23, 23])),
      gP(33, 571, 36, 36, gImg('assets/figma/v/32d0c109fc81be.svg')),
      gP(36.75, 579.438, 28.5, 19.125, gImg('assets/figma/v/d0510db496a139.svg')),
      gP(45.812, 583.062, 11.187, 11.875, gImg('assets/figma/v/b15b773c7a5230.svg')),
      gP(78, 574, 52, 16, gText('YouTube', 12.5, Color(0xFF111015), weight: 600)),
      gP(78, 592, 73, 13, gText('Aminata Studio', 10, Color(0xFF66636E))),
      gP(306, 577, 44, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(24, 620, 342, 46, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0A403366), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [23, 23, 23, 23])),
      gP(33, 625, 36, 36, gImg('assets/figma/v/8d79189c6b44cd.svg')),
      gP(39.328, 629.609, 22.25, 24.762, gImg('assets/figma/v/fb66ceb9f59412.svg')),
      gP(40.422, 630.391, 22.25, 24.762, gImg('assets/figma/v/71018b229b0429.svg')),
      gP(39.875, 630, 22.25, 24.762, gImg('assets/figma/v/6d96f22ff4f7d3.svg')),
      gP(78, 628, 38, 16, gText('TikTok', 12.5, Color(0xFF111015), weight: 600)),
      gP(78, 646, 65, 13, gText('@aminata.vid', 10, Color(0xFF66636E))),
      gP(306, 631, 44, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFDAD7E0), knob: 18)),
      gP(24, 674, 342, 46, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0A403366), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [23, 23, 23, 23])),
      gP(33, 679, 36, 36, gImg('assets/figma/v/9bf666bb945341.svg')),
      gP(43.25, 685.375, 15.75, 25.25, gImg('assets/figma/v/b2bf564bd14a46.svg')),
      gP(78, 682, 62, 16, gText('Facebook', 12.5, Color(0xFF111015), weight: 600)),
      gP(78, 700, 98, 13, gText('Aminata Bello Studio', 10, Color(0xFF66636E))),
      gP(306, 685, 44, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(24, 728, 342, 46, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0A403366), offset: Offset(0, 3), blurRadius: 10, spreadRadius: 0)], radii: [23, 23, 23, 23])),
      gP(33, 733, 36, 36, gImg('assets/figma/v/f83e4a11f261ab.svg')),
      gP(39.25, 744.875, 9.5, 17.25, gImg('assets/figma/v/fbe04227537c7f.svg')),
      gP(38.938, 738.938, 10.125, 10.125, gImg('assets/figma/v/9bdf15055a9571.svg')),
      gP(45.25, 744.625, 16.875, 17.5, gImg('assets/figma/v/499cf4460c1614.svg')),
      gP(78, 736, 51, 16, gText('LinkedIn', 12.5, Color(0xFF111015), weight: 600)),
      gP(78, 754, 105, 13, gText('Connecter ce compte', 10, Color(0xFF66636E))),
      gP(274, 739, 76, 25, gBox(color: Color(0xFFEEE9FF), radii: [100, 100, 100, 100])),
      gP(286, 745, 52, 13, gText('Connecter', 10, Color(0xFF5A3FE0), weight: 600)),
      gP(24, 790, 166, 40, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20])),
      gP(40.333, 800.333, 19.333, 19.333, gImg('assets/figma/v/94aebfd05b72e8.svg')),
      gP(47, 803, 8.667, 11.333, gImg('assets/figma/v/92fb5f1c9637a7.svg')),
      gP(68, 802, 48, 16, gText('Planifier', 12.5, Color(0xFF111015), weight: 500)),
      gP(200, 790, 166, 40, gBox(color: Color(0xFFEEE9FF), radii: [20, 20, 20, 20]), tap: () => gToast(context, 'Démonstration : Propulser')),
      gP(217.75, 801.167, 16.5, 17.667, gImg('assets/figma/v/0a4ae151139fec.svg')),
      gP(246, 802, 59, 16, gText('Propulser', 12.5, Color(0xFF5A3FE0), weight: 600)),
      gP(296, 386, 26, 26, gBox(color: Color(0xFFEDE7FF), oval: true)),
      gP(304, 390, 13, 18, gText('#', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(326, 386, 26, 26, gBox(color: Color(0xFFEDE7FF), oval: true)),
      gP(332, 390, 13, 18, gText('@', 14, Color(0xFF5A3FE0), weight: 700)),
      gP(24, 428, 342, 200, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x38332666), offset: Offset(0, 10), blurRadius: 28, spreadRadius: 0)], radii: [22, 22, 22, 22])),
      gP(42, 442, 111, 15, gText('Comptes suggérés', 12, Color(0xFF6B6877), weight: 600)),
      gP(42, 468, 38, 38, gBox(color: Color(0xFFF4B48A), oval: true)),
      gP(55, 477, 14, 19, gText('M', 15, Color(0xFF111015), weight: 700)),
      gP(92, 471, 113, 18, gText('@mbella.parfum', 14, Color(0xFF111015), weight: 600)),
      gP(92, 489, 102, 14, gText('Mbella SARL · Client', 11, Color(0xFF6B6877))),
      gP(42, 520, 38, 38, gBox(color: Color(0xFFCBB8FF), oval: true)),
      gP(55, 529, 14, 19, gText('M', 15, Color(0xFF111015), weight: 700)),
      gP(92, 523, 107, 18, gText('@mbella.studio', 14, Color(0xFF111015), weight: 600)),
      gP(92, 541, 114, 14, gText('Atelier Mbella · Douala', 11, Color(0xFF6B6877))),
      gP(42, 572, 38, 38, gBox(color: Color(0xFF9ED8C6), oval: true)),
      gP(55, 581, 14, 19, gText('M', 15, Color(0xFF111015), weight: 700)),
      gP(92, 575, 113, 18, gText('@mbarga.carine', 14, Color(0xFF111015), weight: 600)),
      gP(92, 593, 137, 14, gText('Carine Mbarga · Génie civil', 11, Color(0xFF6B6877))),
      gTap(301, 78, 65, 27, () => gOpen(context, '244')),
    ]);
  }
}
