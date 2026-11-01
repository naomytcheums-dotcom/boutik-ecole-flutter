// GÉNÉRÉ par tool/figma_export/convert.py — écran 135 (nœud Figma 43:1139). Ne pas éditer à la main.
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

class G_135 extends ConsumerWidget {
  const G_135({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 134, 485, 222, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(284, 148, 208, 17, gText('Règles actuelles (modifiables)', 14, Color(0xFF111015), weight: 700, inter: true)),
      gP(284, 182, 167, 15, gText('Commission sur les produits', 12.5, Color(0xFF66636E), inter: true)),
      gP(575, 182, 162, 15, Consumer(builder: (context, ref, _) => gText('${ref.watch(rulesConfigProvider).product} %', 12.5, Color(0xFF111015), weight: 600, inter: true, wrap: true, align: TextAlign.right))),
      gP(284, 207, 453, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 216, 168, 15, gText('Commission sur les services', 12.5, Color(0xFF66636E), inter: true)),
      gP(576, 216, 161, 15, Consumer(builder: (context, ref, _) => gText('${ref.watch(rulesConfigProvider).service} %', 12.5, Color(0xFF111015), weight: 600, inter: true, wrap: true, align: TextAlign.right))),
      gP(284, 241, 453, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 250, 217, 15, gText('Commission financement participatif', 12.5, Color(0xFF66636E), inter: true)),
      gP(575, 250, 162, 15, Consumer(builder: (context, ref, _) => gText('${ref.watch(rulesConfigProvider).financing} %', 12.5, Color(0xFF111015), weight: 600, inter: true, wrap: true, align: TextAlign.right))),
      gP(284, 275, 453, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 284, 136, 15, gText('Frais de retrait kiosque', 12.5, Color(0xFF66636E), inter: true)),
      gP(695, 284, 42, 15, gText('Gratuit', 12.5, Color(0xFF111015), weight: 600, inter: true, align: TextAlign.right)),
      gP(284, 309, 453, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 318, 158, 15, gText('Seuil de paiement vendeur', 12.5, Color(0xFF66636E), inter: true)),
      gP(519, 318, 218, 15, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(rulesConfigProvider).threshold), 12.5, Color(0xFF111015), weight: 600, inter: true, wrap: true, align: TextAlign.right))),
      gP(767, 134, 485, 132, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(779, 147, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(790.167, 158.167, 17.667, 17.667, gImg('assets/figma/v/ce24693e5a670e.svg')),
      gP(789.333, 157.333, 10.167, 10.167, gImg('assets/figma/v/5857530a2c5105.svg')),
      gP(798.5, 166.5, 10.167, 10.167, gImg('assets/figma/v/5857530a2c5105.svg')),
      gP(831, 146, 167, 16, gText('Modifier les commissions', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(831, 168, 150, 14, gText('Effet à la prochaine période', 11.5, Color(0xFF66636E), inter: true)),
      gP(1166.8, 156, 71.2, 22, gBox(color: Color(0xFFEFEBFA), radii: [11, 11, 11, 11])),
      gP(1179.9, 160, 45, 13, gText('Modifier', 11, Color(0xFF5A3FE0), weight: 600, inter: true, align: TextAlign.center)),
      gP(831, 200, 409, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(779, 213, 40, 40, gBox(color: Color(0xFFF1EEFB), radii: [13, 13, 13, 13])),
      gP(788.5, 222.507, 21, 21, gImg('assets/figma/v/d19162b8025859.svg')),
      gP(788.5, 222.5, 10.167, 10.167, gImg('assets/figma/v/b5845d52cef132.svg')),
      gP(796, 225.833, 9.333, 11.833, gImg('assets/figma/v/42754a1c3e0ea3.svg')),
      gP(831, 212, 188, 16, gText('Historique des changements', 13.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(831, 234, 124, 14, Consumer(builder: (context, ref, _) => gText('Dernier : ${ref.watch(rulesConfigProvider).updated}', 11.5, Color(0xFF66636E), inter: true))),
      gP(1192.4, 222, 45.6, 22, gBox(color: Color(0xFFF2EFF6), radii: [11, 11, 11, 11])),
      gP(1203.7, 226, 22, 13, gText('Voir', 11, Color(0xFF66636E), weight: 600, inter: true, align: TextAlign.center)),
      gP(268, 370, 984, 52, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(280, 380, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(285.917, 385.917, 20.167, 20.167, gImg('assets/figma/v/48fd286aff90cc.svg')),
      gP(293, 393, 6, 8.833, gImg('assets/figma/v/9fc27387b9ffa1.svg')),
      gP(293, 390.167, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(320, 387.5, 919, 17, gText('Ces règles financières ont été validées par l’IUT de Douala ; l’administrateur peut les ajuster.', 12, Color(0xFF4A4854), inter: true, lh: 17, wrap: true)),
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true, onSubmitted: (v) { backofficeSearch(context, ref, v); })),
      gP(252.5, 21.5, 15, 15, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(251.375, 20.375, 16, 16, gImg('assets/figma/v/3a82c8c513bd84.svg')),
      gP(259.938, 28.938, 8.687, 8.687, gImg('assets/figma/v/ee5ed5a7003f46.svg')),
      gP(940, 15, 28, 28, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(960, 15, 28, 28, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(980, 15, 28, 28, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, border: Color(0xFFFFFFFF), bw: 2, oval: true)),
      gP(1026, 17, 24, 24, gBox(color: Color(0xFF111015), oval: true)),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(926.5, 10, 170, 36, '+3', 11, 500), GChip(1082, 10, 170, 36, 'Exporter', 12, 600)], selected: 1, selFill: Color(0xFF0B0B0D), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 18, inter: true)),
      gP(1214.125, 20.125, 15.75, 15.75, gImg('assets/figma/v/c7f198a8ce01e5.svg')),
      gP(0, 56, 240, 834, gBox(color: Color(0xFFF1EFEC))),
      gP(20, 84, 42, 12, gText('Principal', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(23.375, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 106.375, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(30.25, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(23.375, 113.25, 10.375, 10.375, gImg('assets/figma/v/46f5855326ca3f.svg')),
      gP(52, 107, 93, 15, gText('Tableau de bord', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 153.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(24.625, 146.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(33.375, 153.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(31.5, 146.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(52, 147, 97, 15, gText('Comptes et rôles', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 197.625, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(24.625, 186.375, 14.75, 17.25, gImg('assets/figma/v/b3da102be08062.svg')),
      gP(27.125, 193.875, 9.75, 9.75, gImg('assets/figma/v/c0732433837967.svg')),
      gP(52, 187, 63, 15, gText('Institutions', 12, Color(0xFF55524C), inter: true)),
      gP(24, 225.75, 16, 14.75, gImg('assets/figma/v/f78685b3689094.svg')),
      gP(24, 233.875, 6, 10.375, gImg('assets/figma/v/152d55a645ddf7.svg')),
      gP(52, 227, 65, 15, gText('Modération', 12, Color(0xFF55524C), inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(22.739, 298.366, 18.51, 17.259, gImg('assets/figma/v/2adfe02c023131.svg')),
      gP(29, 302.125, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(29, 307.125, 6.006, 6, gImg('assets/figma/v/ea7a417c4e88fe.svg')),
      gP(52, 299, 77, 15, gText('Signalements', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 338.375, 17.25, 16.625, gImg('assets/figma/v/0e7bfe7735ff71.svg')),
      gP(23.375, 341.5, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(29, 343.375, 6, 9.125, gImg('assets/figma/v/43269c010b1817.svg')),
      gP(52, 339, 72, 15, gText('Commandes', 12, Color(0xFF55524C), inter: true)),
      gP(24, 377.75, 16, 18.5, gImg('assets/figma/v/b8b641560aad30.svg')),
      gP(26.5, 381.5, 11, 11, gImg('assets/figma/v/f82584207e62a2.svg')),
      gP(29, 380.562, 6, 12.875, gImg('assets/figma/v/084a5a2da19358.svg')),
      gP(52, 379, 38, 15, gText('Litiges', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 418.375, 17.875, 14.125, gImg('assets/figma/v/b45a94448c908a.svg')),
      gP(23.375, 419.625, 17.25, 16, gImg('assets/figma/v/942aaa660c45c9.svg')),
      gP(52, 419, 73, 15, gText('Transactions', 12, Color(0xFF55524C), inter: true)),
      gP(12, 450, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(24.625, 459.625, 14.75, 14.75, gImg('assets/figma/v/b3a3ae04257941.svg')),
      gP(24, 459, 9.125, 9.125, gImg('assets/figma/v/e8118c9116f61a.svg')),
      gP(30.875, 465.875, 9.125, 9.125, gImg('assets/figma/v/e8118c9116f61a.svg')),
      gP(52, 459, 79, 15, gText('Commissions', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(23.375, 503.375, 17.25, 12.875, gImg('assets/figma/v/c58908ef7b898a.svg')),
      gP(25.875, 497.75, 12.25, 11.625, gImg('assets/figma/v/11c41e811d2750.svg')),
      gP(52, 499, 47, 15, gText('Sécurité', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 538.38, 17.25, 17.25, gImg('assets/figma/v/a50cd9410c0076.svg')),
      gP(23.375, 538.375, 9.125, 9.125, gImg('assets/figma/v/3ad9c2af89ef3b.svg')),
      gP(29, 540.875, 8.5, 10.375, gImg('assets/figma/v/23a92abb65788c.svg')),
      gP(52, 539, 68, 15, gText('Audit global', 12, Color(0xFF55524C), inter: true)),
      gP(27.125, 582.125, 9.75, 9.75, gImg('assets/figma/v/b916ebbd5954b5.svg')),
      gP(22.75, 577.75, 18.5, 18.5, gImg('assets/figma/v/6cbb5365a7f38e.svg')),
      gP(52, 579, 77, 15, gText('Configuration', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 71, 14, gText('Super admin', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 101, 11, gText('Administration globale', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 421, 29, gText('Commissions et règles économiques', 24, Color(0xFF18181B), weight: 500, inter: true)),
      gP(268, 110, 226, 15, gText('Vue d’ensemble · mise à jour aujourd’hui', 12, Color(0xFF6D6A64), inter: true)),
      gP(954, 78, 110, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(967.125, 87.125, 15.75, 15.75, gImg('assets/figma/v/e1d0d9c2726ec6.svg')),
      gP(992, 87, 56, 14, gText('Actualiser', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gP(1080, 78, 160, 34, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E3DE), bw: 1, radii: [17, 17, 17, 17])),
      gP(1093.667, 88.75, 14.667, 12.5, gImg('assets/figma/v/54d63e10c1f201.svg')),
      gP(1099.083, 87.667, 8.167, 8.167, gImg('assets/figma/v/aa6a66611de441.svg')),
      gP(1095.833, 90.917, 8.167, 8.167, gImg('assets/figma/v/aa6a66611de441.svg')),
      gP(1100.167, 94.167, 8.167, 8.167, gImg('assets/figma/v/aa6a66611de441.svg')),
      gP(1118, 87, 111, 14, gText('Personnaliser la vue', 11.5, Color(0xFF111015), weight: 500, inter: true)),
      gTap(1150, 148, 100, 36, () { commissionDialog(context, ref); }),
      gTap(1180, 150, 70, 34, () { commissionDialog(context, ref); }),
      gTap(12, 96, 216, 36, () => gOpen(context, '127')),
      gTap(12, 136, 216, 36, () => gOpen(context, '128')),
      gTap(12, 176, 216, 36, () => gOpen(context, '129')),
      gTap(12, 216, 216, 36, () => gOpen(context, '130')),
      gTap(12, 288, 216, 36, () => gOpen(context, '131')),
      gTap(12, 328, 216, 36, () => gOpen(context, '132')),
      gTap(12, 368, 216, 36, () => gOpen(context, '133')),
      gTap(12, 408, 216, 36, () => gOpen(context, '134')),
      gTap(12, 488, 216, 36, () => gOpen(context, '136')),
      gTap(12, 528, 216, 36, () => gOpen(context, '137')),
      gTap(12, 568, 216, 36, () => gOpen(context, '138')),
    ]);
  }
}
