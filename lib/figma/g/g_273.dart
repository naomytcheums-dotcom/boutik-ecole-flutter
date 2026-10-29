// GÉNÉRÉ par tool/figma_export/convert.py — écran 273 (nœud Figma 200:137). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_273 extends ConsumerWidget {
  const G_273({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(140.5, 76, 109, 21, gText('Mes données', 17, Color(0xFF111015), weight: 500)),
      gP(127.5, 102, 135, 15, gText('Confidentialité et droits', 12, Color(0xFF66636E))),
      gP(189.25, 144.75, 11.5, 57.5, gImg('assets/figma/r/200_236.png')),
      gP(170.084, 171.584, 49.833, 30.666, gImg('assets/figma/r/200_237.png')),
      gP(158.583, 209.917, 72.833, 11.5, gImg('assets/figma/r/200_238.png')),
      gP(81.5, 250, 227, 25, gText('Vous gardez le contrôle', 20, Color(0xFF111015), weight: 700)),
      gP(26.5, 280, 337, 16, gText('Téléchargez ou supprimez vos données à tout moment.', 13, Color(0xFF6B6877))),
      gP(24, 320, 342, 150, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(44, 338, 163, 19, gText('Exporter mes données', 15, Color(0xFF111015), weight: 600)),
      gP(44, 362, 286, 15, gText('Profil, projets, commandes, messages · ZIP + JSON', 12, Color(0xFF6B6877))),
      gP(44, 382, 209, 15, gText('Prêt sous 24 h · lien envoyé par e-mail', 12, Color(0xFF6B6877))),
      gP(44, 412, 160, 40, gBox(color: Color(0xFF111015), radii: [20, 20, 20, 20]), tap: () => gToast(context, 'Démonstration : Demander l’export')),
      gP(60, 424, 118, 16, gText('Demander l’export', 13, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 490, 342, 160, gBox(color: Color(0xD9FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [22, 22, 22, 22])),
      gP(44, 508, 172, 19, gText('Supprimer mon compte', 15, Color(0xFFC2410C), weight: 600)),
      gP(44, 532, 302, 20, gText('Délai de rétractation de 30 jours. Les certificats émis et les factures sont conservés (obligation légale).', 12, Color(0xFF6B6877))),
      gP(44, 598, 170, 40, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFC2410C), bw: 1.5, radii: [20, 20, 20, 20]), tap: () => gToast(context, 'Démonstration : Supprimer le compte')),
      gP(58, 610, 132, 16, gText('Supprimer le compte', 13, Color(0xFFC2410C), weight: 600)),
      gP(24, 690, 212, 15, gText('Dernier export : 12 mars 2026 · 4,2 Mo', 12, Color(0xFF6B6877), weight: 500)),
    ]);
  }
}
