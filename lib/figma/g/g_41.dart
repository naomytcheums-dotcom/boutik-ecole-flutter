// GÉNÉRÉ par tool/figma_export/convert.py — écran 41 (nœud Figma 54:719). Ne pas éditer à la main.
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

class G_41 extends ConsumerWidget {
  const G_41({super.key});

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
      gP(76, 70, 203, 26, gText('Adresse de livraison', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 120, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 128.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(27.5, 158, 33, 14, gText('Panier', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(120.667, 158, 48, 14, gText('Livraison', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(220.333, 158, 50, 14, gText('Paiement', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(311, 158, 70, 14, gText('Confirmation', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 122, 16, gText('Nom du destinataire', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 208, 342, 48, GField(hint: '', initial: 'Mariam Essono', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(39, 223, 18, 18, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(41.25, 222.25, 13.5, 13.5, gImg('assets/figma/v/c741934f1ce95f.svg')),
      gP(39, 229.75, 18, 12, gImg('assets/figma/v/f07df42423af95.svg')),
      gP(24, 270, 64, 16, gText('Téléphone', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 290, 342, 48, GField(hint: '', initial: '+237 6 XX XX XX XX', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(39.75, 303.5, 16.5, 21, gImg('assets/figma/v/f88bf1acb4da04.svg')),
      gP(45, 315.5, 6.008, 6, gImg('assets/figma/v/f943396fb20219.svg')),
      gP(24, 352, 91, 16, gText('Ville et quartier', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 372, 342, 48, GField(hint: '', initial: 'Douala · Ndokoti', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(39, 385.5, 18, 21, gImg('assets/figma/v/32cd8858f7ce88.svg')),
      gP(42.75, 389.25, 10.5, 10.5, gImg('assets/figma/v/f34fbbf4909aff.svg')),
      gP(334.5, 390.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 434, 97, 16, gText('Adresse précise', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 454, 342, 48, GField(hint: '', initial: 'Rue de l’IUT, face au Bloc A', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 468.427, 19.5, 19.147, gImg('assets/figma/v/e1fd0d54c046bf.svg')),
      gP(47.25, 470.323, 6, 17.25, gImg('assets/figma/v/32c1fcbd2d95de.svg')),
      gP(42.75, 468.427, 6, 17.25, gImg('assets/figma/v/32c1fcbd2d95de.svg')),
      gP(24, 516, 93, 16, gText('Point de repère', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 536, 342, 48, GField(hint: '', initial: 'Près de la bibliothèque', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(39, 549.5, 18, 16.5, gImg('assets/figma/v/30f0e53e8efa49.svg')),
      gP(39, 559.25, 6, 11.25, gImg('assets/figma/v/37382165c8fa4f.svg')),
      gP(24, 598, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 601.75, 14.667, 11.958, gImg('assets/figma/v/w_check.svg')),
      gP(54, 599, 315, 18, gText('Enregistrer cette adresse dans mon carnet', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Continuer')),
      gP(160, 778, 70, 18, gText('Continuer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
