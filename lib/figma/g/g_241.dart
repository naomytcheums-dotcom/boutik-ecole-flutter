// GÉNÉRÉ par tool/figma_export/convert.py — écran 241 (nœud Figma 125:99). Ne pas éditer à la main.
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

class G_241 extends ConsumerWidget {
  const G_241({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.546, 83.546, 11.454, 16.908, gImg('assets/figma/v/eadfa38ab5fb32.svg')),
      gP(43.546, 89, 16.908, 6, gImg('assets/figma/v/876f9e4ca5bd5d.svg')),
      gP(140, 76, 110, 21, gText('Mes contacts', 17, Color(0xFF111015), weight: 500)),
      gP(89, 100, 212, 15, gText('WhatsApp et répertoire du téléphone', 12, Color(0xFF66636E))),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(328.65, 82.65, 18.7, 18.7, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(327.987, 81.988, 18.467, 18.467, gImg('assets/figma/v/027b8aa954f1e6.svg')),
      gP(338.662, 92.662, 9.35, 9.35, gImg('assets/figma/v/096e5d96dc48c0.svg')),
      gP(34, 146, 40, 40, gBox(color: Color(0xFFEEE9FF), oval: true)),
      gP(44.25, 162.25, 19.5, 14.25, gImg('assets/figma/v/1978463acc5f47.svg')),
      gP(47.25, 155.5, 13.5, 12.75, gImg('assets/figma/v/cea5406f3a6ffe.svg')),
      gP(86, 142, 189, 16, gText('Autoriser l’accès aux contacts', 13, Color(0xFF111015), weight: 600)),
      gP(86, 162, 213, 30, gText('Rien n’est enregistré sans ton accord.\nTu peux le retirer à tout moment.', 10.5, Color(0xFF66636E), lh: 15, wrap: true)),
      gP(318, 154, 36, 22, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 16)),
      gP(24, 220, 342, 46, GField(hint: 'Rechercher un contact', size: 12.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46)),
      gP(38, 235, 16, 16, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(37, 234, 16.667, 16.667, gImg('assets/figma/v/6cd505732f55fa.svg')),
      gP(46.133, 243.133, 8.867, 8.867, gImg('assets/figma/v/9ff6d75c1f17b1.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 278, 94, 34, 'WhatsApp', 12, 500), GChip(126, 278, 102, 34, 'Téléphone', 12, 400), GChip(236, 278, 62, 34, 'Tous', 12, 400)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFFFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 17)),
      gP(40, 340, 40, 40, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(92, 343, 99, 16, gText('Brice Ndoumbe', 13, Color(0xFF111015), weight: 600)),
      gP(92, 362, 158, 13, gText('Sur WhatsApp · pas encore inscrit', 10, Color(0xFF66636E))),
      gP(324, 348, 24, 24, gBox(color: Color(0xFF111015), oval: true)),
      gP(328.667, 353.75, 14.667, 11.958, gImg('assets/figma/v/c3c396240caa1d.svg')),
      gP(92, 387, 254, 1, gBox(color: Color(0xFFF0EDF4))),
      gP(40, 398, 40, 40, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(92, 401, 92, 16, gText('Carine Mbarga', 13, Color(0xFF111015), weight: 600)),
      gP(92, 420, 164, 13, gText('Sur WhatsApp · pas encore inscrite', 10, Color(0xFF66636E))),
      gP(324, 406, 24, 24, gBox(color: Color(0xFF111015), oval: true)),
      gP(328.667, 411.75, 14.667, 11.958, gImg('assets/figma/v/c3c396240caa1d.svg')),
      gP(92, 445, 254, 1, gBox(color: Color(0xFFF0EDF4))),
      gP(40, 456, 40, 40, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(92, 459, 89, 16, gText('Kouassi Tagne', 13, Color(0xFF111015), weight: 600)),
      gP(92, 478, 158, 13, gText('Sur WhatsApp · pas encore inscrit', 10, Color(0xFF66636E))),
      gP(324, 464, 24, 24, gBox(color: Color(0xFF111015), oval: true)),
      gP(328.667, 469.75, 14.667, 11.958, gImg('assets/figma/v/c3c396240caa1d.svg')),
      gP(92, 503, 254, 1, gBox(color: Color(0xFFF0EDF4))),
      gP(40, 514, 40, 40, gBox(image: 'assets/figma/img/2bbb6fbaae9e6d864765beabd4e677ca34d5a95e.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(92, 517, 76, 16, gText('Mme Mbella', 13, Color(0xFF111015), weight: 600)),
      gP(92, 536, 131, 13, gText('Sur WhatsApp · déjà inscrite', 10, Color(0xFF126B49))),
      gP(286, 522, 60, 25, gBox(color: Color(0xFFE8F7EE), radii: [100, 100, 100, 100])),
      gP(298, 528, 36, 13, gText('Inscrite', 10, Color(0xFF126B49), weight: 600)),
      gP(92, 561, 254, 1, gBox(color: Color(0xFFF0EDF4))),
      gP(40, 572, 40, 40, gBox(image: 'assets/figma/img/46d80b349804afa588f99bc3738b28175881dec1.png', fit: BoxFit.cover, radii: [20, 20, 20, 20])),
      gP(92, 575, 110, 16, gText('Yannick Mouanga', 13, Color(0xFF111015), weight: 600)),
      gP(92, 594, 158, 13, gText('Sur WhatsApp · pas encore inscrit', 10, Color(0xFF66636E))),
      gP(324, 580, 24, 24, gBox(color: Color(0xFFECE8F6), oval: true)),
      gP(44, 654, 89, 14, gText('Message envoyé', 11, Color(0xFF66636E), weight: 500)),
      gP(44, 674, 302, 52, gBox(color: Color(0xFFE7F6D9), radii: [16, 16, 16, 16]), tap: () => gToast(context, 'Démonstration : Salut ! Rejoins Boutik-École, la marketplace des talents de l’IUT de Douala : boutik-ecole.cm/r/mariam24')),
      gP(54, 680, 287, 28, gText('Salut ! Rejoins Boutik-École, la marketplace des talents de l’IUT de Douala : boutik-ecole.cm/r/mariam24', 10.5, Color(0xFF111015), lh: 14, wrap: true)),
      gP(24, 748, 342, 52, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x40403366), offset: Offset(0, 10), blurRadius: 22, spreadRadius: 0)], radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Envoyer via WhatsApp (3)')),
      gP(109, 763, 172, 18, gText('Envoyer via WhatsApp (3)', 14, Color(0xFFFFFFFF), weight: 600)),
      gP(91, 810, 208, 13, gText('Ou copier le lien et le partager moi-même', 10.5, Color(0xFF66636E), weight: 500)),
    ]);
  }
}
