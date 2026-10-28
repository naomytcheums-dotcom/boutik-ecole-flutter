import '../j_widgets.dart';

/// 88 · Espace entreprise (tableau de bord du partenaire).
class EspaceEntrepriseScreen extends ConsumerWidget {
  const EspaceEntrepriseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionJDataProvider);
    return JRootPage(
      title: 'Espace entreprise',
      subtitle: '${d.companyName} · ${d.companyStatus}',
      action: HeaderIcon(AppIcons.bell, label: 'Notifications', onTap: () => context.openScreen('50')),
      children: [
        GKpiGrid(d.dashboardKpis, valueSize: 23),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Propositions reçues par mois',
                      style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(d.proposalsPeriod, style: AppText.small),
                ],
              ),
              const SizedBox(height: 20),
              JBars(bars: d.proposalsByMonth, unit: 'propositions'),
            ],
          ),
        ),
        JSectionTitle('Opportunités du moment', trailing: TextLink('Voir tout →', onTap: () => context.openScreen('96'))),
        JItemList(d.opportunities),
      ],
    );
  }
}
