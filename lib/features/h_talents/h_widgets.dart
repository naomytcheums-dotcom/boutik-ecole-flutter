import '../common/common.dart';

export '../../data/demo/section_h_demo.dart';
export '../g_espace_etudiant/g_widgets.dart' show GOutlineButton, GStepper;
export '../common/common.dart';

/// Lavande des pastilles et vignettes d'icônes de la section.
const hLavender = Color(0xFFEEE9FF);

enum HBadgeKind { success, pending, accent }

/// Pastille de statut (« Disponible », « Occupée », « Postuler »…).
class HBadge extends StatelessWidget {
  const HBadge(this.label, this.kind, {super.key});

  final String label;
  final HBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      HBadgeKind.success => (const Color(0xFFDDF5EC), AppColors.success),
      HBadgeKind.pending => (hLavender, AppColors.warning),
      HBadgeKind.accent => (hLavender, AppColors.accent),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppText.small.copyWith(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Vignette carrée lavande portant une icône (documents, offres).
class HIconTile extends StatelessWidget {
  const HIconTile(this.icon, {super.key, this.size = 40, this.color = const Color(0xFFF1EEFB)});

  final String icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: AppIcon(icon, size: 20),
  );
}

/// Ligne de liste : élément de tête, titre, sous-titre, élément de fin.
class HRow extends StatelessWidget {
  const HRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.height = 66,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppText.small.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte blanche de lignes séparées par un filet aligné sur le texte.
class HListCard extends StatelessWidget {
  const HListCard({super.key, required this.children, this.indent = 62});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: indent, color: const Color(0xFFE9E7EC)),
            c,
          ],
        ],
      ),
    );
  }
}

/// Titre de comptage au-dessus d'une liste (« 32 talents disponibles »).
class HCountTitle extends StatelessWidget {
  const HCountTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 18),
    child: Semantics(
      header: true,
      child: Text(text, style: AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
  );
}

/// En-tête des écrans de la section (titre gras à gauche, action à droite).
class HHeader extends StatelessWidget {
  const HHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 34, 16, 0),
    child: Row(
      children: [
        RoundIconButton(
          icon: AppIcons.arrowLeft,
          label: 'Retour',
          bordered: false,
          background: Colors.transparent,
          onTap: () => ScreenHeader.back(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Page sans menu bas : en-tête de section, contenu défilant, bande blanche d'actions en bas.
class HPage extends StatelessWidget {
  const HPage({super.key, required this.title, required this.children, required this.actions});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: AppScaffold(
              showNav: false,
              header: HHeader(title),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: children,
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 16), Expanded(child: a)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtres « pastilles » horizontaux défilants (noir = actif).
class HChips extends StatelessWidget {
  const HChips({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (i, l) in labels.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: i == selected,
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: ShapeDecoration(
                        color: i == selected ? AppColors.ink : Colors.white.withValues(alpha: .7),
                        shape: const StadiumBorder(),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          l,
                          style: AppText.secondary.copyWith(
                            fontSize: 13.5,
                            color: i == selected ? Colors.white : const Color(0xFF4A4752),
                            fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton icône transparent de l'en-tête.
class HHeaderAction extends StatelessWidget {
  const HHeaderAction(this.icon, {super.key, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      RoundIconButton(icon: icon, label: label, bordered: false, background: Colors.transparent, onTap: onTap);
}

/// Message d'état vide d'une liste filtrée.
class HEmpty extends StatelessWidget {
  const HEmpty(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(28),
    child: Text(text, textAlign: TextAlign.center, style: AppText.secondary),
  );
}
