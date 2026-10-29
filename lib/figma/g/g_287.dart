// GÉNÉRÉ par tool/figma_export/convert.py — écran 287 (nœud Figma 210:16). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_287 extends ConsumerWidget {
  const G_287({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 768, h: 1024, radius: 32, bg: LinearGradient(begin: Alignment(-0.241, -1.103), end: Alignment(0.448, 0.621), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(40, 50, 433, 35, gText('Catalogue du département MMI', 28, Color(0xFF111015), weight: 700)),
      gP(40, 92, 327, 18, gText('18 fiches · 12 publiées · 4 en validation · 2 brouillons', 14, Color(0xFF66636E))),
      gP(40, 132, 688, 48, gBox(color: Color(0xFFFFFFFF), radii: [24, 24, 24, 24])),
      gP(64, 147, 149, 18, gText('Rechercher une fiche…', 14, Color(0xFF66636E))),
      gP(560, 138, 160, 36, gBox(color: Color(0xFF111015), radii: [18, 18, 18, 18]), tap: () => gToast(context, 'Démonstration : + Nouvelle fiche')),
      gP(582, 147, 100, 16, gText('+ Nouvelle fiche', 13, Color(0xFFFFFFFF), weight: 600)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(40, 198, 72, 34, 'Toutes', 13, 600), GChip(156, 198, 72, 34, 'Produits', 13, 600), GChip(266, 198, 72, 34, 'Services', 13, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 17)),
      gP(150, 198, 84, 34, gBox(color: Color(0xFFFFFFFF), radii: [17, 17, 17, 17])),
      gP(260, 198, 84, 34, gBox(color: Color(0xFFFFFFFF), radii: [17, 17, 17, 17])),
      gP(370, 198, 75, 34, gBox(color: Color(0xFFFFFFFF), radii: [17, 17, 17, 17])),
      gP(385, 206, 45, 16, gText('Projets', 13, Color(0xFF111015), weight: 600)),
      gP(40, 256, 216, 210, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(44, 482, 151, 18, gText('Lampe en bois recyclé', 14, Color(0xFF111015), weight: 600)),
      gP(44, 506, 82, 16, gText('25 000 FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(44, 532, 37, 15, gText('Publié', 12, Color(0xFF0F7A52), weight: 700)),
      gP(44, 560, 116, 15, gText('Modifier  ·  Dupliquer', 12, Color(0xFF66636E), weight: 500)),
      gP(272, 256, 216, 210, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(276, 482, 138, 18, gText('Tote bag sérigraphié', 14, Color(0xFF111015), weight: 600)),
      gP(276, 506, 75, 16, gText('8 000 FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(276, 532, 37, 15, gText('Publié', 12, Color(0xFF0F7A52), weight: 700)),
      gP(276, 560, 116, 15, gText('Modifier  ·  Dupliquer', 12, Color(0xFF66636E), weight: 500)),
      gP(504, 256, 216, 210, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(508, 482, 155, 18, gText('Site vitrine boulangerie', 14, Color(0xFF111015), weight: 600)),
      gP(508, 506, 89, 16, gText('150 000 FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(508, 532, 74, 15, gText('En validation', 12, Color(0xFF8F5400), weight: 700)),
      gP(508, 560, 116, 15, gText('Modifier  ·  Dupliquer', 12, Color(0xFF66636E), weight: 500)),
      gP(40, 606, 216, 210, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(44, 832, 141, 18, gText('Chaise ergonomique', 14, Color(0xFF111015), weight: 600)),
      gP(44, 856, 83, 16, gText('45 000 FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(44, 882, 52, 15, gText('Brouillon', 12, Color(0xFF66636E), weight: 700)),
      gP(44, 910, 116, 15, gText('Modifier  ·  Dupliquer', 12, Color(0xFF66636E), weight: 500)),
      gP(272, 606, 216, 210, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(276, 832, 142, 18, gText('Pack identité visuelle', 14, Color(0xFF111015), weight: 600)),
      gP(276, 856, 84, 16, gText('90 000 FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(276, 882, 37, 15, gText('Publié', 12, Color(0xFF0F7A52), weight: 700)),
      gP(276, 910, 116, 15, gText('Modifier  ·  Dupliquer', 12, Color(0xFF66636E), weight: 500)),
      gP(504, 606, 216, 210, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [22, 22, 22, 22])),
      gP(508, 832, 123, 18, gText('Panneau solaire V1', 14, Color(0xFF111015), weight: 600)),
      gP(508, 856, 89, 16, gText('120 000 FCFA', 13, Color(0xFF5A3FE0), weight: 600)),
      gP(508, 882, 74, 15, gText('En validation', 12, Color(0xFF8F5400), weight: 700)),
      gP(508, 910, 116, 15, gText('Modifier  ·  Dupliquer', 12, Color(0xFF66636E), weight: 500)),
      gP(40, 970, 401, 15, gText('Mise en page adaptée : 3 colonnes (mobile : 1 colonne, bureau : tableau)', 12, Color(0xFF66636E))),
    ]);
  }
}
