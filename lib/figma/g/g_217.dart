// GÉNÉRÉ par tool/figma_export/convert.py — écran 217 (nœud Figma 87:80). Ne pas éditer à la main.
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
import '../live/engage.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_217 extends ConsumerWidget {
  const G_217({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 1112, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 216.96, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 806.32, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 227, 26, gText('Lampe en bois recyclé', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 190, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [26, 26, 26, 26])),
      gP(24, 120, 342, 190, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x000B2340), Color(0xE00B2340)], stops: [0, 1]), radii: [26, 26, 26, 26])),
      gP(42, 248, 309, 46, gText('Si 200 personnes la veulent, on la fabrique', 18, Color(0xFFFFFFFF), weight: 800, wrap: true)),
      gP(42, 278, 309, 15, gText('Vœu de Mouanga Yannick · Génie civil', 12, Color(0xD9FFFFFF), weight: 500, wrap: true)),
      gP(49, 414, 78, 30, gBox(color: Color(0xD98DF03A), layerBlur: 12, oval: true)),
      gP(38, 334, 100, 100, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF0E1A0B), Color(0xFF000000)], stops: [0, 1]), radii: [50, 50, 50, 50])),
      gP(38, 379, 100, 55, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x008DF03A), Color(0xBF8DF03A)], stops: [0, 1]))),
      gP(85, 332.5, 6, 14.5, gImg('assets/figma/v/bb3ffcce1ff37a.svg')),
      gP(88.49, 332.68, 6.74, 14.47, gImg('assets/figma/v/27471dd7fd42f6.svg')),
      gP(91.95, 333.24, 7.47, 14.37, gImg('assets/figma/v/d284dad05a7508.svg')),
      gP(95.35, 334.15, 8.2, 14.21, gImg('assets/figma/v/10517294c4483c.svg')),
      gP(98.68, 335.42, 8.91, 13.99, gImg('assets/figma/v/e1ea4c36d346f4.svg')),
      gP(101.9, 337.04, 9.6, 13.71, gImg('assets/figma/v/7fa6745da4f058.svg')),
      gP(105, 339, 10.25, 13.36, gImg('assets/figma/v/5d599dbbafa97d.svg')),
      gP(107.94, 341.27, 10.88, 12.96, gImg('assets/figma/v/54a80ea998f77f.svg')),
      gP(110.71, 343.85, 11.47, 12.51, gImg('assets/figma/v/63f1426b53fc09.svg')),
      gP(113.28, 346.71, 12.01, 12.01, gImg('assets/figma/v/737d55eec49986.svg')),
      gP(115.64, 349.82, 12.51, 11.47, gImg('assets/figma/v/214db4f131827e.svg')),
      gP(117.77, 353.18, 12.96, 10.88, gImg('assets/figma/v/65aef2437f5b54.svg')),
      gP(119.64, 356.75, 13.36, 10.25, gImg('assets/figma/v/272d8004580fa4.svg')),
      gP(121.25, 360.5, 13.71, 9.6, gImg('assets/figma/v/c51c76419add0b.svg')),
      gP(122.59, 364.41, 13.99, 8.91, gImg('assets/figma/v/7f037c7cf43dc9.svg')),
      gP(123.64, 368.45, 14.21, 8.2, gImg('assets/figma/v/11c8f3161b72d9.svg')),
      gP(124.39, 372.58, 14.37, 7.47, gImg('assets/figma/v/2ec4dd1998cc50.svg')),
      gP(124.85, 376.77, 14.47, 6.74, gImg('assets/figma/v/306f61194c19aa.svg')),
      gP(125, 381, 14.5, 6, gImg('assets/figma/v/dbfcf58eab0fa1.svg')),
      gP(124.85, 384.49, 14.47, 6.74, gImg('assets/figma/v/3d8c06ab69f6aa.svg')),
      gP(124.39, 387.95, 14.37, 7.47, gImg('assets/figma/v/fccc364045e04f.svg')),
      gP(123.64, 391.35, 14.21, 8.2, gImg('assets/figma/v/cf8a710f8e8599.svg')),
      gP(122.59, 394.68, 13.99, 8.91, gImg('assets/figma/v/e30dec620ab2ad.svg')),
      gP(121.25, 397.9, 13.71, 9.6, gImg('assets/figma/v/eff9e29824f079.svg')),
      gP(119.64, 401, 13.36, 10.25, gImg('assets/figma/v/ff94859845ea41.svg')),
      gP(117.77, 403.94, 12.96, 10.88, gImg('assets/figma/v/de96a23e2f5ab2.svg')),
      gP(115.64, 406.71, 12.51, 11.47, gImg('assets/figma/v/5bc145737308b4.svg')),
      gP(113.28, 409.28, 12.01, 12.01, gImg('assets/figma/v/0e79386414bb45.svg')),
      gP(110.71, 411.64, 11.47, 12.51, gImg('assets/figma/v/03ec7a382c1926.svg')),
      gP(107.94, 413.77, 10.88, 12.96, gImg('assets/figma/v/507e4c3daee336.svg')),
      gP(105, 415.64, 10.25, 13.36, gImg('assets/figma/v/65c370b128388d.svg')),
      gP(101.9, 417.25, 9.6, 13.71, gImg('assets/figma/v/1a5eca955ab25b.svg')),
      gP(98.68, 418.59, 8.91, 13.99, gImg('assets/figma/v/12385ed3d53fca.svg')),
      gP(95.35, 419.64, 8.2, 14.21, gImg('assets/figma/v/68e4b0b172c4d4.svg')),
      gP(91.95, 420.39, 7.47, 14.37, gImg('assets/figma/v/428c959da65038.svg')),
      gP(88.49, 420.85, 6.74, 14.47, gImg('assets/figma/v/c500eb012f7fea.svg')),
      gP(85, 421, 6, 14.5, gImg('assets/figma/v/aa756e6be2a18d.svg')),
      gP(80.77, 420.85, 6.74, 14.47, gImg('assets/figma/v/24b686e9f79325.svg')),
      gP(76.58, 420.39, 7.47, 14.37, gImg('assets/figma/v/ec438b825140ee.svg')),
      gP(72.45, 419.64, 8.2, 14.21, gImg('assets/figma/v/2f17e2a53b98ae.svg')),
      gP(68.41, 418.59, 8.91, 13.99, gImg('assets/figma/v/6e9292601b25ee.svg')),
      gP(64.5, 417.25, 9.6, 13.71, gImg('assets/figma/v/35b68d03e7b514.svg')),
      gP(60.75, 415.64, 10.25, 13.36, gImg('assets/figma/v/347263c84897ec.svg')),
      gP(57.18, 413.77, 10.88, 12.96, gImg('assets/figma/v/84bacbe0efd450.svg')),
      gP(53.82, 411.64, 11.47, 12.51, gImg('assets/figma/v/464570a76a441c.svg')),
      gP(50.71, 409.28, 12.01, 12.01, gImg('assets/figma/v/2577064d0aa798.svg')),
      gP(47.85, 406.71, 12.51, 11.47, gImg('assets/figma/v/297e504e57dd2b.svg')),
      gP(45.27, 403.94, 12.96, 10.88, gImg('assets/figma/v/f5c2e0ad5f5851.svg')),
      gP(43, 401, 13.36, 10.25, gImg('assets/figma/v/945eb72b8fb189.svg')),
      gP(41.04, 397.9, 13.71, 9.6, gImg('assets/figma/v/bc3a77af8349dc.svg')),
      gP(39.42, 394.68, 13.99, 8.91, gImg('assets/figma/v/c48dcfd61bcb16.svg')),
      gP(38.15, 391.35, 14.21, 8.2, gImg('assets/figma/v/5a56b1ca0f939e.svg')),
      gP(37.24, 387.95, 14.37, 7.47, gImg('assets/figma/v/292ec28bb150d1.svg')),
      gP(36.68, 384.49, 14.47, 6.74, gImg('assets/figma/v/68493056ed287d.svg')),
      gP(36.5, 381, 14.5, 6, gImg('assets/figma/v/35fdf7276720cd.svg')),
      gP(36.68, 376.77, 14.47, 6.74, gImg('assets/figma/v/11990715245205.svg')),
      gP(37.24, 372.58, 14.37, 7.47, gImg('assets/figma/v/01e303e178d25c.svg')),
      gP(38.15, 368.45, 14.21, 8.2, gImg('assets/figma/v/a413104b6380cf.svg')),
      gP(39.42, 364.41, 13.99, 8.91, gImg('assets/figma/v/366b663a9f7783.svg')),
      gP(41.04, 360.5, 13.71, 9.6, gImg('assets/figma/v/7167d05e94bb4b.svg')),
      gP(43, 356.75, 13.36, 10.25, gImg('assets/figma/v/e98ba674cae6aa.svg')),
      gP(45.27, 353.18, 12.96, 10.88, gImg('assets/figma/v/4e01e2214372e5.svg')),
      gP(47.85, 349.82, 12.51, 11.47, gImg('assets/figma/v/e211e02703dbeb.svg')),
      gP(50.71, 346.71, 12.01, 12.01, gImg('assets/figma/v/4536162728744c.svg')),
      gP(53.82, 343.85, 11.47, 12.51, gImg('assets/figma/v/49509e989beda2.svg')),
      gP(57.18, 341.27, 10.88, 12.96, gImg('assets/figma/v/abf6b11d9dd397.svg')),
      gP(60.75, 339, 10.25, 13.36, gImg('assets/figma/v/7840d8a8082e2d.svg')),
      gP(64.5, 337.04, 9.6, 13.71, gImg('assets/figma/v/361df34499eacf.svg')),
      gP(68.41, 335.42, 8.91, 13.99, gImg('assets/figma/v/aeeeada5022f5c.svg')),
      gP(72.45, 334.15, 8.2, 14.21, gImg('assets/figma/v/3e458cd27d3134.svg')),
      gP(76.58, 333.24, 7.47, 14.37, gImg('assets/figma/v/9eeba09b250050.svg')),
      gP(80.77, 332.68, 6.74, 14.47, gImg('assets/figma/v/4510aeb054463f.svg')),
      gP(80.667, 352.083, 14.667, 16.833, gImg('assets/figma/v/fb0d9d095f4d85.svg')),
      gP(61.5, 370, 53, 33, gText('78%', 27, Color(0xFF9BE88A), weight: 300, inter: true)),
      gP(152, 358, 201, 19, gText('156 sur 200', 15, Color(0xFF111015), weight: 700, wrap: true)),
      gP(152, 384, 201, 34, gText('Encore 44 précommandes pour lancer la production.', 12, Color(0xFF66636E), lh: 17, wrap: true)),
      gP(40, 472, 76, 18, gText('Conditions', 14, Color(0xFF111015), weight: 700)),
      gP(40, 506, 22, 16, gText('Prix', 12.5, Color(0xFF66636E))),
      gP(271, 506, 79, 16, gText('25 000 FCFA', 12.5, Color(0xFF111015), weight: 700, align: TextAlign.right)),
      gP(40, 531, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 540, 103, 16, gText('Livraison estimée', 12.5, Color(0xFF66636E))),
      gP(204, 540, 146, 16, gText('6 semaines après le seuil', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 565, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 574, 100, 16, gText('Remboursement', 12.5, Color(0xFF66636E))),
      gP(162, 574, 188, 16, gText('Automatique si seuil non atteint', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 626, 51, 19, gText('Étapes', 15, Color(0xFF111015), weight: 700)),
      gP(33, 686, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 665, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 669.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 664, 305, 17, gText('Vœu publié', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 684, 305, 14, gText('02 oct.', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 748, 2, 40, gBox(color: Color(0xFFECE8F2), radii: [1, 1, 1, 1])),
      gP(24, 727, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 726, 305, 17, gText('Précommandes ouvertes', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 746, 305, 14, gText('156 / 200', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 810, 2, 40, gBox(color: Color(0xFFECE8F2), radii: [1, 1, 1, 1])),
      gP(24, 789, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 788, 305, 17, gText('Production', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 808, 305, 14, gText('Dès 200 précommandes', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 851, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 850, 305, 17, gText('Retrait au kiosque', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 870, 305, 14, gText('', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 926, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 941, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(43.333, 946.943, 17.333, 20.173, gImg('assets/figma/v/b35e336eb0a1dc.svg')),
      gP(46.875, 952.583, 10.25, 8.833, gImg('assets/figma/v/2bdcafa88f7a43.svg')),
      gP(76, 940, 277, 34, gText('Votre argent reste bloqué en séquestre jusqu’au lancement de la production.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 1012, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 1028, 342, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => engageOrManage(context, ref, 'preorder', 'wish:lampe-en-bois-recycle', data: {'price': 25000}, success: 'Précommande enregistrée. Le paiement n’est demandé qu’au lancement de la production.', need: 'précommander', activeTitle: 'Précommande déjà enregistrée', activeBody: 'Vous serez prévenu(e) au lancement de la production ; aucun paiement n’a été demandé.', keepLabel: 'La garder', cancelLabel: 'Annuler la précommande', cancelled: 'Précommande annulée.')),
      if (isEngaged(ref, 'preorder|wish:lampe-en-bois-recycle')) gP(24, 1046, 342, 18, gText('Précommandé ✓ · Gérer', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)) else gP(89.5, 1046, 211, 18, gText('Précommander · 25 000 FCFA', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 1098, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
    ]);
  }
}
