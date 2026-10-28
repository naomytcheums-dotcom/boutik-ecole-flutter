import '../common/common.dart';

export '../../data/demo/section_d_demo.dart';

/// Couleurs propres aux maquettes de la section D (relevées sur les captures).
abstract final class DColors {
  static const tile = Color(0xFFF1EEFB);
  static const soft = Color(0xFFF1EEF4);
  static const line = Color(0xFFE6E1EE);
  static const divider = Color(0xFFF0EDF3);
  static const fieldBorder = Color(0xFFECE8F2);
  static const done = Color(0xFF1F9D6B);
  static const doneSoft = Color(0xFFE2F5EC);
  static const doneText = Color(0xFF0F7A52);
  static const lowSoft = Color(0xFFEFEAFB);
  static const lowText = Color(0xFF7A4A00);
  static const outSoft = Color(0xFFFDE7E7);
  static const outText = Color(0xFFB42318);
  static const star = Color(0xFFF4B740);
  static const track = Color(0xFFF1EEF4);
  static const shadow = Color(0x178E79B8);
  static const note = Color(0xFFEFEBF4);
  static const noteText = Color(0xFF4A4854);
}

/// Styles de texte de la section D (tailles mesurées sur les maquettes).
abstract final class DTxt {
  static final title = AppText.h2.copyWith(fontSize: 21, fontWeight: FontWeight.w700);
  static final section = AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static final cardTitle = AppText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
  static final item = AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
  static final label = AppText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600);
  static final body = AppText.body.copyWith(fontSize: 13, color: const Color(0xFF55525C), height: 1.69);
  static final kvLabel = AppText.body.copyWith(fontSize: 12.5, color: AppColors.textSecondary);
  static final value = AppText.bodyStrong.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700);
  static final meta = AppText.small.copyWith(fontSize: 11.5);
  static final badge = AppText.label.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600);
  static final button = AppText.button.copyWith(fontSize: 14.5);
  static final note = AppText.small.copyWith(fontSize: 12, color: DColors.noteText, height: 1.4);
}

/// Gabarit mobile de la section : fond dégradé, en-tête retour + titre, contenu défilant,
/// panneau blanc d'actions en bas.
class DScaffold extends StatelessWidget {
  const DScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.headerActions = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  final String title;
  final List<Widget> children;

  /// Boutons du panneau blanc du bas (1 ou 2).
  final List<Widget>? actions;
  final List<Widget> headerActions;
  final EdgeInsets padding;

  static const panelHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = (actions != null ? panelHeight : 0) + 24.0;
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            const Positioned.fill(child: AppBackgroundGlow()),
            SafeArea(
              bottom: false,
              minimum: const EdgeInsets.only(top: 47),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      DHeader(title, actions: headerActions),
                      Expanded(
                        child: ListView(
                          padding: padding.add(EdgeInsets.only(bottom: bottomInset)),
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (actions != null) Positioned(left: 0, right: 0, bottom: 0, child: _ActionPanel(actions: actions!)),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14473556), blurRadius: 24, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: DScaffold.panelHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16.5, 24, 0),
                child: Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 17),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// En-tête « flèche retour + titre gras » (+ icônes d'action à droite).
class DHeader extends StatelessWidget {
  const DHeader(this.title, {super.key, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 17, 13),
      child: SizedBox(
        height: 44,
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
                child: Text(title, style: DTxt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Icône d'action de l'en-tête (44 px, sans fond).
class DHeaderAction extends StatelessWidget {
  const DHeaderAction(this.icon, {super.key, required this.label, required this.onTap, this.color});

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => RoundIconButton(
    icon: icon,
    label: label,
    bordered: false,
    background: Colors.transparent,
    foreground: color ?? AppColors.ink,
    onTap: onTap,
  );
}

enum DButtonKind { primary, outline }

/// Bouton (54 px) du panneau d'actions.
class DButton extends StatelessWidget {
  const DButton(this.label, {super.key, required this.onPressed, this.kind = DButtonKind.primary});

  final String label;
  final VoidCallback? onPressed;
  final DButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final primary = kind == DButtonKind.primary;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          shadows: primary ? const [BoxShadow(color: Color(0x24111015), blurRadius: 20, offset: Offset(0, 6))] : null,
        ),
        child: Material(
          color: primary ? AppColors.ink : Colors.white,
          shape: StadiumBorder(side: primary ? BorderSide.none : const BorderSide(color: DColors.line, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: SizedBox(
              height: 54,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: DTxt.button.copyWith(color: primary ? Colors.white : AppColors.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie (rayon 26) à ombre douce violette.
class DCard extends StatelessWidget {
  const DCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color = Colors.white,
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [BoxShadow(color: DColors.shadow, blurRadius: 32, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Filet de séparation des listes en carte.
class DDivider extends StatelessWidget {
  const DDivider({super.key, this.indent = 16, this.endIndent = 16});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.only(left: indent, right: endIndent),
    color: DColors.divider,
  );
}

/// Titre de bloc (« Variantes », « Formules »…).
class DSectionTitle extends StatelessWidget {
  const DSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(header: true, child: Text(text, style: DTxt.section)),
      ),
      ?trailing,
    ],
  );
}

/// Lien violet « Tout voir → ».
class DLink extends StatelessWidget {
  const DLink(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: DTxt.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            const AppIcon(AppIcons.arrowRight, size: 15),
          ],
        ),
      ),
    ),
  );
}

/// Carte « libellé … valeur » séparés par des filets.
class DKvCard extends StatelessWidget {
  const DKvCard({super.key, required this.rows, this.title, this.rowHeight = 34});

  final String? title;
  final List<(String, String)> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return DCard(
      padding: EdgeInsets.fromLTRB(16, title == null ? 4 : 13, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(header: true, child: Text(title!, style: DTxt.cardTitle)),
            const SizedBox(height: 7),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const DDivider(indent: 0, endIndent: 0),
            Semantics(
              label: '${rows[i].$1} : ${rows[i].$2}',
              excludeSemantics: true,
              child: SizedBox(
                height: i == 0 ? rowHeight : rowHeight - 1,
                child: Row(
                  children: [
                    Text(rows[i].$1, style: DTxt.kvLabel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        rows[i].$2,
                        style: DTxt.value,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pastille de sélection (fond encre si sélectionnée, lavande sinon).
class DChoiceChip extends StatelessWidget {
  const DChoiceChip(this.label, {super.key, required this.selected, required this.onTap, this.height = 34});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: ShapeDecoration(color: selected ? AppColors.ink : DColors.soft, shape: const StadiumBorder()),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: DTxt.label.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF3D3A44),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastille d'état colorée (« En stock », « Rupture »…).
class DBadge extends StatelessWidget {
  const DBadge(this.label, {super.key, required this.background, required this.foreground, this.height = 22});

  final String label;
  final Color background;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 13),
    decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
    child: Center(
      widthFactor: 1,
      child: Text(label, style: DTxt.badge.copyWith(color: foreground)),
    ),
  );
}

/// Tuile d'icône carrée (fond lavande ou blanc).
class DTile extends StatelessWidget {
  const DTile(this.icon, {super.key, this.size = 40, this.color = DColors.tile, this.iconSize = 20});

  final String icon;
  final double size;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * .3)),
    alignment: Alignment.center,
    child: AppIcon(icon, size: iconSize),
  );
}

/// Photo arrondie (repli lavande si l'image manque).
class DPhoto extends StatelessWidget {
  const DPhoto(this.image, {super.key, this.radius = 24, this.label, this.width, this.height, this.alignment});

  final String image;
  final double radius;
  final String? label;
  final double? width;
  final double? height;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        image,
        fit: BoxFit.cover,
        alignment: alignment ?? Alignment.center,
        semanticLabel: label,
        excludeFromSemantics: label == null,
        errorBuilder: (_, _, _) => const ColoredBox(color: DColors.soft),
      ),
    ),
  );
}

/// Avatar rond.
class DAvatar extends StatelessWidget {
  const DAvatar(this.image, {super.key, this.size = 50, this.label});

  final String image;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        image,
        fit: BoxFit.cover,
        semanticLabel: label,
        excludeFromSemantics: label == null,
        errorBuilder: (_, _, _) => const ColoredBox(color: DColors.soft),
      ),
    ),
  );
}

/// Carte résumé (vignette ou avatar, titre, sous-titre, élément à droite).
class DSummaryCard extends StatelessWidget {
  const DSummaryCard({
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
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DTxt.item, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: DTxt.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
    return DCard(
      child: onTap == null
          ? row
          : Semantics(
              button: true,
              child: InkWell(onTap: onTap, child: row),
            ),
    );
  }
}

/// Encadré d'information lavande avec tuile d'icône blanche.
class DNote extends StatelessWidget {
  const DNote({super.key, required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
      decoration: BoxDecoration(color: DColors.note, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          DTile(icon, size: 28, color: Colors.white, iconSize: 16),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: DTxt.note)),
        ],
      ),
    );
  }
}

/// Libellé de champ de formulaire.
class DFieldLabel extends StatelessWidget {
  const DFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4.5),
    child: Text(text, style: DTxt.label),
  );
}

/// Contour blanc arrondi commun aux champs du formulaire.
BoxDecoration dFieldDecoration({bool error = false, double radius = 24}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: error ? AppColors.error : DColors.fieldBorder, width: error ? 1.5 : 1),
  boxShadow: const [BoxShadow(color: Color(0x0F8E79B8), blurRadius: 16, offset: Offset(0, 4))],
);

/// Champ de saisie blanc arrondi (icône facultative) avec message d'erreur sous le champ.
class DTextField extends StatelessWidget {
  const DTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.validator,
    this.lines = 1,
    this.height,
    this.keyboardType,
    this.style,
    this.hintStyle,
  });

  final TextEditingController controller;

  /// Libellé accessible du champ.
  final String label;
  final String? hint;
  final String? icon;
  final FormFieldValidator<String>? validator;
  final int lines;
  final double? height;
  final TextInputType? keyboardType;
  final TextStyle? style;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final multi = lines > 1;
    return FormField<String>(
      validator: (_) => validator?.call(controller.text),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: height ?? (multi ? null : 46),
            decoration: dFieldDecoration(error: state.hasError, radius: multi ? 24 : 23),
            padding: multi ? const EdgeInsets.fromLTRB(16, 15, 16, 13) : const EdgeInsets.only(left: 16, right: 16),
            child: Row(
              crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[AppIcon(icon!, size: 18), const SizedBox(width: 14)],
                Expanded(
                  child: Semantics(
                    label: label,
                    textField: true,
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType ?? (multi ? TextInputType.multiline : TextInputType.text),
                      minLines: multi ? lines : 1,
                      maxLines: multi ? lines : 1,
                      style: style ?? DTxt.item.copyWith(fontWeight: FontWeight.w500, height: 1.5),
                      onChanged: (v) {
                        state.didChange(v);
                        if (state.hasError) state.validate();
                      },
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle:
                            hintStyle ??
                            DTxt.item.copyWith(
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6E6B76),
                              height: 1.5,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6),
              child: Text(state.errorText!, style: DTxt.meta.copyWith(color: AppColors.error)),
            ),
        ],
      ),
    );
  }
}

/// Liste déroulante simulée : ouvre une feuille de choix en bas d'écran.
class DSelectField extends StatelessWidget {
  const DSelectField({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String icon;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Semantics(header: true, child: Text(label, style: DTxt.section)),
              ),
              for (final (i, o) in options.indexed)
                Semantics(
                  button: true,
                  selected: i == selected,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(ctx).pop(i),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(child: Text(o, style: DTxt.item)),
                          if (i == selected) const AppIcon(AppIcons.check, size: 18, color: AppColors.accent),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label : ${options[selected]}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          height: 46,
          decoration: dFieldDecoration(radius: 23),
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Row(
            children: [
              AppIcon(icon, size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Text(options[selected], style: DTxt.item.copyWith(fontWeight: FontWeight.w500)),
              ),
              const AppIcon(AppIcons.chevronDown, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
