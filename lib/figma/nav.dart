import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router/paths.dart';

/// Ouvre un autre écran du manifeste (liens du prototype Figma).
void gOpen(BuildContext context, String id) => GoRouter.of(context).push(screenPath(id));

/// Bouton retour.
void gBack(BuildContext context) {
  final r = GoRouter.of(context);
  if (r.canPop()) {
    r.pop();
  }
}
