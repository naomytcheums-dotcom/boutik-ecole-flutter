import '../y_widgets.dart';

/// 202 · Pack Lancement de marque : offre multi-filières clé en main.
class PackLancementScreen extends ConsumerWidget {
  const PackLancementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionYDataProvider);
    final (title, subtitle) = d.packHero;
    return GPage(
      title: 'Pack Lancement de marque',
      actions: [
        YOutlineButton('Personnaliser', onPressed: () => context.openScreen('191')),
        PrimaryButton(
          label: 'Commander le pack',
          onPressed: () => context.toast('Pack commandé : ${fcfa(d.packPrice)} en séquestre par jalons.'),
        ),
      ],
      children: [
        YHero(image: Photos.foodSpread, title: title, subtitle: subtitle, height: 180),
        const YTitle('Ce qui est inclus', top: 12, bottom: 16),
        YCard(
          children: [
            for (final (icon, name, detail, track) in d.packItems)
              YIconRow(icon: icon, title: name, subtitle: detail, trailing: YBadge(track, Tone.accent)),
          ],
        ),
        const SizedBox(height: 14),
        YKvCard(rows: [('Prix du pack', fcfa(d.packPrice)), ('Économie', d.packSaving), ('Délai', d.packDelay)]),
        const SizedBox(height: 14),
        const YNote(
          'L’administrateur coordonne les filières et vous suivez tout dans un seul dossier.',
          icon: AppIcons.sparkle,
        ),
      ],
    );
  }
}
