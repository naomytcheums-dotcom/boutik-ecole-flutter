import '../g_widgets.dart';

/// 57 · Tableau de bord vendeur.
class TableauDeBordVendeurScreen extends ConsumerWidget {
  const TableauDeBordVendeurScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionGDataProvider);
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: GRootHeader(
        'Tableau de bord',
        subtitle: 'Bonjour ${d.sellerName}, voici votre activité',
        action: HeaderIcon(AppIcons.bell, label: 'Notifications', onTap: () => context.openScreen('50')),
      ),
      children: [
        GKpiGrid(d.dashboardKpis, valueSize: 23),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Ventes mensuelles (FCFA)', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600))),
                  Text(d.monthlySalesPeriod, style: AppText.small),
                ],
              ),
              gap16,
              GBars(bars: d.monthlySales, height: 122),
            ],
          ),
        ),
        GSectionTitle(
          'Commandes à préparer',
          trailing: TextLink('Voir tout →', onTap: () => context.openScreen('63')),
        ),
        GListCard(
          children: [
            for (final o in d.dashboardOrders)
              GThumbRow(
                image: o.image,
                title: '${o.ref} · ${o.product}',
                subtitle: '${o.mode} · ${fcfa(o.amount)}',
                trailing: GBadge(orderStatus(o.status).$1, orderStatus(o.status).$2),
                onTap: () => context.openScreen('64'),
              ),
          ],
        ),
      ],
    );
  }
}