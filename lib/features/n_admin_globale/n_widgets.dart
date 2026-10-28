import '../common/common.dart';

/// Barre latérale des écrans d'administration globale (128–138).
const nAdminNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '127', section: 'Principal'),
  WebNavItem('Comptes et rôles', AppIcons.users, target: '128', section: 'Principal'),
  WebNavItem('Institutions', AppIcons.landmark, target: '129', section: 'Principal'),
  WebNavItem('Modération', AppIcons.flag, target: '130', section: 'Principal'),
  WebNavItem('Signalements', AppIcons.triangleAlert, target: '131', section: 'Gestion'),
  WebNavItem('Commandes', AppIcons.shoppingBag, target: '132', section: 'Gestion'),
  WebNavItem('Litiges', AppIcons.receipt, target: '133', section: 'Gestion'),
  WebNavItem('Transactions', AppIcons.wallet, target: '134', section: 'Gestion'),
  WebNavItem('Commissions', AppIcons.percent, target: '135', section: 'Gestion'),
  WebNavItem('Sécurité', AppIcons.lock, target: '136', section: 'Gestion'),
  WebNavItem('Audit global', AppIcons.history, target: '137', section: 'Gestion'),
  WebNavItem('Configuration', AppIcons.settings, target: '138', section: 'Gestion'),
];

/// Gabarit commun des écrans 128–138 (sous-titre « Vue d’ensemble »).
class NAdminShell extends StatelessWidget {
  const NAdminShell({super.key, required this.title, required this.selected, required this.children});

  final String title;
  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return WebShell(
      title: title,
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: nAdminNav,
      selected: selected,
      accountName: 'Super admin',
      accountSubtitle: 'Administration globale',
      children: children,
    );
  }
}

/// Correspondance des tonalités de démonstration vers les badges des consoles.
OpsTone opsToneOf(Tone t) => switch (t) {
  Tone.success => OpsTone.success,
  Tone.error => OpsTone.danger,
  Tone.warning => OpsTone.pending,
  Tone.accent => OpsTone.info,
  Tone.neutral => OpsTone.neutral,
};

/// Deux blocs côte à côte (ratio [flex]) au-delà de 700 px, empilés sinon.
class OpsSplit extends StatelessWidget {
  const OpsSplit({super.key, required this.left, required this.right, this.flex = (1, 1)});

  final Widget left;
  final Widget right;
  final (int, int) flex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 700) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, gap16, right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flex.$1, child: left),
            const SizedBox(width: 16),
            Expanded(flex: flex.$2, child: right),
          ],
        );
      },
    );
  }
}

/// Conversion des indicateurs de démonstration.
List<OpsKpi> opsKpisOf(List<({String label, String value, String icon, String? note, Tone tone})> data) => [
  for (final k in data) OpsKpi(k.label, k.value, k.icon, note: k.note, noteTone: opsToneOf(k.tone)),
];
