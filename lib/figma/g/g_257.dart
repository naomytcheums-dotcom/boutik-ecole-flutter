// GÉNÉRÉ par tool/figma_export/convert.py — écran 257 (nœud Figma 184:174). Ne pas éditer à la main.
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

class G_257 extends ConsumerWidget {
  const G_257({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(156, 76, 78, 21, gText('Paiement', 17, Color(0xFF111015), weight: 500)),
      gP(111.5, 100, 167, 15, Consumer(builder: (context, ref, _) => gText('Commande ${ref.watch(lastOrderProvider).id}', 12, Color(0xFF66636E)))),
      gP(67, 300, 256, 25, gText('En attente de confirmation', 20, Color(0xFF111015), weight: 600)),
      gP(46.5, 336, 297, 54, gText('Validez le paiement sur votre téléphone avec votre code Orange Money. Cela peut prendre jusqu’à 2 minutes.', 12, Color(0xFF66636E), lh: 18, align: TextAlign.center, wrap: true)),
      gP(44, 430, 39, 15, gText('Moyen', 12, Color(0xFF66636E))),
      gP(116, 430, 230, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).method, 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 462, 48, 15, gText('Montant', 12, Color(0xFF66636E))),
      gP(118, 462, 228, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total), 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 494, 60, 15, gText('Référence', 12, Color(0xFF66636E))),
      gP(110, 494, 236, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).reference, 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(44, 526, 72, 15, gText('Délai restant', 12, Color(0xFF66636E))),
      gP(311, 526, 35, 16, gText('01:48', 12.5, Color(0xFF111015), weight: 600)),
      gP(38.25, 611.25, 19.5, 14.25, gImg('assets/figma/v/547ea4a5755a2a.svg')),
      gP(41.25, 604.5, 13.5, 12.75, gImg('assets/figma/v/3cbc362f4fcfa9.svg')),
      gP(70, 596, 273, 32, gText('Ne fermez pas la page. Aucun montant n’est débité tant que vous n’avez pas validé.', 11, Color(0xFF5B5963), lh: 16, wrap: true)),
      gP(24, 680, 342, 52, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x38403366), offset: Offset(0, 8), blurRadius: 18, spreadRadius: 0)], radii: [26, 26, 26, 26])),
      gP(146, 698, 98, 16, gText('Vérifier le statut', 13, Color(0xFFFFFFFF), weight: 600)),
      gP(24, 744, 342, 48, gBox(color: Color(0xBFFFFFFF), border: Color(0xFFFFFFFF), bw: 1, radii: [24, 24, 24, 24])),
      gP(95, 760, 200, 16, gText('Changer de moyen de paiement', 13, Color(0xFF111015), weight: 600)),
      gP(24, 680, 342, 52, const SizedBox.expand(), tap: () => gOpen(context, '259')),
      gP(24, 744, 342, 48, const SizedBox.expand(), tap: () => gOpen(context, '258')),
      gP(145.167, 180.167, 99.667, 99.667, gImg('assets/figma/r/195_20.png')),
      gP(188.5, 197.5, 30.335, 47.668, gImg('assets/figma/r/195_21.png')),
      gTap(24, 680, 342, 52, () { ref.read(ordersProvider.notifier).markPaid(ref.read(lastOrderProvider).id); gOpen(context, '259'); }),
      gTap(24, 744, 342, 48, () => gOpen(context, '258')),
    ]);
  }
}
