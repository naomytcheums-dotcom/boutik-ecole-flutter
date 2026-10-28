import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 269 · Innovation Radar (compétences demandées, besoins du marché, tendances).
class InnovationRadarScreen extends ConsumerWidget {
  const InnovationRadarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return WebShell(
      title: 'Innovation Radar',
      subtitle: 'Compétences, tendances et besoins du marché.',
      navItems: adminNav([
        ('Radar', AppIcons.chartColumn, '269'),
        ('Compétences', AppIcons.userCheck, null),
        ('Besoins exprimés', AppIcons.fileText, '188'),
        ('Tendances', AppIcons.globe, null),
      ]),
      selected: 0,
      children: [
        TwoColumns(
          flex: (3, 2),
          left: WebPanel(
            title: 'Compétences les plus demandées',
            child: Column(
              children: [
                for (final s in d.skillDemand) ...[
                  Row(
                    children: [
                      Expanded(child: Text(s.name, style: AppText.body.copyWith(fontWeight: FontWeight.w400))),
                      Text(s.level, style: AppText.label),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(padding: const EdgeInsets.only(right: 60), child: ProgressLine(value: s.value)),
                  gap16,
                ],
              ],
            ),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebTable(
                title: 'Besoins du marché',
                columns: const ['Besoin exprimé', 'Demandes'],
                flex: const [3, 1],
                rows: [for (final n in d.marketNeeds) [Cell(n.$1, strong: true), Cell(n.$2)]],
              ),
              gap16,
              WebPanel(
                title: 'Tendance du trimestre',
                child: Text(d.quarterTrend, style: AppText.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
