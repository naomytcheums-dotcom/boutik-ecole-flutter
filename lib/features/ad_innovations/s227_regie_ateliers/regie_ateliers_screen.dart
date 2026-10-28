import '../../l_departement/l_widgets.dart' show LDepartmentShell, lBadge, lKpis, OpsSplit;
import '../ad_widgets.dart';

/// 227 · Régie des ateliers en direct (web, programmation et audience).
class RegieAteliersScreen extends ConsumerStatefulWidget {
  const RegieAteliersScreen({super.key});

  @override
  ConsumerState<RegieAteliersScreen> createState() => _RegieAteliersScreenState();
}

class _RegieAteliersScreenState extends ConsumerState<RegieAteliersScreen> {
  final _approved = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    return LDepartmentShell(
      title: 'Régie des ateliers en direct',
      selected: 7,
      children: [
        OpsKpiRow(lKpis(d.liveKpis)),
        gap16,
        OpsSplit(
          flex: (3, 2),
          left: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Spectateurs cette semaine',
                    style: AppText.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                _AudienceBars(values: d.liveAudience, labels: d.liveDays),
              ],
            ),
          ),
          right: OpsCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'En direct maintenant',
                    style: AppText.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(d.liveNow.$3, fit: BoxFit.cover, excludeFromSemantics: true),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: const ShapeDecoration(color: Color(0xFFE11D48), shape: StadiumBorder()),
                            child: Text(
                              'EN DIRECT',
                              style: AppText.label.copyWith(color: Colors.white, fontSize: 11.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(d.liveNow.$1, style: AppText.bodyStrong),
                Text(d.liveNow.$2, style: AppText.secondary),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OpsBigButton(
                        label: 'Ouvrir la régie',
                        icon: AppIcons.video,
                        height: 44,
                        onTap: () => context.openScreen('222'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        gap16,
        OpsTable(
          columns: const ['Atelier', 'Animateur', 'Créneau', 'Audience', 'Statut'],
          flex: const [4, 3, 2, 2, 2],
          rows: [
            for (final l in d.liveSchedule)
              [
                OpsCell(l.$1, strong: true),
                OpsCell(l.$2),
                OpsCell(l.$3),
                OpsCell(l.$4),
                if (l.$5 == 'À valider' && !_approved.contains(l.$1))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OpsBadge(
                      'Valider',
                      tone: OpsTone.info,
                      onTap: () {
                        setState(() => _approved.add(l.$1));
                        context.toast('Atelier « ${l.$1} » programmé.');
                      },
                    ),
                  )
                else if (_approved.contains(l.$1))
                  lBadge('Programmé', Tone.accent)
                else
                  lBadge(l.$5, l.$6),
              ],
          ],
        ),
      ],
    );
  }
}

/// Histogramme d'audience journalière (barre du jour le plus fort en violet).
class _AudienceBars extends StatelessWidget {
  const _AudienceBars({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final max = values.reduce((a, b) => a > b ? a : b);
    const h = 170.0;
    return Semantics(
      label: [for (final (i, v) in values.indexed) '${labels[i]} : ${v.round()} spectateurs'].join(', '),
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in values)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${v.round()}', style: AppText.small.copyWith(fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: (h - 22) * v / max,
                          decoration: BoxDecoration(
                            color: v == max ? AppColors.accent : AppColors.ink,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final l in labels)
                Expanded(
                  child: Text(l, textAlign: TextAlign.center, style: AppText.small.copyWith(fontSize: 11.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
