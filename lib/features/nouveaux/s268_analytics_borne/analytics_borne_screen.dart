import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 268 · Analytics de la borne (sessions, scans QR, conversions).
class AnalyticsBorneScreen extends ConsumerWidget {
  const AnalyticsBorneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return WebShell(
      title: 'Analytics de la borne',
      subtitle: 'Sessions, scans QR et conversions.',
      navItems: adminNav([
        ('Tableau de bord', AppIcons.layoutGrid, '145'),
        ('Bornes', AppIcons.server, '277'),
        ('Analytics', AppIcons.chartColumn, '268'),
        ('Incidents', AppIcons.bell, '147-1'),
      ]),
      selected: 2,
      children: [
        KpiGrid(d.kioskKpis),
        gap16,
        TwoColumns(
          flex: (3, 2),
          left: WebPanel(
            title: 'Sessions par jour',
            child: SizedBox(height: 170, child: BarChart(values: d.sessionsPerDay, highlightFrom: 21)),
          ),
          right: WebTable(
            title: 'Top produits',
            columns: const ['Produit consulté', 'Vues'],
            flex: const [4, 1],
            rows: [for (final p in d.topKioskProducts) [Cell(p.$1, strong: true), Cell(p.$2)]],
          ),
        ),
        gap16,
        WebTable(
          title: 'Parc de bornes',
          columns: const ['Borne', 'Emplacement', 'Dernière activité', 'Version', 'État'],
          flex: const [2, 3, 3, 2, 2],
          rows: [for (final k in d.kioskFleet) [Cell(k.$1, strong: true), Cell(k.$2), Cell(k.$3), Cell(k.$4), Cell(k.$5)]],
        ),
      ],
    );
  }
}

/// Histogramme simple (barres arrondies) ; les barres à partir de [highlightFrom] sont accentuées.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, this.highlightFrom});

  final List<double> values;
  final int? highlightFrom;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Histogramme de ${values.length} valeurs',
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / values.length;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, v) in values.indexed)
                SizedBox(
                  width: w,
                  child: Center(
                    child: Container(
                      width: (w * .55).clamp(3, 12),
                      height: c.maxHeight * v,
                      decoration: BoxDecoration(
                        color: highlightFrom != null && i >= highlightFrom! ? const Color(0xFFA77BE6) : const Color(0xFFE2D3F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
