import '../g_widgets.dart';

/// 62 · Stocks (indicateurs, articles à surveiller, alertes).
class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen> {
  bool _low = true;
  bool _out = true;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const Padding(padding: EdgeInsets.only(top: 22), child: TitleHeader('Stocks')),
      children: [
        GKpiGrid(d.stockKpis, valueSize: 21),
        const GSectionTitle('Articles à surveiller'),
        GListCard(
          children: [
            for (final s in d.watchedStock)
              GThumbRow(
                image: s.image,
                title: s.title,
                subtitle: 'Seuil : ${s.threshold} · Restant : ${s.remaining}',
                trailing: GBadge('${s.remaining}', s.remaining == 0 ? Tone.error : (s.remaining < s.threshold ? Tone.accent : Tone.success)),
                onTap: () => context.openScreen('60'),
              ),
          ],
        ),
        const GSectionTitle('Alertes'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Column(
            children: [
              ToggleRow(title: 'Alerte stock bas', subtitle: 'Notifier sous le seuil', value: _low, onChanged: (v) => setState(() => _low = v)),
              const Divider(height: 1),
              ToggleRow(title: 'Alerte de rupture', subtitle: 'Notifier à 0 unité', value: _out, onChanged: (v) => setState(() => _out = v)),
            ],
          ),
        ),
        gap16,
        TextFieldWithError(label: 'Seuil par défaut', initialValue: '${d.defaultThreshold} unités', prefixIcon: AppIcons.package),
      ],
    );
  }
}