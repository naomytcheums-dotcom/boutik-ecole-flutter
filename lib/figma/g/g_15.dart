// GÉNÉRÉ par tool/figma_export/convert.py — écran 15 (nœud Figma 20:217). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_15 extends ConsumerWidget {
  const G_15({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 147, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 624, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 73, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 74.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 81, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 71, 204, 26, gText('Mot de passe oublié', 21, Color(0xFF111015), weight: 700)),
      gP(27.5, 282, 335, 28, gText('Réinitialiser votre mot de passe', 22, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(50.5, 332.5, 289, 63, gText('Saisissez votre numéro de téléphone ou votre\ne-mail. Nous vous enverrons un code pour\nréinitialiser votre mot de passe.', 13.5, Color(0xFF66636E), lh: 21, align: TextAlign.center)),
      gP(24, 438, 128, 16, gText('Téléphone ou e-mail', 13, Color(0xFF111015), weight: 600)),
      gP(24, 462, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 462, 342, 52, GField(hint: 'Ex. +237 6 XX XX XX XX', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52, onChanged: (v) { ref.read(formProvider.notifier).put('fg_id', v); }, onSubmitted: (v) { submitForgot(ref, context); })),
      errorText('fg_id', 28, 516),
      gP(39.083, 478.667, 21.833, 18.667, gImg('assets/figma/v/7e8276104a8e4f.svg')),
      gP(39.083, 481.042, 21.833, 11.542, gImg('assets/figma/v/904a4bba0b310b.svg')),
      gP(24, 546, 342, 72, gBox(color: Color(0xFFF2EFF6), radii: [22, 22, 22, 22])),
      gP(40.75, 578.083, 22.5, 16.083, gImg('assets/figma/v/28a0764538148f.svg')),
      gP(44.417, 569.833, 15.167, 14.25, gImg('assets/figma/v/857bfb88ff06e0.svg')),
      gP(76, 564, 207, 36, gText('Pour votre sécurité, le code envoyé\nest valable pendant 10 minutes.', 12.5, Color(0xFF66636E), lh: 18)),
      gP(24, 656, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(119.5, 673, 123, 20, gText('Envoyer le code', 16, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(253.25, 680, 16.5, 6, gImg('assets/figma/v/2d30ecf6147fbb.svg')),
      gP(258.5, 674.75, 11.25, 16.5, gImg('assets/figma/v/996965d4e56708.svg')),
      gP(123, 747, 144, 18, gText('Retour à la connexion', 14, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center)),
      gP(125, 884, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(156.417, 190.75, 51.666, 51.666, gImg('assets/figma/r/178_28.png')),
      gP(188.5, 155.333, 55, 55, gImg('assets/figma/r/178_29.png')),
      gTap(24, 656, 342, 54, () { submitForgot(ref, context); }),
      gTap(123, 747, 144, 18, () { gOpen(context, '11'); }),
    ]);
  }
}
