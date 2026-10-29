// GÉNÉRÉ par tool/figma_export/convert.py — écran 28 (nœud Figma 30:79). Ne pas éditer à la main.
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
import '../../data/repositories/repositories.dart' show cartProvider;

class G_28 extends ConsumerWidget {
  const G_28({super.key});

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
      gP(21.507, 77.015, 16.25, 16.25, const SizedBox.expand(), tap: () => gBack(context)),
      gP(21.893, 77.401, 10.74, 15.479, gImg('assets/figma/v/e1d17c75fdda0b.svg')),
      gP(21.893, 82.14, 15.479, 6, gImg('assets/figma/v/9a3ac87741dc9a.svg')),
      gP(58.309, 75.14, 135, 20, gText('Mes commandes', 16.25, Color(0xFF111015), weight: 700)),
      gP(19.118, 127.34, 66.912, 45.161, gBox(color: Color(0xFF111015), radii: [14.577, 14.577, 14.577, 14.577])),
      gP(32.074, 141.921, 41, 16, gText('Toutes', 12.426, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(97.5, 127.34, 80.294, 45.161, gBox(color: Color(0xFFF2EFF6), radii: [14.577, 14.577, 14.577, 14.577])),
      gP(112.147, 141.921, 51, 16, gText('En cours', 12.426, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(192.132, 127.34, 74.559, 45.161, gBox(color: Color(0xFFF2EFF6), radii: [14.577, 14.577, 14.577, 14.577])),
      gP(207.912, 141.921, 43, 16, gText('Livrées', 12.426, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(280.074, 127.34, 85.074, 45.161, gBox(color: Color(0xFFF2EFF6), radii: [14.577, 14.577, 14.577, 14.577])),
      gP(295.11, 141.921, 55, 16, gText('Annulées', 12.426, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(19.596, 203.596, 351.287, 111.053, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(23.419, 227.663, 60.699, 60.699, gBox(image: 'assets/figma/img/34e8344812f71c763e7e4b52e1acffce9319e372.png', fit: BoxFit.cover, radii: [9.559, 9.559, 9.559, 9.559])),
      gP(98.456, 226.691, 108, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 0 ? ref.watch(ordersAllProvider)[0].id : '', 12.904, Color(0xFF111015), weight: 700))),
      gP(98.456, 259.526, 149, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 0 ? '${ref.watch(ordersAllProvider)[0].date}  •  ${fcfa(ref.watch(ordersAllProvider)[0].total)}' : '', 10.993, Color(0xFF5A3FE0), weight: 500))),
      gP(316.397, 226.547, 46.36, 32.575, gBox(color: (badgeFill((ref.watch(ordersAllProvider).length > 0 ? ref.watch(ordersAllProvider)[0].badge : 'En cours'))), radii: [10.515, 10.515, 10.515, 10.515])),
      gP(322.577, 235.835, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 0 ? ref.watch(ordersAllProvider)[0].badge : '', 11.471, (badgeInk((ref.watch(ordersAllProvider).length > 0 ? ref.watch(ordersAllProvider)[0].badge : 'En cours'))), weight: 600, align: TextAlign.center))),
      gP(19.596, 333.158, 351.287, 111.053, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(23.419, 357.224, 60.699, 60.699, gBox(image: 'assets/figma/img/9e2ce90f4496911ea5fab01d09cc48a0c7a22b47.png', fit: BoxFit.cover, radii: [9.559, 9.559, 9.559, 9.559])),
      gP(98.456, 356.253, 108, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 1 ? ref.watch(ordersAllProvider)[1].id : '', 12.904, Color(0xFF111015), weight: 700))),
      gP(98.456, 389.088, 145, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 1 ? '${ref.watch(ordersAllProvider)[1].date}  •  ${fcfa(ref.watch(ordersAllProvider)[1].total)}' : '', 10.993, Color(0xFF5A3FE0), weight: 500))),
      gP(302.537, 356.109, 60.221, 32.575, gBox(color: (badgeFill((ref.watch(ordersAllProvider).length > 1 ? ref.watch(ordersAllProvider)[1].badge : 'En cours'))), radii: [10.515, 10.515, 10.515, 10.515])),
      gP(309.147, 365.396, 47, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 1 ? ref.watch(ordersAllProvider)[1].badge : '', 11.471, (badgeInk((ref.watch(ordersAllProvider).length > 1 ? ref.watch(ordersAllProvider)[1].badge : 'En cours'))), weight: 600, align: TextAlign.center))),
      gP(19.596, 462.719, 351.287, 111.053, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(23.419, 486.786, 60.699, 60.699, gBox(image: 'assets/figma/img/55fe764cd9b0e1fc03c630662e027fb0f9f7ade4.png', fit: BoxFit.cover, radii: [9.559, 9.559, 9.559, 9.559])),
      gP(98.456, 485.814, 107, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 2 ? ref.watch(ordersAllProvider)[2].id : '', 12.904, Color(0xFF111015), weight: 700))),
      gP(98.456, 518.649, 148, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 2 ? '${ref.watch(ordersAllProvider)[2].date}  •  ${fcfa(ref.watch(ordersAllProvider)[2].total)}' : '', 10.993, Color(0xFF5A3FE0), weight: 500))),
      gP(316.397, 485.67, 46.36, 32.575, gBox(color: (badgeFill((ref.watch(ordersAllProvider).length > 2 ? ref.watch(ordersAllProvider)[2].badge : 'En cours'))), radii: [10.515, 10.515, 10.515, 10.515])),
      gP(322.577, 494.958, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 2 ? ref.watch(ordersAllProvider)[2].badge : '', 11.471, (badgeInk((ref.watch(ordersAllProvider).length > 2 ? ref.watch(ordersAllProvider)[2].badge : 'En cours'))), weight: 600, align: TextAlign.center))),
      gP(19.596, 592.281, 351.287, 111.053, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, 3), blurRadius: 12, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(23.419, 616.347, 60.699, 60.699, gBox(image: 'assets/figma/img/9803b1792923bb371cffd2d64272ebebf74ea2d4.png', fit: BoxFit.cover, radii: [9.559, 9.559, 9.559, 9.559])),
      gP(98.456, 615.375, 105, 16, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 3 ? ref.watch(ordersAllProvider)[3].id : '', 12.904, Color(0xFF111015), weight: 700))),
      gP(98.456, 648.211, 152, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 3 ? '${ref.watch(ordersAllProvider)[3].date}  •  ${fcfa(ref.watch(ordersAllProvider)[3].total)}' : '', 10.993, Color(0xFF5A3FE0), weight: 500))),
      gP(304.449, 615.232, 58.309, 32.575, gBox(color: (badgeFill((ref.watch(ordersAllProvider).length > 3 ? ref.watch(ordersAllProvider)[3].badge : 'En cours'))), radii: [10.515, 10.515, 10.515, 10.515])),
      gP(311.103, 624.519, 45, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(ordersAllProvider).length > 3 ? ref.watch(ordersAllProvider)[3].badge : '', 11.471, (badgeInk((ref.watch(ordersAllProvider).length > 3 ? ref.watch(ordersAllProvider)[3].badge : 'En cours'))), weight: 600, align: TextAlign.center))),
      gP(125, 832, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '53')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(321.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gOpen(context, '10')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gOpen(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gOpen(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/af3cc156833fdf.svg')),
      gTap(20, 213, 351, 118, () { final l = ref.read(ordersAllProvider); if (l.length > 0) { ref.read(selectedOrderIdProvider.notifier).set(l[0].id); gOpen(context, '09'); } }),
      gTap(20, 342, 351, 118, () { final l = ref.read(ordersAllProvider); if (l.length > 1) { ref.read(selectedOrderIdProvider.notifier).set(l[1].id); gOpen(context, '09'); } }),
      gTap(20, 472, 351, 118, () { final l = ref.read(ordersAllProvider); if (l.length > 2) { ref.read(selectedOrderIdProvider.notifier).set(l[2].id); gOpen(context, '09'); } }),
      gTap(20, 601, 351, 118, () { final l = ref.read(ordersAllProvider); if (l.length > 3) { ref.read(selectedOrderIdProvider.notifier).set(l[3].id); gOpen(context, '09'); } }),
    ]);
  }
}
