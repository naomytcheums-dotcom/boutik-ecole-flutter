// GÉNÉRÉ par tool/figma_export/convert.py — écran 18c (nœud Figma 22:200). Ne pas éditer à la main.
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
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_18c extends ConsumerWidget {
  const G_18c({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF5F0E8), Color(0xFFEFE9F4), Color(0xFFF7E9DB)], stops: [0, 0.55, 1]), children: [
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
      gP(32.583, 74.583, 12.417, 18.833, gImg('assets/figma/v/2e8d6b9b0673a0.svg')),
      gP(32.583, 81, 18.833, 6, gImg('assets/figma/v/34ad6fe6386c09.svg')),
      gP(76, 71, 208, 26, gText('Vérification étudiant', 21, Color(0xFF111015), weight: 700)),
      gP(24, 128, 342, 58, gBox(color: Color(0xFFF1EEFB), radii: [20, 20, 20, 20])),
      gP(38.667, 145.667, 22.667, 22.667, gImg('assets/figma/v/be05bf41534ad8.svg')),
      gP(47, 154, 6, 9.333, gImg('assets/figma/v/1e56c9812e5c79.svg')),
      gP(47, 150.667, 6.008, 6, gImg('assets/figma/v/0f091c2614d4b3.svg')),
      gP(76, 139, 250, 36, gText('Ces informations permettent de confirmer\nvotre statut d’étudiant de l’IUT de Douala.', 12.5, Color(0xFF4A4854), lh: 18)),
      gP(24, 198, 59, 16, gText('Matricule', 13, Color(0xFF111015), weight: 600)),
      gP(24, 222, 342, 52, GField(hint: '', initial: 'IUT-2023-0412', size: 14.5, hintColor: Color(0xFF111015), weight: 500, padL: 52)),
      gP(39.083, 239.458, 21.833, 13.917, gImg('assets/figma/v/c98361d28851b5.svg')),
      gP(42.25, 245, 15.5, 11.74, gImg('assets/figma/v/6ec829d4faedab.svg')),
      gP(24, 282, 38, 16, gText('Filière', 13, Color(0xFF111015), weight: 600)),
      gP(24, 306, 342, 52, GField(hint: '', initial: 'Génie informatique', size: 14.5, hintColor: Color(0xFF111015), weight: 500, padL: 52)),
      gP(39.875, 336.125, 20.25, 6, gImg('assets/figma/v/d7874e6aba6e58.svg')),
      gP(41.458, 321.875, 17.083, 20.25, gImg('assets/figma/v/1b67178ff4d68e.svg')),
      gP(44.625, 331.375, 10.75, 10.75, gImg('assets/figma/v/d1b2d323733bea.svg')),
      gP(44.625, 327.417, 6.008, 6, gImg('assets/figma/v/3f8aa7666c0108.svg')),
      gP(49.375, 327.417, 6.008, 6, gImg('assets/figma/v/3f8aa7666c0108.svg')),
      gP(330.25, 326.625, 15.5, 10.75, gImg('assets/figma/v/debe62e3abf025.svg')),
      gP(24, 366, 96, 16, gText('Niveau d’étude', 13, Color(0xFF111015), weight: 600)),
      gP(24, 390, 342, 52, GField(hint: 'Sélectionnez votre niveau', size: 14.5, hintColor: Color(0xFF66636E), weight: 500, padL: 52)),
      gP(39.083, 407.458, 21.833, 13.917, gImg('assets/figma/v/c98361d28851b5.svg')),
      gP(42.25, 413, 15.5, 11.74, gImg('assets/figma/v/6ec829d4faedab.svg')),
      gP(330.25, 410.625, 15.5, 10.75, gImg('assets/figma/v/debe62e3abf025.svg')),
      gP(24, 458.5, 144, 19, gText('Pièces justificatives', 15, Color(0xFF111015), weight: 700)),
      gP(40, 504, 50, 48, gBox(color: Color(0xFFF1EEFB), radii: [16, 16, 16, 16])),
      gP(54, 515, 22, 26, gImg('assets/figma/v/31af238caaf3f0.svg')),
      gP(64, 515, 12, 12, gImg('assets/figma/v/8e2e7e901fb142.svg')),
      gP(104, 508, 116, 18, gText('Carte d’étudiant', 14.5, Color(0xFF111015), weight: 600)),
      gP(104, 532.5, 153, 15, gText('carte_etudiant.jpg • 1,2 Mo', 12, Color(0xFF66636E))),
      gP(323, 514, 26, 26, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(328.333, 520.5, 15.333, 12.417, gImg('assets/figma/v/ad3423d22b0298.svg')),
      gP(175, 596, 40, 40, gBox(color: Color(0xFFFDEFC8), oval: true)),
      gP(184.5, 615.5, 21, 11, gImg('assets/figma/v/e3af7898ac3f9a.svg')),
      gP(187.833, 605.5, 14.333, 10.167, gImg('assets/figma/v/09f03a98f4325f.svg')),
      gP(192, 605.5, 6, 16, gImg('assets/figma/v/85622fb50b760d.svg')),
      gP(119, 637, 152, 18, gText('Certificat de scolarité', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(65.5, 660, 259, 14, gText('Appuyez pour téléverser (PDF ou JPG, 5 Mo max)', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(24, 696, 342, 56, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(39.5, 720.167, 21, 15.167, gImg('assets/figma/v/a22c4670362503.svg')),
      gP(42.833, 712.667, 14.333, 13.5, gImg('assets/figma/v/36c552ce02b737.svg')),
      gP(76, 707, 228, 34, gText('Vos documents sont chiffrés et ne sont\nconsultés que par l’équipe de validation.', 12, Color(0xFF66636E), lh: 17)),
      gP(24, 780, 342, 54, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFF9B7BFF), Color(0xFF6A4DFF)], stops: [0, 1]), shadows: [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(91, 797, 180, 20, gText('Envoyer pour validation', 16, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(281.75, 804, 16.5, 6, gImg('assets/figma/v/5a610cda8a2e08.svg')),
      gP(287, 798.75, 11.25, 16.5, gImg('assets/figma/v/d16794a9c0b390.svg')),
      gP(125, 884, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
