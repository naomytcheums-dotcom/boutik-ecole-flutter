// GÉNÉRÉ par tool/figma_export/convert.py — écran 12 (nœud Figma 20:50). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_12 extends ConsumerWidget {
  const G_12({super.key});

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
      gP(76, 71, 172, 26, gText('Créer un compte', 21, Color(0xFF111015), weight: 700)),
      gP(24, 129, 286, 18, gText('Rejoignez la marketplace de l’IUT de Douala', 14, Color(0xFF66636E))),
      gP(24, 168, 86, 16, gText('Nom complet', 13, Color(0xFF111015), weight: 600)),
      gP(24, 192, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 192, 342, 52, GField(hint: 'Ex. Mariam Essono', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52, onChanged: (v) { ref.read(formProvider.notifier).put('su_name', v); })),
      errorText('su_name', 28, 246),
      gP(40.5, 208.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(43.042, 207.875, 13.917, 13.917, gImg('assets/figma/v/15e6e73e8eaf8c.svg')),
      gP(40.667, 215.792, 18.667, 12.333, gImg('assets/figma/v/179cc05e604d6c.svg')),
      gP(24, 258, 66, 16, gText('Téléphone', 13, Color(0xFF111015), weight: 600)),
      gP(24, 282, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 282, 342, 52, GField(hint: '+237 6 XX XX XX XX', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52, onChanged: (v) { ref.read(formProvider.notifier).put('su_phone', v); })),
      errorText('su_phone', 28, 336),
      gP(41.458, 297.083, 17.083, 21.833, gImg('assets/figma/v/2660f7e30da185.svg')),
      gP(47, 309.75, 6.008, 6, gImg('assets/figma/v/964b38e3841185.svg')),
      gP(24, 348, 42, 16, gText('E-mail', 13, Color(0xFF111015), weight: 600)),
      gP(24, 372, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 372, 342, 52, GField(hint: 'exemple@mail.com', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52, onChanged: (v) { ref.read(formProvider.notifier).put('su_email', v); })),
      errorText('su_email', 28, 426),
      gP(39.083, 388.667, 21.833, 18.667, gImg('assets/figma/v/7e8276104a8e4f.svg')),
      gP(39.083, 391.042, 21.833, 11.542, gImg('assets/figma/v/904a4bba0b310b.svg')),
      gP(24, 438, 84, 16, gText('Mot de passe', 13, Color(0xFF111015), weight: 600)),
      gP(24, 462, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 462, 342, 52, GField(hint: '8 caractères minimum', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52, onChanged: (v) { ref.read(formProvider.notifier).put('su_pw', v); })),
      errorText('su_pw', 28, 516),
      gP(39.875, 484.208, 20.25, 14.708, gImg('assets/figma/v/32a45c6e5f0fcb.svg')),
      gP(43.042, 477.083, 13.917, 13.125, gImg('assets/figma/v/1fb86fed903268.svg')),
      gP(327.083, 479.458, 21.833, 17.083, gImg('assets/figma/v/abcfc4162eb13b.svg')),
      gP(332.625, 482.625, 10.75, 10.75, gImg('assets/figma/v/e4edba8fd4f28c.svg')),
      gP(24, 528, 164, 16, gText('Confirmer le mot de passe', 13, Color(0xFF111015), weight: 600)),
      gP(24, 552, 342, 52, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFECE8F2), bw: 1.5, radii: [22, 22, 22, 22])),
      gP(24, 552, 342, 52, GField(hint: 'Confirmez votre mot de passe', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52, obscure: true, onChanged: (v) { ref.read(formProvider.notifier).put('su_pw2', v); })),
      errorText('su_pw2', 28, 606),
      gP(39.875, 574.208, 20.25, 14.708, gImg('assets/figma/v/32a45c6e5f0fcb.svg')),
      gP(43.042, 567.083, 13.917, 13.125, gImg('assets/figma/v/1fb86fed903268.svg')),
      gP(327.083, 569.458, 21.833, 17.083, gImg('assets/figma/v/abcfc4162eb13b.svg')),
      gP(332.625, 572.625, 10.75, 10.75, gImg('assets/figma/v/e4edba8fd4f28c.svg')),
      gP(24, 628, 22, 22, gBox(color: Color(0xFF111015), radii: [7, 7, 7, 7]), show: (ref.watch(termsProvider))),
      gP(27.333, 632.5, 15.333, 12.417, gImg('assets/figma/v/3ba50c08806376.svg'), show: (ref.watch(termsProvider))),
      gP(24, 628, 22, 22, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFCFCBD6), bw: 1.5, radii: [7.0, 7.0, 7.0, 7.0]), show: !ref.watch(termsProvider)),
      gP(58, 622, 243, 36, gText('J’accepte les Conditions d’utilisation et la\nPolitique de confidentialité.', 12.5, Color(0xFF4A4854), lh: 18)),
      gP(24, 684, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(108, 701, 146, 20, gText('Créer mon compte', 16, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(264.75, 708, 16.5, 6, gImg('assets/figma/v/2d30ecf6147fbb.svg')),
      gP(270, 702.75, 11.25, 16.5, gImg('assets/figma/v/996965d4e56708.svg')),
      gP(120, 763.5, 110, 17, gText('Déjà un compte ?', 13.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(236, 763.5, 88, 17, gText('Se connecter', 13.5, Color(0xFF5A3FE0), weight: 700, align: TextAlign.center)),
      gP(125, 884, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 622, 34, 34, () { ref.read(termsProvider.notifier).toggle(); }),
      gTap(24, 684, 342, 54, () { submitSignup(ref, context); }),
      gTap(236, 764, 88, 17, () { gOpen(context, '11'); }),
    ]);
  }
}
