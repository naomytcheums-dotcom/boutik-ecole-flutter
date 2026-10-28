import '../x_widgets.dart';

/// 189 · Propositions reçues (web) : onglets, tableau comparatif et analyse IA.
class PropositionsRecuesWebScreen extends ConsumerStatefulWidget {
  const PropositionsRecuesWebScreen({super.key});

  @override
  ConsumerState<PropositionsRecuesWebScreen> createState() => _PropositionsRecuesWebScreenState();
}

class _PropositionsRecuesWebScreenState extends ConsumerState<PropositionsRecuesWebScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionXDataProvider);
    final rows = d.proposals.where(
      (p) => switch (_tab) {
        1 => p.shortlisted,
        2 => p.refused,
        _ => true,
      },
    );
    return XCompanyShell(
      title: 'Propositions reçues',
      selected: 3,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OpsFilterChips(
            labels: ['Toutes (${d.proposalsAll})', 'Présélection (${d.proposalsShortlisted})', 'Refusées'],
            selected: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
        ),
        const SizedBox(height: 4),
        XSplit(
          flex: (60, 40),
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OpsTable(
                columns: const ['Talent', 'Prix (FCFA)', 'Délai', 'Compat. IA', 'Statut'],
                flex: const [14, 10, 8, 10, 14],
                minWidth: 560,
                emptyLabel: _tab == 2 ? 'Aucune proposition refusée.' : 'Aucune proposition à afficher.',
                rows: [
                  for (final p in rows)
                    [
                      OpsCell(p.talent, strong: true),
                      OpsCell(fcfa(p.price, withUnit: false)),
                      OpsCell('${p.days} jours'),
                      OpsCell('${p.match}$nbsp%'),
                      OpsBadge(p.status, tone: xToneOf(p.tone), minWidth: 66),
                    ],
                ],
              ),
              const SizedBox(height: 20),
              IntrinsicWidth(
                child: PrimaryButton(
                  label: 'Comparer la sélection',
                  expand: false,
                  height: 50,
                  onPressed: () => context.openScreen('94'),
                ),
              ),
            ],
          ),
          right: _AiAnalysisCard(title: d.aiTitle, summary: d.aiSummary, checks: d.aiChecks),
        ),
      ],
    );
  }
}

class _AiAnalysisCard extends StatelessWidget {
  const _AiAnalysisCard({required this.title, required this.summary, required this.checks});

  final String title;
  final String summary;
  final List<String> checks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF0E2C4E), Color(0xFF1E4A80)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.sparkles, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: AppText.body.copyWith(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(summary, style: AppText.small.copyWith(color: const Color(0xFFE6ECF5), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final c in checks)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 6),
              child: Row(
                children: [
                  const AppIcon(AppIcons.check, size: 14, color: AppColors.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c,
                      style: AppText.small.copyWith(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
