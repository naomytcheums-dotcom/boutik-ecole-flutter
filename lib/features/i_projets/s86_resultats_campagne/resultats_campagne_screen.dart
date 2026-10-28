import '../i_widgets.dart';

/// 86 · Résultats de campagne.
class ResultatsCampagneScreen extends ConsumerWidget {
  const ResultatsCampagneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionIDataProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const CHeader('Résultats de campagne'),
      children: [
        GKpiGrid([
          GKpi('Contributions', '${d.contributors}', AppIcons.users),
          GKpi('Montant moyen', fcfa(d.averageContribution), AppIcons.wallet),
          GKpi('Taux de conversion', d.conversion, AppIcons.percent, delta: d.conversionDelta),
          GKpi('Partages', '${d.shares}', AppIcons.share, delta: d.sharesDelta),
        ], valueSize: 21),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Collecte cumulée (k FCFA)', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text(d.collectPeriod, style: AppText.small),
                ],
              ),
              gap12,
              GLineChart(values: d.cumulative, height: 120),
            ],
          ),
        ),
        const GSectionTitle('Derniers contributeurs'),
        GListCard(
          children: [
            for (final c in d.lastContributors)
              GThumbRow(
                image: c.avatar,
                title: c.name,
                subtitle: c.detail,
                trailing: Text(
                  fcfa(int.parse(c.role!), withUnit: false),
                  style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
