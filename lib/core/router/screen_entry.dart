import 'package:flutter/widgets.dart';

/// Format d'écran de la maquette.
enum ScreenFormat { mobile, web, tablet, kiosk }

/// Un écran du manifeste (docs/SCREENS_MANIFEST.md) et son constructeur.
class ScreenEntry {
  const ScreenEntry(
    this.id,
    this.title,
    this.builder, {
    required this.section,
    required this.node,
    this.format = ScreenFormat.mobile,
  });

  /// Numéro du manifeste (`03`, `18b`, `146-1`…).
  final String id;
  final String title;
  final WidgetBuilder builder;
  final String section;

  /// nodeId Figma (référence visuelle).
  final String node;
  final ScreenFormat format;
}
