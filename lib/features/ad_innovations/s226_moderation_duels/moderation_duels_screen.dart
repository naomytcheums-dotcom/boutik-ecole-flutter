import '../../n_admin_globale/n_widgets.dart' show NAdminShell, OpsSplit, opsToneOf;
import '../ad_widgets.dart';

/// 226 · Modération des duels (web, administration globale).
class ModerationDuelsScreen extends ConsumerStatefulWidget {
  const ModerationDuelsScreen({super.key});

  @override
  ConsumerState<ModerationDuelsScreen> createState() => _ModerationDuelsScreenState();
}

class _ModerationDuelsScreenState extends ConsumerState<ModerationDuelsScreen> {
  int _tab = 0;
  final _decided = <String, (String, Tone)>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    (String, Tone) status((String, String, String, int, String, String, Tone) r) => _decided[r.$1] ?? (r.$6, r.$7);
    final rows = d.duelRows
        .where((r) => _tab == 0 || status(r).$1 == d.duelTabs[_tab].replaceAll('Terminés', 'Terminé'))
        .toList();
    return NAdminShell(
      title: 'Modération des duels',
      selected: 3,
      children: [
        OpsKpiRow([for (final k in d.duelKpis) OpsKpi(k.$1, k.$2, k.$3)]),
        gap16,
        OpsTabs(labels: d.duelTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Duel', 'Demandeur', 'Participants', 'Séquestre', 'Échéance', 'Statut'],
          flex: const [4, 3, 2, 2, 2, 3],
          emptyLabel: 'Aucun duel dans cet onglet.',
          rows: [
            for (final r in rows)
              [
                OpsCell(r.$1, strong: true),
                OpsCell(r.$2),
                OpsCell(r.$3),
                OpsCell(r.$4 == 0 ? '—' : fcfa(r.$4)),
                OpsCell(r.$5),
                if (status(r).$1 == 'À valider')
                  Wrap(
                    spacing: 6,
                    children: [
                      OpsBadge(
                        'Valider',
                        tone: OpsTone.success,
                        onTap: () {
                          setState(() => _decided[r.$1] = ('En cours', Tone.success));
                          context.toast('Duel « ${r.$1} » validé et ouvert aux étudiants.');
                        },
                      ),
                      OpsBadge(
                        'Suspendre',
                        tone: OpsTone.danger,
                        onTap: () {
                          setState(() => _decided[r.$1] = ('Suspendu', Tone.error));
                          context.toast('Duel « ${r.$1} » suspendu, séquestre conservé.');
                        },
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OpsBadge(status(r).$1, tone: opsToneOf(status(r).$2)),
                  ),
              ],
          ],
        ),
        gap16,
        OpsSplit(
          left: OpsKvCard(title: 'Séquestre des duels', rows: d.duelEscrow),
          right: OpsInfoNote(d.duelModerationNote),
        ),
      ],
    );
  }
}
