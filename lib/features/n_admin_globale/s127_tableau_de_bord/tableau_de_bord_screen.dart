import '../../common/common.dart';
import '../../../data/demo/section_n_demo.dart';

/// 127 · Tableau de bord de la plateforme (super admin, réseau d'établissements).
class TableauDeBordPlateformeScreen extends ConsumerWidget {
  const TableauDeBordPlateformeScreen({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '127', section: 'Principal'),
    WebNavItem('Établissements', AppIcons.layers, target: '129', section: 'Principal'),
    WebNavItem('Utilisateurs', AppIcons.chartColumn, target: '128', section: 'Principal'),
    WebNavItem('Modération', AppIcons.user, target: '130', section: 'Gestion'),
    WebNavItem('Circuits de validation', AppIcons.user, target: '130', section: 'Gestion'),
    WebNavItem('Finances', AppIcons.users, target: '134', section: 'Gestion'),
    WebNavItem('Kiosques', AppIcons.messageCircle, target: '145', section: 'Réseau'),
    WebNavItem('Sécurité', AppIcons.chartColumn, target: '136', section: 'Réseau'),
    WebNavItem('Paramètres', AppIcons.settings, target: '138', section: 'Compte'),
    WebNavItem('Journal d’audit', AppIcons.circleHelp, target: '137', section: 'Compte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionNDataProvider);
    final rows = [
      for (final e in d.establishments)
        OpsListRow(
          image: e.$1,
          title: e.$2,
          subtitle: e.$3,
          middle: fcfa(e.$4, withUnit: false),
          status: e.$5,
          statusTone: e.$6 == Tone.success ? OpsTone.lime : OpsTone.grey,
          amount: '${fcfa(e.$7, withUnit: false)}${nbsp}k',
        ),
    ];
    return WebShell(
      title: 'Tableau de bord de la plateforme',
      subtitle: 'Activité de tous les établissements du réseau.',
      navItems: nav,
      selected: 0,
      accountName: 'Super admin',
      accountSubtitle: 'Boutik-École Network',
      children: [
        _Split(
          flex: (36, 65),
          left: const OpsHeroCard(headline: 'Garde la plateforme\nen pleine forme.'),
          right: OpsTrendCard(
            title: d.volumeTitle,
            total: fcfa(d.volumeTotal),
            delta: d.volumeDelta,
            deltaNote: '+ ${fcfa(d.volumeGain, withUnit: false)} vs mois précédent',
            bars: d.volumeBars,
            curve: d.volumeCurve,
            highlight: d.volumeHighlight,
            tooltipValue: d.volumeTooltip.$1,
            tooltipLabel: d.volumeTooltip.$2,
            months: d.months,
            onFilter: () => context.toast('Filtres de période (démonstration).'),
          ),
        ),
        const SizedBox(height: 12),
        _Split(
          flex: (63, 39),
          left: OpsListCard(
            title: 'Établissements du réseau',
            columns: const ['Établissement', 'Utilisateurs', 'Statut', 'Ventes'],
            rows: rows,
            onSort: () => context.toast('Tri par ventes (démonstration).'),
            onFilter: () => context.toast('Filtres (démonstration).'),
            onRowTap: (_) => context.openScreen('129'),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsGoalCard(
                title: 'Objectif de déploiement',
                percent: d.deploymentGoal,
                caption: 'des établissements',
                progress: d.deploymentProgress,
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

class _Split extends StatelessWidget {
  const _Split({required this.left, required this.right, required this.flex});

  final Widget left;
  final Widget right;
  final (int, int) flex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flex.$1, child: left),
            const SizedBox(width: 14),
            Expanded(flex: flex.$2, child: right),
          ],
        );
      },
    );
  }
}
