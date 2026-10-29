// GÉNÉRÉ par tool/figma_export/convert.py — écran 275 (nœud Figma 200:366). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_275 extends ConsumerWidget {
  const G_275({super.key});

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
      gP(116.5, 76, 157, 21, gText('Déposer un produit', 17, Color(0xFF111015), weight: 500)),
      gP(119, 102, 152, 15, gText('Étape 2 sur 4 · Informations', 12, Color(0xFF66636E))),
      gP(28, 130, 89, 15, gText('Titre du produit', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 150, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFD92D20), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(28, 202, 218, 14, gText('Le titre est obligatoire (3 à 80 caractères).', 11, Color(0xFFD92D20), weight: 500)),
      gP(28, 236, 63, 15, gText('Prix (FCFA)', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 256, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFD92D20), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(24, 256, 342, 48, GField(hint: 'Ex : 25 000', size: 14, hintColor: Color(0xFF77747F), weight: 500, padL: 16)),
      gP(28, 308, 246, 14, gText('Entrez un montant entier supérieur à 500 FCFA.', 11, Color(0xFFD92D20), weight: 500)),
      gP(28, 342, 59, 15, gText('Catégorie', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 362, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFDAD8DF), bw: 1, radii: [14, 14, 14, 14])),
      gP(24, 362, 342, 48, GField(hint: '', initial: 'Mobilier · Bois recyclé', size: 14, hintColor: Color(0xFF111015), weight: 500, padL: 16)),
      gP(28, 442, 96, 15, gText('Photo principale', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 462, 342, 48, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFD92D20), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(24, 462, 342, 48, GField(hint: '', initial: 'image-trop-lourde.png · 9,4 Mo', size: 14, hintColor: Color(0xFF111015), weight: 500, padL: 16)),
      gP(28, 514, 274, 14, gText('Fichier trop lourd : 5 Mo maximum (JPG, PNG, WebP).', 11, Color(0xFFD92D20), weight: 500)),
      gP(24, 560, 342, 64, gBox(color: Color(0xFFFEF3F2), border: Color(0xFFFECDCA), bw: 1, radii: [18, 18, 18, 18])),
      gP(36.817, 579.983, 26.366, 22.866, gImg('assets/figma/r/200_479.png')),
      gP(48.483, 588.15, 3.045, 12.366, gImg('assets/figma/r/200_480.png')),
      gP(72, 576, 274, 20, gText('3 champs à corriger avant de continuer. Votre brouillon est enregistré.', 12, Color(0xFFB42318), weight: 500)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => gToast(context, 'Démonstration : Continuer')),
      gP(158.5, 788, 73, 19, gText('Continuer', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}
