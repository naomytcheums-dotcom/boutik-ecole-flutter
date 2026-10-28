import '../../l_departement/l_widgets.dart' show LDepartmentShell, lBadge, lKpis, OpsSplit;
import '../ad_widgets.dart';

/// 224 · Validation des vœux (web, responsable de département).
class ValidationVoeuxScreen extends ConsumerStatefulWidget {
  const ValidationVoeuxScreen({super.key});

  @override
  ConsumerState<ValidationVoeuxScreen> createState() => _ValidationVoeuxScreenState();
}

class _ValidationVoeuxScreenState extends ConsumerState<ValidationVoeuxScreen> {
  int _tab = 0;
  final _decided = <String, (String, Tone)>{};

  static const _tabStatus = ['À valider', 'En campagne', 'Refusé'];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    (String, Tone) status((String, String, int, String, String, String, Tone) w) => _decided[w.$1] ?? (w.$6, w.$7);
    final rows = d.wishReviews.where((w) => status(w).$1 == _tabStatus[_tab]).toList();
    return LDepartmentShell(
      title: 'Validation des vœux',
      selected: 2,
      children: [
        OpsKpiRow(lKpis(d.wishKpis)),
        gap16,
        OpsTabs(labels: d.wishReviewTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Vœu', 'Porteur', 'Prix', 'Seuil', 'Soumis', 'Décision'],
          flex: const [4, 3, 2, 1, 2, 3],
          emptyLabel: 'Aucun vœu dans cet onglet.',
          rows: [
            for (final w in rows)
              [
                OpsCell(w.$1, strong: true),
                OpsCell(w.$2),
                OpsCell(fcfa(w.$3)),
                OpsCell(w.$4),
                OpsCell(w.$5),
                if (status(w).$1 == 'À valider')
                  Wrap(
                    spacing: 6,
                    children: [
                      OpsBadge(
                        'Valider',
                        tone: OpsTone.success,
                        onTap: () {
                          setState(() => _decided[w.$1] = ('En campagne', Tone.success));
                          context.toast('« ${w.$1} » validé : la campagne est en ligne.');
                        },
                      ),
                      OpsBadge(
                        'Refuser',
                        tone: OpsTone.danger,
                        onTap: () {
                          setState(() => _decided[w.$1] = ('Refusé', Tone.error));
                          context.toast('« ${w.$1} » refusé : le porteur est notifié.');
                        },
                      ),
                    ],
                  )
                else
                  lBadge(status(w).$1, status(w).$2),
              ],
          ],
        ),
        gap16,
        OpsSplit(
          left: OpsKvCard(title: 'Règles de publication', rows: d.wishRules),
          right: OpsInfoNote(d.wishRulesNote),
        ),
      ],
    );
  }
}
