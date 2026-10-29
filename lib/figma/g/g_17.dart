// GÉNÉRÉ par tool/figma_export/convert.py — écran 17 (nœud Figma 34:3). Ne pas éditer à la main.
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

class G_17 extends ConsumerWidget {
  const G_17({super.key});

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
      gP(76, 70, 292, 26, gText('Conditions et confidentialité', 21, Color(0xFF111015), weight: 700)),
      gP(24, 156, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(46, 130, 70, 16, gText('Conditions', 13, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(41.1, 154, 79.8, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(148.5, 130, 93, 16, gText('Confidentialité', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(258.5, 130, 101, 16, gText('Consentements', 13, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 174, 210, 19, gText('1. Utilisation de la plateforme', 15, Color(0xFF111015), weight: 700)),
      gP(24, 212, 345, 81, gText('Boutik-École est la marketplace de l’expertise et des productions de l’IUT de Douala. En créant un compte, vous vous engagez à publier des informations exactes et à respecter les règles de la communauté étudiante.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 307, 179, 19, gText('2. Données personnelles', 15, Color(0xFF111015), weight: 700)),
      gP(24, 345, 345, 61, gText('Vos données servent uniquement au fonctionnement du service : commandes, livraison, validation du compte et communication avec les vendeurs.', 13, Color(0xFF4A4854), lh: 20.15, wrap: true)),
      gP(24, 420, 145, 19, gText('Vos consentements', 15, Color(0xFF111015), weight: 700)),
      gP(24, 458, 342, 198, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 470, 181, 17, gText('Notifications de commande', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 492, 144, 14, gText('Suivi, livraison et réception', 11.5, Color(0xFF66636E))),
      gP(308, 479, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(40, 524, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 536, 124, 17, gText('Actualités et offres', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 558, 191, 14, gText('Nouveautés et événements de l’IUT', 11.5, Color(0xFF66636E))),
      gP(308, 545, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18)),
      gP(40, 590, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 602, 149, 17, gText('Statistiques anonymes', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 624, 161, 14, gText('Aider à améliorer l’application', 11.5, Color(0xFF66636E))),
      gP(308, 611, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18)),
      gP(24, 670, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 673.75, 14.667, 11.958, gImg('assets/figma/v/ac006383c9ee5c.svg')),
      gP(54, 671, 315, 36, gText('J’ai lu et j’accepte les Conditions d’utilisation et la Politique de confidentialité.', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Accepter et continuer')),
      gP(118.5, 778, 153, 18, gText('Accepter et continuer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
