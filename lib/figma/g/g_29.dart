// GÉNÉRÉ par tool/figma_export/convert.py — écran 29 (nœud Figma 30:147). Ne pas éditer à la main.
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
import '../live/messages.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_29 extends ConsumerWidget {
  const G_29({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 19, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(24.925, 69.429, 16.617, 16.617, const SizedBox.expand(), tap: () => gBack(context)),
      gP(25.387, 69.89, 10.846, 15.693, gImg('assets/figma/v/0b4e529e54ae01.svg')),
      gP(25.387, 74.737, 15.693, 6, gImg('assets/figma/v/6db7411883462c.svg')),
      gP(57.669, 65.756, 184, 21, gText('Détail de la commande', 16.617, Color(0xFF111015), weight: 700)),
      gP(26.391, 131.868, 163, 25, Consumer(builder: (context, ref, _) => gText(demoContent ? '#BE-2026-0142' : ref.watch(viewedOrderProvider).id, 19.549, Color(0xFF111015), weight: 700))),
      gP(313.759, 128.081, 53.271, 35.537, gBox(color: (demoContent ? Color(0xFFDDF5EC) : badgeFill(ref.watch(viewedOrderProvider).badge)), radii: [11.729, 11.729, 11.729, 11.729])),
      gP(322.65, 138.349, 35, 15, Consumer(builder: (context, ref, _) => gText(demoContent ? 'Livrée' : ref.watch(viewedOrderProvider).badge, 11.729, (demoContent ? Color(0xFF0F7A52) : badgeInk(ref.watch(viewedOrderProvider).badge)), weight: 600, align: TextAlign.center))),
      gP(26.391, 173.646, 152, 14, Consumer(builder: (context, ref, _) => gText(demoContent ? '22 oct. 2026  •  32 500 FCFA' : '${ref.watch(viewedOrderProvider).date}  •  ${fcfa(ref.watch(viewedOrderProvider).total)}', 11.241, Color(0xFF5A3FE0), weight: 500))),
      gP(54.737, 233.211, 84.549, 2.221, gBox(color: (demoContent || ref.watch(viewedOrderProvider).status >= 1 ? Color(0xFFBFE8D6) : Color(0xFFEEEAF4)), radii: [0.489, 0.489, 0.489, 0.489])),
      gP(37.632, 225.643, 16.617, 16.617, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(39.682, 228.507, 12.516, 10.48, gImg('assets/figma/v/2aa6dab576de7d.svg')),
      gP(23.361, 262.247, 52, 13, gText('Confirmée', 10.263, Color(0xFF66636E), align: TextAlign.center)),
      gP(156.88, 233.211, 83.083, 2.221, gBox(color: (demoContent || ref.watch(viewedOrderProvider).status >= 2 ? Color(0xFFBFE8D6) : Color(0xFFEEEAF4)), radii: [0.489, 0.489, 0.489, 0.489])),
      gP(139.774, 225.643, 16.617, 16.617, gBox(color: (demoContent || ref.watch(viewedOrderProvider).status >= 1 ? Color(0xFF1F9D6B) : Color(0xFFDAD5E4)), oval: true)),
      gP(141.825, 228.507, 12.516, 10.48, gImg('assets/figma/v/2aa6dab576de7d.svg')),
      gP(125.083, 262.247, 46, 13, gText('Préparée', 10.263, Color(0xFF66636E), align: TextAlign.center)),
      gP(257.556, 233.211, 79.173, 2.221, gBox(color: (demoContent || ref.watch(viewedOrderProvider).status >= 3 ? Color(0xFFBFE8D6) : Color(0xFFEEEAF4)), radii: [0.489, 0.489, 0.489, 0.489])),
      gP(240.451, 225.643, 16.617, 16.617, gBox(color: (demoContent || ref.watch(viewedOrderProvider).status >= 2 ? Color(0xFF1F9D6B) : Color(0xFFDAD5E4)), oval: true)),
      gP(242.501, 228.507, 12.516, 10.48, gImg('assets/figma/v/2aa6dab576de7d.svg')),
      gP(225.259, 262.247, 47, 13, gText('Expédiée', 10.263, Color(0xFF66636E), align: TextAlign.center)),
      gP(337.218, 225.643, 16.617, 16.617, gBox(color: (demoContent || ref.watch(viewedOrderProvider).status >= 3 ? Color(0xFF1F9D6B) : Color(0xFFDAD5E4)), oval: true)),
      gP(339.268, 228.507, 12.516, 10.48, gImg('assets/figma/v/2aa6dab576de7d.svg')),
      gP(330.526, 262.247, 30, 13, gText('Livrée', 10.263, Color(0xFF66636E), align: TextAlign.center)),
      gP(26.391, 326.879, 50, 17, gText('Articles', 13.195, Color(0xFF111015), weight: 700)),
      gP(26.391, 379.379, 67.444, 64.511, Consumer(builder: (context, ref, _) => gBox(image: (demoContent || ref.watch(viewedOrderProvider).lines.isEmpty ? 'assets/figma/img/84a49a20614dc5f12ab62f18400caa2290c40ec0.png' : ref.watch(viewedOrderProvider).lines.first.image), fit: BoxFit.cover, radii: [9.774, 9.774, 9.774, 9.774]))),
      gP(107.03, 368.598, 94, 15, Consumer(builder: (context, ref, _) => gText(demoContent || ref.watch(viewedOrderProvider).lines.isEmpty ? 'Sac à dos design' : ref.watch(viewedOrderProvider).lines.first.title, 11.729, Color(0xFF111015), weight: 500))),
      gP(107.03, 396.732, 77, 15, Consumer(builder: (context, ref, _) => gText(demoContent || ref.watch(viewedOrderProvider).lines.isEmpty ? '25 000 FCFA' : fcfa(ref.watch(viewedOrderProvider).lines.first.price), 12.218, Color(0xFF111015), weight: 600))),
      gP(107.03, 426.605, 30, 13, Consumer(builder: (context, ref, _) => gText(demoContent || ref.watch(viewedOrderProvider).lines.isEmpty ? 'Qté : 1' : 'Qté : ${ref.watch(viewedOrderProvider).lines.first.qty}', 10.263, Color(0xFF66636E)))),
      gP(347.256, 371.579, 10, 12, Consumer(builder: (context, ref, _) => gText(demoContent || ref.watch(viewedOrderProvider).lines.isEmpty ? '×1' : '×${ref.watch(viewedOrderProvider).lines.first.qty}', 9.774, Color(0xFF66636E), align: TextAlign.right))),
      gP(26.391, 473.825, 341.128, 0.74, gBox(color: Color(0xFFF2EFF6))),
      gP(28.346, 490.016, 90, 15, gText('Frais de livraison', 11.729, Color(0xFF66636E))),
      gP(302.03, 490.016, 65, 15, Consumer(builder: (context, ref, _) => gText(demoContent ? '7 500 FCFA' : (ref.watch(viewedOrderProvider).fee == 0 ? 'Gratuit' : fcfa(ref.watch(viewedOrderProvider).fee)), 11.729, Color(0xFF111015), weight: 600, align: TextAlign.right))),
      gP(26.391, 524.168, 341.128, 0.74, gBox(color: Color(0xFFF2EFF6))),
      gP(28.346, 538.86, 34, 18, gText('Total', 14.173, Color(0xFF111015), weight: 700)),
      gP(279.03, 538.86, 88, 18, Consumer(builder: (context, ref, _) => gText(demoContent ? '32 500 FCFA' : fcfa(ref.watch(viewedOrderProvider).total), 14.173, Color(0xFF111015), weight: 700, align: TextAlign.right))),
      gP(26.391, 612.414, 123, 16, gText('Adresse de livraison', 12.707, Color(0xFF111015), weight: 700)),
      gP(31.048, 654.912, 17.078, 19.847, gImg('assets/figma/v/aeca3d14d1ba7e.svg')),
      gP(34.509, 658.373, 10.154, 10.154, gImg('assets/figma/v/5c78743d895a79.svg')),
      gP(60.113, 651.912, 160, 14, gText('IUT de Douala, Quartier Ndokoti', 10.752, Color(0xFF4A4854))),
      gP(60.113, 680.046, 95, 14, gText('Douala, Cameroun', 10.752, Color(0xFF4A4854))),
      gP(18.571, 731.467, 182.293, 64.411, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18, spreadRadius: 0)], radii: [28, 28, 28, 28]), tap: () => contactOrderSeller(ref, context)),
      gP(41.474, 755.542, 136, 17, gText('Contacter le vendeur', 13.195, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(212.594, 731.467, 163.722, 64.411, gBox(color: Color(0xFF111015), radii: [21.504, 21.504, 21.504, 21.504]), tap: () { downloadDocument(context, ref, invoice: false); }),
      gP(261.199, 756.042, 67, 16, gText('Voir le reçu', 12.707, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(149.549, 820.309, 105.564, 3.702, gBox(color: Color(0xFF111015), radii: [1.466, 1.466, 1.466, 1.466])),
      gTap(18.4, 604.4, 139, 32, () { gOpen(context, '46'); }), // parcours 29 -> 46
    ]);
  }
}
