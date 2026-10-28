import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Pastille arrondie (filtre, catégorie, étiquette sélectionnable).
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    final pill = Container(
      height: dense ? 32 : 40,
      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
      decoration: ShapeDecoration(
        color: selected ? AppColors.ink : AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.ink : AppColors.cardBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: (dense ? AppText.label : AppText.body).copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}

/// Rangée horizontale défilante de pastilles sélectionnables.
class PillBar extends StatelessWidget {
  const PillBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Pill(
              labels[i],
              selected: i == selected,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

enum BadgeTone { neutral, success, warning, error, accent, dark }

/// Badge d'état (« Payée », « En attente », « Compatibilité 96 % »…).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final String? icon;

  static (Color, Color) colors(BadgeTone tone) => switch (tone) {
    BadgeTone.neutral => (AppColors.field, AppColors.ink),
    BadgeTone.success => (AppColors.successSoft, AppColors.success),
    BadgeTone.warning => (AppColors.warningSoft, AppColors.warning),
    BadgeTone.error => (AppColors.errorSoft, AppColors.error),
    BadgeTone.accent => (AppColors.accentSoft, AppColors.accent),
    BadgeTone.dark => (AppColors.ink, Colors.white),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppText.label.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
