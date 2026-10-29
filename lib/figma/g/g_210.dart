// GÉNÉRÉ par tool/figma_export/convert.py — écran 210 (nœud Figma 83:2241). Ne pas éditer à la main.
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

class G_210 extends ConsumerWidget {
  const G_210({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 720, h: 1280, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(-120, 780, 440, 440, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(48, 44, 64, 58, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20])),
      gP(55, 49, 50, 48, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(128, 56, 181, 35, gText('Boutik-École', 28, Color(0xFF111015), weight: 600)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(520, 50, 68, 48, 'FR', 20, 600), GChip(596, 50, 68, 48, 'EN', 20, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 24)),
      gP(596, 50, 68, 48, gBox(color: Color(0xFFFFFFFF), radii: [24, 24, 24, 24])),
      gP(188, 376, 344, 63, gText('C’est envoyé !', 50, Color(0xFF111015), weight: 600)),
      gP(147, 444, 426, 28, gText('Le lien du produit est sur votre téléphone.', 22, Color(0xFF66636E))),
      gP(110, 510, 500, 560, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1F403366), offset: Offset(0, 16), blurRadius: 34, spreadRadius: 0)], radii: [44, 44, 44, 44])),
      gP(84, 762, 52, 52, gBox(color: Color(0xFFF0EBF2), oval: true)),
      gP(584, 762, 52, 52, gBox(color: Color(0xFFF0EBF2), oval: true)),
      gP(147, 785, 426, 6, gImg('assets/figma/v/25156d5fff55a1.svg')),
      gP(146, 546, 108, 108, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [30, 30, 30, 30])),
      gP(274, 556, 313, 35, Consumer(builder: (context, ref, _) => gText(kioskView(ref).title, 28, Color(0xFF111015), weight: 600, wrap: true))),
      gP(274, 612, 313, 23, Consumer(builder: (context, ref, _) => gText('${kioskView(ref).department} · IUT de Douala', 18, Color(0xFF66636E), wrap: true))),
      gP(274, 646, 164, 33, Consumer(builder: (context, ref, _) => gText(fcfa(kioskView(ref).price), 26, Color(0xFF5A3FE0), weight: 700))),
      gP(146, 696, 35, 19, gText('Date', 15, Color(0xFF66636E))),
      gP(146, 720, 115, 24, Consumer(builder: (context, ref, _) => gText('${ref.watch(nowProvider).day} ${const ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."][ref.watch(nowProvider).month - 1]} ${ref.watch(nowProvider).year}', 19, Color(0xFF111015), weight: 600))),
      gP(298, 696, 44, 19, gText('Heure', 15, Color(0xFF66636E))),
      gP(298, 720, 52, 24, Consumer(builder: (context, ref, _) => gText('${ref.watch(nowProvider).hour.toString().padLeft(2, "0")}:${ref.watch(nowProvider).minute.toString().padLeft(2, "0")}', 19, Color(0xFF111015), weight: 600))),
      gP(450, 696, 48, 19, gText('Retrait', 15, Color(0xFF66636E))),
      gP(450, 720, 94, 24, gText('Atelier GC', 19, Color(0xFF111015), weight: 600)),
      gP(308.5, 826, 103, 20, gText('Code de suivi', 16, Color(0xFF66636E))),
      gP(235.5, 854, 249, 43, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskSessionProvider)?.tracking ?? 'BE-2210-7F3A', 34, Color(0xFF111015), weight: 700))),
      gP(173, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(181, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(189, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(197, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(205, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(213, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(221, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(229, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(237, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(245, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(253, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(261, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(269, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(277, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(285, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(293, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(301, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(309, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(317, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(325, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(333, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(341, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(349, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(357, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(365, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(373, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(381, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(389, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(397, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(405, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(413, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(421, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(429, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(437, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(445, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(453, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(461, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(469, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(477, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(485, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(493, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(501, 927, 10, 76, gImg('assets/figma/v/833619e80c5a5a.svg')),
      gP(509, 927, 12, 76, gImg('assets/figma/v/1b82a3c6ea8156.svg')),
      gP(517, 927, 9, 76, gImg('assets/figma/v/b58ca8be7b9aaf.svg')),
      gP(525, 927, 11, 76, gImg('assets/figma/v/e8f9fb3df9076b.svg')),
      gP(533, 927, 8, 76, gImg('assets/figma/v/bc15be253fcc8c.svg')),
      gP(130, 1100, 300, 92, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x14403366), offset: Offset(0, 6), blurRadius: 16, spreadRadius: 0)], radii: [46, 46, 46, 46])),
      gP(174.5, 1130.5, 31, 26, gImg('assets/figma/v/d22735c1ec7639.svg')),
      gP(179.5, 1145.5, 21, 16, gImg('assets/figma/v/dd0bf2dbcaada1.svg')),
      gP(230, 1131, 105, 30, gText('Imprimer', 24, Color(0xFF111015), weight: 600)),
      gP(446, 1100, 144, 92, gBox(color: Color(0xFF111015), radii: [46, 46, 46, 46])),
      gP(472, 1131, 92, 28, gText('Terminer', 22, Color(0xFFFFFFFF), weight: 600)),
      gP(255, 1214, 210, 21, gText('Retour à l’accueil dans 15 s', 17, Color(0xFF66636E))),
      gP(288.75, 190.75, 142.5, 142.5, gImg('assets/figma/r/178_50.png')),
      gP(326.25, 237.625, 67.5, 55, gImg('assets/figma/r/178_51.png')),
      gTap(446, 1100, 144, 92, () => gOpen(context, '237')),
      gTap(130, 1100, 300, 92, () { gToast(context, 'Ticket envoyé à l’imprimante de la borne'); }),
    ]);
  }
}
