import '../q_widgets.dart';

/// 149 · Langue et affichage (préférences appliquées à toute l’application).
class LangueAffichageScreen extends ConsumerWidget {
  const LangueAffichageScreen({super.key});

  static const _sizes = [('Petit', 0.9), ('Normal', 1.0), ('Grand', 1.2)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    final en = s.locale.languageCode == 'en';
    final size = _sizes.indexWhere((x) => (x.$2 - s.textScale).abs() < .01);
    Widget badge(String label) => const GBadge('Actif', Tone.success);
    return CPage(
      title: 'Langue et affichage',
      tab: NavTab.profile,
      children: [
        Text('Langue', style: AppText.bodyStrong),
        gap8,
        QCard(
          children: [
            QRow(
              icon: AppIcons.languages,
              title: 'Français',
              subtitle: 'Langue par défaut',
              trailing: en ? null : badge('Actif'),
              onTap: () => n.setLocale(const Locale('fr')),
            ),
            QRow(
              icon: AppIcons.globe,
              title: 'English',
              subtitle: 'English (Cameroon)',
              trailing: en ? badge('Actif') : const AppIcon(AppIcons.chevronRight, size: 18),
              onTap: () {
                n.setLocale(const Locale('en'));
                context.openScreen('185');
              },
            ),
          ],
        ),
        gap16,
        Text('Accessibilité', style: AppText.bodyStrong),
        gap8,
        QCard(
          children: [
            ToggleRow(
              title: 'Texte agrandi',
              subtitle: 'Augmenter la taille des textes',
              value: s.textScale > 1.05,
              onChanged: (v) => n.setTextScale(v ? 1.2 : 1.0),
            ),
            ToggleRow(
              title: 'Contraste renforcé',
              subtitle: 'Améliorer la lisibilité',
              value: s.highContrast,
              onChanged: n.setHighContrast,
            ),
            ToggleRow(
              title: 'Réduire les animations',
              subtitle: 'Limiter les mouvements',
              value: s.reduceMotion,
              onChanged: n.setReduceMotion,
            ),
            ToggleRow(
              title: 'Lecture vocale',
              subtitle: 'Compatible lecteur d’écran',
              value: s.screenReader,
              onChanged: n.setScreenReader,
            ),
          ],
        ),
        gap16,
        Text('Taille du texte', style: AppText.bodyStrong),
        gap8,
        GTabs(
          labels: [for (final x in _sizes) x.$1],
          selected: size < 0 ? 1 : size,
          onSelected: (i) => n.setTextScale(_sizes[i].$2),
        ),
        gap8,
        TextLink('Plus d’options d’accessibilité →', onTap: () => context.openScreen('186')),
      ],
    );
  }
}
