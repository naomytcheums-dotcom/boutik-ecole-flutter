import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_scaffold.dart';

/// Gabarit borne tactile 720×1280 : grandes zones tactiles, pas de menu bas,
/// contenu centré et mis à l'échelle si l'écran physique est plus grand.
class KioskScaffold extends StatelessWidget {
  const KioskScaffold({super.key, required this.children, this.footer, this.title, this.subtitle, this.dark = false});

  final List<Widget> children;
  final Widget? footer;
  final String? title;
  final String? subtitle;
  final bool dark;

  static const designSize = Size(720, 1280);

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Scaffold(
      backgroundColor: dark ? AppColors.ink : AppColors.bgTop,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: dark ? null : AppColors.backgroundGradient),
        child: SafeArea(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 40, withName: true),
                      const Spacer(),
                      Text('Borne IUT de Douala', style: AppText.secondary.copyWith(color: dark ? Colors.white70 : null)),
                    ],
                  ),
                  if (title != null) ...[
                    const SizedBox(height: 40),
                    Semantics(header: true, child: Text(title!, style: AppText.display.copyWith(fontSize: 44, color: fg))),
                  ],
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(subtitle!, style: AppText.body.copyWith(fontSize: 22, color: dark ? Colors.white70 : AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 28),
                  Expanded(child: ListView(children: children)),
                  if (footer != null) ...[const SizedBox(height: 16), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
