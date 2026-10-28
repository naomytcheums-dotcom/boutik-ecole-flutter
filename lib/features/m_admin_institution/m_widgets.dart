import '../../data/demo/section_m_demo.dart';
import '../l_departement/l_widgets.dart';

export '../../data/demo/section_m_demo.dart';
export '../l_departement/l_widgets.dart';

/// Barre latérale de l'administration institutionnelle (118–126).
const mAdminNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '117', section: 'Principal'),
  WebNavItem('Établissement', AppIcons.landmark, target: '118', section: 'Principal'),
  WebNavItem('Départements', AppIcons.layers, target: '119', section: 'Principal'),
  WebNavItem('Utilisateurs', AppIcons.users, target: '120', section: 'Principal'),
  WebNavItem('Responsables', AppIcons.award, target: '121', section: 'Gestion'),
  WebNavItem('Circuits de validation', AppIcons.shieldCheck, target: '122', section: 'Gestion'),
  WebNavItem('Activité et ventes', AppIcons.trendingUp, target: '123', section: 'Gestion'),
  WebNavItem('Événements', AppIcons.calendar, target: '124', section: 'Gestion'),
  WebNavItem('Rapports', AppIcons.file, target: '125', section: 'Gestion'),
  WebNavItem('Journal d’audit', AppIcons.history, target: '126', section: 'Gestion'),
];

/// Gabarit commun des écrans 118–126.
class MAdminShell extends ConsumerWidget {
  const MAdminShell({super.key, required this.title, required this.selected, required this.children});

  final String title;
  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionMDataProvider);
    return WebShell(
      title: title,
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: mAdminNav,
      selected: selected,
      accountName: d.account,
      accountSubtitle: d.accountSubtitle,
      children: children,
    );
  }
}
