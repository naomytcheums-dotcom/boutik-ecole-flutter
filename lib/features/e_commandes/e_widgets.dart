import 'package:flutter/services.dart';

import '../common/common.dart';
import '../../data/demo/section_e_demo.dart';

export '../../data/demo/section_e_demo.dart';

/// Couleurs propres aux maquettes de la section E (relevées sur les captures).
abstract final class EColors {
  static const tile = Color(0xFFF1EEFB);
  static const soft = Color(0xFFF2EFF6);
  static const line = Color(0xFFE6E1EE);
  static const divider = Color(0xFFF0EDF3);
  static const fieldBorder = Color(0xFFECE8F2);
  static const checkBorder = Color(0xFFDAD5E4);
  static const done = Color(0xFF1F9D6B);
  static const doneLine = Color(0xFFBFE8D6);
  static const pendingLine = Color(0xFFE4E8EE);
  static const noteText = Color(0xFF4A4854);
  static const dangerBorder = Color(0xFFE5484D);
  static const shadow = Color(0x178E79B8);
}

/// Styles de texte de la section E (tailles mesurées sur les maquettes).
abstract final class ETxt {
  static final title = AppText.h2.copyWith(fontSize: 21, fontWeight: FontWeight.w700);
  static final section = AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static final cardTitle = AppText.bodyStrong.copyWith(fontSize: 14, fontWeight: FontWeight.w700);
  static final item = AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600);
  // Rendu à 1x plus maigre que la capture 2x : le « medium » Figma correspond ici au w600.
  static final itemRegular = AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600);
  static final label = AppText.label.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600);
  static final body = AppText.body.copyWith(fontSize: 12.5, color: AppColors.textSecondary);
  static final value = AppText.bodyStrong.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700);
  static final meta = AppText.small.copyWith(fontSize: 11.5);
  static final badge = AppText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
  static final button = AppText.button.copyWith(fontSize: 14.5);
  static final note = AppText.small.copyWith(fontSize: 12, color: EColors.noteText, height: 1.38);
}

/// Gabarit mobile de la section : fond dégradé, en-tête, contenu défilant,
/// panneau blanc d'actions en bas (ou menu « verre liquide »).
class EScaffold extends StatelessWidget {
  const EScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.showBack = true,
    this.showNav = false,
  });

  final String title;
  final List<Widget> children;

  /// Boutons du panneau blanc du bas (1 ou 2).
  final List<Widget>? actions;
  final bool showBack;
  final bool showNav;

  static const panelHeight = 100.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = (showNav ? GlassNavBar.height + 28 : 0) + (actions != null ? panelHeight : 0) + 24.0;
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
                      EHeader(title, showBack: showBack),
                      Expanded(
                        child: ListView(padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset), children: children),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (actions != null) Positioned(left: 0, right: 0, bottom: 0, child: _ActionPanel(actions: actions!)),
            if (showNav)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(padding: EdgeInsets.only(bottom: 13), child: GlassNavBar()),
                ),
              ),
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
          height: EScaffold.panelHeight,
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

/// En-tête « flèche retour + titre gras » des écrans E.
class EHeader extends StatelessWidget {
  const EHeader(this.title, {super.key, this.showBack = true});

  final String title;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(showBack ? 20 : 24, 14, 20, 13),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (showBack) ...[
              RoundIconButton(
                icon: AppIcons.arrowLeft,
                label: 'Retour',
                bordered: false,
                background: Colors.transparent,
                onTap: () => ScreenHeader.back(context),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: ETxt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum EButtonKind { primary, outline, danger }

/// Bouton (54 px) du panneau d'actions.
class EButton extends StatelessWidget {
  const EButton(this.label, {super.key, required this.onPressed, this.kind = EButtonKind.primary});

  final String label;
  final VoidCallback? onPressed;
  final EButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      EButtonKind.primary => (AppColors.ink, Colors.white, null),
      EButtonKind.outline => (Colors.white, AppColors.ink, EColors.line),
      EButtonKind.danger => (Colors.white, AppColors.error, EColors.dangerBorder),
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          shadows: kind == EButtonKind.primary
              ? const [BoxShadow(color: Color(0x24111015), blurRadius: 20, offset: Offset(0, 6))]
              : null,
        ),
        child: Material(
          color: bg,
          shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border, width: 1.5)),
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
                    child: Text(label, maxLines: 1, style: ETxt.button.copyWith(color: fg)),
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
class ECard extends StatelessWidget {
  const ECard({super.key, required this.child, this.padding = EdgeInsets.zero, this.color = Colors.white});

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: EColors.shadow, blurRadius: 32, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Filet de séparation des listes en carte.
class EDivider extends StatelessWidget {
  const EDivider({super.key, this.indent = 16, this.endIndent = 16});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.only(left: indent, right: endIndent),
    color: EColors.divider,
  );
}

/// Tuile d'icône carrée (40 px, fond lavande ou blanc).
class ETile extends StatelessWidget {
  const ETile(this.icon, {super.key, this.size = 40, this.color = EColors.tile, this.iconSize = 20});

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

/// Vignette photo carrée 50 px.
class EThumb extends StatelessWidget {
  const EThumb(this.image, {super.key, this.label});

  final String image;
  final String? label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 50,
      height: 50,
      child: Image.asset(
        image,
        fit: BoxFit.cover,
        semanticLabel: label,
        excludeFromSemantics: label == null,
        errorBuilder: (_, _, _) => const ColoredBox(color: EColors.soft),
      ),
    ),
  );
}

/// Ligne de liste dans une carte : visuel à gauche, titre/sous-titre, élément à droite.
class ERow extends StatelessWidget {
  const ERow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.height = 66,
    this.titleStyle,
    this.chevron = false,
    this.leftPadding = 12,
    this.rightPadding = 14,
    this.overflowTitle = false,
  });

  final double rightPadding;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;
  final TextStyle? titleStyle;
  final bool chevron;
  final double leftPadding;

  /// Titre non coupé : il passe sous l'élément de droite (comme sur la maquette 48).
  final bool overflowTitle;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
        child: Row(
          children: [
            if (leading != null) ...[leading!, SizedBox(width: leading is EThumb ? 12.5 : 12)],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? ETxt.item,
                    maxLines: 1,
                    softWrap: !overflowTitle,
                    overflow: overflowTitle ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4.5),
                    Text(subtitle!, style: ETxt.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (chevron) ...[const SizedBox(width: 8), const AppIcon(AppIcons.chevronRight, size: 20)],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Lignes « libellé … valeur » séparées par des filets (récapitulatifs).
class EKvList extends StatelessWidget {
  const EKvList({super.key, required this.rows, this.title, this.rowHeight = 34});

  final String? title;
  final List<(String, String)> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return ECard(
      padding: EdgeInsets.fromLTRB(16, title == null ? 3.5 : 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Semantics(header: true, child: Text(title!, style: ETxt.cardTitle)),
            const SizedBox(height: 5.3),
          ],
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const EDivider(indent: 0, endIndent: 0),
            Semantics(
              label: '${rows[i].$1} : ${rows[i].$2}',
              excludeSemantics: true,
              child: SizedBox(
                height: i == 0 ? rowHeight : rowHeight - 1,
                child: Row(
                  children: [
                    Expanded(child: Text(rows[i].$1, style: ETxt.body)),
                    Text(rows[i].$2, style: ETxt.value),
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

/// Encadré d'information lavande : tuile blanche + texte.
class ENote extends StatelessWidget {
  const ENote(this.text, {super.key, required this.icon});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9.5, 16, 9.5),
      decoration: BoxDecoration(color: EColors.soft, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          ETile(icon, size: 32, color: Colors.white, iconSize: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(text, style: ETxt.note),
            ),
          ),
        ],
      ),
    );
  }
}

/// Case à cocher carrée (pleine encre quand cochée, comme sur les maquettes).
class ECheckRow extends StatelessWidget {
  const ECheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.radio = false,
    this.height = 36,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Choix exclusif (motifs) : annoncé comme bouton radio.
  final bool radio;
  final double height;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      inMutuallyExclusiveGroup: radio,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: value ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: value ? null : Border.all(color: EColors.checkBorder, width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: ETxt.body.copyWith(color: EColors.noteText, height: 1.45)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frise verticale de suivi : pastille verte (fait), noire (en cours), blanche (à venir).
class ETimeline extends StatelessWidget {
  const ETimeline({super.key, required this.steps, required this.current, this.pitch = 62});

  final List<ETrackStep> steps;
  final int current;
  final double pitch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            label:
                '${steps[i].title}, ${steps[i].detail}, ${i < current ? 'terminée' : (i == current ? 'en cours' : 'à venir')}',
            excludeSemantics: true,
            child: SizedBox(
              height: i == steps.length - 1 ? 40 : pitch,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        _dot(i),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(width: 2, color: i < current ? EColors.doneLine : EColors.pendingLine),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].title, style: ETxt.item),
                          const SizedBox(height: 2),
                          Text(steps[i].detail, style: ETxt.meta),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot(int i) {
    if (i < current) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(color: EColors.done, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const AppIcon(AppIcons.check, size: 12, color: Colors.white),
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: i == current ? AppColors.ink : Colors.white,
        shape: BoxShape.circle,
        border: i == current ? null : Border.all(color: EColors.line, width: 1.5),
      ),
    );
  }
}

/// Étapes du tunnel d'achat (Panier → Confirmation).
class ECheckoutStepper extends StatelessWidget {
  const ECheckoutStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Étape ${current + 1} sur ${labels.length} : ${labels[current]}',
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        child: LayoutBuilder(
          builder: (context, c) {
            final n = labels.length;
            final step = (c.maxWidth - 40) / (n - 1);
            double cx(int i) => 20 + i * step;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < n - 1; i++)
                  Positioned(
                    left: cx(i),
                    width: step,
                    top: 16,
                    height: 2,
                    child: ColoredBox(color: i < current ? AppColors.ink : EColors.line),
                  ),
                for (var i = 0; i < n; i++)
                  Positioned(left: cx(i) - (i == current ? 17 : 15), top: i == current ? 0 : 2, child: _circle(i)),
                for (var i = 0; i < n; i++)
                  Positioned(
                    left: cx(i) - 50,
                    width: 100,
                    top: 38,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: AppText.small.copyWith(
                        fontSize: 11,
                        color: i == current ? AppColors.ink : AppColors.textSecondary,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _circle(int i) {
    if (i == current) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
      );
    }
    final done = i < current;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: done ? AppColors.ink : Colors.white,
        shape: BoxShape.circle,
        border: done ? null : Border.all(color: EColors.line, width: 1.5),
      ),
      alignment: Alignment.center,
      child: done ? const AppIcon(AppIcons.check, size: 15, color: Colors.white) : null,
    );
  }
}

/// Pastille de statut de commande.
class EStatusBadge extends StatelessWidget {
  const EStatusBadge(this.status, {super.key});

  final EOrderStatus status;

  static String labelOf(EOrderStatus s) => switch (s) {
    EOrderStatus.delivered => 'Livrée',
    EOrderStatus.inProgress => 'En cours',
    EOrderStatus.preparing => 'En préparation',
    EOrderStatus.inTransit => 'En route',
    EOrderStatus.cancelled => 'Annulée',
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      EOrderStatus.delivered => (const Color(0xFFDDF5EC), AppColors.success),
      EOrderStatus.inProgress || EOrderStatus.inTransit => (const Color(0xFFEFEBFA), AppColors.accent),
      EOrderStatus.preparing => (const Color(0xFFEEE9FF), AppColors.warning),
      EOrderStatus.cancelled => (const Color(0xFFFDE6E7), AppColors.error),
    };
    return Container(
      height: 21.5,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(labelOf(status), style: ETxt.badge.copyWith(color: fg)),
    );
  }
}

/// Champ de recherche lavande (45, 49).
class ESearchField extends StatelessWidget {
  const ESearchField({super.key, required this.hint, this.onChanged, this.onFilter, this.controller});

  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: EdgeInsets.only(left: 16, right: onFilter == null ? 16 : 4),
      decoration: const ShapeDecoration(color: EColors.soft, shape: StadiumBorder()),
      child: Row(
        children: [
          const AppIcon(AppIcons.search, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: ETxt.itemRegular,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: ETxt.itemRegular.copyWith(color: AppColors.textSecondary),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onFilter != null)
            RoundIconButton(
              icon: AppIcons.slidersHorizontal,
              label: 'Filtres',
              bordered: false,
              background: Colors.transparent,
              onTap: onFilter,
            ),
        ],
      ),
    );
  }
}

/// Champ de formulaire pilule (41) : libellé au-dessus, icône à gauche, erreur dessous.
class EField extends StatelessWidget {
  const EField({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String icon;
  final TextEditingController? controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Champ en lecture seule ouvrant un sélecteur.
  final VoidCallback? onTap;
  final Widget? trailing;

  static OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(23),
    borderSide: BorderSide(color: c, width: w),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ETxt.label),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: onTap != null,
          onTap: onTap,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: ETxt.itemRegular,
          decoration: InputDecoration(
            hintText: hint,
            // Sur la maquette, le masque du numéro est affiché en encre.
            hintStyle: ETxt.itemRegular,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            errorStyle: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            errorMaxLines: 2,
            prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: AppIcon(icon, size: 20)),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 46),
            suffixIcon: trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Center(widthFactor: 1, heightFactor: 1, child: trailing),
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 46),
            border: _border(EColors.fieldBorder),
            enabledBorder: _border(EColors.fieldBorder),
            focusedBorder: _border(AppColors.ink, 1.5),
            errorBorder: _border(AppColors.error, 1.5),
            focusedErrorBorder: _border(AppColors.error, 1.5),
          ),
        ),
      ],
    );
  }
}
