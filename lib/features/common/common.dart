import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';

export 'package:flutter/material.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';

export '../../core/router/paths.dart';
export '../../core/theme/app_colors.dart';
export '../../core/theme/app_icons.dart';
export '../../core/theme/app_theme.dart';
export '../../core/utils/money.dart';
export '../../core/widgets/widgets.dart';
export '../../data/demo/catalog_demo.dart' show Photos;
export '../../data/models/models.dart';
export '../../data/repositories/repositories.dart';

extension ScreenNav on BuildContext {
  /// Ouvre l'écran du manifeste `id` par-dessus l'écran courant.
  void openScreen(String id) => push(screenPath(id));

  /// Remplace la pile par l'écran `id`.
  void goScreen(String id) => go(screenPath(id));

  /// Message bref (actions simulées en démonstration).
  void toast(String message) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

Color toneToColor(Tone t) => switch (t) {
  Tone.success => AppColors.success,
  Tone.warning => AppColors.warning,
  Tone.error => AppColors.error,
  Tone.accent => AppColors.accent,
  Tone.neutral => AppColors.textSecondary,
};

BadgeTone toneToBadge(Tone t) => switch (t) {
  Tone.success => BadgeTone.success,
  Tone.warning => BadgeTone.warning,
  Tone.error => BadgeTone.error,
  Tone.accent => BadgeTone.accent,
  Tone.neutral => BadgeTone.neutral,
};

KV kvOf(LabeledValue v) => KV(v.label, v.value, color: v.tone == null ? null : toneToColor(v.tone!));

/// Gabarit des écrans mobiles secondaires : en-tête retour + bouton d'action en bas, sans menu.
class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.action,
    this.onAction,
    this.secondaryAction,
    this.onSecondaryAction,
    this.headerActions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final String? action;
  final VoidCallback? onAction;
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    Widget? bottom;
    if (action != null || secondaryAction != null) {
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action != null) PrimaryButton(label: action!, onPressed: onAction ?? () {}),
          if (secondaryAction != null) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: secondaryAction!,
              variant: ButtonVariant.secondary,
              onPressed: onSecondaryAction ?? () {},
            ),
          ],
        ],
      );
    }
    return AppScaffold(
      showNav: false,
      header: ScreenHeader(title: title, subtitle: subtitle, actions: headerActions),
      bottomBar: bottom,
      bottomBarHeight: action != null && secondaryAction != null ? 148 : 84,
      children: children,
    );
  }
}

/// Espacement vertical standard entre blocs.
const gap8 = SizedBox(height: 8);
const gap12 = SizedBox(height: 12);
const gap16 = SizedBox(height: 16);
const gap24 = SizedBox(height: 24);
