import '../o_widgets.dart';

/// 139 · Tableau de bord financier.
class TableauDeBordFinancierScreen extends ConsumerWidget {
  const TableauDeBordFinancierScreen({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '139', section: 'Principal'),
    WebNavItem('Paiements déclarés', AppIcons.layers, target: '140', section: 'Principal'),
    WebNavItem('Journal financier', AppIcons.chartColumn, target: '141', section: 'Principal'),
    WebNavItem('Rapports', AppIcons.user, target: '142', section: 'Gestion'),
    WebNavItem('Points de retrait', AppIcons.user, target: '145', section: 'Gestion'),
    WebNavItem('Incidents kiosques', AppIcons.users, target: '147-1', section: 'Gestion'),
    WebNavItem('Tickets support', AppIcons.messageCircle, target: '147-2', section: 'Suivi'),
    WebNavItem('Interventions', AppIcons.chartColumn, target: '147-3', section: 'Suivi'),
    WebNavItem('Paramètres', AppIcons.settings, target: '144', section: 'Compte'),
    WebNavItem('Aide et retours', AppIcons.circleHelp, target: '48', section: 'Compte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionODataProvider);
    return WebShell(
      title: 'Tableau de bord financier',
      subtitle: 'Encaissements, reversements et commissions en un coup d’œil.',
      navItems: nav,
      selected: 0,
      accountName: d.account,
      accountSubtitle: d.accountMail,
      children: [
        OpsSplit(
          flex: (36, 65),
          left: const OpsHeroCard(headline: 'Garde le cap\nsur tes flux.'),
          right: OpsTrendCard(
            title: d.flowTitle,
            total: fcfa(d.flowTotal),
            delta: d.flowDelta,
            deltaNote: '+ ${fcfa(d.flowGain, withUnit: false)} vs 30 jours précédents',
            bars: d.flowBars,
            curve: d.flowCurve,
            highlight: d.flowHighlight,
            tooltipValue: d.flowTooltip.$1,
            tooltipLabel: d.flowTooltip.$2,
            months: d.months,
            onFilter: () => context.toast('Filtres de période (démonstration).'),
          ),
        ),
        const SizedBox(height: 12),
        OpsSplit(
          flex: (63, 39),
          left: OpsListCard(
            title: 'Derniers flux',
            columns: const ['Référence', 'Type', 'Statut', 'Montant'],
            rows: [
              for (final f in d.lastFlows)
                OpsListRow(
                  image: f.$1,
                  title: f.$2,
                  subtitle: f.$3,
                  middle: f.$4,
                  status: f.$5,
                  statusTone: f.$6 == Tone.success ? OpsTone.lime : OpsTone.grey,
                  amount: '${fcfa(f.$7, withUnit: false)}${nbsp}F',
                ),
            ],
            onSort: () => context.toast('Tri par date (démonstration).'),
            onFilter: () => context.toast('Filtres (démonstration).'),
            onRowTap: (_) => context.openScreen('141'),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsGoalCard(
                title: 'Objectif d’encaissement',
                percent: d.cashGoal,
                caption: 'du budget encaissé',
                progress: d.cashProgress,
              ),
              const SizedBox(height: 12),
              OpsAssistantCard(
                avatar: d.kelaAvatar,
                question: d.kelaQuestion,
                answer: d.kelaAnswer,
                onAsk: () => context.openScreen('140'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
