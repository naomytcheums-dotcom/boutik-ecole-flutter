// GÉNÉRÉ par tool/figma_export/convert.py — écran 156 (nœud Figma 60:471). Ne pas éditer à la main.
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

class G_156 extends ConsumerWidget {
  const G_156({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1020, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 186.6, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 727.2, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 222, 26, gText('Préférences d’alertes', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 56, 19, gText('Canaux', 15, Color(0xFF111015), weight: 700)),
      gP(24, 158, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 170, 202, 17, gText('Notifications dans l’application', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 192, 87, 14, gText('Toujours actives', 11.5, Color(0xFF66636E))),
      gP(308, 179, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 224, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 236, 30, 17, gText('SMS', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 258, 175, 14, gText('Alertes importantes uniquement', 11.5, Color(0xFF66636E))),
      gP(308, 245, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 290, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 302, 70, 17, gText('WhatsApp', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 324, 159, 14, gText('Opportunités et dates limites', 11.5, Color(0xFF66636E))),
      gP(308, 311, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(40, 356, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 368, 43, 17, gText('E-mail', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 390, 128, 14, gText('Résumé hebdomadaire', 11.5, Color(0xFF66636E))),
      gP(308, 377, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(24, 436, 112, 19, gText('Types d’alertes', 15, Color(0xFF111015), weight: 700)),
      gP(24, 474, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 486, 119, 17, gText('Dossier incomplet', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 508, 187, 14, gText('Documents manquants ou refusés', 11.5, Color(0xFF66636E))),
      gP(308, 495, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 540, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 552, 128, 17, gText('Offres compatibles', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 574, 88, 14, gText('Selon mon profil', 11.5, Color(0xFF66636E))),
      gP(308, 561, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 606, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 618, 84, 17, gText('Dates limites', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 640, 107, 14, gText('48 h avant la clôture', 11.5, Color(0xFF66636E))),
      gP(308, 627, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 672, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 684, 162, 17, gText('Résultats de candidature', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 706, 174, 14, gText('À chaque changement de statut', 11.5, Color(0xFF66636E))),
      gP(308, 693, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(24, 752, 66, 16, gText('Fréquence', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 772, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 772, 342, 48, GField(hint: '', initial: 'Quotidienne', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(37.5, 785.5, 21, 21, gImg('assets/figma/v/8283e962773df2.svg')),
      gP(45, 788.5, 9, 12, gImg('assets/figma/v/ed425c4c4b79bb.svg')),
      gP(334.5, 790.75, 15, 10.5, gImg('assets/figma/v/7abbf201b36418.svg')),
      gP(24, 834, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 849, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 854.916, 17.333, 20.169, gImg('assets/figma/v/d9a3b6dd8cdae8.svg')),
      gP(46.875, 860.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 848, 277, 34, gText('L’IA n’envoie jamais d’alerte sans votre accord et vous pouvez tout désactiver.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 920, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 936, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Enregistrer les préférences')),
      gP(100.5, 954, 189, 18, gText('Enregistrer les préférences', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 1006, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
