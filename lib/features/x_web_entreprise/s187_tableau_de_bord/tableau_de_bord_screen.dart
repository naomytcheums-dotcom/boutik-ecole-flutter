import '../x_widgets.dart';

/// 187 · Tableau de bord entreprise (web) : propositions reçues, besoins publiés, besoins pourvus, Kéla.
class TableauDeBordEntrepriseScreen extends ConsumerWidget {
  const TableauDeBordEntrepriseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionXDataProvider);
    final rows = [
      for (final n in d.needs)
        OpsListRow(
          image: n.image,
          title: n.title,
          subtitle: n.code,
          middle: '${n.proposals} propositions',
          status: n.status,
          statusTone: n.tone == Tone.success ? OpsTone.lime : OpsTone.grey,
          amount: '${n.match}$nbsp%',
        ),
    ];
    return WebShell(
      title: 'Tableau de bord entreprise',
      subtitle: 'Vos besoins, propositions et collaborations avec l’IUT.',
      navItems: xDashboardNav,
      selected: 0,
      accountName: d.contactName,
      accountSubtitle: d.companyName,
      children: [
        XSplit(
          flex: (36, 65),
          left: OpsHeroCard(headline: d.heroHeadline),
          right: OpsTrendCard(
            title: 'Propositions reçues',
            total: '${d.proposalsTotal} propositions',
            delta: '+ ${d.proposalsDelta}',
            deltaNote: 'reçues pour ${d.publishedNeeds} besoins publiés',
            bars: d.proposalBars,
            curve: d.proposalCurve,
            highlight: d.proposalHighlight,
            tooltipValue: d.proposalsTooltip.$1,
            tooltipLabel: d.proposalsTooltip.$2,
            months: d.months,
            onFilter: () => context.toast('Filtres de période (démonstration).'),
          ),
        ),
        const SizedBox(height: 12),
        XSplit(
          flex: (63, 39),
          left: OpsListCard(
            title: 'Besoins publiés',
            columns: const ['Besoin', 'Propositions', 'Statut', 'Compatibilité'],
            rows: rows,
            onSort: () => context.toast('Tri par compatibilité (démonstration).'),
            onFilter: () => context.toast('Filtres (démonstration).'),
            onRowTap: (_) => context.openScreen('189'),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsGoalCard(
                title: 'Besoins pourvus',
                percent: d.fulfilledPercent,
                caption: 'des besoins publiés',
                progress: d.fulfilledProgress,
              ),
              const SizedBox(height: 12),
              OpsAssistantCard(
                avatar: d.kelaAvatar,
                question: d.kelaQuestion,
                answer: d.kelaAnswer,
                onAsk: () => context.toast('Kéla prépare une réponse (démonstration).'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
