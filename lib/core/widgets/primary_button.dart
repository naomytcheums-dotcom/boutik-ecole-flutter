import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

enum ButtonVariant { primary, secondary, ghost, danger, accent }

/// Bouton principal : noir, arrondi, hauteur 52.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = ButtonVariant.primary,
    this.expand = true,
    this.height = AppSizes.buttonHeight,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final String? trailingIcon;
  final ButtonVariant variant;
  final bool expand;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      ButtonVariant.primary => (AppColors.ink, Colors.white, null),
      ButtonVariant.secondary => (
        const Color(0xCCFFFAF5),
        AppColors.ink,
        Colors.white,
      ),
      ButtonVariant.ghost => (Colors.transparent, AppColors.ink, null),
      ButtonVariant.danger => (AppColors.error, Colors.white, null),
      ButtonVariant.accent => (AppColors.accent, Colors.white, null),
    };
    final disabled = onPressed == null && !loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null) ...[
          AppIcon(icon!, size: 20, color: fg),
          const SizedBox(width: 10),
        ],
        if (!loading)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: AppText.button.copyWith(color: fg)),
            ),
          ),
        if (trailingIcon != null && !loading) ...[
          const SizedBox(width: 10),
          AppIcon(trailingIcon!, size: 20, color: fg),
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Material(
          color: bg,
          shape: StadiumBorder(
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: loading ? null : onPressed,
            child: Container(
              height: height < AppSizes.minTouch ? AppSizes.minTouch : height,
              padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 22),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lien texte d'accent (« Voir tout »), zone tactile 44 px.
class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: color ?? AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
