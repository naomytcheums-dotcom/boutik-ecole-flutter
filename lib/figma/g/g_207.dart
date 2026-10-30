// GÉNÉRÉ par tool/figma_export/convert.py — écran 207 (nœud Figma 83:1783). Ne pas éditer à la main.
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

class G_207 extends ConsumerWidget {
  const G_207({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 720, h: 1280, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(380, 60, 480, 480, gBox(color: Color(0x80CDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(48, 44, 64, 58, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20])),
      gP(55, 49, 50, 48, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(128, 56, 181, 35, gText('Boutik-École', 28, Color(0xFF111015), weight: 600)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(520, 50, 68, 48, 'FR', 20, 600), GChip(596, 50, 68, 48, 'EN', 20, 600)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 24)),
      gP(596, 50, 68, 48, gBox(color: Color(0xFFFFFFFF), radii: [24, 24, 24, 24])),
      gP(48, 140, 624, 84, GField(hint: 'Que cherchez-vous ?', size: 26, hintColor: Color(0xFF66636E), weight: 400, padL: 88, onChanged: (v) { ref.read(kioskQueryProvider.notifier).set(v); }, multiline: true, padT: 24)),
      gP(84, 166, 32, 32, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(85, 167, 27.333, 27.333, gImg('assets/figma/v/6942bfb3846595.svg')),
      gP(103.267, 185.267, 11.733, 11.733, gImg('assets/figma/v/e1a28e5ccaba89.svg')),
      gP(598, 152, 60, 60, GMic(child: gBox(color: Color(0xFF111015), oval: true))),
      gP(48, 248, 116, 64, gBox(color: Color(0xFF111015), radii: [32, 32, 32, 32]), tap: () => gToast(context, 'Démonstration : Tout')),
      gP(82.5, 264, 47, 28, gText('Tout', 22, Color(0xFFFFFFFF), weight: 600)),
      gP(178, 248, 176, 64, gBox(color: Color(0xFFFFFFFF), radii: [32, 32, 32, 32]), tap: () => gToast(context, 'Démonstration : Produits')),
      gP(221.5, 264, 89, 28, gText('Produits', 22, Color(0xFF111015), weight: 500)),
      gP(368, 248, 176, 64, gBox(color: Color(0xFFFFFFFF), radii: [32, 32, 32, 32]), tap: () => gToast(context, 'Démonstration : Services')),
      gP(410.5, 264, 91, 28, gText('Services', 22, Color(0xFF111015), weight: 500)),
      gP(558, 248, 176, 64, gBox(color: Color(0xFFFFFFFF), radii: [32, 32, 32, 32]), tap: () => gToast(context, 'Démonstration : Missions')),
      gP(600.5, 264, 91, 28, gText('Missions', 22, Color(0xFF111015), weight: 500)),
      gP(48, 340, 304, 230, gBox(image: (ref.watch(kioskProductsProvider).length > 0 ? ref.watch(kioskProductsProvider)[0].image : ''), fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 22, spreadRadius: 0)], radii: [40, 40, 40, 40]), show: (ref.watch(kioskProductsProvider).length > 0)),
      gP(62, 354, 104, 40, gBox(color: Color(0xFFFFFFFF), radii: [20, 20, 20, 20])),
      gP(71.5, 362.667, 21, 22.667, gImg('assets/figma/v/92817dfd3eb1c2.svg')),
      gP(98, 364, 60, 21, gText('Boosté', 17, Color(0xFF111015), weight: 600)),
      gP(48, 582, 304, 114, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 16, spreadRadius: 0)], radii: [34, 34, 34, 34]), show: (ref.watch(kioskProductsProvider).length > 0)),
      gP(70, 596, 263, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 0 ? ref.watch(kioskProductsProvider)[0].title : '', 22, Color(0xFF111015), weight: 600, wrap: true)), show: (ref.watch(kioskProductsProvider).length > 0)),
      gP(70, 628, 78, 20, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 0 ? ref.watch(kioskProductsProvider)[0].department : '', 16, Color(0xFF66636E))), show: (ref.watch(kioskProductsProvider).length > 0)),
      gP(70, 654, 139, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 0 ? fcfa(ref.watch(kioskProductsProvider)[0].price) : '', 22, Color(0xFF5A3FE0), weight: 700)), show: (ref.watch(kioskProductsProvider).length > 0)),
      gP(213.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(235.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(257.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(279.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(301.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(368, 340, 304, 230, gBox(image: (ref.watch(kioskProductsProvider).length > 1 ? ref.watch(kioskProductsProvider)[1].image : ''), fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 22, spreadRadius: 0)], radii: [40, 40, 40, 40]), show: (ref.watch(kioskProductsProvider).length > 1)),
      gP(368, 582, 304, 114, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 16, spreadRadius: 0)], radii: [34, 34, 34, 34]), show: (ref.watch(kioskProductsProvider).length > 1)),
      gP(390, 596, 263, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 1 ? ref.watch(kioskProductsProvider)[1].title : '', 22, Color(0xFF111015), weight: 600, wrap: true)), show: (ref.watch(kioskProductsProvider).length > 1)),
      gP(390, 628, 29, 20, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 1 ? ref.watch(kioskProductsProvider)[1].department : '', 16, Color(0xFF66636E))), show: (ref.watch(kioskProductsProvider).length > 1)),
      gP(390, 654, 119, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 1 ? fcfa(ref.watch(kioskProductsProvider)[1].price) : '', 22, Color(0xFF5A3FE0), weight: 700)), show: (ref.watch(kioskProductsProvider).length > 1)),
      gP(533.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(555.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(577.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(599.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(621.5, 621.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(48, 720, 304, 230, gBox(image: (ref.watch(kioskProductsProvider).length > 2 ? ref.watch(kioskProductsProvider)[2].image : ''), fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 22, spreadRadius: 0)], radii: [40, 40, 40, 40]), show: (ref.watch(kioskProductsProvider).length > 2)),
      gP(48, 962, 304, 114, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 16, spreadRadius: 0)], radii: [34, 34, 34, 34]), show: (ref.watch(kioskProductsProvider).length > 2)),
      gP(70, 976, 263, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 2 ? ref.watch(kioskProductsProvider)[2].title : '', 22, Color(0xFF111015), weight: 600, wrap: true)), show: (ref.watch(kioskProductsProvider).length > 2)),
      gP(70, 1008, 67, 20, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 2 ? ref.watch(kioskProductsProvider)[2].department : '', 16, Color(0xFF66636E))), show: (ref.watch(kioskProductsProvider).length > 2)),
      gP(70, 1034, 135, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 2 ? fcfa(ref.watch(kioskProductsProvider)[2].price) : '', 22, Color(0xFF5A3FE0), weight: 700)), show: (ref.watch(kioskProductsProvider).length > 2)),
      gP(213.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(235.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(257.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(279.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(301.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(368, 720, 304, 230, gBox(image: (ref.watch(kioskProductsProvider).length > 3 ? ref.watch(kioskProductsProvider)[3].image : ''), fit: BoxFit.cover, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 10), blurRadius: 22, spreadRadius: 0)], radii: [40, 40, 40, 40]), show: (ref.watch(kioskProductsProvider).length > 3)),
      gP(368, 962, 304, 114, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 16, spreadRadius: 0)], radii: [34, 34, 34, 34]), show: (ref.watch(kioskProductsProvider).length > 3)),
      gP(390, 976, 263, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 3 ? ref.watch(kioskProductsProvider)[3].title : '', 22, Color(0xFF111015), weight: 600, wrap: true)), show: (ref.watch(kioskProductsProvider).length > 3)),
      gP(390, 1008, 99, 20, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 3 ? ref.watch(kioskProductsProvider)[3].department : '', 16, Color(0xFF66636E))), show: (ref.watch(kioskProductsProvider).length > 3)),
      gP(390, 1034, 125, 28, Consumer(builder: (context, ref, _) => gText(ref.watch(kioskProductsProvider).length > 3 ? fcfa(ref.watch(kioskProductsProvider)[3].price) : '', 22, Color(0xFF5A3FE0), weight: 700)), show: (ref.watch(kioskProductsProvider).length > 3)),
      gP(533.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(555.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(577.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(599.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(621.5, 1031.5, 21, 20.25, gImg('assets/figma/v/5d0c07559d57d2.svg')),
      gP(48, 1112, 624, 124, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 8), blurRadius: 24, spreadRadius: 0)], backBlur: 28, radii: [62, 62, 62, 62])),
      gP(108, 1142, 36, 36, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(109.5, 1142.03, 33, 34.47, gImg('assets/figma/v/591e7e13beabb7.svg')),
      gP(96, 1190, 60, 21, gText('Accueil', 17, Color(0xFF111015), weight: 500), tap: () => gTab(context, '03')),
      gP(212, 1126, 140, 96, gBox(color: Color(0xFF111015), radii: [48, 48, 48, 48])),
      gP(264, 1142, 36, 36, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(265.5, 1143.5, 30, 30, gImg('assets/figma/v/0e0e8a6ca98696.svg')),
      gP(286.05, 1164.05, 12.45, 12.45, gImg('assets/figma/v/b24debd4c97b40.svg')),
      gP(247.5, 1190, 69, 21, gText('Explorer', 17, Color(0xFFFFFFFF), weight: 600)),
      gP(421.5, 1143.5, 16.5, 16.5, gImg('assets/figma/v/f071cd031085d5.svg')),
      gP(438, 1143.5, 16.5, 16.5, gImg('assets/figma/v/f071cd031085d5.svg')),
      gP(421.5, 1160, 16.5, 16.5, gImg('assets/figma/v/f071cd031085d5.svg')),
      gP(438, 1160, 15, 16.5, gImg('assets/figma/v/3270830e2cda0b.svg')),
      gP(405.5, 1190, 65, 21, gText('Mon QR', 17, Color(0xFF111015), weight: 500)),
      gP(576, 1142, 36, 36, gImg('assets/figma/v/9366c93bec9b55.svg')),
      gP(586.65, 1149.612, 14.7, 20.888, gImg('assets/figma/v/ea16a39cf97c64.svg')),
      gP(575, 1190, 38, 21, gText('Aide', 17, Color(0xFF111015), weight: 500)),
      gP(48, 340, 304, 360, const SizedBox.expand(), tap: () => gOpen(context, '208')),
      gTap(48, 340, 304, 360, () { final l = ref.read(kioskProductsProvider); if (l.length > 0) { ref.read(kioskProductProvider.notifier).set(l[0].title); gOpen(context, '208'); } }),
      gTap(368, 340, 304, 360, () { final l = ref.read(kioskProductsProvider); if (l.length > 1) { ref.read(kioskProductProvider.notifier).set(l[1].title); gOpen(context, '208'); } }),
      gTap(48, 720, 304, 360, () { final l = ref.read(kioskProductsProvider); if (l.length > 2) { ref.read(kioskProductProvider.notifier).set(l[2].title); gOpen(context, '208'); } }),
      gTap(368, 720, 304, 360, () { final l = ref.read(kioskProductsProvider); if (l.length > 3) { ref.read(kioskProductProvider.notifier).set(l[3].title); gOpen(context, '208'); } }),
      gTap(397.5, 1182, 81, 37, () { gOpen(context, '282'); }), // lien métier 207 -> 282
    ]);
  }
}
