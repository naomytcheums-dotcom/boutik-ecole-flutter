// GÉNÉRÉ par tool/figma_export/convert.py — écran 161 (nœud Figma 60:847). Ne pas éditer à la main.
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

class G_161 extends ConsumerWidget {
  const G_161({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 881, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140.73, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 607.66, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
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
      gP(76, 70, 112, 26, gText('Hackathon', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 180, gBox(image: 'assets/figma/img/e48f8827338ec470670d1109125a15b7d0f21476.png', fit: BoxFit.cover, radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 180, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00111015), Color(0xC7111015)], stops: [0, 1]), radii: [24, 24, 24, 24])),
      gP(42, 238, 309, 23, Consumer(builder: (context, ref, _) => gText(ref.watch(currentEventProvider).title, 18, Color(0xFFFFFFFF), weight: 700, wrap: true))),
      gP(42, 266, 309, 15, Consumer(builder: (context, ref, _) => gText('${ref.watch(currentEventProvider).dates} · ${ref.watch(currentEventProvider).city}', 12, Color(0xFFE3ECF7), wrap: true))),
      gP(60, 328, 42, 25, Consumer(builder: (context, ref, _) => gText('${ref.watch(currentEventProvider).hours} h', 20, Color(0xFF111015), weight: 800, align: TextAlign.center))),
      gP(64, 358, 34, 14, gText('Durée', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(177.5, 328, 35, 25, Consumer(builder: (context, ref, _) => gText(prizeShort(ref.watch(currentEventProvider).prize).replaceAll(' FCFA', ''), 20, Color(0xFF111015), weight: 800, align: TextAlign.center))),
      gP(161, 358, 68, 14, gText('FCFA de prix', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(138, 328, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(291.5, 328, 35, 25, Consumer(builder: (context, ref, _) => gText('${placesLeft(ref.watch(currentEventProvider), ref.watch(registrationsProvider))}', 20, Color(0xFF111015), weight: 800, align: TextAlign.center))),
      gP(290.5, 358, 37, 14, gText('Places', 11.5, Color(0xFF66636E), align: TextAlign.center)),
      gP(252, 328, 1, 48, gBox(color: Color(0xFFF2EFF6))),
      gP(24, 440, 342, 1, gBox(color: Color(0xFFECE8F2))),
      gP(41.25, 414, 51, 14, gText('À propos', 11.5, Color(0xFF111015), weight: 700, align: TextAlign.center)),
      gP(36.825, 438, 59.85, 3, gBox(color: Color(0xFF6A4DFF), radii: [2, 2, 2, 2])),
      gP(119.25, 414, 66, 14, gText('Programme', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(227.25, 414, 21, 14, gText('Prix', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(292.75, 414, 61, 14, gText('Règlement', 11.5, Color(0xFF66636E), weight: 500, align: TextAlign.center)),
      gP(24, 458, 345, 61, Consumer(builder: (context, ref, _) => gText(ref.watch(currentEventProvider).desc, 13, Color(0xFF4A4854), lh: 20.15, wrap: true))),
      gP(24, 533, 77, 19, gText('Calendrier', 15, Color(0xFF111015), weight: 700)),
      gP(33, 593, 2, 40, gBox(color: Color(0xFFBFE8D6), radii: [1, 1, 1, 1])),
      gP(24, 572, 20, 20, gBox(color: Color(0xFF1F9D6B), oval: true)),
      gP(27.333, 576.25, 13.333, 11.042, gImg('assets/figma/v/23149818a3337a.svg')),
      gP(56, 571, 305, 17, gText('Clôture des inscriptions', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 591, 305, 14, gText('05 nov. 2026', 11.5, Color(0xFF66636E), wrap: true)),
      gP(33, 655, 2, 40, gBox(color: Color(0xFFE4E8EE), radii: [1, 1, 1, 1])),
      gP(24, 634, 20, 20, gBox(color: Color(0xFF111015), oval: true)),
      gP(56, 633, 305, 17, gText('Lancement et mentorat', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 653, 305, 14, gText('14 nov. · 09 h', 11.5, Color(0xFF66636E), wrap: true)),
      gP(24, 696, 20, 20, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 2, oval: true)),
      gP(56, 695, 305, 17, gText('Pitch final et jury', 13.5, Color(0xFF111015), weight: 600, wrap: true)),
      gP(56, 715, 305, 14, gText('16 nov. · 15 h', 11.5, Color(0xFF66636E), wrap: true)),
      gP(0, 781, 390, 100, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x12122640), offset: Offset(0, -4), blurRadius: 16, spreadRadius: 0)])),
      gP(24, 797, 163, 54, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [27, 27, 27, 27]), tap: () => shareText(context, 'Découvrez Boutik-École, la marketplace de l’IUT de Douala : ' + siteUrl)),
      gP(75, 815, 61, 18, gText('Partager', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(203, 797, 163, 54, gBox(color: Color(0xFF111015), shadows: [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], radii: [27, 27, 27, 27]), tap: () => gToast(context, 'Démonstration : S’inscrire')),
      gP(251.5, 815, 66, 18, gText('S’inscrire', 14.5, Color(0xFFFFFFFF), weight: 600, align: TextAlign.center)),
      gP(125, 867, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gP(341.667, 79, 20.667, 15.167, gImg('assets/figma/v/38cc299702e092.svg')),
      gP(345.333, 69.833, 13.333, 9.667, gImg('assets/figma/v/d83f01d420bc41.svg')),
      gP(349, 69.833, 6, 17.917, gImg('assets/figma/v/7c9d8fa2b191bd.svg')),
      gTap(203, 797, 163, 54, () { if (ref.read(registrationsProvider).containsKey(ref.read(currentEventProvider).id)) { gToast(context, 'Votre équipe est déjà inscrite.'); gOpen(context, '164'); } else { gOpen(context, '162'); } }),
      gTap(24, 797, 163, 54, () { gToast(context, 'Lien du concours copié'); }),
    ]);
  }
}
