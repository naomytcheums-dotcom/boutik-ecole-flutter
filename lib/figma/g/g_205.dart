// GÉNÉRÉ par tool/figma_export/convert.py — écran 205 (nœud Figma 83:779). Ne pas éditer à la main.
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

class G_205 extends ConsumerWidget {
  const G_205({super.key});

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
      gP(76, 70, 226, 26, gText('Soumettre mon projet', 21, Color(0xFF111015), weight: 700)),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(27, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(32, 158, 24, 14, gText('Idée', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(129.667, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(125.667, 158, 38, 14, gText('Équipe', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(224.333, 158, 42, 14, gText('Besoins', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(331.5, 158, 29, 14, gText('Envoi', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 188, 86, 16, gText('Nom du projet', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 208, 342, 48, GField(hint: '', initial: 'Serre intelligente pour maraîchers', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(40.5, 221.5, 15, 15, gImg('assets/figma/v/a49ecdd3bef596.svg')),
      gP(42.75, 233.5, 10.5, 6, gImg('assets/figma/v/2e2c4a27235860.svg')),
      gP(43.5, 236.5, 9, 6, gImg('assets/figma/v/ab681c73d5c7eb.svg')),
      gP(24, 270, 99, 16, gText('Problème résolu', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 290, 342, 96, GField(hint: '', initial: 'Les maraîchers perdent des récoltes à cause de la chaleur…', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 16, multiline: true, padT: 14)),
      gP(24, 400, 116, 19, gText('Aide demandée', 15, Color(0xFF111015), weight: 700)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 438, 70.4, 34, 'Mentor', 12.5, 600), GChip(102.4, 438, 92.6, 34, 'Prototype', 12.5, 500), GChip(203, 438, 107.4, 34, 'Financement', 12.5, 500), GChip(318.4, 438, 92.6, 34, 'Juridique', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17)),
      gP(24, 486, 138, 16, gText('Besoin de financement', 12.5, Color(0xFF111015), weight: 600)),
      gP(24, 506, 342, 48, GField(hint: '', initial: '1 500 000 FCFA', size: 13.5, hintColor: Color(0xFF111015), weight: 500, padL: 48)),
      gP(38.25, 520.25, 20.25, 15.75, gImg('assets/figma/v/16ec94a7384869.svg')),
      gP(38.25, 521.75, 19.5, 18, gImg('assets/figma/v/fbc7a9ade9c600.svg')),
      gP(36, 581, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(44.667, 600.5, 17.667, 11, gImg('assets/figma/v/b08196471e66d3.svg')),
      gP(47.167, 590.5, 12.667, 12.667, gImg('assets/figma/v/50a1540c3efbda.svg')),
      gP(58.833, 600.583, 8.5, 10.917, gImg('assets/figma/v/177509d436bc97.svg')),
      gP(56.333, 590.583, 8.593, 12.5, gImg('assets/figma/v/c6f34f8f35a8e0.svg')),
      gP(88, 580, 155, 17, gText('Ajouter des coéquipiers', 13.5, Color(0xFF111015), weight: 600)),
      gP(88, 602, 179, 14, gText('Compétences complémentaires', 11.5, Color(0xFF66636E))),
      gP(336.75, 593.5, 10.5, 15, gImg('assets/figma/v/b8b27a74d41268.svg')),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Brouillon')),
      gP(74.5, 778, 62, 18, gText('Brouillon', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Envoyer à l’IUT')),
      gP(234, 778, 101, 18, gText('Envoyer à l’IUT', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
