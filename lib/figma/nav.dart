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

/// Visite de présentation lancée par « Commencer » (02) : acheteur 176 → étudiant 175 → entreprise 177 → accueil 03.
/// Hors visite, « Continuer » garde la destination propre à chaque rôle.
const kVisite = ['176', '175', '177'];

void gVisiteStart(BuildContext context) => GoRouter.of(context).push('${screenPath(kVisite.first)}?visite=1');

void gVisiteNext(BuildContext context, String id, String horsVisite) {
  var enVisite = false;
  try {
    enVisite = GoRouterState.of(context).uri.queryParameters.containsKey('visite');
  } catch (_) {}
  if (!enVisite) return gTab(context, horsVisite);
  final i = kVisite.indexOf(id);
  if (i < 0 || i == kVisite.length - 1) return gTab(context, '03');
  GoRouter.of(context).push('${screenPath(kVisite[i + 1])}?visite=${i + 2}');
}
