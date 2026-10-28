import '../w_widgets.dart';

/// 186 · Accessibilité : taille du texte, contraste, animations, lecteur d'écran (appliqués à toute l'application).
class AccessibiliteScreen extends ConsumerWidget {
  const AccessibiliteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionWDataProvider);
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    final sizeIndex = d.textSizes.indexWhere((x) => (x.$2 - s.textScale).abs() < .01);
    const large = 1.2;
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const CHeader('Accessibilité'),
      children: [
        GTabs(
          labels: [for (final x in d.textSizes) x.$1],
          selected: sizeIndex < 0 ? 1 : sizeIndex,
          onSelected: (i) => n.setTextScale(d.textSizes[i].$2),
        ),
        gap16,
        QCard(
          children: [
            ToggleRow(
              title: 'Texte agrandi',
              subtitle: 'Taille 18 px et plus',
              value: s.textScale >= large - .01,
              onChanged: (v) => n.setTextScale(v ? large : 1.0),
            ),
            ToggleRow(
              title: 'Contraste renforcé',
              subtitle: 'Textes plus lisibles',
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
              title: 'Lecteur d’écran',
              subtitle: 'Étiquettes vocales',
              value: s.screenReader,
              onChanged: n.setScreenReader,
            ),
          ],
        ),
        gap16,
        KeyValueCard(title: 'Normes appliquées', rows: [for (final x in d.norms) KV(x.$1, x.$2)]),
        gap16,
        PrimaryButton(
          label: 'Aperçu avec texte agrandi',
          icon: AppIcons.eye,
          height: 50,
          variant: ButtonVariant.secondary,
          onPressed: () {
            if (s.textScale < large) n.setTextScale(large);
            context.toast('Texte agrandi appliqué à toute l’application.');
          },
        ),
      ],
    );
  }
}
