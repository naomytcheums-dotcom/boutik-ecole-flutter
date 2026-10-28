import '../../common/common.dart';

/// Barre latérale commune des écrans web d'administration (262–269).
List<WebNavItem> adminNav(List<(String, String, String?)> items) => [
  for (final (label, icon, target) in items) WebNavItem(label, icon, target: target),
];

/// Carte web blanche avec titre (Inter).
class WebPanel extends StatelessWidget {
  const WebPanel({super.key, required this.title, required this.child, this.padding = const EdgeInsets.all(20)});

  final String title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
          gap16,
          child,
        ],
      ),
    );
  }
}

/// Deux colonnes sur grand écran (ratio [flex]), empilées sinon.
class TwoColumns extends StatelessWidget {
  const TwoColumns({super.key, required this.left, required this.right, this.flex = (3, 2), this.breakpoint = 900});

  final Widget left;
  final Widget right;
  final (int, int) flex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint - AppSizes.sidebarWidth) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, gap16, right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flex.$1, child: left),
            const SizedBox(width: 16),
            Expanded(flex: flex.$2, child: right),
          ],
        );
      },
    );
  }
}

/// Indicateurs (KPI) web en grille.
class KpiGrid extends StatelessWidget {
  const KpiGrid(this.kpis, {super.key});

  final List<Kpi> kpis;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      columns: kpis.length,
      minItemWidth: 160,
      children: [
        for (final k in kpis)
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.label, style: AppText.small),
                const SizedBox(height: 6),
                Text(k.value, style: AppText.amount.copyWith(fontWeight: FontWeight.w700, fontSize: 26)),
                const SizedBox(height: 4),
                if (k.status != null)
                  StatusBadge(k.status!, tone: k.tone == Tone.success ? BadgeTone.success : BadgeTone.warning)
                else if (k.delta != null)
                  Text(
                    k.delta!,
                    style: AppText.small.copyWith(color: toneToColor(k.tone), fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
