// GÉNÉRÉ par tool/figma_export/convert.py — écran 13 (nœud Figma 22:2). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_13 extends ConsumerWidget {
  const G_13({super.key});

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
      gP(76, 71, 148, 26, gText('Choix du profil', 21, Color(0xFF111015), weight: 700)),
      gP(24, 128, 228, 28, gText('Quel est votre profil ?', 22, Color(0xFF111015), weight: 700)),
      gP(24, 164, 246, 40, gText('Choisissez le rôle qui vous correspond.\nVous pourrez le modifier plus tard.', 13.5, Color(0xFF66636E), lh: 20)),
      gP(44, 257, 56, 56, gBox(color: Color(0xFFF1EEFB), radii: [18, 18, 18, 18])),
      gP(58.5, 270.333, 27, 29.333, gImg('assets/figma/v/e3652aea7784a1.svg')),
      gP(58.5, 275, 27, 6, gImg('assets/figma/v/281ac9c54a374b.svg')),
      gP(64.333, 279.667, 15.333, 10.667, gImg('assets/figma/v/c0a5abb59b3a48.svg')),
      gP(24, 226, 342, 118, gBox(color: Color(0xFFFFFDF7), border: Color(0xFFF5B730), bw: 2.5, radii: [24.0, 24.0, 24.0, 24.0]), show: ref.watch(signupRoleProvider) == 0),
      gP(118, 253.5, 48, 21, gText('Client', 16.5, Color(0xFF111015), weight: 600)),
      gP(276, 238, 74, 24, gBox(color: Color(0xFF111015), radii: [12.0, 12.0, 12.0, 12.0]), show: ref.watch(signupRoleProvider) == 0),
      gP(282, 244, 62, 13, gText('Sélectionné', 10, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center, wrap: true), show: ref.watch(signupRoleProvider) == 0),
      gP(118, 284, 192, 36, gText('Achetez des produits et services\nproposés par les étudiants.', 12.5, Color(0xFF66636E), lh: 18)),
      gP(328, 240, 20, 20, gBox(border: Color(0xFF6B6877), bw: 1.8, oval: true)),
      gP(24, 356, 342, 118, gBox(color: Color(0xFFFFFFFF), radii: [28.0, 28.0, 28.0, 28.0]), show: ref.watch(signupRoleProvider) != 1),
      gP(44, 387, 56, 56, gBox(color: Color(0xFFFDEFC8), radii: [18, 18, 18, 18])),
      gP(57.333, 403.833, 29.333, 17.667, gImg('assets/figma/v/9334d03309f7e4.svg')),
      gP(62, 412, 20, 14.458, gImg('assets/figma/v/d4b8f4bde082c9.svg')),
      gP(24, 356, 342, 118, gBox(color: Color(0xFFFFFDF7), border: Color(0xFFF5B730), bw: 2.5, radii: [24.0, 24.0, 24.0, 24.0]), show: ref.watch(signupRoleProvider) == 1),
      gP(118, 383.5, 136, 21, gText('Étudiant vendeur', 16.5, Color(0xFF111015), weight: 600)),
      gP(276, 368, 74, 24, gBox(color: Color(0xFF111015), radii: [12.0, 12.0, 12.0, 12.0]), show: ref.watch(signupRoleProvider) == 1),
      gP(282, 374, 62, 13, gText('Sélectionné', 10, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center, wrap: true), show: ref.watch(signupRoleProvider) == 1),
      gP(118, 414, 188, 36, gText('Publiez vos produits, services et\nprojets sur la marketplace.', 12.5, Color(0xFF66636E), lh: 18)),
      gP(276, 368, 74, 24, gBox(color: Color(0xFF111015), radii: [12, 12, 12, 12]), show: (ref.watch(signupRoleProvider) == 1)),
      gP(282, 373.5, 62, 13, gText('Sélectionné', 10.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center), show: (ref.watch(signupRoleProvider) == 1)),
      gP(44, 517, 56, 56, gBox(color: Color(0xFFF1EEFB), radii: [18, 18, 18, 18])),
      gP(57.333, 536.167, 29.333, 22.333, gImg('assets/figma/v/ed6763c2b1ff1f.svg')),
      gP(64.333, 531.5, 15.333, 27, gImg('assets/figma/v/95747c6d5f85d5.svg')),
      gP(24, 486, 342, 118, gBox(color: Color(0xFFFFFDF7), border: Color(0xFFF5B730), bw: 2.5, radii: [24.0, 24.0, 24.0, 24.0]), show: ref.watch(signupRoleProvider) == 2),
      gP(118, 513.5, 83, 21, gText('Entreprise', 16.5, Color(0xFF111015), weight: 600)),
      gP(276, 498, 74, 24, gBox(color: Color(0xFF111015), radii: [12.0, 12.0, 12.0, 12.0]), show: ref.watch(signupRoleProvider) == 2),
      gP(282, 504, 62, 13, gText('Sélectionné', 10, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center, wrap: true), show: ref.watch(signupRoleProvider) == 2),
      gP(118, 544, 186, 36, gText('Découvrez des talents et lancez\ndes collaborations.', 12.5, Color(0xFF66636E), lh: 18)),
      gP(328, 500, 20, 20, gBox(border: Color(0xFF6B6877), bw: 1.8, oval: true)),
      gP(44, 647, 56, 56, gBox(color: Color(0xFFF1EEFB), radii: [18, 18, 18, 18])),
      gP(57.333, 675.5, 22.333, 13, gImg('assets/figma/v/10c680750e7ca9.svg')),
      gP(60.833, 661.5, 15.333, 15.333, gImg('assets/figma/v/87914a6b9ef7bc.svg')),
      gP(77.167, 675.652, 9.5, 12.848, gImg('assets/figma/v/eb66e0814a913b.svg')),
      gP(73.667, 661.652, 9.509, 15.042, gImg('assets/figma/v/d57d30d032eb7f.svg')),
      gP(24, 616, 342, 118, gBox(color: Color(0xFFFFFDF7), border: Color(0xFFF5B730), bw: 2.5, radii: [24.0, 24.0, 24.0, 24.0]), show: ref.watch(signupRoleProvider) == 3),
      gP(118, 643.5, 146, 21, gText('Autre rôle autorisé', 16.5, Color(0xFF111015), weight: 600)),
      gP(276, 628, 74, 24, gBox(color: Color(0xFF111015), radii: [12.0, 12.0, 12.0, 12.0]), show: ref.watch(signupRoleProvider) == 3),
      gP(282, 634, 62, 13, gText('Sélectionné', 10, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center, wrap: true), show: ref.watch(signupRoleProvider) == 3),
      gP(118, 674, 151, 36, gText('Enseignant, partenaire ou\nadministration de l’IUT.', 12.5, Color(0xFF66636E), lh: 18)),
      gP(328, 630, 20, 20, gBox(border: Color(0xFF6B6877), bw: 1.8, oval: true)),
      gP(24, 762, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(142.5, 779, 77, 20, gText('Continuer', 16, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(230.25, 786, 16.5, 6, gImg('assets/figma/v/2d30ecf6147fbb.svg')),
      gP(235.5, 780.75, 11.25, 16.5, gImg('assets/figma/v/996965d4e56708.svg')),
      gP(125, 884, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 226, 342, 118, () { ref.read(signupRoleProvider.notifier).set(0); }),
      gTap(24, 356, 342, 118, () { ref.read(signupRoleProvider.notifier).set(1); }),
      gTap(24, 486, 342, 118, () { ref.read(signupRoleProvider.notifier).set(2); }),
      gTap(24, 616, 342, 118, () { ref.read(signupRoleProvider.notifier).set(3); }),
      gTap(24, 762, 342, 54, () { submitRole(ref, context); }),
    ]);
  }
}
