// GÉNÉRÉ par tool/figma_export/convert.py — écran 275 (nœud Figma 200:366), puis raccordé à la main (gelé dans bindings.json).
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
import '../live/lots.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_275 extends ConsumerWidget {
  const G_275({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Récapitulatif réel des erreurs du formulaire 58 (au moins deux champs à corriger) ; sans erreur réelle, la maquette.
    final errs = ref.watch(errorsProvider);
    final f = ref.watch(formProvider);
    final real = newProductErrorKeys.any(errs.containsKey);
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
      gP(119, 102, 152, 15, gText(real ? 'Nouveau produit · corrections' : 'Étape 2 sur 4 · Informations', 12, Color(0xFF66636E))),
      gP(28, 130, 89, 15, gText('Titre du produit', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 150, 342, 48, gBox(color: Color(0xFFFFFFFF), border: (!real || errs.containsKey('np_title')) ? Color(0xFFD92D20) : Color(0xFFE6E1EE), bw: 1.5, radii: [14, 14, 14, 14])),
      gP(40, 165, 310, 18, gText(f['np_title'] ?? '', 14, Color(0xFF111015), weight: 500), show: real),
      gP(28, 202, 320, 14, gText(real ? (errs['np_title'] ?? '') : 'Le titre est obligatoire (3 à 80 caractères).', 11, Color(0xFFD92D20), weight: 500)),
      gP(28, 236, 63, 15, gText('Prix (FCFA)', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 256, 342, 48, real ? _ro(f['np_price'] ?? '25 000') : GField(hint: 'Ex : 25 000', size: 14, hintColor: Color(0xFF77747F), weight: 500, padL: 16)),
      gP(28, 308, 246, 14, gText(real ? (errs['np_price'] ?? '') : 'Entrez un montant entier supérieur à 500 FCFA.', 11, Color(0xFFD92D20), weight: 500)),
      gP(28, 342, 59, 15, gText('Catégorie', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 362, 342, 48, real ? _ro(f['np_cat'] ?? 'Maison et déco') : GField(hint: '', initial: 'Mobilier · Bois recyclé', size: 14, hintColor: Color(0xFF111015), weight: 500, padL: 16)),
      gP(28, 414, 320, 14, gText(errs['np_cat'] ?? '', 11, Color(0xFFD92D20), weight: 500), show: real),
      gP(28, 442, 96, 15, gText(real ? 'Stock disponible' : 'Photo principale', 12, Color(0xFF6B6877), weight: 600)),
      gP(24, 462, 342, 48, real ? _ro(f['np_stock'] ?? '30') : GField(hint: '', initial: 'image-trop-lourde.png · 9,4 Mo', size: 14, hintColor: Color(0xFF111015), weight: 500, padL: 16)),
      gP(28, 514, 274, 14, gText(real ? (errs['np_stock'] ?? '') : 'Fichier trop lourd : 5 Mo maximum (JPG, PNG, WebP).', 11, Color(0xFFD92D20), weight: 500)),
      gP(36.817, 579.983, 26.366, 22.866, gImg('assets/figma/r/200_479.png')),
      gP(48.483, 588.15, 3.045, 12.366, gImg('assets/figma/r/200_480.png')),
      gP(72, 576, 274, 20, gText(real ? newProductErrorsSummary(errs) : '3 champs à corriger avant de continuer. Votre brouillon est enregistré.', 12, Color(0xFFB42318), weight: 500)),
      gP(24, 770, 342, 52, gBox(color: Color(0xFF111015), radii: [26, 26, 26, 26]), tap: () => real ? gBack(context) : gOpen(context, '58')),
      gP(158.5, 788, 73, 19, gText('Continuer', 15, Color(0xFFFFFFFF), weight: 600)),
    ]);
  }
}

/// Valeur saisie sur 58, affichée sans être modifiable (la correction se fait sur 58).
Widget _ro(String v) => DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE6E1EE), width: 1.5)),
      child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 16), child: gText(v, 14, const Color(0xFF111015), weight: 500))),
    );
