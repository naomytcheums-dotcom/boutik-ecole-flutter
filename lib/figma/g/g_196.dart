// GÉNÉRÉ par tool/figma_export/convert.py — écran 196 (nœud Figma 83:352). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_196 extends ConsumerWidget {
  const G_196({super.key});

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
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 191, 26, gText('Dossier #BR-0412', 21, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 120, 54, 34, 'Fil', 12.5, 600), GChip(86, 120, 85.2, 34, 'Fichiers', 12.5, 500), GChip(179.2, 120, 92.6, 34, 'Paiements', 12.5, 500), GChip(279.8, 120, 70.4, 34, 'Équipe', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 168, 40, 40, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [20, 20, 20, 20])),
      gP(54, 168, 40, 40, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [20, 20, 20, 20])),
      gP(84, 168, 40, 40, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [20, 20, 20, 20])),
      gP(114, 168, 40, 40, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, radii: [20, 20, 20, 20])),
      gP(24, 222, 253.08, 58, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28]), tap: () => gToast(context, 'Démonstration : Bonjour, voici les trois pistes de logo. Qu’en pensez-vous ?')),
      gP(38, 233, 228.08, 36, gText('Bonjour, voici les trois pistes de logo. Qu’en pensez-vous ?', 12.5, Color(0xFF111015), lh: 18, wrap: true)),
      gP(30, 284, 24, 13, gText('10:12', 10, Color(0xFF8793A5))),
      gP(112.92, 306, 253.08, 58, gBox(color: Color(0xFF111015), radii: [18, 18, 18, 18]), tap: () => gToast(context, 'Démonstration : La piste 2 me plaît. Pouvez-vous essayer une version plus sobre ?')),
      gP(126.92, 317, 228.08, 36, gText('La piste 2 me plaît. Pouvez-vous essayer une version plus sobre ?', 12.5, Color(0xFFFFFFFF), lh: 18, wrap: true)),
      gP(332, 368, 28, 13, gText('10:20', 10, Color(0xFF8793A5), align: TextAlign.right)),
      gP(24, 390, 253.08, 40, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1, radii: [18, 18, 18, 18]), tap: () => gToast(context, 'Démonstration : Bien sûr, nouvelle version sous 48 h.')),
      gP(38, 401, 228.08, 18, gText('Bien sûr, nouvelle version sous 48 h.', 12.5, Color(0xFF111015), lh: 18, wrap: true)),
      gP(30, 434, 27, 13, gText('10:24', 10, Color(0xFF8793A5))),
      gP(36, 483, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 491.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 491.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 482, 159, 17, gText('Moodboard_Mbella.pdf', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 504, 158, 14, gText('Ajouté par Aminata B. · 16 oct.', 11.5, Color(0xFF66636E))),
      gP(306.4, 492, 45.6, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(318.7, 496, 21, 14, gText('Voir', 11, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(88, 536, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 549, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 557.667, 19.333, 22.667, gImg('assets/figma/v/6b7ab80aa88481.svg')),
      gP(88, 548, 136, 17, gText('Jalon 1 · 54 000 FCFA', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 570, 84, 14, gText('Libéré le 14 oct.', 11.5, Color(0xFF66636E))),
      gP(306.4, 558, 45.6, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(316.2, 562, 26, 14, gText('Payé', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Ajouter un fichier')),
      gP(46.5, 778, 118, 18, gText('Ajouter un fichier', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Envoyer')),
      gP(256, 778, 57, 18, gText('Envoyer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
