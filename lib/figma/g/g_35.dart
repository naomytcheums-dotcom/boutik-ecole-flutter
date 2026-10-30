// GÉNÉRÉ par tool/figma_export/convert.py — écran 35 (nœud Figma 35:1033). Ne pas éditer à la main.
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

class G_35 extends ConsumerWidget {
  const G_35({super.key});

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
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 129, 26, gText('Disponibilité', 21, Color(0xFF111015), weight: 700)),
      gP(36, 128, 50, 50, gBox(image: 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 132, 145, 17, gText('Lampe en bois recyclé', 13.5, Color(0xFF111015), weight: 600)),
      gP(98, 154, 169, 14, gText('25 000 FCFA · 15 unités au total', 11.5, Color(0xFF66636E))),
      gP(280.8, 142, 71.2, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(293.4, 146, 46, 14, gText('En stock', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(24, 200, 69, 19, gText('Variantes', 15, Color(0xFF111015), weight: 700)),
      gP(40, 250, 91, 17, gText('Chêne naturel', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 272, 66, 14, gText('SKU LB-001', 11.5, Color(0xFF66636E))),
      gP(261.6, 260, 90.4, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(277.8, 264, 58, 14, gText('12 en stock', 11, Color(0xFF0F7A52), weight: 600, align: TextAlign.center)),
      gP(40, 304, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 316, 40, 17, gText('Noyer', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 338, 69, 14, gText('SKU LB-002', 11.5, Color(0xFF66636E))),
      gP(268, 326, 84, 22, gBox(color: Color(0xFFEEE9FF), radii: [11, 11, 11, 11])),
      gP(283, 330, 54, 14, gText('3 en stock', 11, Color(0xFF8F5400), weight: 600, align: TextAlign.center)),
      gP(40, 370, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 382, 56, 17, gText('Bambou', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 404, 69, 14, gText('SKU LB-003', 11.5, Color(0xFF66636E))),
      gP(287.2, 392, 64.8, 22, gBox(color: Color(0xFFFDE6E7), radii: [11, 11, 11, 11])),
      gP(298.1, 396, 43, 14, gText('Rupture', 11, Color(0xFFE5484D), weight: 600, align: TextAlign.center)),
      gP(40, 464, 149, 18, gText('Informations de stock', 14, Color(0xFF111015), weight: 700)),
      gP(40, 498, 75, 16, gText('Disponibilité', 12.5, Color(0xFF66636E))),
      gP(298, 498, 52, 16, gText('En stock', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 523, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 532, 70, 16, gText('Préparation', 12.5, Color(0xFF66636E))),
      gP(297, 532, 53, 16, gText('24 à 48 h', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 557, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 566, 40, 16, gText('Retrait', 12.5, Color(0xFF66636E))),
      gP(228, 566, 122, 16, gText('Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 591, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 600, 89, 16, gText('Réassort prévu', 12.5, Color(0xFF66636E))),
      gP(271, 600, 79, 16, gText('03 nov. 2026', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 652, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 667, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(41.904, 673.615, 20.178, 18.76, gImg('assets/figma/v/57d49290c6ec28.svg')),
      gP(49, 677.875, 6, 8.833, gImg('assets/figma/v/0a15efd0dabd53.svg')),
      gP(49, 683.542, 6.007, 6, gImg('assets/figma/v/c499ab72bb5251.svg')),
      gP(76, 666, 277, 34, gText('Stock bas sur la variante « Noyer » : commandez vite ou activez l’alerte.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Me prévenir')),
      gP(64.5, 778, 82, 18, gText('Me prévenir', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () { ref.read(cartProvider.notifier).add(ref.read(selectedProductProvider).toLine()); gToast(context, 'Ajouté au panier'); gOpen(context, '06'); }),
      gP(225.5, 778, 118, 18, gText('Ajouter au panier', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
    ]);
  }
}
