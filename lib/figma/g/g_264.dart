// GÉNÉRÉ par tool/figma_export/convert.py — écran 264 (nœud Figma 190:275). Ne pas éditer à la main.
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
import '../live/lots.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_264 extends ConsumerWidget {
  const G_264({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 24, color: Color(0xFFF7F6F4), children: [
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(254.375, 23.375, 10, 10, gImg('assets/figma/r/190_281.png')),
      gP(262.938, 31.938, 2.687, 2.687, gImg('assets/figma/r/190_282.png')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFF6A4DFF), Color(0xFFB46BFF)], stops: [0, 1]), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/fa3cac59b84f88.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(26.375, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_296.png')),
      gP(33.25, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_297.png')),
      gP(33.25, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_298.png')),
      gP(26.375, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_299.png')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(12, 138, 216, 34, gBox(color: Color(0xFFFFFFFF), radii: [10, 10, 10, 10])),
      gP(27, 148.75, 10, 12.5, gImg('assets/figma/r/190_303.png')),
      gP(33.25, 148.75, 3.75, 3.75, gImg('assets/figma/r/190_304.png')),
      gP(52, 147, 100, 15, gText('Pages éditoriales', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(26.375, 189.375, 11.25, 11.25, gImg('assets/figma/r/190_307.png')),
      gP(28.875, 191.875, 2.5, 2.5, gImg('assets/figma/r/190_308.png')),
      gP(28.25, 194.58, 9.375, 6.045, gImg('assets/figma/r/190_309.png')),
      gP(52, 187, 56, 15, gText('Bannières', 12, Color(0xFF55524C), inter: true)),
      gP(24.5, 227.5, 15, 15, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(25.75, 229.37, 11.88, 11.88, gImg('assets/figma/r/190_312.png')),
      gP(52, 227, 23, 15, gText('FAQ', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 45, 14, gText('Compte', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 57, 11, gText('Boutik-École', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 198, 29, gText('Pages éditoriales', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 264, 15, gText('Gérez les pages, bannières et contenus d’aide.', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(970.125, 90.125, 9.75, 9.75, gImg('assets/figma/r/190_322.png')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1096.667, 91.75, 8.667, 6.5, gImg('assets/figma/r/190_326.png')),
      gP(1102.083, 90.667, 2.167, 2.167, gImg('assets/figma/r/190_327.png')),
      gP(1098.833, 93.917, 2.167, 2.167, gImg('assets/figma/r/190_328.png')),
      gP(1103.167, 97.167, 2.167, 2.167, gImg('assets/figma/r/190_329.png')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(268, 134, 571, 360, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(290, 152, 39, 16, gText('Pages', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(282, 184, 543, 28, gBox(color: Color(0xFFF4F3F1), radii: [10, 10, 10, 10])),
      gP(290, 191, 25, 12, gText('Page', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(518, 191, 73, 12, gText('Dernière modif.', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(668, 191, 30, 12, gText('Statut', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(290, 232, 42, 14, gText('Accueil', 11.5, Color(0xFF18181B), weight: 600, inter: true), tap: () => gTab(context, '03')),
      gP(518, 232, 82, 14, gText('22 oct. · Admin', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(668, 232, 40, 14, gText('Publiée', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 258, 543, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 276, 141, 14, gText('À propos de Boutik-École', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(518, 276, 83, 14, gText('20 oct. · Admin', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(668, 276, 40, 14, gText('Publiée', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 302, 543, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 320, 23, 14, gText('FAQ', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(518, 320, 90, 14, gText('18 oct. · Support', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(668, 320, 40, 14, gText('Publiée', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 346, 543, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 364, 119, 14, gText('Conditions générales', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(518, 364, 97, 14, gText('15 oct. · Juridique', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(668, 364, 47, 14, gText('Brouillon', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 390, 543, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 408, 95, 14, gText('Mentions légales', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(518, 408, 97, 14, gText('15 oct. · Juridique', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(668, 408, 47, 14, gText('Brouillon', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 434, 543, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 452, 69, 14, gText('Page impact', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(518, 452, 81, 14, gText('12 oct. · Admin', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(668, 452, 40, 14, gText('Publiée', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(859, 134, 393, 480, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(881, 154, 96, 17, gText('Page : Accueil', 14, Color(0xFF18181B), weight: 600, inter: true)),
      gP(881, 190, 349, 40, GField(hint: '', initial: 'Titre : Les talents de l’IUT de Douala', size: 11.5, hintColor: Color(0xFF111015), weight: 400, padL: 14, inter: true)),
      gP(881, 246, 349, 220, gBox(color: Color(0xFFF4F3F1), radii: [14, 14, 14, 14])),
      gP(895, 262, 263, 14, gText('Bloc héros · texte · liste de produits en vedette…', 11.5, Color(0xFF66636E), inter: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(881, 500, 120, 36, 'Publier', 11.5, 600), GChip(1001, 500, 120, 36, 'Aperçu', 11.5, 500)], selected: 0, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 18, inter: true)),
      gP(1011, 500, 100, 36, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [18, 18, 18, 18]), tap: () => previewPagesDialog(context)),
      gP(881, 560, 165, 13, gText('Historique des versions conservé', 10.5, Color(0xFF66636E), inter: true)),
    ]);
  }
}
