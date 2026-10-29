// GÉNÉRÉ par tool/figma_export/convert.py — écran 211 (nœud Figma 83:847). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_211 extends ConsumerWidget {
  const G_211({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 930, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 156.9, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 649.8, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 215, 26, gText('Passeport du produit', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 170, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 120, 342, 170, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 228, 309, 23, gText('Lampe en bois recyclé', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 258, 309, 15, gText('Certifié par l’IUT de Douala', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(40, 318, 51, 18, gText('Origine', 14, Color(0xFF111015), weight: 700)),
      gP(40, 352, 81, 16, gText('Département', 12.5, Color(0xFF66636E))),
      gP(259, 352, 91, 16, gText('Génie civil · GC', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 377, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 386, 53, 16, gText('Créateur', 12.5, Color(0xFF66636E))),
      gP(244, 386, 106, 16, gText('Mouanga Yannick', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 411, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 420, 29, 16, gText('Date', 12.5, Color(0xFF66636E))),
      gP(276, 420, 74, 16, gText('12 oct. 2026', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 445, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 454, 61, 16, gText('Identifiant', 12.5, Color(0xFF66636E))),
      gP(256, 454, 94, 16, gText('BE-CERT-0021', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(24, 506, 156, 19, gText('Étapes de fabrication', 15, Color(0xFF111015), weight: 700)),
      gP(33, 566, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 545, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 549.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 544, 175, 17, gText('Récupération des chutes', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 564, 175, 14, gText('Ateliers GC', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 628, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 607, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 611.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 606, 175, 17, gText('Découpe et assemblage', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 626, 175, 14, gText('Équipe de 2 étudiants', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 669, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 673.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 668, 175, 17, gText('Contrôle qualité', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 688, 175, 14, gText('Validé par Dr Tchoupo', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 744, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 759, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 764.943, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 770.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 758, 277, 34, gText('Le certificat est ancré par empreinte numérique ; aucune donnée personnelle n’est publiée.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 830, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 846, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Voir le certificat')),
      gP(140, 864, 110, 18, gText('Voir le certificat', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 916, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
