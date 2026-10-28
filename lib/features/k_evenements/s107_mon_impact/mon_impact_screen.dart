import '../k_widgets.dart';

/// 107 · Mon impact (CO₂ évité, achats locaux, objectifs).
class MonImpactScreen extends ConsumerWidget {
  const MonImpactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionKDataProvider);
    return CPage(
      title: 'Mon impact',
      tab: NavTab.profile,
      children: [
        GKpiGrid([
          for (final k in d.impactKpis) GKpi(k.$1, k.$2, k.$3, delta: k.$4.isEmpty ? null : k.$4),
        ], valueSize: 21),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Impact par mois (kg CO₂)', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text('6 mois', style: AppText.small),
                ],
              ),
              gap16,
              GBars(bars: [for (final b in d.impactBars) GBar(b.$1, b.$2)], height: 122),
            ],
          ),
        ),
        gap12,
        IProgressCard([
          ('Objectif de l’année', '${d.yearGoal.$1} / ${d.yearGoal.$2} kg', d.yearGoal.$1 / d.yearGoal.$2, 0xFF1F9D6B),
          ('Soutien aux étudiants', '${d.studentSupport}%', d.studentSupport / 100, 0xFF1E4A80),
        ]),
      ],
    );
  }
}
