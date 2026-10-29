// GÉNÉRÉ par tool/figma_export/convert.py — écran 279 (nœud Figma 209:142). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_279 extends ConsumerWidget {
  const G_279({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GScreen(w: 390, h: 844, radius: 46, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 140, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 580, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 28, 18, gText('9:41', 14, Color(0xFF111015), weight: 600)),
      gP(140, 10, 110, 30, gBox(color: Color(0xFF000000), radii: [15, 15, 15, 15])),
      gP(22, 38, 34, 32, gBox(image: 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png', fit: BoxFit.contain)),
      gP(30, 70, 44, 44, gBox(color: Color(0x8CFFFFFF), border: Color(0xFFFFFFFF), bw: 1.5, backBlur: 20, oval: true), tap: () => gBack(context)),
      gP(42.5, 82.5, 19, 19, const SizedBox.expand(), tap: () => gBack(context)),
      gP(43.458, 83.458, 11.542, 17.083, gImg('assets/figma/v/7a21623fe0dfea.svg')),
      gP(43.458, 89, 17.083, 6, gImg('assets/figma/v/e130a05f3cf779.svg')),
      gP(117, 76, 156, 21, gText('Ajouter des fichiers', 17, Color(0xFF111015), weight: 500)),
      gP(76, 102, 238, 15, gText('Contrôles automatiques avant publication', 12, Color(0xFF66636E))),
      gP(164.917, 136.637, 63.334, 66.612, gImg('assets/figma/r/209_239.png')),
      gP(24, 226, 342, 120, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(44, 242, 111, 18, gText('Règles de dépôt', 14, Color(0xFF111015), weight: 600)),
      gP(44, 272, 89, 15, gText('Types autorisés', 12, Color(0xFF66636E))),
      gP(153, 272, 193, 15, gText('JPG · PNG · WebP · PDF · MP4 · ZIP', 12, Color(0xFF111015), weight: 600)),
      gP(44, 298, 85, 15, gText('Taille maximale', 12, Color(0xFF66636E))),
      gP(191, 298, 155, 15, gText('5 Mo image · 200 Mo vidéo', 12, Color(0xFF111015), weight: 600)),
      gP(44, 324, 45, 15, gText('Analyse', 12, Color(0xFF66636E))),
      gP(202, 324, 144, 15, gText('Antivirus à chaque dépôt', 12, Color(0xFF111015), weight: 600)),
      gP(24, 366, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(40, 382, 10, 10, gBox(color: Color(0xFF0F7A52), oval: true)),
      gP(60, 376, 101, 16, gText('plan-lampe.pdf', 13, Color(0xFF111015), weight: 600)),
      gP(300, 376, 33, 14, gText('2,1 Mo', 11, Color(0xFF66636E), weight: 500)),
      gP(60, 400, 132, 15, gText('Analyse terminée : sain', 12, Color(0xFF0F7A52), weight: 600)),
      gP(24, 440, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(40, 456, 10, 10, gBox(color: Color(0xFFA35F00), oval: true)),
      gP(60, 450, 85, 16, gText('maquette.zip', 13, Color(0xFF111015), weight: 600)),
      gP(300, 450, 33, 14, gText('48 Mo', 11, Color(0xFF66636E), weight: 500)),
      gP(60, 474, 138, 15, gText('Analyse en cours… 64 %', 12, Color(0xFF8F5400), weight: 600)),
      gP(24, 514, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(40, 530, 10, 10, gBox(color: Color(0xFFB42318), oval: true)),
      gP(60, 524, 64, 16, gText('script.exe', 13, Color(0xFF111015), weight: 600)),
      gP(300, 524, 33, 14, gText('1,2 Mo', 11, Color(0xFF66636E), weight: 500)),
      gP(60, 548, 150, 15, gText('Refusé : type non autorisé', 12, Color(0xFFB42318), weight: 600)),
      gP(24, 588, 342, 64, gBox(color: Color(0xE0FFFFFF), border: Color(0xFFEEECE8), bw: 1, radii: [20, 20, 20, 20])),
      gP(40, 604, 10, 10, gBox(color: Color(0xFFB42318), oval: true)),
      gP(60, 598, 114, 16, gText('video-demo.mp4', 13, Color(0xFF111015), weight: 600)),
      gP(300, 598, 37, 14, gText('312 Mo', 11, Color(0xFF66636E), weight: 500)),
      gP(60, 622, 146, 15, gText('Refusé : dépasse 200 Mo', 12, Color(0xFFB42318), weight: 600)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Ajouter un fichier')),
      gP(134, 788, 122, 19, gText('Ajouter un fichier', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
