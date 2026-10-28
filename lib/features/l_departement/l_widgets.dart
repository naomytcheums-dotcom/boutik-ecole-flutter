import '../../data/demo/section_l_demo.dart';
import '../k_evenements/k_widgets.dart';
import '../n_admin_globale/n_widgets.dart' show opsToneOf;

export '../../data/demo/section_l_demo.dart';
export '../k_evenements/k_widgets.dart';
export '../n_admin_globale/n_widgets.dart' show OpsSplit, opsToneOf;

/// Barre latérale du responsable de département (109–116).
const lDepartmentNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '108', section: 'Principal'),
  WebNavItem('Étudiants et vendeurs', AppIcons.users, target: '109', section: 'Principal'),
  WebNavItem('Validations', AppIcons.circleCheck, target: '110', section: 'Principal'),
  WebNavItem('Projets', AppIcons.lightbulb, target: '111', section: 'Principal'),
  WebNavItem('Statistiques', AppIcons.chartColumn, target: '112', section: 'Gestion'),
  WebNavItem('Productions', AppIcons.layers, target: '113', section: 'Gestion'),
  WebNavItem('Mentors', AppIcons.award, target: '114', section: 'Gestion'),
  WebNavItem('Événements', AppIcons.calendar, target: '115', section: 'Gestion'),
  WebNavItem('Rapports', AppIcons.file, target: '116', section: 'Gestion'),
];

/// Gabarit commun des écrans 109–116.
class LDepartmentShell extends ConsumerWidget {
  const LDepartmentShell({super.key, required this.title, required this.selected, required this.children});

  final String title;
  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionLDataProvider);
    return WebShell(
      title: title,
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: lDepartmentNav,
      selected: selected,
      accountName: d.head,
      accountSubtitle: d.headDepartment,
      children: children,
    );
  }
}

/// Indicateurs (libellé, valeur, icône) au format des consoles.
List<OpsKpi> lKpis(List<(String, String, String)> items) => [for (final k in items) OpsKpi(k.$1, k.$2, k.$3)];

/// Badge de statut d'une console à partir d'une tonalité de démonstration.
Widget lBadge(String label, Tone tone) =>
    Align(alignment: Alignment.centerLeft, child: OpsBadge(label, tone: opsToneOf(tone)));
