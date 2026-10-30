// GÉNÉRÉ par tool/figma_export/convert.py — écran 288 (nœud Figma 210:68). Ne pas éditer à la main.
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
import '../live/engage.dart';
import '../live/lots.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_288 extends ConsumerWidget {
  const G_288({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 800, color: Color(0xFFF7F6F4), children: [
      gP(0, 0, 240, 800, gBox(color: Color(0xFFF1EFEC))),
      gP(24, 24, 113, 22, gText('Boutik-École', 18, Color(0xFF111015), weight: 700, inter: true)),
      gP(24, 84, 47, 13, gText('Principal', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(28, 114, 101, 16, gText('Tableau de bord', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(12, 146, 216, 36, gBox(color: Color(0xFFFFFFFF), radii: [10, 10, 10, 10])),
      gP(28, 154, 65, 16, gText('Catalogue', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(28, 194, 79, 16, gText('Soumissions', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(28, 234, 79, 16, gText('Commandes', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(24, 284, 42, 13, gText('Gestion', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(28, 310, 137, 16, gText('Équipe et permissions', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(28, 350, 82, 16, gText('Médiathèque', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(28, 390, 56, 16, gText('Finances', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(240, 0, 1040, 64, gBox(color: Color(0xFFFFFFFF))),
      gP(264, 14, 360, 36, GField(hint: 'Rechercher une fiche…', size: 13, hintColor: Color(0xFF66636E), weight: 400, padL: 18, inter: true)),
      gP(1140, 14, 110, 36, gBox(color: Color(0xFF111015), radii: [18, 18, 18, 18]), tap: () => exportCatalog(context, ref)),
      gP(1170, 23, 55, 16, gText('Exporter', 13, Color(0xFFFFFFFF), weight: 600, inter: true)),
      gP(264, 88, 372, 29, gText('Catalogue du département MMI', 24, Color(0xFF111015), weight: 700, inter: true)),
      gP(264, 122, 204, 16, gText('18 fiches · filtrer, modifier, publier', 13, Color(0xFF66636E), inter: true)),
      gP(1086, 88, 164, 40, gBox(color: Color(0xFF111015), radii: [20, 20, 20, 20]), tap: () => gOpen(context, '58')),
      gP(1110, 99, 102, 16, gText('+ Nouvelle fiche', 13, Color(0xFFFFFFFF), weight: 600, inter: true)),
      gP(264, 160, 986, 600, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(296, 180, 32, 15, gText('Fiche', 12, Color(0xFF66636E), weight: 600, inter: true)),
      gP(620, 180, 29, 15, gText('Type', 12, Color(0xFF66636E), weight: 600, inter: true)),
      gP(740, 180, 23, 15, gText('Prix', 12, Color(0xFF66636E), weight: 600, inter: true)),
      gP(880, 180, 36, 15, gText('Statut', 12, Color(0xFF66636E), weight: 600, inter: true)),
      gP(1010, 180, 56, 15, gText('Mis à jour', 12, Color(0xFF66636E), weight: 600, inter: true)),
      gP(1130, 180, 45, 15, gText('Actions', 12, Color(0xFF66636E), weight: 600, inter: true)),
      gP(276, 270, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 220, 40, 40, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 230, 141, 16, gText('Lampe en bois recyclé', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 230, 45, 16, gText('Produit', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 230, 81, 16, gText('25 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 230, 40, 16, gText('Publié', 13, Color(0xFF0F7A52), weight: 700, inter: true)),
      gP(1010, 230, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 230, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 330, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 280, 40, 40, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 290, 130, 16, gText('Tote bag sérigraphié', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 290, 47, 16, gText('Service', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 290, 73, 16, gText('8 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 290, 40, 16, gText('Publié', 13, Color(0xFF0F7A52), weight: 700, inter: true)),
      gP(1010, 290, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 290, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 390, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 340, 40, 40, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 350, 146, 16, gText('Site vitrine boulangerie', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 350, 45, 16, gText('Produit', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 350, 88, 16, gText('150 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 350, 82, 16, gText('En validation', 13, Color(0xFF8F5400), weight: 700, inter: true)),
      gP(1010, 350, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 350, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 450, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 400, 40, 40, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 410, 130, 16, gText('Chaise ergonomique', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 410, 45, 16, gText('Produit', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 410, 82, 16, gText('45 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 410, 57, 16, gText('Brouillon', 13, Color(0xFF66636E), weight: 700, inter: true)),
      gP(1010, 410, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 410, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 510, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 460, 40, 40, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 470, 134, 16, gText('Pack identité visuelle', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 470, 47, 16, gText('Service', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 470, 82, 16, gText('90 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 470, 40, 16, gText('Publié', 13, Color(0xFF0F7A52), weight: 700, inter: true)),
      gP(1010, 470, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 470, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 570, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 520, 40, 40, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 530, 119, 16, gText('Panneau solaire V1', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 530, 45, 16, gText('Produit', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 530, 88, 16, gText('120 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 530, 82, 16, gText('En validation', 13, Color(0xFF8F5400), weight: 700, inter: true)),
      gP(1010, 530, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 530, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 630, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 580, 40, 40, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 590, 137, 16, gText('Lampe de bureau LED', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 590, 45, 16, gText('Produit', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 590, 82, 16, gText('35 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 590, 40, 16, gText('Publié', 13, Color(0xFF0F7A52), weight: 700, inter: true)),
      gP(1010, 590, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 590, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 690, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 640, 40, 40, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 650, 154, 16, gText('Maquette immeuble R+2', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 650, 47, 16, gText('Service', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 650, 82, 16, gText('60 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 650, 57, 16, gText('Brouillon', 13, Color(0xFF66636E), weight: 700, inter: true)),
      gP(1010, 650, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 650, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gP(276, 750, 962, 1, gBox(color: Color(0xFFEEECE8))),
      gP(296, 700, 40, 40, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [10, 10, 10, 10])),
      gP(350, 710, 199, 16, gText('Application de gestion de stock', 13, Color(0xFF111015), weight: 600, inter: true)),
      gP(620, 710, 45, 16, gText('Produit', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(740, 710, 90, 16, gText('200 000 FCFA', 13, Color(0xFF111015), weight: 500, inter: true)),
      gP(880, 710, 82, 16, gText('En validation', 13, Color(0xFF8F5400), weight: 700, inter: true)),
      gP(1010, 710, 70, 16, gText('12/10/2026', 13, Color(0xFF66636E), inter: true)),
      gP(1130, 710, 114, 16, gText('Modifier  ·  Publier', 13, Color(0xFF5A3FE0), weight: 600, inter: true)),
      gTap(20, 342, 98, 32, () { gOpen(context, '263'); }), // lien métier 288 -> 263
    ]);
  }
}
