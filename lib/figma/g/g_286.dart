// GÉNÉRÉ par tool/figma_export/convert.py — écran 286 (nœud Figma 209:1035). Ne pas éditer à la main.
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

class G_286 extends ConsumerWidget {
  const G_286({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(103, 76, 184, 21, gText('Soumissions et équipe', 17, Color(0xFF111015), weight: 500)),
      gP(144, 102, 102, 15, gText('Département MMI', 12, Color(0xFF66636E))),
      gP(24, 128, 178, 18, gText('Soumissions en attente (3)', 14, Color(0xFF111015), weight: 600)),
      gP(24, 156, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 166, 140, 16, gText('Lampe en bois recyclé', 13, Color(0xFF111015), weight: 600)),
      gP(44, 188, 95, 14, gText('Mariam E. · Il y a 2 h', 11, Color(0xFF66636E))),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(250, 174, 50, 28, 'Valider', 11, 600), GChip(306.5, 174, 50, 28, 'Refuser', 11, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFFB42318), radius: 14)),
      gP(24, 230, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 240, 128, 16, gText('Tote bag sérigraphié', 13, Color(0xFF111015), weight: 600)),
      gP(44, 262, 100, 14, gText('Yannick M. · Il y a 5 h', 11, Color(0xFF66636E))),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(250, 248, 50, 28, 'Valider', 11, 600), GChip(306.5, 248, 50, 28, 'Refuser', 11, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFFB42318), radius: 14)),
      gP(24, 304, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 314, 144, 16, gText('Site vitrine boulangerie', 13, Color(0xFF111015), weight: 600)),
      gP(44, 336, 77, 14, gText('Carine M. · Hier', 11, Color(0xFF66636E))),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(250, 322, 50, 28, 'Valider', 11, 600), GChip(306.5, 322, 50, 28, 'Refuser', 11, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFFB42318), radius: 14)),
      gP(24, 392, 149, 18, gText('Équipe et permissions', 14, Color(0xFF111015), weight: 600)),
      gP(24, 420, 342, 260, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 434, 150, 16, gText('Dr Ngono · Responsable', 13, Color(0xFF111015), weight: 600)),
      gP(44, 452, 123, 14, gText('Valider · Publier · Équipe', 11, Color(0xFF66636E))),
      gP(44, 482, 198, 16, gText('Pr Fotso · Référent de validation', 13, Color(0xFF111015), weight: 600)),
      gP(44, 500, 36, 14, gText('Valider', 11, Color(0xFF66636E))),
      gP(44, 530, 207, 16, gText('Sandra T. · Modératrice éditoriale', 13, Color(0xFF111015), weight: 600)),
      gP(44, 548, 75, 14, gText('Éditer · Publier', 11, Color(0xFF66636E))),
      gP(44, 578, 118, 16, gText('Éric B. · Logisticien', 13, Color(0xFF111015), weight: 600)),
      gP(44, 596, 106, 14, gText('Commandes · Stock', 11, Color(0xFF66636E))),
      gP(44, 626, 131, 16, gText('Mariam E. · Étudiante', 13, Color(0xFF111015), weight: 600)),
      gP(44, 644, 46, 14, gText('Déposer', 11, Color(0xFF66636E))),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Inviter un membre')),
      gP(130, 788, 130, 19, gText('Inviter un membre', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
