// GÉNÉRÉ par tool/figma_export/convert.py — écran 163 (nœud Figma 60:983). Ne pas éditer à la main.
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

class G_163 extends ConsumerWidget {
  const G_163({super.key});

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
      gP(76, 70, 244, 26, gText('Trouver des coéquipiers', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 342, 48, gBox(color: Color(0xFFF2EFF6), radii: [24, 24, 24, 24])),
      gP(24, 120, 342, 48, GField(hint: 'Compétence, filière, nom…', size: 13.5, hintColor: Color(0xFF66636E), weight: 400, padL: 46, onChanged: (v) { ref.read(mateQueryProvider.notifier).set(v); })),
      gP(40.5, 134.5, 19, 19, const SizedBox.expand(), tap: () => gOpen(context, '244')),
      gP(39.875, 133.875, 18.667, 18.667, gImg('assets/figma/v/50f467eb8a9b46.svg')),
      gP(50.721, 144.721, 9.404, 9.404, gImg('assets/figma/v/18d279137d73d9.svg')),
      gP(338.583, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(329.875, 134.667, 11.542, 6, gImg('assets/figma/v/e35f2f0eee5049.svg')),
      gP(337, 141, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(329.875, 141, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(340.167, 147.333, 9.958, 6, gImg('assets/figma/v/22731c39f43211.svg')),
      gP(329.875, 147.333, 13.125, 6, gImg('assets/figma/v/3fa48fd4ed8834.svg')),
      gP(338.583, 133.083, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(333.833, 139.417, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      gP(340.167, 145.75, 6, 9.167, gImg('assets/figma/v/3221f2f163c9f7.svg')),
      Positioned.fill(child: GChoiceGroup(chips: [GChip(24, 182, 114.8, 34, 'Développeurs', 12.5, 600), GChip(146.8, 182, 92.6, 34, 'Designers', 12.5, 500), GChip(247.4, 182, 85.2, 34, 'Business', 12.5, 500), GChip(340.6, 182, 100, 34, 'IA et data', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0xFFF2EFF6), selText: Color(0xFFFFFFFF), unselText: Color(0xFF66636E), radius: 17, onChanged: (i) { ref.read(mateTabProvider.notifier).set(i); })),
      gP(24, 230, 156, 19, Consumer(builder: (context, ref, _) => gText('${ref.watch(visibleMatesProvider).length} talents disponibles', 15, Color(0xFF111015), weight: 700))),
      gP(24, 268, 342, 264, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x0D122640), offset: Offset(0, 2), blurRadius: 10, spreadRadius: 0)], radii: [28, 28, 28, 28])),
      gP(36, 276, 50, 50, gBox(image: 'assets/figma/img/182e32fd66d212ef3f18ac6a5a7fb09c404b45a7.png', fit: BoxFit.cover, radii: [25, 25, 25, 25]), show: (ref.watch(visibleMatesProvider).length > 0)),
      gP(98, 280, 93, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 0 ? ref.watch(visibleMatesProvider)[0].name : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleMatesProvider).length > 0)),
      gP(98, 302, 155, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 0 ? ref.watch(visibleMatesProvider)[0].skills : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleMatesProvider).length > 0)),
      gP(287.2, 290, 64.8, 22, gBox(color: (ref.watch(visibleMatesProvider).length > 0 ? inviteFill(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[0].name)) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleMatesProvider).length > 0)),
      gP(302.6, 294, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 0 ? (ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[0].name) ? 'Invité' : 'Inviter') : '', 11, (ref.watch(visibleMatesProvider).length > 0 ? inviteInk(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[0].name)) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleMatesProvider).length > 0)),
      gP(98, 334, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 342, 50, 50, gBox(image: 'assets/figma/img/ebf23a969ca7b1083d1dcab994c4899c0b4db38b.png', fit: BoxFit.cover, radii: [25, 25, 25, 25]), show: (ref.watch(visibleMatesProvider).length > 1)),
      gP(98, 346, 96, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 1 ? ref.watch(visibleMatesProvider)[1].name : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleMatesProvider).length > 1)),
      gP(98, 368, 132, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 1 ? ref.watch(visibleMatesProvider)[1].skills : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleMatesProvider).length > 1)),
      gP(287.2, 356, 64.8, 22, gBox(color: (ref.watch(visibleMatesProvider).length > 1 ? inviteFill(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[1].name)) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleMatesProvider).length > 1)),
      gP(302.6, 360, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 1 ? (ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[1].name) ? 'Invité' : 'Inviter') : '', 11, (ref.watch(visibleMatesProvider).length > 1 ? inviteInk(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[1].name)) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleMatesProvider).length > 1)),
      gP(98, 400, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 408, 50, 50, gBox(image: 'assets/figma/img/c15478a4e0a5cc1be462d8179ed1a24390853242.png', fit: BoxFit.cover, radii: [25, 25, 25, 25]), show: (ref.watch(visibleMatesProvider).length > 2)),
      gP(98, 412, 107, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 2 ? ref.watch(visibleMatesProvider)[2].name : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleMatesProvider).length > 2)),
      gP(98, 434, 125, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 2 ? ref.watch(visibleMatesProvider)[2].skills : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleMatesProvider).length > 2)),
      gP(293.6, 422, 58.4, 22, gBox(color: (ref.watch(visibleMatesProvider).length > 2 ? inviteFill(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[2].name)) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleMatesProvider).length > 2)),
      gP(307.8, 426, 30, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 2 ? (ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[2].name) ? 'Invité' : 'Inviter') : '', 11, (ref.watch(visibleMatesProvider).length > 2 ? inviteInk(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[2].name)) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleMatesProvider).length > 2)),
      gP(98, 466, 256, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(36, 474, 50, 50, gBox(image: 'assets/figma/img/8d2db59994dcfe0c5b9851845e0b9f6aec49d36d.png', fit: BoxFit.cover, radii: [25, 25, 25, 25]), show: (ref.watch(visibleMatesProvider).length > 3)),
      gP(98, 478, 114, 17, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 3 ? ref.watch(visibleMatesProvider)[3].name : '', 13.5, Color(0xFF111015), weight: 600)), show: (ref.watch(visibleMatesProvider).length > 3)),
      gP(98, 500, 133, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 3 ? ref.watch(visibleMatesProvider)[3].skills : '', 11.5, Color(0xFF66636E))), show: (ref.watch(visibleMatesProvider).length > 3)),
      gP(287.2, 488, 64.8, 22, gBox(color: (ref.watch(visibleMatesProvider).length > 3 ? inviteFill(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[3].name)) : const Color(0x00000000)), radii: [11, 11, 11, 11]), show: (ref.watch(visibleMatesProvider).length > 3)),
      gP(302.6, 492, 34, 14, Consumer(builder: (context, ref, _) => gText(ref.watch(visibleMatesProvider).length > 3 ? (ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[3].name) ? 'Invité' : 'Inviter') : '', 11, (ref.watch(visibleMatesProvider).length > 3 ? inviteInk(ref.watch(teamMembersProvider).any((m) => m.name == ref.watch(visibleMatesProvider)[3].name)) : const Color(0xFF5A3FE0)), weight: 600, align: TextAlign.center)), show: (ref.watch(visibleMatesProvider).length > 3)),
      gP(24, 546, 342, 79, gBox(color: Color(0xFFF2EFF6), radii: [20, 20, 20, 20])),
      gP(36, 569.5, 32, 32, gBox(color: Color(0xFFFFFFFF), radii: [11, 11, 11, 11])),
      gP(42.625, 575.417, 18.75, 16.625, gImg('assets/figma/v/b2ae09d0fd46bb.svg')),
      gP(47.796, 588.875, 8.408, 6.712, gImg('assets/figma/v/f59da0513c0b4c.svg')),
      gP(76, 560, 277, 51, gText('Les invitations sont envoyées par notification, SMS ou WhatsApp selon les préférences du talent.', 12, Color(0xFF4A4854), lh: 17, wrap: true)),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 274, 342, 62, () { final l = ref.read(visibleMatesProvider); if (l.length > 0) { toggleInvite(ref, context, l[0]); } }),
      gTap(24, 340, 342, 62, () { final l = ref.read(visibleMatesProvider); if (l.length > 1) { toggleInvite(ref, context, l[1]); } }),
      gTap(24, 406, 342, 62, () { final l = ref.read(visibleMatesProvider); if (l.length > 2) { toggleInvite(ref, context, l[2]); } }),
      gTap(24, 472, 342, 62, () { final l = ref.read(visibleMatesProvider); if (l.length > 3) { toggleInvite(ref, context, l[3]); } }),
    ]);
  }
}
