import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/router/paths.dart';

import 'fx.dart';

const ink = Color(0xFF111015);
const grey = Color(0xFF66636E);
const _c = 'assets/figma/common';

/// Éléments communs à tous les écrans mobiles de la maquette : halos, heure, îlot, logo, bouton retour.
List<Widget> fxChrome({VoidCallback? onBack, bool back = true}) => [
      fxImgBleed('$_c/halo_a.svg', 200, 140, 300, 300, 0.4),
      fxImgBleed('$_c/halo_b.svg', -110, 580, 300, 300, 0.4),
      fxText('9:41', 30, 14, 14, ink, weight: 600),
      fxBox(140, 10, 110, 30, color: Colors.black, radius: 15),
      fxImg('$_c/logo.png', 22, 38, 34, 32, fit: BoxFit.contain),
      if (back) ...[
        fxImg('$_c/bouton_rond.svg', 30, 70, 44, 44),
        fxImg('$_c/icon_back.svg', 42.5, 82.5, 19, 19),
        if (onBack != null) fxTap(30, 70, 44, 44, onBack),
      ],
    ];

/// Titre centré + sous-titre des écrans « Détail ».
List<Widget> fxHeader(String title, String sub, {double titleX = 0, double subX = 0}) => [
      fxText(title, 0, 76, 17, ink, weight: 500, w: 390, align: TextAlign.center),
      fxText(sub, 0, 100, 12, grey, w: 390, align: TextAlign.center),
    ];

/// Ouvre un autre écran du manifeste (même navigation que le prototype Figma).
void fxOpen(BuildContext context, String id) => GoRouter.of(context).push(screenPath(id));
