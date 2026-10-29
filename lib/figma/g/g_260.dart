// GÉNÉRÉ par tool/figma_export/convert.py — écran 260 (nœud Figma 184:290). Ne pas éditer à la main.
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

class G_260 extends ConsumerWidget {
  const G_260({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 900, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(163.5, 76, 63, 21, gText('Facture', 17, Color(0xFF111015), weight: 500)),
      gP(147.5, 100, 95, 15, gText('FA-2026-00391', 12, Color(0xFF66636E))),
      gP(24, 124, 342, 640, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0F403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [30, 30, 30, 30])),
      gP(44, 144, 98, 19, gText('Boutik-École', 15, Color(0xFF111015), weight: 700)),
      gP(44, 166, 127, 13, gText('IUT de Douala · Cameroun', 10.5, Color(0xFF66636E))),
      gP(201, 144, 145, 14, Consumer(builder: (context, ref, _) => gText('Facture n° FA-2026-' + ref.watch(lastOrderProvider).id.substring(ref.watch(lastOrderProvider).id.length - 4), 11, Color(0xFF111015), weight: 600))),
      gP(143, 164, 203, 13, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).date, 10.5, Color(0xFF66636E), wrap: true, align: TextAlign.right))),
      gP(44, 200, 302, 30, gBox(color: Color(0xFFF4F1F8), radii: [10, 10, 10, 10])),
      gP(54, 208, 61, 13, gText('Désignation', 10.5, Color(0xFF66636E), weight: 500)),
      gP(226, 208, 20, 13, gText('Qté', 10.5, Color(0xFF66636E), weight: 500)),
      gP(293, 208, 43, 13, gText('Montant', 10.5, Color(0xFF66636E), weight: 500)),
      gP(54, 248, 128, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 0 ? ref.watch(lastOrderProvider).lines[0].title : '', 12, Color(0xFF111015), weight: 500))),
      gP(230, 248, 8, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 0 ? '${ref.watch(lastOrderProvider).lines[0].qty}' : '', 12, Color(0xFF111015)))),
      gP(152, 248, 184, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 0 ? fcfa(ref.watch(lastOrderProvider).lines[0].price * ref.watch(lastOrderProvider).lines[0].qty).replaceAll(' FCFA', '') : '', 12, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 276, 302, 1, gBox(color: Color(0xFFEEECF1))),
      gP(54, 288, 108, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 1 ? ref.watch(lastOrderProvider).lines[1].title : '', 12, Color(0xFF111015), weight: 500))),
      gP(230, 288, 5, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 1 ? '${ref.watch(lastOrderProvider).lines[1].qty}' : '', 12, Color(0xFF111015)))),
      gP(155, 288, 181, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 1 ? fcfa(ref.watch(lastOrderProvider).lines[1].price * ref.watch(lastOrderProvider).lines[1].qty).replaceAll(' FCFA', '') : '', 12, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 316, 302, 1, gBox(color: Color(0xFFEEECF1))),
      gP(54, 328, 114, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 2 ? ref.watch(lastOrderProvider).lines[2].title : '', 12, Color(0xFF111015), weight: 500))),
      gP(230, 328, 8, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 2 ? '${ref.watch(lastOrderProvider).lines[2].qty}' : '', 12, Color(0xFF111015)))),
      gP(152, 328, 184, 15, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).lines.length > 2 ? fcfa(ref.watch(lastOrderProvider).lines[2].price * ref.watch(lastOrderProvider).lines[2].qty).replaceAll(' FCFA', '') : '', 12, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 356, 302, 1, gBox(color: Color(0xFFEEECF1))),
      gP(44, 380, 103, 15, gText('Détail du montant', 12, Color(0xFF111015), weight: 600)),
      gP(44, 408, 71, 14, gText('Montant brut', 11.5, Color(0xFF66636E))),
      gP(133, 408, 213, 14, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total), 11.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 438, 97, 14, gText('Frais de paiement', 11.5, Color(0xFF66636E))),
      gP(145, 438, 201, 14, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total * 0.015), 11.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 468, 96, 14, gText('Taxes applicables', 11.5, Color(0xFF66636E))),
      gP(306, 468, 40, 14, gText('0 FCFA', 11.5, Color(0xFF111015), weight: 600)),
      gP(44, 498, 194, 14, gText('Commission de la plateforme (10 %)', 11.5, Color(0xFF66636E))),
      gP(141, 498, 205, 14, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total * 0.10), 11.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 528, 194, 14, gText('Part étudiants / département (70 %)', 11.5, Color(0xFF66636E))),
      gP(134, 528, 212, 14, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total * 0.70), 11.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 558, 141, 14, gText('Fonds d’innovation (20 %)', 11.5, Color(0xFF66636E))),
      gP(137, 558, 209, 14, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total * 0.20), 11.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 604, 302, 60, gBox(color: Color(0xFFF4F1F8), radii: [22, 22, 22, 22])),
      gP(60, 626, 61, 18, gText('Total TTC', 14, Color(0xFF111015), weight: 600)),
      gP(76, 624, 254, 23, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total), 18, Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right))),
      gP(44, 690, 305, 13, gText('Répartition indicative selon la règle validée par l’établissement.', 10, Color(0xFF66636E), wrap: true)),
      gP(24, 790, 342, 52, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x38403366), offset: Offset(0, 8), blurRadius: 18, spreadRadius: 0)], radii: [26, 26, 26, 26])),
      gP(108.5, 808, 173, 16, gText('Télécharger la facture (PDF)', 13, Color(0xFFFFFFFF), weight: 600)),
      gTap(24, 790, 342, 52, () => gOpen(context, '44')),
    ]);
  }
}
