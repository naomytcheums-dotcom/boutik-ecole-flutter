import '../y_web.dart';

const _columnColor = Color(0xFFEDF0F5);

/// 200 · Missions et encaissement (web admin) : séquestre, tableau des missions, répartition des paiements.
class MissionsEncaissementScreen extends ConsumerWidget {
  const MissionsEncaissementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionYDataProvider);
    return YAdminShell(
      title: 'Missions et encaissement',
      selected: 3,
      children: [
        YWebKpiRow([
          YWebKpi(label: 'Encaissé en séquestre', value: fcfa(d.escrowTotal, withUnit: false), unit: 'FCFA'),
          YWebKpi(label: 'À libérer cette semaine', value: fcfa(d.toReleaseThisWeek, withUnit: false), unit: 'FCFA'),
          YWebKpi(label: 'Missions actives', value: '${d.activeMissions}'),
          YWebKpi(label: 'En retard', value: '${d.lateMissions}'),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final perRow = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
            final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, col) in d.board.indexed)
                  SizedBox(
                    width: w,
                    child: _BoardColumn(column: col, delivered: i == 3),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SplitPanel(split: d.paymentSplit),
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({required this.column, required this.delivered});

  final (String, int, List<(String, String, String, double, int)>) column;
  final bool delivered;

  @override
  Widget build(BuildContext context) {
    final (title, count, cards) = column;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(color: _columnColor, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(header: true, child: Text(title, style: AppText.label.copyWith(fontSize: 14))),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: AppText.small.copyWith(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, c) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            _MissionCard(card: c, color: delivered ? const Color(0xFF1F9D6B) : const Color(0xFF6C4CF1)),
          ],
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.card, required this.color});

  final (String, String, String, double, int) card;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, avatar, progress, amount) = card;
    return Semantics(
      label: '$title, $subtitle, ${(progress * 100).round()} %, ${fcfa(amount)} bloqués',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        radius: 18,
        borderColor: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(child: Image.asset(avatar, width: 30, height: 30, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.label.copyWith(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppText.small.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            YProgress(progress, color: color, height: 5),
            const SizedBox(height: 10),
            Text('${fcfa(amount)} bloqués', style: AppText.label.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SplitPanel extends StatelessWidget {
  const _SplitPanel({required this.split});

  final List<(int, String, int)> split;

  @override
  Widget build(BuildContext context) {
    return YWebCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Répartition de chaque paiement (configurable)', style: AppText.label.copyWith(fontSize: 14)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final (pct, label, color) in split)
                Expanded(
                  child: Semantics(
                    label: '$pct % : $label',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text('$pct %', style: AppText.h2.copyWith(fontSize: 19)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(label, style: AppText.secondary.copyWith(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final (i, (pct, _, color)) in split.indexed) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: pct,
                      child: ColoredBox(color: Color(color)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
