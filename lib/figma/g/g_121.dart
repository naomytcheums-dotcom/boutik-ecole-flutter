// GÉNÉRÉ par tool/figma_export/convert.py — écran 121 (nœud Figma 42:593). Ne pas éditer à la main.
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

class G_121 extends ConsumerWidget {
  const G_121({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 1280, h: 890, radius: 16, color: Color(0xFFF7F6F4), children: [
      gP(268, 134, 238.5, 92, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(282, 146, 77, 14, gText('Responsables', 11.5, Color(0xFF66636E), weight: 500, inter: true)),
      gP(282, 166, 14, 24, gText('8', 20, Color(0xFF111015), weight: 700, inter: true)),
      gP(466.5, 146, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(473.75, 150.75, 13.5, 13.5, gImg('assets/figma/v/c741934f1ce95f.svg')),
      gP(474.375, 157.556, 12.25, 11.694, gImg('assets/figma/v/fceb02bed58402.svg')),
      gP(516.5, 134, 238.5, 92, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(530.5, 146, 68, 14, gText('Enseignants', 11.5, Color(0xFF66636E), weight: 500, inter: true)),
      gP(530.5, 166, 27, 24, gText('64', 20, Color(0xFF111015), weight: 700, inter: true)),
      gP(715, 146, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(719.75, 158.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(721.625, 151.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(730.375, 158.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(728.5, 151.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(765, 134, 238.5, 92, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(779, 146, 63, 14, gText('Encadreurs', 11.5, Color(0xFF66636E), weight: 500, inter: true)),
      gP(779, 166, 25, 24, gText('27', 20, Color(0xFF111015), weight: 700, inter: true)),
      gP(963.5, 146, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(968.25, 152.625, 18.5, 12.25, gImg('assets/figma/v/07abce74978c9f.svg')),
      gP(970.75, 157, 13.5, 10.531, gImg('assets/figma/v/bdb6350ece6237.svg')),
      gP(1013.5, 134, 238.5, 92, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(1027.5, 146, 97, 14, gText('Mentors externes', 11.5, Color(0xFF66636E), weight: 500, inter: true)),
      gP(1027.5, 166, 23, 24, gText('12', 20, Color(0xFF111015), weight: 700, inter: true)),
      gP(1212, 146, 28, 28, gBox(color: Color(0xFFF1EEFB), radii: [9, 9, 9, 9])),
      gP(1216.75, 153.875, 18.5, 14.75, gImg('assets/figma/v/95b3663071ee25.svg')),
      gP(1220.5, 151.375, 11, 17.25, gImg('assets/figma/v/4aa62e9dd5b95e.svg')),
      gP(268, 240, 984, 216, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [26, 26, 26, 26])),
      gP(269, 241, 982, 39, gBox(color: Color(0xFFF4F1F8), radii: [15, 15, 15, 15])),
      gP(284, 253, 25, 13, gText('Nom', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(512.48, 253, 47, 13, gText('Fonction', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(702.88, 253, 71, 13, gText('Département', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(912.32, 253, 66, 13, gText('Affectations', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(1083.68, 253, 33, 13, gText('Statut', 11, Color(0xFF66636E), weight: 600, inter: true)),
      gP(284, 294, 61, 15, gText('Dr Mbarga', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(512.48, 294, 73, 15, gText('Responsable', 12, Color(0xFF4A4854), inter: true)),
      gP(702.88, 294, 108, 15, gText('Génie informatique', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 294, 79, 15, gText('248 étudiants', 12, Color(0xFF4A4854), inter: true)),
      gP(1083.68, 291, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(1096.68, 295, 26, 13, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 324, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 338, 68, 15, gText('Dr Tchoupo', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(512.48, 338, 73, 15, gText('Responsable', 12, Color(0xFF4A4854), inter: true)),
      gP(702.88, 338, 59, 15, gText('Génie civil', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 338, 77, 15, gText('212 étudiants', 12, Color(0xFF4A4854), inter: true)),
      gP(1083.68, 335, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(1096.68, 339, 26, 13, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 368, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 382, 59, 15, gText('Pr Ngassa', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(512.48, 382, 58, 15, gText('Encadreur', 12, Color(0xFF4A4854), inter: true)),
      gP(702.88, 382, 93, 15, gText('Génie électrique', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 382, 56, 15, gText('18 projets', 12, Color(0xFF4A4854), inter: true)),
      gP(1083.68, 379, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(1096.68, 383, 26, 13, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(280, 412, 960, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(284, 426, 66, 15, gText('Mme Etoga', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(512.48, 426, 73, 15, gText('Responsable', 12, Color(0xFF4A4854), inter: true)),
      gP(702.88, 426, 25, 15, gText('MMI', 12, Color(0xFF4A4854), inter: true)),
      gP(912.32, 426, 77, 15, gText('180 étudiants', 12, Color(0xFF4A4854), inter: true)),
      gP(1083.68, 423, 52, 22, gBox(color: Color(0xFFDDF5EC), radii: [11, 11, 11, 11])),
      gP(1096.68, 427, 26, 13, gText('Actif', 11, Color(0xFF0F7A52), weight: 600, inter: true, align: TextAlign.center)),
      gP(0, 0, 1280, 56, gBox(color: Color(0xFFFFFFFF))),
      gP(20, 10, 36, 34, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(62, 17, 107, 21, gText('Boutik-École', 17, Color(0xFF18181B), weight: 700, inter: true)),
      gP(240, 12, 330, 34, GField(hint: 'Rechercher données, rapports, produits…', size: 11.5, hintColor: Color(0xFF66636E), weight: 400, padL: 36, inter: true)),
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
      gP(23.375, 157.625, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(24.625, 146.375, 14.75, 17.25, gImg('assets/figma/v/b3da102be08062.svg')),
      gP(27.125, 153.875, 9.75, 9.75, gImg('assets/figma/v/c0732433837967.svg')),
      gP(52, 147, 80, 15, gText('Établissement', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 185.75, 18.5, 12.25, gImg('assets/figma/v/a8962ce588a956.svg')),
      gP(22.75, 195.125, 18.5, 9.125, gImg('assets/figma/v/24a45f8b5f58fe.svg')),
      gP(22.75, 192, 18.5, 9.125, gImg('assets/figma/v/24a45f8b5f58fe.svg')),
      gP(52, 187, 81, 15, gText('Départements', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 233.875, 14.75, 9.75, gImg('assets/figma/v/1782796e9e22c0.svg')),
      gP(24.625, 226.375, 11, 11, gImg('assets/figma/v/3bae74da037db6.svg')),
      gP(33.375, 233.956, 7.875, 9.669, gImg('assets/figma/v/7b2b9c968238b1.svg')),
      gP(31.5, 226.456, 7.88, 10.844, gImg('assets/figma/v/7d1afd23f298a1.svg')),
      gP(52, 227, 64, 15, gText('Utilisateurs', 12, Color(0xFF55524C), inter: true)),
      gP(20, 276, 37, 12, gText('Gestion', 10, Color(0xFF716D65), weight: 500, inter: true)),
      gP(12, 290, 216, 34, gBox(color: Color(0xFFFFFFFF), shadows: [BoxShadow(color: Color(0x144D401A), offset: Offset(0, 2), blurRadius: 8, spreadRadius: 0)], radii: [10, 10, 10, 10])),
      gP(25.25, 297.75, 13.5, 13.5, gImg('assets/figma/v/c741934f1ce95f.svg')),
      gP(25.875, 304.556, 12.25, 11.694, gImg('assets/figma/v/1fd18b4a4a1f32.svg')),
      gP(52, 299, 82, 15, gText('Responsables', 12, Color(0xFF111015), weight: 600, inter: true)),
      gP(24, 337.75, 16, 18.502, gImg('assets/figma/v/eb1ca16ae0995f.svg')),
      gP(27.125, 342.75, 9.75, 8.5, gImg('assets/figma/v/67b1d949f5166f.svg')),
      gP(52, 339, 119, 15, gText('Circuits de validation', 12, Color(0xFF55524C), inter: true)),
      gP(22.75, 380.875, 18.5, 12.25, gImg('assets/figma/v/b8aa2d550e4e95.svg')),
      gP(31.5, 380.875, 9.75, 9.75, gImg('assets/figma/v/bf4c9c3198e949.svg')),
      gP(52, 379, 99, 15, gText('Activité et ventes', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 419, 17.25, 17.25, gImg('assets/figma/v/acdac738c047b0.svg')),
      gP(31.5, 417.75, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(26.5, 417.75, 6, 8.5, gImg('assets/figma/v/c96460ed96947c.svg')),
      gP(23.375, 422.75, 17.25, 6, gImg('assets/figma/v/fabbebac184fd2.svg')),
      gP(52, 419, 70, 15, gText('Événements', 12, Color(0xFF55524C), inter: true)),
      gP(24, 457.75, 16, 18.5, gImg('assets/figma/v/ff64e2b6a5eb10.svg')),
      gP(30.25, 457.75, 9.75, 9.75, gImg('assets/figma/v/3b2d5604a267d0.svg')),
      gP(52, 459, 52, 15, gText('Rapports', 12, Color(0xFF55524C), inter: true)),
      gP(23.375, 498.38, 17.25, 17.25, gImg('assets/figma/v/a50cd9410c0076.svg')),
      gP(23.375, 498.375, 9.125, 9.125, gImg('assets/figma/v/3ad9c2af89ef3b.svg')),
      gP(29, 500.875, 8.5, 10.375, gImg('assets/figma/v/23a92abb65788c.svg')),
      gP(52, 499, 83, 15, gText('Journal d’audit', 12, Color(0xFF55524C), inter: true)),
      gP(12, 814, 216, 56, gBox(color: Color(0xFFFFFFFF), radii: [14, 14, 14, 14])),
      gP(22, 824, 36, 36, gBox(image: 'assets/figma/img/d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47.png', fit: BoxFit.cover, oval: true)),
      gP(66, 827, 51, 14, gText('Direction', 11.5, Color(0xFF111015), weight: 600, inter: true)),
      gP(66, 844, 64, 11, gText('IUT de Douala', 9.5, Color(0xFF66636E), inter: true)),
      gP(268, 76, 326, 29, gText('Responsables et encadreurs', 24, Color(0xFF18181B), weight: 500, inter: true)),
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
      gTap(12, 96, 216, 36, () => gOpen(context, '117')),
      gTap(12, 136, 216, 36, () => gOpen(context, '118')),
      gTap(12, 176, 216, 36, () => gOpen(context, '119')),
      gTap(12, 216, 216, 36, () => gOpen(context, '120')),
      gTap(12, 328, 216, 36, () => gOpen(context, '122')),
      gTap(12, 368, 216, 36, () => gOpen(context, '123')),
      gTap(12, 408, 216, 36, () => gOpen(context, '124')),
      gTap(12, 448, 216, 36, () => gOpen(context, '125')),
      gTap(12, 488, 216, 36, () => gOpen(context, '126')),
    ]);
  }
}
