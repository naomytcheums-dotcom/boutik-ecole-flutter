import '../l_widgets.dart';

/// 108 · Tableau de bord du département.
class TableauDeBordDepartementScreen extends ConsumerWidget {
  const TableauDeBordDepartementScreen({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '108', section: 'Principal'),
    WebNavItem('Étudiants et vendeurs', AppIcons.layers, target: '109', section: 'Principal'),
    WebNavItem('Validations', AppIcons.chartColumn, target: '110', section: 'Principal'),
    WebNavItem('Projets', AppIcons.user, target: '111', section: 'Gestion'),
    WebNavItem('Statistiques', AppIcons.user, target: '112', section: 'Gestion'),
    WebNavItem('Productions', AppIcons.users, target: '113', section: 'Gestion'),
    WebNavItem('Mentors', AppIcons.messageCircle, target: '114', section: 'Suivi'),
    WebNavItem('Événements', AppIcons.chartColumn, target: '115', section: 'Suivi'),
    WebNavItem('Rapports', AppIcons.settings, target: '116', section: 'Compte'),
    WebNavItem('Aide et retours', AppIcons.circleHelp, target: '48', section: 'Compte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionLDataProvider);
    return WebShell(
      title: 'Tableau de bord du département',
      subtitle: 'Étudiants, productions et ventes du département Génie informatique.',
      navItems: nav,
      selected: 0,
      accountName: d.head,
      accountSubtitle: d.headDepartment,
      children: [
        OpsSplit(
          flex: (36, 65),
          left: const OpsHeroCard(headline: 'Fais rayonner\ntes étudiants.'),
          right: OpsTrendCard(
            title: d.salesTitle,
            total: fcfa(d.salesTotal),
            delta: d.salesDelta,
            deltaNote: '+ ${fcfa(d.salesGain, withUnit: false)} vs mois précédent',
            bars: d.salesBars,
            curve: d.salesCurve,
            highlight: d.salesHighlight,
            tooltipValue: d.salesTooltip.$1,
            tooltipLabel: d.salesTooltip.$2,
            months: d.months,
            onFilter: () => context.toast('Filtres de période (démonstration).'),
          ),
        ),
        const SizedBox(height: 12),
        OpsSplit(
          flex: (63, 39),
          left: OpsListCard(
            title: 'Validations en attente',
            columns: const ['Annonce', 'Vendeur', 'Statut', 'Prix'],
            rows: [
              for (final v in d.pendingValidations)
                OpsListRow(
                  image: v.$1,
                  title: v.$2,
                  subtitle: v.$3,
                  middle: v.$4,
                  status: v.$5,
                  statusTone: v.$6 == Tone.success ? OpsTone.lime : OpsTone.grey,
                  amount: '${fcfa(v.$7, withUnit: false)}${nbsp}F',
                ),
            ],
            onSort: () => context.toast('Tri par date (démonstration).'),
            onFilter: () => context.toast('Filtres (démonstration).'),
            onRowTap: (_) => context.openScreen('110'),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsGoalCard(
                title: 'Objectif annuel du département',
                percent: d.yearGoal,
                caption: 'des ventes cibles',
                progress: d.yearProgress,
              ),
              const SizedBox(height: 12),
              OpsAssistantCard(
                avatar: d.kelaAvatar,
                question: d.kelaQuestion,
                answer: d.kelaAnswer,
                onAsk: () => context.openScreen('230'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
