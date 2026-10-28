import '../g_widgets.dart';

/// 67 · Statistiques (période, vues, conversion, ventes, meilleures annonces).
class StatistiquesScreen extends ConsumerStatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  ConsumerState<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends ConsumerState<StatistiquesScreen> {
  late int _period = ref.read(sectionGDataProvider).statsDefaultPeriod;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    final p = d.statsPeriods[_period];
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const GRootHeader('Statistiques'),
      children: [
        GTabs(labels: [for (final s in d.statsPeriods) s.label], selected: _period, onSelected: (i) => setState(() => _period = i)),
        gap8,
        GKpiGrid(p.kpis, valueSize: 21),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text(_period == 2 ? 'Ventes par mois' : (_period == 0 ? 'Ventes par jour' : 'Ventes par semaine'), style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600))),
                  Text('FCFA', style: AppText.small),
                ],
              ),
              gap12,
              GBars(bars: p.bars, height: 128),
            ],
          ),
        ),
        const GSectionTitle('Annonces les plus performantes'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            children: [
              for (final (i, a) in d.performers.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(a.title, style: AppText.body.copyWith(fontSize: 13.5))),
                    Text('${a.percent}%', style: AppText.small.copyWith(color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(value: a.percent / 100, color: Color(a.color), height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}