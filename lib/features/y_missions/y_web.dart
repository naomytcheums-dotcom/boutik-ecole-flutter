import 'y_widgets.dart';

export 'y_widgets.dart';

/// Barre latérale de la console des missions sur mesure (198–200).
const yAdminNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid),
  WebNavItem('Briefs reçus', AppIcons.file, target: '198'),
  WebNavItem('Attribution', AppIcons.users, target: '199'),
  WebNavItem('Missions', AppIcons.layers, target: '200'),
  WebNavItem('Paiements et séquestre', AppIcons.wallet, section: 'Gestion'),
  WebNavItem('Commissions', AppIcons.percent, section: 'Gestion'),
  WebNavItem('Litiges', AppIcons.triangleAlert, section: 'Gestion'),
  WebNavItem('Certificats', AppIcons.circleCheck, section: 'Gestion'),
];

/// Gabarit web de la section : barre latérale admin, compte « Administration ».
class YAdminShell extends StatelessWidget {
  const YAdminShell({super.key, required this.title, required this.selected, required this.children});

  final String title;
  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => WebShell(
    title: title,
    subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
    navItems: yAdminNav,
    selected: selected,
    accountName: 'Administration',
    children: children,
  );
}

/// Carte blanche web arrondie à fine bordure.
class YWebCard extends StatelessWidget {
  const YWebCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 22});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      AppCard(padding: padding, radius: radius, borderColor: const Color(0xFFE9E7E3), child: child);
}

/// Indicateur web : libellé, grande valeur (unité éventuelle), trait de couleur.
class YWebKpi extends StatelessWidget {
  const YWebKpi({super.key, required this.label, required this.value, this.unit, this.bar});

  final String label;
  final String value;
  final String? unit;
  final Color? bar;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label : $value${unit == null ? '' : ' $unit'}',
    excludeSemantics: true,
    child: YWebCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SizedBox(
        height: 60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.secondary.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: value),
                    if (unit != null)
                      TextSpan(
                        text: unit,
                        style: AppText.small.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                style: AppText.h1.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.1),
              ),
            ),
            const Spacer(),
            if (bar != null)
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Rangée d'indicateurs : 4 colonnes en large, 2 en étroit.
class YWebKpiRow extends StatelessWidget {
  const YWebKpiRow(this.kpis, {super.key});

  final List<Widget> kpis;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final perRow = c.maxWidth >= 700 ? kpis.length : 2;
      final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final k in kpis) SizedBox(width: w, child: k)],
      );
    },
  );
}

/// Boutons compacts des cartes web.
class YWebButton extends StatelessWidget {
  const YWebButton(this.label, {super.key, required this.onTap, this.dark = false, this.width});

  final String label;
  final VoidCallback onTap;
  final bool dark;
  final double? width;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: dark ? AppColors.ink : Colors.white,
      shape: StadiumBorder(side: dark ? BorderSide.none : const BorderSide(color: Color(0xFFDAD7DF))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 36,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                label,
                style: AppText.label.copyWith(fontSize: 12.5, color: dark ? Colors.white : AppColors.ink),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pastille de statut web.
class YWebBadge extends StatelessWidget {
  const YWebBadge(this.label, {super.key, required this.tone});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.success => (const Color(0xFFDDF5EC), AppColors.success),
      Tone.warning => (const Color(0xFFF1ECFA), AppColors.warning),
      Tone.accent => (const Color(0xFFEDE9FC), AppColors.accent),
      Tone.error => (AppColors.errorSoft, AppColors.error),
      Tone.neutral => (const Color(0xFFF0EEF3), AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(
        label,
        style: AppText.small.copyWith(fontSize: 11.5, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Barre de progression arrondie.
class YProgress extends StatelessWidget {
  const YProgress(
    this.value, {
    super.key,
    this.color = const Color(0xFF6C4CF1),
    this.height = 6,
    this.track = const Color(0xFFE6E7EC),
  });

  final double value;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) => Semantics(
    value: '${(value * 100).round()} %',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    ),
  );
}
