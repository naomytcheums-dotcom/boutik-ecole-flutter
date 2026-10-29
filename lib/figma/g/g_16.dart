// GÉNÉRÉ par tool/figma_export/convert.py — écran 16 (nœud Figma 22:61). Ne pas éditer à la main.
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

class G_16 extends ConsumerWidget {
  const G_16({super.key});

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
      gP(76, 71, 232, 26, gText('Nouveau mot de passe', 21, Color(0xFF111015), weight: 700)),
      gP(33.5, 233, 323, 26, gText('Créez un nouveau mot de passe', 21, Color(0xFF111015), weight: 800, align: TextAlign.center)),
      gP(64.5, 264, 261, 40, gText('Choisissez un mot de passe fort que vous\nn’utilisez pas ailleurs.', 13.5, Color(0xFF66636E), lh: 20, align: TextAlign.center)),
      gP(24, 322, 143, 16, gText('Nouveau mot de passe', 13, Color(0xFF111015), weight: 600)),
      gP(24, 346, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 346, 342, 52, GField(hint: '••••••••••', size: 17, hintColor: Color(0xFF111015), weight: 500, padL: 52, obscure: true, onChanged: (v) { ref.read(formProvider.notifier).put('rs_pw', v); })),
      errorText('rs_pw', 28, 400),
      gP(39.875, 368.208, 20.25, 14.708, gImg('assets/figma/v/32a45c6e5f0fcb.svg')),
      gP(43.042, 361.083, 13.917, 13.125, gImg('assets/figma/v/1fb86fed903268.svg')),
      gP(327.083, 363.458, 21.833, 17.083, gImg('assets/figma/v/abcfc4162eb13b.svg')),
      gP(332.625, 366.625, 10.75, 10.75, gImg('assets/figma/v/e4edba8fd4f28c.svg')),
      gP(24, 424, 80, 6, gBox(color: Color(0xFF1F9D6B), radii: [3, 3, 3, 3])),
      gP(111, 424, 80, 6, gBox(color: Color(0xFF1F9D6B), radii: [3, 3, 3, 3])),
      gP(198, 424, 80, 6, gBox(color: Color(0xFF1F9D6B), radii: [3, 3, 3, 3])),
      gP(285, 424, 80, 6, gBox(color: Color(0xFFE4E8EE), radii: [3, 3, 3, 3])),
      gP(24, 442, 135, 16, gText('Force du mot de passe', 12.5, Color(0xFF66636E))),
      gP(340, 442, 26, 16, gText('Fort', 12.5, Color(0xFF0F7A52), weight: 700, align: TextAlign.right)),
      gP(24, 482, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27, 486, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(56, 483.5, 142, 17, gText('8 caractères minimum', 13.5, Color(0xFF111015), weight: 500)),
      gP(24, 512, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27, 516, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(56, 513.5, 132, 17, gText('Une lettre majuscule', 13.5, Color(0xFF111015), weight: 500)),
      gP(24, 542, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27, 546, 14, 11.5, gImg('assets/figma/v/d9758b2cc9e4ca.svg')),
      gP(56, 543.5, 63, 17, gText('Un chiffre', 13.5, Color(0xFF111015), weight: 500)),
      gP(24, 572, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, oval: true)),
      gP(56, 573.5, 188, 17, gText('Un caractère spécial (! @ # …)', 13.5, Color(0xFF66636E), weight: 500)),
      gP(24, 618, 164, 16, gText('Confirmer le mot de passe', 13, Color(0xFF111015), weight: 600)),
      gP(24, 642, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 642, 342, 52, GField(hint: '••••••••••', size: 17, hintColor: Color(0xFF111015), weight: 500, padL: 52, obscure: true, onChanged: (v) { ref.read(formProvider.notifier).put('rs_pw2', v); }, onSubmitted: (v) { submitReset(ref, context); })),
      errorText('rs_pw2', 28, 696),
      gP(39.875, 664.208, 20.25, 14.708, gImg('assets/figma/v/32a45c6e5f0fcb.svg')),
      gP(43.042, 657.083, 13.917, 13.125, gImg('assets/figma/v/1fb86fed903268.svg')),
      gP(327.083, 659.458, 21.833, 17.083, gImg('assets/figma/v/abcfc4162eb13b.svg')),
      gP(332.625, 662.625, 10.75, 10.75, gImg('assets/figma/v/e4edba8fd4f28c.svg')),
      gP(24, 724, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Réinitialiser le mot de passe')),
      gP(89, 741, 212, 20, gText('Réinitialiser le mot de passe', 16, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 884, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(166.5, 172.167, 69, 42.167, gImg('assets/figma/r/173_46.png')),
      gP(178.833, 134.667, 44.333, 40.5, gImg('assets/figma/v/9a0bdefbfa5dbf.svg')),
      gTap(24, 724, 342, 54, () { submitReset(ref, context); }),
    ]);
  }
}
