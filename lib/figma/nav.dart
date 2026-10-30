import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router/paths.dart';

/// Ouvre un autre écran du manifeste (liens du prototype Figma).
void gOpen(BuildContext context, String id) => GoRouter.of(context).push(screenPath(id));

/// Onglet du menu principal : remplace la pile (pas d'empilement d'écrans) pour que « retour » reste cohérent.
void gTab(BuildContext context, String id) => GoRouter.of(context).go(screenPath(id));

/// Bouton retour : revient à l'écran précédent, sinon à l'accueil.
void gBack(BuildContext context) {
  final r = GoRouter.of(context);
  if (r.canPop()) {
    r.pop();
  } else {
    r.go(screenPath('03'));
  }
}

/// Ouvre « Mes rubriques » : toutes les sections de l'application ouvertes au rôle connecté.
void gEspace(BuildContext context) => GoRouter.of(context).push('/espace');
