// GÉNÉRÉ par tool/figma_export/convert.py — écran 170 (nœud Figma 61:2). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_170 extends ConsumerWidget {
  const G_170({super.key});

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
      gP(76, 70, 218, 26, gText('Signaler une annonce', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 66, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 145, 17, gText('Lampe en bois recyclé', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 196, 14, gText('25 000 FCFA · Vendeur : Y. Mouanga', 11.5, Color(0xFF66636E))),
      gP(24, 200, 154, 19, gText('Motif du signalement', 15, Color(0xFF111015), weight: 700)),
      gP(24, 238, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 241.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(54, 239, 315, 18, gText('Annonce frauduleuse ou trompeuse', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 274, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 275, 315, 18, gText('Photos ou description non conformes', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 310, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 311, 315, 36, gText('Prix anormal ou demande de paiement hors plateforme', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 360, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 361, 315, 18, gText('Contenu inapproprié', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 396, 130, 16, gText('Précisions (facultatif)', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 416, 342, 96, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(24, 416, 342, 96, GField(hint: 'Expliquez ce qui pose problème…', size: 13.5, hintColor: Color(0xFF66636E), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 526, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 549.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 555.416, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 561.083, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 540, 277, 51, gText('Votre signalement est anonyme pour le vendeur et examiné par l’équipe de modération sous 24 h.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Annuler')),
      gP(78.5, 778, 54, 18, gText('Annuler', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE5484D), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Envoyer le signalement')),
      gP(204, 778, 161, 18, gText('Envoyer le signalement', 14.5, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
