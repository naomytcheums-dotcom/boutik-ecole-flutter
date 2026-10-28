import '../j_widgets.dart';

/// 99 · Historique des besoins, devis, projets et stages.
class HistoriqueScreen extends ConsumerStatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  ConsumerState<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends ConsumerState<HistoriqueScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    final items = d.history.where((h) => h.category == d.historyTabs[_tab]).toList();
    return JRootPage(
      title: 'Historique',
      children: [
        HChips(labels: d.historyTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          HEmpty('Aucun élément « ${d.historyTabs[_tab]} » dans l’historique.')
        else
          JItemList(items, onTap: (h) => context.toast('${h.title} · ${h.badge}')),
        gap16,
        Row(
          children: [
            for (final (i, k) in d.historyKpis.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: SizedBox(height: 92, child: GKpiCard(k, valueSize: 23))),
            ],
          ],
        ),
      ],
    );
  }
}
