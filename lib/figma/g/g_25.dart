// GÉNÉRÉ par tool/figma_export/convert.py — écran 25 (nœud Figma 29:347). Ne pas éditer à la main.
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

class G_25 extends ConsumerWidget {
  const G_25({super.key});

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
      gP(21.447, 70.675, 20.318, 20.318, const SizedBox.expand(), tap: () => gBack(context)),
      gP(22.68, 71.908, 11.926, 17.852, gImg('assets/figma/v/bed4925108d4f6.svg')),
      gP(22.68, 77.834, 17.852, 6, gImg('assets/figma/v/0093241f24fab2.svg')),
      gP(59.826, 66.834, 125, 28, gText('Mes favoris', 22.576, Color(0xFF111015), weight: 700)),
      gP(347.106, 70.675, 20.318, 20.318, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(346.645, 70.214, 19.546, 19.546, gImg('assets/figma/v/eaac3155ede28a.svg')),
      gP(358.244, 81.813, 9.64, 9.64, gImg('assets/figma/v/3c4d7466583ca9.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(21.447, 120.062, 56.44, 34.473, 'Tous', 15.239, 600), GChip(88.046, 120.062, 67.728, 34.473, 'Produits', 14.674, 500), GChip(165.933, 120.062, 68.857, 34.473, 'Services', 14.674, 500), GChip(246.078, 120.062, 65.47, 34.473, 'Talents', 14.674, 500), GChip(321.708, 120.062, 65.47, 34.473, 'Projets', 14.674, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 16.368)),
      gP(24.834, 179.499, 156, 124.817, gBox(image: (ref.watch(favoriteProductsProvider).length > 0 ? ref.watch(favoriteProductsProvider)[0].image : ''), fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: (ref.watch(favoriteProductsProvider).length > 0)),
      gP(196.834, 194.273, 105, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 0 ? ref.watch(favoriteProductsProvider)[0].title : '', 12.981, Color(0xFF111015), weight: 700)), show: (ref.watch(favoriteProductsProvider).length > 0)),
      gP(196.834, 219.237, 89, 18, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 0 ? fcfa(ref.watch(favoriteProductsProvider)[0].price) : '', 14.11, Color(0xFF111015), weight: 600)), show: (ref.watch(favoriteProductsProvider).length > 0)),
      gP(196.834, 245.794, 81, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 0 ? ref.watch(favoriteProductsProvider)[0].department : '', 12.981, Color(0xFF5A3FE0))), show: (ref.watch(favoriteProductsProvider).length > 0)),
      
      gP(136, 183.5, 34.061, 34.061, GHeartLive(title: ref.watch(favoriteProductsProvider).length > 0 ? ref.watch(favoriteProductsProvider)[0].title : ''), show: (ref.watch(favoriteProductsProvider).length > 0)),
      gP(349.326, 242.341, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(24.834, 317.986, 156, 126.006, gBox(image: (ref.watch(favoriteProductsProvider).length > 1 ? ref.watch(favoriteProductsProvider)[1].image : ''), fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: (ref.watch(favoriteProductsProvider).length > 1)),
      gP(196.834, 332.761, 147, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 1 ? ref.watch(favoriteProductsProvider)[1].title : '', 12.981, Color(0xFF111015), weight: 700)), show: (ref.watch(favoriteProductsProvider).length > 1)),
      gP(196.834, 357.724, 86, 18, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 1 ? fcfa(ref.watch(favoriteProductsProvider)[1].price) : '', 14.11, Color(0xFF111015), weight: 600)), show: (ref.watch(favoriteProductsProvider).length > 1)),
      gP(196.834, 384.282, 108, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 1 ? ref.watch(favoriteProductsProvider)[1].department : '', 12.981, Color(0xFF5A3FE0))), show: (ref.watch(favoriteProductsProvider).length > 1)),
      
      gP(136, 322, 34.061, 34.061, GHeartLive(title: ref.watch(favoriteProductsProvider).length > 1 ? ref.watch(favoriteProductsProvider)[1].title : ''), show: (ref.watch(favoriteProductsProvider).length > 1)),
      gP(349.326, 380.828, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(24.834, 457.662, 156, 126.6, gBox(image: (ref.watch(favoriteProductsProvider).length > 2 ? ref.watch(favoriteProductsProvider)[2].image : ''), fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: (ref.watch(favoriteProductsProvider).length > 2)),
      gP(196.834, 472.437, 166, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 2 ? ref.watch(favoriteProductsProvider)[2].title : '', 12.981, Color(0xFF111015), weight: 700)), show: (ref.watch(favoriteProductsProvider).length > 2)),
      gP(196.834, 497.4, 88, 18, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 2 ? fcfa(ref.watch(favoriteProductsProvider)[2].price) : '', 14.11, Color(0xFF111015), weight: 600)), show: (ref.watch(favoriteProductsProvider).length > 2)),
      gP(196.834, 523.958, 80, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 2 ? ref.watch(favoriteProductsProvider)[2].department : '', 12.981, Color(0xFF5A3FE0))), show: (ref.watch(favoriteProductsProvider).length > 2)),
      
      gP(136, 461.7, 34.061, 34.061, GHeartLive(title: ref.watch(favoriteProductsProvider).length > 2 ? ref.watch(favoriteProductsProvider)[2].title : ''), show: (ref.watch(favoriteProductsProvider).length > 2)),
      gP(349.326, 520.504, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(24.834, 597.338, 156, 126.6, gBox(image: (ref.watch(favoriteProductsProvider).length > 3 ? ref.watch(favoriteProductsProvider)[3].image : ''), fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: (ref.watch(favoriteProductsProvider).length > 3)),
      gP(196.834, 612.113, 95, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 3 ? ref.watch(favoriteProductsProvider)[3].title : '', 12.981, Color(0xFF111015), weight: 700)), show: (ref.watch(favoriteProductsProvider).length > 3)),
      gP(196.834, 637.076, 96, 18, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 3 ? fcfa(ref.watch(favoriteProductsProvider)[3].price) : '', 14.11, Color(0xFF111015), weight: 600)), show: (ref.watch(favoriteProductsProvider).length > 3)),
      gP(196.834, 663.634, 110, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(favoriteProductsProvider).length > 3 ? ref.watch(favoriteProductsProvider)[3].department : '', 12.981, Color(0xFF5A3FE0))), show: (ref.watch(favoriteProductsProvider).length > 3)),
      
      gP(136, 601.3, 34.061, 34.061, GHeartLive(title: ref.watch(favoriteProductsProvider).length > 3 ? ref.watch(favoriteProductsProvider)[3].title : ''), show: (ref.watch(favoriteProductsProvider).length > 3)),
      gP(349.326, 660.18, 9.104, 12.208, gImg('assets/figma/v/5375a5aa009d46.svg')),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(25, 179, 300, 125, () { final l = ref.read(favoriteProductsProvider); if (l.length > 0) { ref.read(selectedProductProvider.notifier).select(l[0].title); gOpen(context, '05'); } }),
      gTap(25, 318, 300, 125, () { final l = ref.read(favoriteProductsProvider); if (l.length > 1) { ref.read(selectedProductProvider.notifier).select(l[1].title); gOpen(context, '05'); } }),
      gTap(25, 458, 300, 125, () { final l = ref.read(favoriteProductsProvider); if (l.length > 2) { ref.read(selectedProductProvider.notifier).select(l[2].title); gOpen(context, '05'); } }),
      gTap(25, 597, 300, 125, () { final l = ref.read(favoriteProductsProvider); if (l.length > 3) { ref.read(selectedProductProvider.notifier).select(l[3].title); gOpen(context, '05'); } }),
    ]);
  }
}
