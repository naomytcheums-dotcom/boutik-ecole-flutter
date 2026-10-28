import '../l_widgets.dart';

/// 215 · Fiche d’un département (Génie informatique).
class FicheDepartementScreen extends ConsumerWidget {
  const FicheDepartementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionLDataProvider);
    return GPage(
      title: d.gi.title,
      trailing: HeaderIcon(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('212')),
      actions: [PrimaryButton(label: 'Déposer un brief au département', height: 54, onPressed: () => context.openScreen('191'))],
      children: [
        IHeroBanner(image: d.gi.image, title: d.gi.banner, subtitle: d.gi.detail),
        gap16,
        ICounters(d.giCounters),
        const GSectionTitle('Ce que nous proposons'),
        GListCard(
          children: [
            for (final o in d.giOffers)
              IIconRow(
                icon: o.$3,
                title: o.$1,
                subtitle: o.$2,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('34'),
              ),
          ],
        ),
        const GSectionTitle('Étudiants à la une'),
        GListCard(
          children: [
            for (final s in d.giStudents)
              GThumbRow(
                image: s.$3,
                title: s.$1,
                subtitle: s.$2,
                trailing: KBadgeButton('Voir', Tone.accent, onTap: () => context.openScreen('10')),
                onTap: () => context.openScreen('10'),
              ),
          ],
        ),
      ],
    );
  }
}
