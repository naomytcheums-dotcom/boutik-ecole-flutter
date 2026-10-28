import '../../core/state/app_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/common.dart';

export '../../core/state/app_settings.dart';
export '../../l10n/gen/app_localizations.dart';
export '../common/common.dart';
export '../../data/demo/section_aa_demo.dart';

const kioskStarColor = Color(0xFFF2A516);

/// Page de borne : langue partagée avec l'application, textes traduits (FR/EN), barre basse facultative.
class AAPage extends ConsumerWidget {
  const AAPage({super.key, required this.builder, this.navIndex});

  final Widget Function(BuildContext context, AppLocalizations l, String lang) builder;

  /// Onglet actif de la barre basse (0 Accueil, 1 Explorer, 2 Mon QR, 3 Aide) ; null = pas de barre.
  final int? navIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    return Localizations.override(
      context: context,
      locale: Locale(lang),
      child: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          return KioskScaffold(
            languageCode: lang,
            onLanguage: (code) => ref.read(appSettingsProvider.notifier).setLocale(Locale(code)),
            bottomBar: navIndex == null ? null : KioskNavBar(selected: navIndex!, l: l),
            body: builder(context, l, lang),
          );
        },
      ),
    );
  }
}

/// Barre basse de la borne : Accueil, Explorer, Mon QR, Aide.
class KioskNavBar extends StatelessWidget {
  const KioskNavBar({super.key, required this.selected, required this.l});

  final int selected;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppIcons.house, l.kioskNavHome, () => context.goScreen('206')),
      (AppIcons.search, l.kioskNavExplore, () => context.goScreen('207')),
      (AppIcons.qrCode, l.kioskNavMyQr, () => context.openScreen('209')),
      (AppIcons.circleHelp, l.kioskNavHelp, () => context.toast(l.kioskHelpMessage)),
    ];
    return Container(
      height: 124,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(62),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: items[i].$2,
                excludeSemantics: true,
                child: Material(
                  color: i == selected ? AppColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(48),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(48),
                    onTap: items[i].$3,
                    child: SizedBox(
                      height: 96,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppIcon(items[i].$1, size: 32, color: i == selected ? Colors.white : AppColors.ink),
                          const SizedBox(height: 8),
                          Text(
                            items[i].$2,
                            style: AppText.body.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: i == selected ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille de filtre de la borne (hauteur 64).
class KioskPill extends StatelessWidget {
  const KioskPill({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.ink : Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 44),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppText.body.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cinq étoiles de note.
class KioskStars extends StatelessWidget {
  const KioskStars({super.key, this.size = 18, this.gap = 4});

  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(width: gap),
          AppIcon(AppIcons.starFilled, size: size, color: kioskStarColor),
        ],
      ],
    ),
  );
}

/// Badge « Boosté » posé sur une photo (pictogramme + mot court, fond blanc).
class KioskBoostBadge extends StatelessWidget {
  const KioskBoostBadge(this.label, {super.key, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: large ? 48 : 40,
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.zap, size: large ? 22 : 18, color: AppColors.ink),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.body.copyWith(fontSize: large ? 18 : 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
