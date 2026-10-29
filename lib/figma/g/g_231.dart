// GÉNÉRÉ par tool/figma_export/convert.py — écran 231 (nœud Figma 106:134). Ne pas éditer à la main.
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

class G_231 extends ConsumerWidget {
  const G_231({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFE9E6DC), Color(0xFFEFE9E2), Color(0xFFE6DDEA)], stops: [0, 0.5, 1]), children: [
      gP(-100, 560, 320, 320, gBox(color: Color(0x99E0CDF5), layerBlur: 90, oval: true), fx: 'halo'),
      gP(230, 0, 240, 240, gBox(color: Color(0x80F7D9B0), layerBlur: 90, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(24, 66, 46, 46, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [23, 23, 23, 23])),
      gP(80, 70, 92, 16, gText('Bonjour Mariam', 12.5, Color(0xFF66636E))),
      gP(80, 88, 181, 19, gText('Que fait-on aujourd’hui ?', 15, Color(0xFF111015), weight: 600)),
      gP(317, 68, 42, 42, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(328.306, 78.562, 19.388, 17.156, gImg('assets/figma/v/fc3055d1ee19d1.svg')),
      gP(333.736, 92.694, 8.529, 6.748, gImg('assets/figma/v/698b3315ca6b08.svg')),
      gP(38, 146, 40, 40, gBox(image: 'assets/figma/img/080dae985392a646cb0fab75bf2db27a07c8e921.png', fit: BoxFit.contain)),
      gP(82, 156, 82, 16, gText('Brief express', 13, Color(0xFF111015), weight: 600)),
      gP(38, 194, 123, 26, gText('Décris ton besoin à voix haute', 10.5, Color(0xFF66636E), wrap: true)),
      gP(38, 256, 40, 40, gBox(image: 'assets/figma/img/aa1a076fa6963bfae388c034c08844168452c46f.png', fit: BoxFit.contain)),
      gP(82, 266, 81, 16, gText('Voix en texte', 13, Color(0xFF111015), weight: 600)),
      gP(38, 304, 123, 26, gText('Tes notes en transcription', 10.5, Color(0xFF66636E), wrap: true)),
      gP(216, 146, 56, 56, gBox(image: 'assets/figma/img/75d62324f07569a15dcd7cd5ce6357a2177c94cd.png', fit: BoxFit.contain)),
      gP(218, 214, 87, 20, gText('Parle à Kéla', 16, Color(0xFF111015), weight: 600)),
      gP(218, 238, 117, 14, gText('Essaie dès maintenant', 11, Color(0xFF66636E))),
      gP(218, 288, 134, 40, gBox(color: Color(0xFF111015), radii: [20, 20, 20, 20]), tap: () => gToast(context, 'Démonstration : Commencer')),
      gP(247, 299, 76, 16, gText('Commencer', 12.5, Color(0xFFFFFFFF), weight: 500, align: TextAlign.center)),
      gP(24, 362, 57, 19, gText('Thèmes', 15, Color(0xFF111015), weight: 600)),
      gP(318, 364, 48, 15, gText('Tout voir', 12, Color(0xFF66636E), align: TextAlign.right)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 394, 94, 36, 'Missions', 12.5, 500), GChip(126, 394, 78, 36, 'Design', 12.5, 400), GChip(212, 394, 70, 36, 'Vidéo', 12.5, 400), GChip(290, 394, 94, 36, 'Commerce', 12.5, 400), GChip(392, 394, 62, 36, 'Tech', 12.5, 400)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 18)),
      gP(38, 458, 50, 50, gBox(image: 'assets/figma/img/73da21b1c6a4823a1f04e17582334a3c3bc639ed.png', fit: BoxFit.contain)),
      gP(38, 520, 143, 20, gText('Déposer un besoin', 15, Color(0xFF111015), weight: 600, lh: 20, wrap: true)),
      gP(38, 566, 143, 45, gText('Logo, affiche, vidéo : Kéla t’oriente vers les bons talents.', 10.5, Color(0xFF66636E), lh: 15, wrap: true)),
      gP(38, 598, 98, 28, gBox(color: Color(0xFFF2F0EE), radii: [14, 14, 14, 14])),
      gP(54, 603, 52, 14, gText('Découvrir', 11, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(117.5, 609, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(121.5, 606, 9, 12, gImg('assets/figma/v/8fa5d9e08de732.svg')),
      gP(216, 456, 56, 56, kelaOrb(image: 'assets/figma/img/2b51b5d6469cca917952ac344a2ddf9cc1440830.png', fit: BoxFit.contain)),
      gP(218, 520, 133, 20, gText('Suivre ma mission', 15, Color(0xFF111015), weight: 600, lh: 20, wrap: true)),
      gP(218, 566, 133, 30, gText('Étapes, preuves et paiement par jalons.', 10.5, Color(0xFF66636E), lh: 15, wrap: true)),
      gP(218, 598, 98, 28, gBox(color: Color(0xFFF2F0EE), radii: [14, 14, 14, 14])),
      gP(234, 603, 52, 14, gText('Découvrir', 11, Color(0xFF111015), weight: 500, align: TextAlign.center)),
      gP(297.5, 609, 13, 6, gImg('assets/figma/v/4159f10924eea0.svg')),
      gP(301.5, 606, 9, 12, gImg('assets/figma/v/8fa5d9e08de732.svg')),
      gP(36, 666, 42, 42, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [21, 21, 21, 21])),
      gP(90, 664, 239, 34, gText('2 talents de MMI correspondent à ton brief parfum.', 12, Color(0xFF111015), weight: 500, lh: 17, wrap: true)),
      gP(90, 700, 70, 13, gText('Voir les profils', 10.5, Color(0xFF5A3FE0), weight: 600)),
      gP(164, 154, 24, 24, gBox(color: Color(0xFFF2F0EE), oval: true)),
      gP(169.208, 163, 13.583, 6, gImg('assets/figma/v/3b10dd3179a10e.svg')),
      gP(173.542, 159.75, 9.25, 12.5, gImg('assets/figma/v/7fc706b238185f.svg')),
      gP(164, 264, 24, 24, gBox(color: Color(0xFFF2F0EE), oval: true)),
      gP(169.208, 273, 13.583, 6, gImg('assets/figma/v/3b10dd3179a10e.svg')),
      gP(173.542, 269.75, 9.25, 12.5, gImg('assets/figma/v/7fc706b238185f.svg')),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
    ]);
  }
}
