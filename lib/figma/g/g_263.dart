// GÉNÉRÉ par tool/figma_export/convert.py — écran 263 (nœud Figma 190:149). Ne pas éditer à la main.
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

class G_263 extends ConsumerWidget {
  const G_263({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 24, color: Color(0xFFF7F6F4), children: [
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(254.375, 23.375, 10, 10, gImg('assets/figma/r/190_155.png')),
      gP(262.938, 31.938, 2.687, 2.687, gImg('assets/figma/r/190_156.png')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFF6A4DFF), Color(0xFFB46BFF)], stops: [0, 1]), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/fa3cac59b84f88.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(26.375, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_170.png')),
      gP(33.25, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_171.png')),
      gP(33.25, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_172.png')),
      gP(26.375, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_173.png')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(27, 148.75, 10, 12.5, gImg('assets/figma/r/190_176.png')),
      gP(33.25, 148.75, 3.75, 3.75, gImg('assets/figma/r/190_177.png')),
      gP(52, 147, 58, 15, gText('Catalogue', 12, Color(0xFF55524C), inter: true)),
      gP(12, 178, 216, 34, gBox(color: Color(0xFFFFFFFF), radii: [10, 10, 10, 10])),
      gP(26.375, 189.375, 11.25, 11.25, gImg('assets/figma/r/190_181.png')),
      gP(28.875, 191.875, 2.5, 2.5, gImg('assets/figma/r/190_182.png')),
      gP(28.25, 194.58, 9.375, 6.045, gImg('assets/figma/r/190_183.png')),
      gP(52, 187, 77, 15, gText('Médiathèque', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(25.75, 236.875, 8.75, 3.75, gImg('assets/figma/r/190_186.png')),
      gP(27.625, 229.375, 5, 5, gImg('assets/figma/r/190_187.png')),
      gP(52, 227, 54, 15, gText('Étudiants', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 45, 14, gText('Compte', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 57, 11, gText('Boutik-École', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 152, 29, gText('Médiathèque', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 317, 15, gText('Images, vidéos, preuves et documents des productions.', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(970.125, 90.125, 9.75, 9.75, gImg('assets/figma/r/190_197.png')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1096.667, 91.75, 8.667, 6.5, gImg('assets/figma/r/190_201.png')),
      gP(1102.083, 90.667, 2.167, 2.167, gImg('assets/figma/r/190_202.png')),
      gP(1098.833, 93.917, 2.167, 2.167, gImg('assets/figma/r/190_203.png')),
      gP(1103.167, 97.167, 2.167, 2.167, gImg('assets/figma/r/190_204.png')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(268, 134, 62, 34, 'Tout', 11.5, 500), GChip(338, 134, 78, 34, 'Images', 11.5, 500), GChip(424, 134, 78, 34, 'Vidéos', 11.5, 500), GChip(510, 134, 102, 34, 'Documents', 11.5, 500), GChip(620, 134, 86, 34, 'Preuves', 11.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 17, border: Color(0xFFE6E3DE), inter: true)),
      gP(1082, 134, 170, 36, gBox(color: Color(0xFF0B0B0D), radii: [18, 18, 18, 18]), tap: () => uploadMedia(context, ref)),
      gP(1110.5, 145, 113, 14, gText('Téléverser un média', 11.5, Color(0xFFFFFFFF), weight: 600, inter: true)),
      gP(268, 190, 231, 170, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(272, 370, 151, 15, gText('Lampe en bois recyclé.jpg', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(272, 390, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(437, 200, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(448.5, 204, 31, 13, gText('Image', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(276, 200, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(290.7, 204, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(519, 190, 231, 170, gBox(image: 'assets/figma/img/4ca68f79023605aecb4f83724629d508e921e885.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(523, 370, 110, 15, gText('Jus de bissap.mp4', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(523, 390, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(688, 200, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(700, 204, 30, 13, gText('Vidéo', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(527, 200, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(541.7, 204, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(770, 190, 231, 170, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(774, 370, 80, 15, gText('Kit solaire.jpg', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(774, 390, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(939, 200, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(950.5, 204, 31, 13, gText('Image', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(778, 200, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(792.7, 204, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(1021, 190, 231, 170, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(1025, 370, 136, 15, gText('Application de suivi.jpg', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(1025, 390, 142, 13, gText('Droits : établissement · privé', 10.5, Color(0xFF66636E), inter: true)),
      gP(1190, 200, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(1201.5, 204, 31, 13, gText('Image', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1029, 200, 54, 22, gBox(color: Color(0xFFFFF1D6), radii: [11, 11, 11, 11])),
      gP(1043, 204, 26, 13, gText('Privé', 10.5, Color(0xFFB26A00), weight: 500, inter: true)),
      gP(268, 460, 231, 170, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(272, 640, 130, 15, gText('Affiche concours.mp4', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(272, 660, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(437, 470, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(449, 474, 30, 13, gText('Vidéo', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(276, 470, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(290.7, 474, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(519, 460, 231, 170, gBox(image: 'assets/figma/img/4b7b6cea2f4622846841cd8342842e81fa1ed891.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(523, 640, 125, 15, gText('Maquette de pont.jpg', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(523, 660, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(688, 470, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(699.5, 474, 31, 13, gText('Image', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(527, 470, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(541.7, 474, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(770, 460, 231, 170, gBox(image: 'assets/figma/img/e3a1b5107e8b2a5b3a542598c9ff80a2e1376935.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(774, 640, 116, 15, gText('Tableau de bord.jpg', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(774, 660, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(939, 470, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(950.5, 474, 31, 13, gText('Image', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(778, 470, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(792.7, 474, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(1021, 460, 231, 170, gBox(image: 'assets/figma/img/906aab77f069a2bc93c3049468e70ffe2accdb89.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(1025, 640, 88, 15, gText('Atelier RH.mp4', 12, Color(0xFF18181B), weight: 600, inter: true)),
      gP(1025, 660, 147, 13, gText('Droits : établissement · public', 10.5, Color(0xFF66636E), inter: true)),
      gP(1190, 470, 54, 22, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(1202, 474, 30, 13, gText('Vidéo', 10.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1029, 470, 60.4, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(1043.7, 474, 31, 13, gText('Public', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(268, 744, 403, 14, gText('Stockage utilisé : 14,2 Go sur 50 Go · URLs signées pour les fichiers privés', 11.5, Color(0xFF66636E), inter: true)),
    ]);
  }
}
