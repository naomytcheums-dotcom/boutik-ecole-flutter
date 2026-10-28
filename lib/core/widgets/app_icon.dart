import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Icône du jeu Boutik-École (SVG dans assets/icons). Jamais d'icônes Material.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.asset, {
    super.key,
    this.size = 22,
    this.color = AppColors.ink,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// Bouton icône rond (44 px minimum), fond blanc par défaut.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.size = 44,
    this.background = AppColors.card,
    this.foreground = AppColors.ink,
    this.bordered = true,
    this.badge = false,
    this.elevated = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color background;
  final Color foreground;
  final bool bordered;
  final bool badge;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: size < 44 ? 44 : size,
        height: size < 44 ? 44 : size,
        child: Center(
          child: Material(
            color: background,
            elevation: elevated ? 4 : 0,
            shadowColor: const Color(0x55B9A5D8),
            shape: CircleBorder(
              side: bordered
                  ? const BorderSide(color: AppColors.cardBorder)
                  : BorderSide.none,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AppIcon(icon, size: size * 0.48, color: foreground),
                    if (badge)
                      Positioned(
                        top: size * 0.2,
                        right: size * 0.22,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
