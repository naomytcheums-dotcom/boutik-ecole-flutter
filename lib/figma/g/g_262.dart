// GÉNÉRÉ par tool/figma_export/convert.py — écran 262 (nœud Figma 190:16). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_262 extends ConsumerWidget {
  const G_262({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 24, color: Color(0xFFF7F6F4), children: [
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, gBox(color: Color(0xFFF4F3F1), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(254.375, 23.375, 10, 10, gImg('assets/figma/r/190_22.png')),
      gP(262.938, 31.938, 2.687, 2.687, gImg('assets/figma/r/190_23.png')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFF6A4DFF), Color(0xFFB46BFF)], stops: [0, 1]), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/fa3cac59b84f88.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(12, 98, 216, 34, gBox(color: Color(0xFFFFFFFF), radii: [10, 10, 10, 10])),
      gP(26.375, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_38.png')),
      gP(33.25, 109.375, 4.375, 4.375, gImg('assets/figma/r/190_39.png')),
      gP(33.25, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_40.png')),
      gP(26.375, 116.25, 4.375, 4.375, gImg('assets/figma/r/190_41.png')),
      gP(52, 107, 70, 15, gText('Accueil B2B', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(27, 148.75, 10, 12.5, gImg('assets/figma/r/190_44.png')),
      gP(33.25, 148.75, 3.75, 3.75, gImg('assets/figma/r/190_45.png')),
      gP(52, 147, 89, 15, gText('Besoins publiés', 12, Color(0xFF55524C), inter: true)),
      gP(25.75, 196.875, 8.75, 3.75, gImg('assets/figma/r/190_48.png')),
      gP(27.625, 189.375, 5, 5, gImg('assets/figma/r/190_49.png')),
      gP(52, 187, 121, 15, gText('Recherche de talents', 12, Color(0xFF55524C), inter: true)),
      gP(25.75, 236.875, 8.75, 3.75, gImg('assets/figma/r/190_52.png')),
      gP(27.625, 229.375, 5, 5, gImg('assets/figma/r/190_53.png')),
      gP(52, 227, 71, 15, gText('Propositions', 12, Color(0xFF55524C), inter: true)),
      gP(27, 268.75, 10, 12.5, gImg('assets/figma/r/190_56.png')),
      gP(33.25, 268.75, 3.75, 3.75, gImg('assets/figma/r/190_57.png')),
      gP(52, 267, 32, 15, gText('Devis', 12, Color(0xFF55524C), inter: true)),
      gP(25.75, 316.875, 8.75, 3.75, gImg('assets/figma/r/190_60.png')),
      gP(27.625, 309.375, 5, 5, gImg('assets/figma/r/190_61.png')),
      gP(52, 307, 82, 15, gText('Collaborations', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 45, 14, gText('Compte', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 57, 11, gText('Boutik-École', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 137, 29, gText('Accueil B2B', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 307, 15, gText('Trouvez des talents, publiez un besoin, lancez un défi.', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(970.125, 90.125, 9.75, 9.75, gImg('assets/figma/r/190_71.png')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1096.667, 91.75, 8.667, 6.5, gImg('assets/figma/r/190_75.png')),
      gP(1102.083, 90.667, 2.167, 2.167, gImg('assets/figma/r/190_76.png')),
      gP(1098.833, 93.917, 2.167, 2.167, gImg('assets/figma/r/190_77.png')),
      gP(1103.167, 97.167, 2.167, 2.167, gImg('assets/figma/r/190_78.png')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(268, 134, 541, 230, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF6C84B), Color(0xFFFBE49A), Color(0xFFF9C860)], stops: [0, 0.5, 1]), radii: [26, 26, 26, 26])),
      gP(284, 150, 170, 24, gBox(color: Color(0xFFFFFFFF), radii: [12, 12, 12, 12])),
      gP(294, 155, 139, 11, gText('Analytique · données en direct', 9.5, Color(0xFF4B4638), weight: 500, inter: true)),
      gP(286, 280, 508, 68, gText('Trouvez les bons talents\nde l’IUT de Douala.', 28, Color(0xFF2A2418), inter: true, lh: 34, wrap: true)),
      gP(829, 134, 423, 100, gBox(color: Color(0xFF0B0B0D), radii: [26, 26, 26, 26])),
      gP(853, 164, 151, 22, gText('Publier un besoin', 18, Color(0xFFFFFFFF), weight: 600, inter: true)),
      gP(853, 194, 273, 14, gText('Décrivez votre projet, les équipes vous répondent.', 11.5, Color(0xFFFFFFFF), inter: true)),
      gP(829, 254, 423, 110, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(853, 274, 183, 17, gText('Lancer un défi d’innovation', 14, Color(0xFF18181B), weight: 600, inter: true)),
      gP(853, 298, 227, 14, gText('Plusieurs équipes proposent une solution.', 11.5, Color(0xFF66636E), inter: true)),
      gP(1167.6, 318, 60.4, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(1182.3, 322, 31, 13, gText('Ouvrir', 10.5, Color(0xFF5A3FE0), weight: 500, inter: true)),
      gP(268, 384, 234, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(284, 398, 101, 13, gText('Entreprises inscrites', 10.5, Color(0xFF66636E), inter: true)),
      gP(284, 418, 41, 27, gText('184', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(284, 448, 63, 13, gText('+ 12 ce mois', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(518, 384, 234, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(534, 398, 59, 13, gText('Briefs reçus', 10.5, Color(0xFF66636E), inter: true)),
      gP(534, 418, 30, 27, gText('63', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(534, 448, 91, 13, gText('+ 8 cette semaine', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(768, 384, 234, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(784, 398, 117, 13, gText('Stages et recrutements', 10.5, Color(0xFF66636E), inter: true)),
      gP(784, 418, 27, 27, gText('27', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(784, 448, 59, 13, gText('+ 4 ce mois', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(1018, 384, 234, 86, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(1034, 398, 120, 13, gText('Délai moyen de réponse', 10.5, Color(0xFF66636E), inter: true)),
      gP(1034, 418, 47, 27, gText('2,4 j', 22, Color(0xFF18181B), weight: 700, inter: true)),
      gP(1034, 448, 29, 13, gText('- 0,6 j', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(268, 494, 150, 17, gText('Talents recommandés', 14, Color(0xFF18181B), weight: 600, inter: true)),
      gP(268, 524, 317.333, 150, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(284, 540, 56, 56, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(352, 546, 97, 16, gText('Mariam Essono', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(352, 568, 128, 13, gText('GI · Développement web', 11, Color(0xFF66636E), inter: true)),
      gP(284, 614, 137.2, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(305.1, 618, 95, 13, gText('Compatibilité 96 %', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(475.333, 626, 94, 30, 'Voir le profil', 10.5, 600), GChip(808.667, 626, 94, 30, 'Voir le profil', 10.5, 600)], selected: 0, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFFFFFFFF), radius: 15, inter: true)),
      gP(601.333, 524, 317.333, 150, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(617.333, 540, 56, 56, gBox(image: 'assets/figma/img/1574e42a325d3a4ac509841e7a5eb5a285a3d991.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(685.333, 546, 87, 16, gText('Aminata Bello', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(685.333, 568, 114, 13, gText('MMI · Identité visuelle', 11, Color(0xFF66636E), inter: true)),
      gP(617.333, 614, 137.2, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(638.433, 618, 95, 13, gText('Compatibilité 96 %', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(808.667, 626, 94, 30, gBox(color: Color(0xFF0B0B0D), radii: [15, 15, 15, 15])),
      gP(934.667, 524, 317.333, 150, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(950.667, 540, 56, 56, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [16, 16, 16, 16])),
      gP(1018.667, 546, 97, 16, gText('Brice Ndoumbe', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(1018.667, 568, 102, 13, gText('GEII · IoT et énergie', 11, Color(0xFF66636E), inter: true)),
      gP(950.667, 614, 137.2, 22, gBox(color: Color(0xFFE8F7EE), radii: [11, 11, 11, 11])),
      gP(971.767, 618, 95, 13, gText('Compatibilité 96 %', 10.5, Color(0xFF126B49), weight: 500, inter: true)),
      gP(1142, 626, 94, 30, gBox(color: Color(0xFF0B0B0D), radii: [15, 15, 15, 15])),
      gP(1158.5, 634, 61, 13, gText('Voir le profil', 10.5, Color(0xFFFFFFFF), weight: 600, inter: true)),
      gP(268, 696, 984, 184, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(290, 714, 85, 16, gText('Défis ouverts', 13, Color(0xFF18181B), weight: 600, inter: true)),
      gP(282, 746, 956, 28, gBox(color: Color(0xFFF4F3F1), radii: [10, 10, 10, 10])),
      gP(290, 753, 20, 12, gText('Défi', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(668, 753, 39, 12, gText('Équipes', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(828, 753, 47, 12, gText('Échéance', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(988, 753, 30, 12, gText('Statut', 10, Color(0xFF66636E), weight: 500, inter: true)),
      gP(290, 794, 149, 14, gText('Application de suivi clients', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(668, 794, 53, 14, gText('7 équipes', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(828, 794, 41, 14, gText('30 nov.', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(988, 794, 38, 14, gText('Ouvert', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(282, 820, 956, 1, gBox(color: Color(0xFFEEECE8))),
      gP(290, 838, 114, 14, gText('Borne solaire mobile', 11.5, Color(0xFF18181B), weight: 600, inter: true)),
      gP(668, 838, 54, 14, gText('4 équipes', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(828, 838, 39, 14, gText('15 nov.', 11.5, Color(0xFF3D3B37), inter: true)),
      gP(988, 838, 38, 14, gText('Ouvert', 11.5, Color(0xFF3D3B37), inter: true)),
    ]);
  }
}
