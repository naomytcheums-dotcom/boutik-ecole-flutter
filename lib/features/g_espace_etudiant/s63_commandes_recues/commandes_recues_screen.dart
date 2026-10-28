import '../g_widgets.dart';

/// 63 · Commandes reçues (onglets par état).
class CommandesRecuesScreen extends ConsumerStatefulWidget {
  const CommandesRecuesScreen({super.key});

  @override
  ConsumerState<CommandesRecuesScreen> createState() => _CommandesRecuesScreenState();
}

class _CommandesRecuesScreenState extends ConsumerState<CommandesRecuesScreen> {
  int _tab = 0;

  static const _groups = [
    {GOrderStatus.toPrepare, GOrderStatus.newOrder, GOrderStatus.inProgress},
    {GOrderStatus.inProgress},
    {GOrderStatus.ready},
    {GOrderStatus.delivered},
  ];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    final toPrepare = d.receivedOrders.where((o) => _groups[0].contains(o.status)).length;
    final items = d.receivedOrders.where((o) => _groups[_tab].contains(o.status)).toList();
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const GRootHeader('Commandes reçues'),
      children: [
        GTabs(
          labels: ['${d.orderTabs[0]} ($toPrepare)', ...d.orderTabs.skip(1)],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        gap8,
        if (items.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Text('Aucune commande.', textAlign: TextAlign.center, style: AppText.secondary))
        else
          GListCard(
            children: [
              for (final o in items)
                GThumbRow(
                  image: o.image,
                  title: o.ref,
                  subtitle: '${o.product} · ${o.buyer} · ${fcfa(o.amount)}',
                  trailing: GBadge(orderStatus(o.status).$1, orderStatus(o.status).$2),
                  onTap: () => context.openScreen('64'),
                ),
            ],
          ),
        gap16,
        if (_tab == 0)
          GNote('$toPrepare commandes doivent être préparées avant ${d.prepareDeadline}.', icon: AppIcons.clock),
      ],
    );
  }
}