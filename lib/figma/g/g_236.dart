// GÉNÉRÉ par tool/figma_export/convert.py — écran 236 (nœud Figma 87:1432). Ne pas éditer à la main.
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

class G_236 extends ConsumerWidget {
  const G_236({super.key});

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
      gP(76, 70, 235, 26, gText('Canaux et notifications', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 268, 19, gText('Où voulez-vous suivre vos missions ?', 15, Color(0xFF111015), weight: 700)),
      gP(24, 158, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 171, 40, 40, gBox(color: Color(0xFFDDF5EC), radii: [13, 13, 13, 13])),
      gP(46, 181, 20, 20, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(44.667, 180.493, 21.84, 21.84, gImg('assets/figma/v/c011934b9b1395.svg')),
      gP(88, 170, 70, 17, gText('WhatsApp', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 192, 186, 14, gText('Suivi, validation de jalon, paiement', 11.5, Color(0xFF66636E))),
      gP(293.6, 180, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(305.8, 184, 34, 14, gText('Activé', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 224, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 237, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(88, 236, 30, 17, gText('SMS', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 258, 108, 14, gText('Alertes importantes', 11.5, Color(0xFF66636E))),
      gP(293.6, 246, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(305.8, 250, 34, 14, gText('Activé', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 290, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 303, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(45.5, 311.667, 21, 18.5, gImg('assets/figma/v/e2c8fe85d4329b.svg')),
      gP(51.583, 327.5, 8.833, 6.838, gImg('assets/figma/v/165eb123ea9a50.svg')),
      gP(88, 302, 187, 17, gText('Notifications dans l’applica…', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 324, 87, 14, gText('Toujours actives', 11.5, Color(0xFF66636E))),
      gP(293.6, 312, 58.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(305.8, 316, 34, 14, gText('Activé', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(88, 356, 266, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 369, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(46.333, 377.667, 19.333, 22.667, gImg('assets/figma/v/8a418070bfb100.svg')),
      gP(54.667, 377.667, 11, 11, gImg('assets/figma/v/2e28e879cb0de7.svg')),
      gP(88, 368, 43, 17, gText('E-mail', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 390, 96, 14, gText('Reçus et résumés', 11.5, Color(0xFF66636E))),
      gP(274.4, 378, 77.6, 22, gBox(color: Color(0xFFF2EFF6), radii: [11, 11, 11, 11])),
      gP(286.2, 382, 54, 14, gText('Désactivé', 11, Color(0xFF66636E), weight: 600, align: TextAlign.center)),
      gP(24, 436, 115, 16, gText('Numéro WhatsApp', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 456, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 456, 342, 48, GField(hint: '', initial: '+237 6 XX XX XX XX', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(39, 471, 18, 18, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(37.5, 470.244, 20.256, 20.256, gImg('assets/figma/v/8b8b341bbe1515.svg')),
      gP(24, 518, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 541.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 547.443, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 553.083, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 532, 277, 51, gText('Aucune donnée bancaire n’est demandée dans WhatsApp : le paiement passe par votre application Mobile Money.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Enregistrer')),
      gP(156, 778, 78, 18, gText('Enregistrer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(44.667, 245.667, 22.667, 22.667, gImg('assets/figma/v/37684f95055729.svg')),
      gP(52.167, 245.667, 15.167, 15.167, gImg('assets/figma/v/850ac0825ae325.svg')),
    ]);
  }
}
