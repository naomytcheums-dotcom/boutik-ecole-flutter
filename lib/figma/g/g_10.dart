// GÉNÉRÉ par tool/figma_export/convert.py — écran 10 (nœud Figma 15:96). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/inert_actions.dart';
import '../live/talent_pages.dart';
import '../live/store.dart';
import '../live/circle_feed.dart';
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
import '../live/account_menu.dart';
import '../live/access.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import '../live/company_profile_layers.dart';
import '../live/social_profile.dart' show SocialProfile;
import '../live/lot20b.dart' show myProjectsProvider;
import '../live/company_screens.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_10 extends ConsumerWidget {
  const G_10({super.key, this.viewProfile, this.onPrimary});

  /// Profil d'une autre personne (même écran 10) : texte, chiffres et couverture viennent d'elle ; le bouton principal devient « Écrire ».
  final SocialProfile? viewProfile;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Une entreprise a sa propre fiche (secteur, interlocuteur, pièces, vérification), pas le profil d'un étudiant.
    final me = ref.watch(authProvider.select((a) => a.current));
    // Une entreprise a le même écran 10 (design du Figma) avec son propre contenu : nom, secteur, présentation, chiffres, vérification.
    final isView = viewProfile != null;
    final isCo = !isView && !demoContent && me != null && me.role == 2 && me.staff.isEmpty;
    final hideLinks = isCo || isView;
    final co = isCo ? companyProfileInfo(ref) : null;
    void goTo(String path) => GoRouter.of(context).push(path);
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(18, 92, 114, 244, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: demoContent),
      if (!demoContent) gP(18, 92, 114, 244, FeaturedVideo(slot: 0, userId: viewProfile?.id)),
      gP(140, 92, 124, 244, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: demoContent),
      if (!demoContent) gP(140, 92, 124, 244, FeaturedVideo(slot: 1, userId: viewProfile?.id)),
      gP(272, 92, 114, 244, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [26, 26, 26, 26]), show: demoContent),
      if (!demoContent) gP(272, 92, 114, 244, FeaturedVideo(slot: 2, userId: viewProfile?.id)),
      gP(0, 92, 390, 250, IgnorePointer(child: gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0x00F2EBF0), Color(0x00F2EBF0), Color(0xD9F2EBF0)], stops: [0, 0.78, 1])))),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/cbab01bfe4421a.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/47e4d365400cc9.svg')),
      gP(316, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x24403366), offset: Offset(0, 4), blurRadius: 10, spreadRadius: 0)], backBlur: 20, oval: true), tap: () { accountMenu(context, ref); }),
      gP(334.05, 82.508, 7.9, 7.9, gImg('assets/figma/v/cb3b5db29da178.svg')),
      gP(334.05, 88.05, 7.9, 7.9, gImg('assets/figma/v/fd509ee195da6b.svg')),
      gP(334.05, 93.592, 7.9, 7.9, gImg('assets/figma/v/c2a19bebfb5925.svg')),
      gP(140, 68, 102, 19, gText(demoContent ? 'Profil étudiant' : (isView ? (viewProfile!.role == 'student' ? 'Profil étudiant' : 'Profil') : (isCo ? 'Profil entreprise' : 'Mon profil')), 15, Color(0xFF111015), weight: 600)),
      gP(138, 273, 114, 114, gBox(gradient: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFFF4B6E), Color(0xFFFF8A3D), Color(0xFF9B7BFF)], stops: [0, 0.5, 1]), oval: true)),
      gP(143, 278, 104, 104, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x1A403366), offset: Offset(0, 4), blurRadius: 12, spreadRadius: 0)], oval: true)),
      if (co != null) companyAvatarLayer(co, 149, 284, 92) else profileAvatar(149, 284, 92),
      if (co != null) companyNameLayer(co, 392) else profileNameBadge(392),
      // badge bleu : voir profileNameBadge (certification approuvée uniquement)

      if (co != null) companyLineLayer([co.sector, co.city].where((e) => e.isNotEmpty).join(' · '), 426) else profileSubline(426),
      if (co != null) companyLineLayer(co.tags.join(' '), 446, color: const Color(0xFF5A3FE0), h: 16) else profileSkillsOrCert(446),
      if (co != null) companyBioLayer(co, 470) else profileBio(470),
      gP(34, 512, 104, 30, gBox(color: Color(0xFFF4F3F6), radii: [15, 15, 15, 15])),
      if (isView) companyStatLayer(34, 'Publications', viewProfile!.postsCount) else if (co != null) companyStatLayer(34, 'Offres', co.offers) else profileStat(34, 'Produits', (ref) => ref.watch(listingsProvider).where((l) => l.published).length),
      gP(143, 512, 104, 30, gBox(color: Color(0xFFF4F3F6), radii: [15, 15, 15, 15])),
      if (isView) companyStatLayer(143, 'Abonnés', viewProfile!.followersCount) else if (co != null) companyStatLayer(143, 'Concours', co.contests) else profileStat(143, 'Services', (ref) => ref.watch(listingsProvider).where((l) => l.published && l.category == 'Services').length),
      gP(252, 512, 104, 30, gBox(color: Color(0xFFF4F3F6), radii: [15, 15, 15, 15])),
      if (isView) companyStatLayer(252, 'Suivis', viewProfile!.followingCount) else if (co != null) companyStatLayer(252, 'Besoins', co.needs) else profileStat(252, 'Projets', (ref) => ref.watch(myProjectsProvider)?.length ?? 0),
      gP(24, 562, 29, 14, gText('Liens', 11.5, Color(0xFF57545F), weight: 500)),
      gP(89, 553, 32, 32, gImg('assets/figma/v/cdc43165645969.svg'), show: !hideLinks),
      gP(94.417, 563.292, 9.033, 15.75, gImg('assets/figma/v/ae94c8691f4b0c.svg'), show: !hideLinks),
      gP(94.146, 558.146, 9.575, 9.575, gImg('assets/figma/v/a7dfb3074b8bb1.svg'), show: !hideLinks),
      gP(99.617, 563.075, 15.425, 15.967, gImg('assets/figma/v/69716965815a8f.svg'), show: !hideLinks),
      gP(160, 556, 26, 26, gImg('assets/figma/r/166_126.png'), show: !hideLinks),
      gP(163.5, 559.5, 19, 19, gImg('assets/figma/v/8f84eb67c72226.svg'), show: !hideLinks),
      gP(166.967, 562.967, 12.067, 12.067, gImg('assets/figma/v/4750520cc7ff60.svg'), show: !hideLinks),
      gP(172.871, 561.071, 8.058, 8.058, gImg('assets/figma/v/39063a6ecfe984.svg'), show: !hideLinks),
      gP(24, 624, 110, 70, gBox(image: 'assets/figma/img/768cf16e6d8103ad4296d6cc0fdf1af309f03817.png', fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: demoContent),
      gP(140, 624, 110, 70, gBox(image: 'assets/figma/img/d5a96228e65dc2920e40cfac9b1205c2faee3caf.png', fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: demoContent),
      gP(256, 624, 110, 70, gBox(image: 'assets/figma/img/3772da6500f3556774cbcb6de8b57dfe17455f32.png', fit: BoxFit.cover, radii: [22, 22, 22, 22]), show: demoContent),
      Positioned.fill(child: GChoiceGroup(onChanged: (i) { if (i == 0) { isView ? onPrimary?.call() : (isCo ? goTo('/entreprise/profil') : editProfileDialog(context, ref)); } if (i == 1) { isView ? gToast(context, 'Lien du profil : ${Uri.base.origin}/#/s/10?user=${viewProfile!.id}') : shareMyProfile(context, ref); } }, chips: [GChip(24, 700, 200, 44, isView ? 'Écrire' : (isCo ? 'Modifier la fiche' : 'Modifier mon profil'), 12.5, 600), GChip(199, 700, 200, 44, 'Partager', 12.5, 500)], selected: 0, selFill: Color(0xFF111015), unselFill: Color(0x00FFFFFF), selText: Color(0xFFFFFFFF), unselText: Color(0xFF111015), radius: 22)),
      gP(232, 700, 134, 44, gBox(color: Color(0xB2FFFFFF), border: Color(0xFFFFFFFF), bw: 1, radii: [22, 22, 22, 22]), tap: () => shareMyProfile(context, ref)),
      gP(22, 756, 346, 64, gBox(color: Color(0x6BFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, shadows: [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24, spreadRadius: 0)], backBlur: 26, radii: [32, 32, 32, 32])),
      gP(47.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '19')),
      gP(47.125, 777.125, 20, 20, gImg('assets/figma/v/96285515fb0e14.svg')),
      gP(59.113, 789.113, 9.762, 9.762, gImg('assets/figma/v/524f40fa464a05.svg')),
      gP(113.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '52')),
      gP(112.25, 777.118, 22.632, 22.632, gImg('assets/figma/v/5610544a74c77c.svg')),
      gP(255.5, 777.5, 21, 21, const SizedBox.expand(), tap: () => gTab(context, '230')),
      gP(260.375, 776.25, 11.25, 16.5, gImg('assets/figma/v/3adad339ddf7e4.svg')),
      gP(256.875, 783.25, 18.25, 13, gImg('assets/figma/v/9c6e9349b8c3b4.svg')),
      gP(263, 790.25, 6, 9.5, gImg('assets/figma/v/c403dd00a5d407.svg')),
      gP(324.625, 777.125, 14.75, 14.75, gImg('assets/figma/v/c6a28fb600186c.svg')),
      gP(322, 785.875, 20, 13, gImg('assets/figma/v/de7faa24b27dad.svg')),
      gP(169, 762, 52, 52, gBox(gradient: RadialGradient(center: Alignment(0, 0), radius: 0.5, colors: [Color(0xFF2A2D36), Color(0xFF0E0F14)], stops: [0, 1]), border: Color(0xFFFF8A3D), bw: 2.5, shadows: [BoxShadow(color: Color(0x59FF8A3D), offset: Offset(-2, 2), blurRadius: 10, spreadRadius: 0), BoxShadow(color: Color(0x594F8CFF), offset: Offset(2, -1), blurRadius: 10, spreadRadius: 0)], oval: true), tap: () => gTab(context, '03')),
      gP(184, 777, 22, 22, const SizedBox.expand(), tap: () => gTab(context, '03')),
      gP(183.75, 775.852, 22.5, 23.398, gImg('assets/figma/v/ec9f8d654b9909.svg')),
      gP(123, 553, 32, 32, gImg('assets/figma/v/2d3ef0cebe3113.svg'), show: !hideLinks),
      gP(128.958, 559.631, 20.04, 18.694, gImg('assets/figma/v/31ca13725eac3f.svg'), show: !hideLinks),
      gP(194, 556, 26, 26, gBox(color: Color(0xFF24292E), radii: [8, 8, 8, 8]), show: !hideLinks),
      gP(198.659, 559.333, 16.682, 19.333, gImg('assets/figma/v/9420af15075547.svg'), show: !hideLinks),
      gP(197.333, 568.667, 10.667, 7.707, gImg('assets/figma/v/4b0531a4484979.svg'), show: !hideLinks),
      gP(232, 556, 82, 26, gBox(color: Color(0xCCFFFFFF), border: Color(0xFFFFFFFF), bw: 1, radii: [100, 100, 100, 100])),
      gP(245, 562, 56, 14, gText(isCo ? 'Site web ↗' : 'Portfolio ↗', 11, Color(0xFF120F14), weight: 600)),
      gP(326, 556, 26, 26, gBox(color: Color(0xFF111015), oval: true)),
      gP(326, 556, 26, 26, const Icon(Icons.add_rounded, size: 18, color: Color(0xFFFFFFFF))),
      gP(24, 592, 342, 30, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [15, 15, 15, 15])),
      gP(37, 600, 10, 10, gImg('assets/figma/r/213_260.png')),
      gP(37.667, 607.334, 8.666, 7.333, gImg('assets/figma/r/213_261.png')),
      if (co != null) gP(60, 600, 270, 15, Text(companyPassportLabel(co), style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111015)))) else profilePassport(60, 600),
      gP(344, 598, 6, 19, gText('›', 15, Color(0xFF5A3FE0), weight: 700)),
      gTap(326, 556, 26, 26, () => isView ? null : isCo ? goTo('/entreprise/profil') : gOpen(context, '271')), if (!hideLinks) gTap(89, 553, 32, 32, () => openUrl(context, 'https://www.instagram.com/')), if (!hideLinks) gTap(123, 553, 32, 32, () => openUrl(context, 'https://www.linkedin.com/')), if (!hideLinks) gTap(160, 556, 26, 26, () => openUrl(context, 'https://www.tiktok.com/')), if (!hideLinks) gTap(194, 556, 26, 26, () => openUrl(context, 'https://github.com/')), gTap(232, 556, 82, 26, () => isCo ? ((co?.website ?? '').isEmpty ? goTo('/entreprise/profil') : openUrl(context, co!.website)) : openUrl(context, 'https://boutik-ecole.vercel.app/#/s/10')),
      gTap(24, 596, 342, 92, () => isView ? null : isCo ? goTo('/entreprise/profil') : gOpen(context, '40')),
      gTap(35, 513, 100, 28, () { if (isView) return; isCo ? goTo('/opportunites/mes') : gOpen(context, canOpen(ref.read(authProvider).current, '58') ? '58' : '22'); }),
      gTap(143, 513, 100, 28, () { if (isView) return; isCo ? goTo('/concours/mes') : gOpen(context, '22b'); }),
      gTap(252, 513, 104, 28, () { if (isView) return; isCo ? goTo('/s/99') : gOpen(context, '78'); }),
      gTap(24, 592, 342, 30, () => isView ? null : isCo ? goTo('/entreprise/profil') : gOpen(context, '74')),
      if (!demoContent && !isCo) gTap(232, 552, 82, 34, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => isView ? PortfolioPage(userId: viewProfile!.id, ownerName: viewProfile!.name) : const PortfolioPage()))),
    ]);
  }
}
