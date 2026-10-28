import '../../data/demo/section_o_demo.dart';
import '../l_departement/l_widgets.dart';

export '../../data/demo/section_o_demo.dart';
export '../l_departement/l_widgets.dart';

/// Barre latérale finance et exploitation (140–147).
const oFinanceNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '139', section: 'Principal'),
  WebNavItem('Paiements déclarés', AppIcons.wallet, target: '140', section: 'Principal'),
  WebNavItem('Journal financier', AppIcons.receipt, target: '141', section: 'Principal'),
  WebNavItem('Rapports', AppIcons.chartColumn, target: '142', section: 'Principal'),
  WebNavItem('Points de retrait', AppIcons.store, target: '145', section: 'Gestion'),
  WebNavItem('Incidents kiosques', AppIcons.triangleAlert, target: '147-1', section: 'Gestion'),
  WebNavItem('Tickets support', AppIcons.circleHelp, target: '147-2', section: 'Gestion'),
  WebNavItem('Interventions', AppIcons.history, target: '147-3', section: 'Gestion'),
];

/// Gabarit commun des écrans finance / exploitation.
class OFinanceShell extends ConsumerWidget {
  const OFinanceShell({super.key, required this.title, required this.selected, required this.children});

  final String title;
  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionODataProvider);
    return WebShell(
      title: title,
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: oFinanceNav,
      selected: selected,
      accountName: d.account,
      accountSubtitle: d.accountSubtitle,
      children: children,
    );
  }
}
