import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Gabarit borne tactile 720×1280 (écrans 206–210) : en-tête logo + sélecteur FR/EN,
/// contenu, barre basse facultative. Le canevas 720×1280 est mis à l'échelle de l'écran physique.
class KioskScaffold extends StatelessWidget {
  const KioskScaffold({
    super.key,
    required this.body,
    required this.languageCode,
    required this.onLanguage,
    this.bottomBar,
    this.logo = 'assets/images/ai_logo_be.png',
  });

  final Widget body;
  final Widget? bottomBar;
  final String languageCode;
  final ValueChanged<String> onLanguage;
  final String logo;

  static const designSize = Size(720, 1280);
  static const padding = 48.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              child: SizedBox.fromSize(
                size: designSize,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(padding, 44, 56, 0),
                        child: _KioskHeader(logo: logo, languageCode: languageCode, onLanguage: onLanguage),
                      ),
                      Expanded(child: body),
                      if (bottomBar != null)
                        Padding(padding: const EdgeInsets.fromLTRB(padding, 0, padding, 44), child: bottomBar),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KioskHeader extends StatelessWidget {
  const _KioskHeader({required this.logo, required this.languageCode, required this.onLanguage});

  final String logo;
  final String languageCode;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) {
    Widget lang(String code) {
      final selected = languageCode == code;
      return Semantics(
        button: true,
        selected: selected,
        label: code == 'fr' ? 'Français' : 'English',
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.ink : Colors.white,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onLanguage(code),
            child: SizedBox(
              width: 68,
              height: 48,
              child: Center(
                child: Text(
                  code.toUpperCase(),
                  style: AppText.bodyStrong.copyWith(fontSize: 18, color: selected ? Colors.white : AppColors.ink),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Semantics(
            label: 'Boutik-École',
            image: true,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(logo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 20),
          ExcludeSemantics(
            child: Text('Boutik-École', style: AppText.h2.copyWith(fontSize: 28, fontWeight: FontWeight.w500)),
          ),
          const Spacer(),
          lang('fr'),
          const SizedBox(width: 8),
          lang('en'),
        ],
      ),
    );
  }
}
