// GÉNÉRÉ par tool/figma_export/convert.py — écran 44 (nœud Figma 36:285). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_44 extends ConsumerWidget {
  const G_44({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF5F0E8), Color(0xFFEFE9F4), Color(0xFFF7E9DB)], stops: [0, 0.55, 1]), children: [
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
      gP(24, 70, 229, 26, gText('Commande confirmée', 21, Color(0xFF111015), weight: 700)),
      gP(22.5, 270, 345, 24, gText('Merci pour votre commande !', 19, Color(0xFF111015), weight: 800, align: TextAlign.center, wrap: true)),
      gP(42.5, 302, 305, 38, gText('Votre commande a bien été enregistrée. Un reçu vous a été envoyé par e-mail.', 13, Color(0xFF66636E), lh: 19, align: TextAlign.center, wrap: true)),
      gP(24, 374, 342, 188, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(40, 388, 88, 18, gText('Récapitulatif', 14, Color(0xFF111015), weight: 700)),
      gP(40, 422, 62, 16, gText('Référence', 12.5, Color(0xFF66636E))),
      gP(105, 422, 245, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).id, 12.5, Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right))),
      gP(40, 447, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 456, 29, 16, gText('Date', 12.5, Color(0xFF66636E))),
      gP(134, 456, 216, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(lastOrderProvider).date, 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(40, 481, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 490, 50, 16, gText('Montant', 12.5, Color(0xFF66636E))),
      gP(122, 490, 228, 16, Consumer(builder: (context, ref, _) => gText(fcfa(ref.watch(lastOrderProvider).total), 12.5, Color(0xFF111015), weight: 700, wrap: true, align: TextAlign.right))),
      gP(40, 515, 310, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(-100, 524, 180, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(homeDeliveryProvider) ? 'Livraison' : 'Retrait', 12.5, Color(0xFF66636E), wrap: true, align: TextAlign.right))),
      gP(88, 524, 262, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(homeDeliveryProvider) ? 'Douala, Cameroun' : 'Kiosque IUT – Bloc A', 12.5, Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right))),
      gP(24, 576, 342, 62, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 591, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 596.917, 18.75, 16.625, gImg('assets/figma/v/b2ae09d0fd46bb.svg')),
      gP(47.796, 610.375, 8.408, 6.712, gImg('assets/figma/v/f59da0513c0b4c.svg')),
      gP(76, 590, 277, 34, gText('Vous serez notifié dès que votre commande sera prête à être retirée.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(0, 744, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 760, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : Accueil')),
      gP(79.5, 778, 52, 18, gText('Accueil', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center), tap: () => gOpen(context, '03')),
      gP(203, 760, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27])),
      gP(209, 778, 151, 18, gText('Suivre ma commande', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(157.433, 148.266, 88.334, 96.667, gImg('assets/figma/r/178_34.png')),
      gP(157.433, 164.933, 88.334, 46.667, gImg('assets/figma/r/178_35.png')),
      gTap(203, 760, 163, 54, () => gOpen(context, '09')),
    ]);
  }
}
