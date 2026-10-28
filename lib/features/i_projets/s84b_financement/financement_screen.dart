import '../i_widgets.dart';

/// 84b · Financement d’un projet (page de campagne).
class FinancementScreen extends ConsumerWidget {
  const FinancementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    final pct = d.collected * 100 ~/ d.goal;
    return GPage(
      title: 'Financement',
      trailing: HeaderIcon(AppIcons.share, label: 'Partager', onTap: () => context.openScreen('212')),
      actions: [PrimaryButton(label: 'Contribuer', height: 54, onPressed: () => context.openScreen('08'))],
      children: [
        IHeroBanner(image: d.fundingImage, title: d.fundingTitle, subtitle: d.fundingDetail),
        gap12,
        GKpiGrid([
          GKpi('Collecté', fcfa(d.collected), ''),
          GKpi('Objectif', fcfa(d.goal), ''),
        ], valueSize: 16),
        gap12,
        IProgressCard([('$pct % de l’objectif atteint', '$pct%', pct / 100, 0xFF6A4DF0)]),
        gap12,
        ICounters([('${d.contributors}', 'Contributeurs'), ('${d.daysLeft}', 'Jours restants'), ('$pct %', 'Financé')]),
        const GSectionTitle('Contreparties'),
        GListCard(
          children: [
            for (final r in d.rewards)
              IIconRow(
                icon: r.$4,
                title: r.$1,
                subtitle: r.$2,
                trailing: Text(fcfa(r.$3, withUnit: false), style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                onTap: () => context.openScreen('08'),
              ),
          ],
        ),
      ],
    );
  }
}
