// GÉNÉRÉ par tool/figma_export/convert.py — écran 64 (nœud Figma 54:1142). Ne pas éditer à la main.
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
import '../live/messages.dart' show contactOrderBuyer;
import '../../data/repositories/repositories.dart' show cartProvider;

class G_64 extends ConsumerWidget {
  const G_64({super.key});

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
      gP(76, 70, 268, 26, Consumer(builder: (context, ref, _) => gText('Préparer ${ref.watch(currentSellerOrderProvider).id}', 21, Color(0xFF111015), weight: 700))),
      gP(60, 134, 68.667, 2, gBox(color: Color(0xFF111015), radii: [1, 1, 1, 1])),
      gP(29, 120, 30, 30, gBox(color: Color(0xFF111015), oval: true)),
      gP(36, 128.25, 16, 12.875, gImg('assets/figma/v/515240907c423e.svg')),
      gP(27, 158, 34, 14, gText('Reçue', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(160.667, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(127.667, 118, 34, 34, gBox(color: Color(0xFF111015), oval: true)),
      gP(112.667, 158, 64, 14, gText('Préparation', 11, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(261.333, 134, 68.667, 2, gBox(color: Color(0xFFE6E1EE), radii: [1, 1, 1, 1])),
      gP(230.333, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(230.833, 158, 29, 14, gText('Prête', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(331, 120, 30, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(326.5, 158, 39, 14, gText('Remise', 11, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(36, 196, 50, 50, gBox(image: 'assets/figma/img/787285568a50b7daa40a12adc3c3145d4743215c.png', fit: BoxFit.cover, radii: [12, 12, 12, 12])),
      gP(98, 200, 145, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(currentSellerOrderProvider).title, 13.5, Color(0xFF111015), weight: 600))),
      gP(98, 222, 117, 14, Consumer(builder: (context, ref, _) => gText('Qté : ${ref.watch(currentSellerOrderProvider).qty} · ${fcfa(ref.watch(currentSellerOrderProvider).total)}', 11.5, Color(0xFF66636E)))),
      gP(24, 268, 122, 19, gText('Liste de contrôle', 15, Color(0xFF111015), weight: 700)),
      gP(24, 306, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 309.75, 14.667, 11.958, gImg('assets/figma/v/w_check.svg')),
      gP(54, 307, 315, 18, gText('Article conforme à l’annonce', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 342, 20, 20, gBox(color: Color(0xFF111015), radii: [6, 6, 6, 6])),
      gP(26.667, 345.75, 14.667, 11.958, gImg('assets/figma/v/w_check.svg')),
      gP(54, 343, 315, 18, gText('Emballage soigné et protégé', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 378, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 379, 315, 18, gText('Photo de l’article ajoutée', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(24, 414, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD5E4), bw: 1.5, radii: [6, 6, 6, 6])),
      gP(54, 415, 315, 18, gText('Étiquette de retrait imprimée', 12.5, Color(0xFF4A4854), lh: 18, wrap: true)),
      gP(40, 464, 50, 18, gText('Remise', 14, Color(0xFF111015), weight: 700)),
      gP(40, 498, 88, 16, gText('Remise prévue', 12.5, Color(0xFF66636E))),
      gP(228, 498, 122, 16, gText('Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(40, 523, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 532, 46, 16, gText('Avant le', 12.5, Color(0xFF66636E))),
      gP(272, 532, 78, 16, gText('Demain · 14 h', 12.5, Color(0xFF111015), weight: 600, align: TextAlign.right)),
      gP(24, 584, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 599, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 604.917, 18.75, 16.625, gImg('assets/figma/v/b2ae09d0fd46bb.svg')),
      gP(47.796, 618.375, 8.408, 6.712, gImg('assets/figma/v/f59da0513c0b4c.svg')),
      gP(76, 598, 277, 34, gText('Le client est averti automatiquement quand la commande est marquée prête.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27])),
      gP(47, 778, 117, 18, gText('Signaler un souci', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      orderActionText(203, 778, 163),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(203, 760, 163, 54, () { advanceCurrentOrder(ref, context); }),
      gTap(24, 760, 163, 54, () { contactOrderBuyer(ref, context); }),
    ]);
  }
}
