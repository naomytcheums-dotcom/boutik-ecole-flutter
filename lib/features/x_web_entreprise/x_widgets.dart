import '../common/common.dart';
import '../../data/demo/section_x_demo.dart';

export '../common/common.dart';
export '../../data/demo/section_x_demo.dart';

/// Barre latérale du tableau de bord entreprise (187), regroupée en quatre rubriques.
const xDashboardNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '187', section: 'Principal'),
  WebNavItem('Besoins publiés', AppIcons.layers, target: '90', section: 'Principal'),
  WebNavItem('Recherche de talents', AppIcons.chartColumn, target: '188', section: 'Principal'),
  WebNavItem('Propositions', AppIcons.user, target: '189', section: 'Gestion'),
  WebNavItem('Devis', AppIcons.user, target: '190', section: 'Gestion'),
  WebNavItem('Collaborations', AppIcons.users, target: '98', section: 'Gestion'),
  WebNavItem('Hackathons et défis', AppIcons.messageCircle, target: '96', section: 'Suivi'),
  WebNavItem('Recrutement', AppIcons.chartColumn, target: '97', section: 'Suivi'),
  WebNavItem('Paramètres', AppIcons.settings, target: '89', section: 'Compte'),
  WebNavItem('Aide et retours', AppIcons.circleHelp, target: '49', section: 'Compte'),
];

/// Barre latérale des écrans entreprise 188–190.
const xCompanyNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '187', section: 'Principal'),
  WebNavItem('Besoins publiés', AppIcons.file, target: '90', section: 'Principal'),
  WebNavItem('Recherche de talents', AppIcons.search, target: '188', section: 'Principal'),
  WebNavItem('Propositions', AppIcons.inbox, target: '189', section: 'Principal'),
  WebNavItem('Devis', AppIcons.receipt, target: '190', section: 'Gestion'),
  WebNavItem('Collaborations', AppIcons.users, target: '98', section: 'Gestion'),
  WebNavItem('Hackathons et défis', AppIcons.trophy, target: '96', section: 'Gestion'),
  WebNavItem('Recrutement', AppIcons.briefcase, target: '97', section: 'Gestion'),
];

/// Gabarit commun des écrans 188–190 (sous-titre « Vue d’ensemble »).
class XCompanyShell extends ConsumerWidget {
  const XCompanyShell({super.key, required this.title, required this.selected, required this.children});

  final String title;
  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionXDataProvider);
    return WebShell(
      title: title,
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: xCompanyNav,
      selected: selected,
      accountName: d.contactName,
      accountSubtitle: d.companyName,
      children: children,
    );
  }
}

/// Correspondance des tonalités de démonstration vers les badges des consoles.
OpsTone xToneOf(Tone t) => switch (t) {
  Tone.success => OpsTone.success,
  Tone.error => OpsTone.danger,
  Tone.warning => OpsTone.pending,
  Tone.accent => OpsTone.info,
  Tone.neutral => OpsTone.neutral,
};

/// Deux blocs côte à côte ([flex]) au-delà de [breakpoint], empilés sinon.
class XSplit extends StatelessWidget {
  const XSplit({
    super.key,
    required this.left,
    required this.right,
    this.flex = (1, 1),
    this.gap = 14,
    this.breakpoint = 760,
  });

  final Widget left;
  final Widget right;
  final (int, int) flex;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: gap),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flex.$1, child: left),
            SizedBox(width: gap),
            Expanded(flex: flex.$2, child: right),
          ],
        );
      },
    );
  }
}
