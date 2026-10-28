import '../t_widgets.dart';

/// 166 · Résultats du concours.
class ResultatsConcoursScreen extends ConsumerWidget {
  const ResultatsConcoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionTDataProvider);
    return GPage(
      title: 'Résultats',
      actions: [PrimaryButton(label: 'Voir le certificat', height: 54, onPressed: () => context.openScreen('173'))],
      children: [
        IHeroBanner(image: d.winner.$3, title: d.winner.$1, subtitle: d.winner.$2, height: 176),
        const GSectionTitle('Classement'),
        QCard(
          children: [
            for (final r in d.ranking)
              QRow(icon: AppIcons.trophy, title: r.$1, subtitle: r.$2, trailing: GBadge(r.$3, Tone.success)),
          ],
        ),
        gap12,
        KeyValueCard(title: 'Récompenses', rowGap: 14, rows: [for (final r in d.rewards) KV(r.$1, r.$2)]),
      ],
    );
  }
}
