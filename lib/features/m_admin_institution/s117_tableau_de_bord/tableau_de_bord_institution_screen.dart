import '../m_widgets.dart';

/// 117 · Tableau de bord institutionnel.
class TableauDeBordInstitutionScreen extends ConsumerWidget {
  const TableauDeBordInstitutionScreen({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '117', section: 'Principal'),
    WebNavItem('Établissement', AppIcons.layers, target: '118', section: 'Principal'),
    WebNavItem('Départements', AppIcons.chartColumn, target: '119', section: 'Principal'),
    WebNavItem('Utilisateurs', AppIcons.user, target: '120', section: 'Gestion'),
    WebNavItem('Responsables', AppIcons.user, target: '121', section: 'Gestion'),
    WebNavItem('Circuits de validation', AppIcons.users, target: '122', section: 'Gestion'),
    WebNavItem('Activité et ventes', AppIcons.messageCircle, target: '123', section: 'Suivi'),
    WebNavItem('Événements', AppIcons.chartColumn, target: '124', section: 'Suivi'),
    WebNavItem('Rapports', AppIcons.settings, target: '125', section: 'Compte'),
    WebNavItem('Journal d’audit', AppIcons.circleHelp, target: '126', section: 'Compte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionMDataProvider);
    return WebShell(
      title: 'Tableau de bord institutionnel',
      subtitle: 'Activité de l’IUT de Douala sur Boutik-École.',
      navItems: nav,
      selected: 0,
      accountName: d.account,
      accountSubtitle: d.accountSubtitle,
      children: [
        OpsSplit(
          flex: (36, 65),
          left: const OpsHeroCard(headline: 'Pilote ton\nétablissement.'),
          right: OpsTrendCard(
            title: d.activityTitle,
            total: fcfa(d.activityTotal),
            delta: d.activityDelta,
            deltaNote: '+ ${fcfa(d.activityGain, withUnit: false)} vs mois précédent',
            bars: d.activityBars,
            curve: d.activityCurve,
            highlight: d.activityHighlight,
            tooltipValue: d.activityTooltip.$1,
            tooltipLabel: d.activityTooltip.$2,
            months: d.months,
            onFilter: () => context.toast('Filtres de période (démonstration).'),
          ),
        ),
        const SizedBox(height: 12),
        OpsSplit(
          flex: (63, 39),
          left: OpsListCard(
            title: 'Départements les plus actifs',
            columns: const ['Département', 'Étudiants actifs', 'Statut', 'Ventes'],
            rows: [
              for (final dep in d.activeDepartments)
                OpsListRow(
                  image: dep.$1,
                  title: dep.$2,
                  subtitle: dep.$3,
                  middle: '${dep.$4} étudiants',
                  status: dep.$5,
                  statusTone: dep.$6 == Tone.success ? OpsTone.lime : OpsTone.grey,
                  amount: '${fcfa(dep.$7, withUnit: false)}${nbsp}k',
                ),
            ],
            onSort: () => context.toast('Tri par ventes (démonstration).'),
            onFilter: () => context.toast('Filtres (démonstration).'),
            onRowTap: (_) => context.openScreen('119'),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsGoalCard(
                title: 'Objectif de l’année',
                percent: d.yearGoal,
                caption: 'du chiffre cible',
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
