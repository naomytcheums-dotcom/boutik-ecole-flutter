import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Carte blanche à bord #EEECE8.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = AppColors.card,
    this.radius = AppSizes.radiusCard,
    this.borderColor = AppColors.cardBorder,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );
    final content = Padding(padding: padding, child: child);
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      container: true,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Carte sombre (encre) pour les appels à l'action forts.
class DarkCard extends StatelessWidget {
  const DarkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.ink,
    borderColor: null,
    padding: padding,
    onTap: onTap,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: child,
    ),
  );
}

/// Ligne de liste : icône à gauche, titre/sous-titre, chevron ou valeur à droite.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final String? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.ink;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)]
                else if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: danger ? AppColors.errorSoft : AppColors.field,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(icon!, size: 20, color: color),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong.copyWith(color: color)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppText.small),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                if (showChevron && onTap != null) ...[
                  const SizedBox(width: 8),
                  const AppIcon(
                    'assets/icons/chevron-right.svg',
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur chiffré (tableaux de bord) : libellé, valeur, variation.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaTone = DeltaTone.positive,
    this.web = false,
  });

  final String label;
  final String value;
  final String? delta;
  final DeltaTone deltaTone;
  final bool web;

  @override
  Widget build(BuildContext context) {
    TextStyle s(TextStyle t) => web ? AppText.web(t) : t;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: s(AppText.small), maxLines: 2),
          const SizedBox(height: 8),
          Text(value, style: s(AppText.amount)),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: s(AppText.small).copyWith(
                color: switch (deltaTone) {
                  DeltaTone.positive => AppColors.success,
                  DeltaTone.negative => AppColors.error,
                  DeltaTone.neutral => AppColors.textSecondary,
                },
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum DeltaTone { positive, negative, neutral }

/// Titre de section avec lien « Voir tout ».
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.h3, semanticsLabel: title)),
          if (action != null)
            Semantics(
              button: true,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action!,
                        style: AppText.small.copyWith(color: AppColors.accent),
                      ),
                      const SizedBox(width: 18),
                      const AppIcon('assets/icons/arrow-right.svg', size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Avatar rond (photo ou initiales).
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.image, this.initials, this.size = 44, this.ring = false});

  final String? image;
  final String? initials;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accentSoft,
        border: ring ? Border.all(color: Colors.white, width: 2) : null,
        image: image == null
            ? null
            : DecorationImage(image: AssetImage(image!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image == null
          ? Text(
              initials ?? '',
              style: AppText.label.copyWith(
                color: AppColors.accent,
                fontSize: size * 0.34,
              ),
            )
          : null,
    );
  }
}
