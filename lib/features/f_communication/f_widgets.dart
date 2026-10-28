import 'package:flutter/services.dart';

import '../common/common.dart';
import '../../data/demo/section_f_demo.dart';

export '../../data/demo/section_f_demo.dart';

/// Couleurs propres aux maquettes de la section F (relevées sur les captures).
abstract final class FColors {
  static const tile = Color(0xFFF1EEFB);
  static const soft = Color(0xFFF2EFF6);
  static const badge = Color(0xFFEFEBFA);
  static const line = Color(0xFFE6E1EE);
  static const divider = Color(0xFFF0EDF3);
  static const done = Color(0xFF1F9D6B);
  static const doneLine = Color(0xFFBFE8D6);
  static const pendingLine = Color(0xFFE4E8EE);
  static const bodyText = Color(0xFF4A4854);
  static const successSoft = Color(0xFFDDF5EC);
  static const shadow = Color(0x178E79B8);
}

/// Styles de texte de la section F (tailles mesurées sur les maquettes).
abstract final class FTxt {
  static final title = AppText.h2.copyWith(fontSize: 21.4, fontWeight: FontWeight.w700);
  static final section = AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static final item = AppText.body.copyWith(fontSize: 13.8, fontWeight: FontWeight.w600);
  static final meta = AppText.small.copyWith(fontSize: 11.7);
  static final body = AppText.body.copyWith(fontSize: 12.5, color: AppColors.textSecondary);
  static final value = AppText.bodyStrong.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700);
  static final badge = AppText.label.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
  static final chip = AppText.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500);
  static final link = AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent);
  static final paragraph = AppText.body.copyWith(fontSize: 13.1, color: FColors.bodyText, height: 1.53);
  static final bubble = AppText.body.copyWith(fontSize: 12.5, height: 1.44);
  static final time = AppText.small.copyWith(fontSize: 9.8);
  static final subtitle = AppText.small.copyWith(fontSize: 12.1, height: 1.15);
  static final button = AppText.button.copyWith(fontSize: 14.5);
  static final field = AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500);
}

/// Gabarit mobile de la section : fond dégradé, en-tête, bloc épinglé, contenu défilant,
/// et en bas : panneau blanc d'actions, barre de saisie ou menu « verre liquide ».
class FScaffold extends StatelessWidget {
  const FScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.pinned,
    this.actions,
    this.composer,
    this.showNav = false,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  /// Bloc fixe sous l'en-tête (carte de contexte d'une conversation).
  final Widget? pinned;

  /// Boutons du panneau blanc du bas (1 ou 2).
  final List<Widget>? actions;

  /// Barre de saisie flottante (conversations).
  final Widget? composer;
  final bool showNav;
  final ScrollController? controller;

  static const panelHeight = 100.0;
  static const composerHeight = 55.0;
  static const composerBottom = 41.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        (showNav ? GlassNavBar.height + 28 : 0) +
        (actions != null ? panelHeight : 0) +
        (composer != null ? composerHeight + composerBottom : 0) +
        24.0;
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      resizeToAvoidBottomInset: composer != null,
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
                      FHeader(title, subtitle: subtitle, trailing: trailing),
                      if (pinned != null) Padding(padding: const EdgeInsets.fromLTRB(24, 2, 24, 0), child: pinned),
                      Expanded(
                        child: ListView(
                          controller: controller,
                          padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset),
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (actions != null) Positioned(left: 0, right: 0, bottom: 0, child: _ActionPanel(actions: actions!)),
            if (composer != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, composerBottom), child: composer),
                    ),
                  ),
                ),
              ),
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
          height: FScaffold.panelHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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

/// En-tête « flèche retour + titre gras » (+ sous-titre et action à droite).
class FHeader extends StatelessWidget {
  const FHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(title, style: FTxt.title, maxLines: 1),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, trailing == null ? 14 : 16, 13),
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
                child: subtitle == null
                    ? Align(alignment: Alignment.centerLeft, child: titleText)
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 8.4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                titleText,
                                Text(subtitle!, style: FTxt.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Bouton icône transparent (44 px) de l'en-tête.
class FHeaderButton extends StatelessWidget {
  const FHeaderButton(this.icon, {super.key, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Center(child: AppIcon(icon, size: 23))),
      ),
    );
  }
}

enum FButtonKind { primary, outline }

/// Bouton (54 px) du panneau d'actions.
class FButton extends StatelessWidget {
  const FButton(this.label, {super.key, required this.onPressed, this.kind = FButtonKind.primary});

  final String label;
  final VoidCallback? onPressed;
  final FButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final primary = kind == FButtonKind.primary;
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
          shape: StadiumBorder(side: primary ? BorderSide.none : const BorderSide(color: FColors.line, width: 1.5)),
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
                      style: FTxt.button.copyWith(color: primary ? Colors.white : AppColors.ink),
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
class FCard extends StatelessWidget {
  const FCard({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: FColors.shadow, blurRadius: 32, offset: Offset(0, 6))],
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

/// Carte contenant des lignes séparées par des filets (alignés sur le texte).
class FCardList extends StatelessWidget {
  const FCardList({super.key, required this.children, this.dividerIndent = 16});

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    // Filets superposés en haut de chaque ligne : n lignes = n × 66 px, comme sur la maquette.
    return FCard(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            if (i == 0)
              children[i]
            else
              Stack(
                children: [
                  children[i],
                  Positioned(
                    top: 0,
                    left: dividerIndent,
                    right: 12,
                    height: 1,
                    child: const IgnorePointer(child: ColoredBox(color: FColors.divider)),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// Tuile d'icône carrée (40 px, fond lavande).
class FTile extends StatelessWidget {
  const FTile(this.icon, {super.key, this.color = AppColors.ink});

  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: FColors.tile, borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: AppIcon(icon, size: 20, color: color),
  );
}

/// Photo carrée arrondie (50 px) ou ronde (avatar).
class FPhoto extends StatelessWidget {
  const FPhoto(this.image, {super.key, this.round = false, this.alignment = Alignment.center});

  final String image;
  final bool round;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final img = SizedBox(
      width: 50,
      height: 50,
      child: Image.asset(
        image,
        fit: BoxFit.cover,
        alignment: alignment,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const ColoredBox(color: FColors.soft),
      ),
    );
    return round ? ClipOval(child: img) : ClipRRect(borderRadius: BorderRadius.circular(12), child: img);
  }
}

/// Ligne de liste (66 px) : visuel, titre/sous-titre, élément à droite.
class FRow extends StatelessWidget {
  const FRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.leftPadding = 12,
    this.rightPadding = 14,
    this.semanticLabel,
    this.trailingGap = 8,
  });

  /// Espace entre le texte et l'élément de droite.
  final double trailingGap;

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final double leftPadding;
  final double rightPadding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 66,
      child: Padding(
        padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Padding(
                // Bloc texte remonté de 2 px : centrage optique relevé sur la maquette.
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: FTxt.item, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5.75),
                      Text(subtitle!, style: FTxt.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[SizedBox(width: trailingGap), trailing!],
            if (chevron) ...[const SizedBox(width: 8), const AppIcon(AppIcons.chevronRight, size: 20)],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Pastille de texte (« Nouveau », « Voir », « Ouvert », compteur).
class FBadge extends StatelessWidget {
  const FBadge(
    this.label, {
    super.key,
    this.background = FColors.badge,
    this.foreground = AppColors.accent,
    this.height = 20,
    this.padding = 10,
    this.style,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double height;
  final double padding;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    constraints: BoxConstraints(minWidth: height + 4.5),
    padding: EdgeInsets.symmetric(horizontal: padding),
    alignment: Alignment.center,
    decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
    child: Text(label, maxLines: 1, style: (style ?? FTxt.badge).copyWith(color: foreground)),
  );
}

/// Titre de groupe (« Aujourd’hui », « Notifications ») avec lien optionnel à droite.
class FSectionTitle extends StatelessWidget {
  const FSectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Semantics(header: true, child: Text(title, style: FTxt.section));
    if (action == null) return text;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(child: text),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action!, style: FTxt.link),
                    const AppIcon(AppIcons.arrowRight, size: 17),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille de filtre (34 px visibles, zone tactile de 44 px).
class FChip extends StatelessWidget {
  const FChip({super.key, required this.label, required this.selected, required this.onTap, this.minWidth = 0});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 34,
              constraints: BoxConstraints(minWidth: minWidth),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: ShapeDecoration(color: selected ? AppColors.ink : FColors.soft, shape: const StadiumBorder()),
              child: Text(
                label,
                maxLines: 1,
                style: FTxt.chip.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interrupteur 42 × 24 des préférences (zone tactile 44 px).
class FSwitch extends StatelessWidget {
  const FSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: ShapeDecoration(color: value ? AppColors.ink : FColors.line, shape: const StadiumBorder()),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ de recherche lavande (52).
class FSearchField extends StatelessWidget {
  const FSearchField({super.key, required this.hint, this.onChanged});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const ShapeDecoration(color: FColors.soft, shape: StadiumBorder()),
      child: Row(
        children: [
          const AppIcon(AppIcons.search, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: FTxt.item,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: FTxt.item.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frise verticale de suivi : pastille verte (fait), noire (en cours), blanche (à venir).
class FTimeline extends StatelessWidget {
  const FTimeline({super.key, required this.steps, required this.current, this.pitch = 62});

  final List<FStep> steps;
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
                            child: Container(width: 2, color: i < current ? FColors.doneLine : FColors.pendingLine),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].title, style: FTxt.item),
                          const SizedBox(height: 2),
                          Text(steps[i].detail, style: FTxt.meta),
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
        decoration: const BoxDecoration(color: FColors.done, shape: BoxShape.circle),
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
        border: i == current ? null : Border.all(color: FColors.line, width: 1.5),
      ),
    );
  }
}

/// Lignes « libellé … valeur » séparées par des filets.
class FKvList extends StatelessWidget {
  const FKvList({super.key, required this.rows, this.rowHeight = 34});

  final List<(String, String)> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return FCard(
      padding: const EdgeInsets.fromLTRB(16, 3.5, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: FColors.divider),
            Semantics(
              label: '${rows[i].$1} : ${rows[i].$2}',
              excludeSemantics: true,
              child: SizedBox(
                height: i == 0 ? rowHeight : rowHeight - 1,
                child: Row(
                  children: [
                    Expanded(child: Text(rows[i].$1, style: FTxt.body)),
                    Text(rows[i].$2, style: FTxt.value),
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

/// Carte de contexte d'une conversation (article, commande, besoin d'entreprise).
class FContextCardView extends StatelessWidget {
  const FContextCardView(this.card, {super.key, this.onOpen});

  final FContextCard card;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (card.action != null) {
      trailing = Semantics(
        button: true,
        label: '${card.action} ${card.title}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(card.action!, style: AppText.bodyStrong.copyWith(fontSize: 13.8)),
            ),
          ),
        ),
      );
    } else if (card.badge != null) {
      final success = card.badgeTone == FBadgeTone.success;
      final badge = FBadge(
        card.badge!,
        height: 21.5,
        padding: 11,
        background: success ? FColors.successSoft : FColors.badge,
        foreground: success ? AppColors.success : AppColors.accent,
        style: FTxt.badge.copyWith(fontSize: 12),
      );
      trailing = onOpen == null
          ? badge
          : Semantics(
              button: true,
              label: '${card.badge} ${card.title}',
              excludeSemantics: true,
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(height: 44, child: Center(widthFactor: 1, child: badge)),
              ),
            );
    }
    return FCard(
      child: FRow(
        title: card.title,
        subtitle: card.detail,
        rightPadding: card.action != null ? 16 : 14,
        leading: card.image != null ? FPhoto(card.image!) : FTile(card.icon ?? AppIcons.info),
        trailing: trailing,
      ),
    );
  }
}

/// Bulle de message + heure.
class FBubble extends StatelessWidget {
  const FBubble(this.message, {super.key});

  final FMessage message;

  static const width = 246.0;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Semantics(
      label: '${mine ? 'Vous' : 'Message reçu'}, ${message.time} : ${message.text}',
      excludeSemantics: true,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10.75),
              decoration: BoxDecoration(
                color: mine ? AppColors.ink : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: mine ? null : const [BoxShadow(color: FColors.shadow, blurRadius: 24, offset: Offset(0, 4))],
              ),
              child: Text(
                message.text,
                style: FTxt.bubble.copyWith(
                  color: mine ? Colors.white : AppColors.ink,
                  // Texte blanc sur encre : graisse régulière (il paraît plus gras à taille égale).
                  fontWeight: mine ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(message.time, style: FTxt.time),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de saisie d'une conversation : pièce jointe, texte, photo, micro / envoi.
class FComposer extends StatelessWidget {
  const FComposer({
    super.key,
    required this.hint,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onCamera,
    required this.onVoice,
  });

  final String hint;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onCamera;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: FScaffold.composerHeight,
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: .82),
        shape: const StadiumBorder(side: BorderSide(color: Colors.white)),
        shadows: const [BoxShadow(color: Color(0x1A8E79B8), blurRadius: 28, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 5.5),
          _RoundAction(
            label: 'Joindre un fichier',
            onTap: onAttach,
            child: Container(
              width: 37,
              height: 37,
              decoration: const BoxDecoration(color: FColors.tile, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.paperclip, size: 21),
            ),
          ),
          const SizedBox(width: 6.5),
          Expanded(
            child: TextField(
              controller: controller,
              style: FTxt.field.copyWith(color: AppColors.ink),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: FTxt.field.copyWith(color: AppColors.textSecondary),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _RoundAction(label: 'Prendre une photo', onTap: onCamera, child: const AppIcon(AppIcons.camera, size: 22)),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) {
              final canSend = v.text.trim().isNotEmpty;
              return _RoundAction(
                label: canSend ? 'Envoyer' : 'Message vocal',
                onTap: canSend ? onSend : onVoice,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: AppIcon(canSend ? AppIcons.send : AppIcons.mic, size: canSend ? 19 : 21, color: Colors.white),
                ),
              );
            },
          ),
          const SizedBox(width: 5),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 44, height: 44, child: Center(child: child)),
    ),
  );
}

/// Fil de conversation (53–55) : carte de contexte épinglée, bulles, barre de saisie.
class FChatView extends StatefulWidget {
  const FChatView({super.key, required this.conversation, this.trailing, this.onOpenCard});

  final FConversation conversation;
  final Widget? trailing;
  final VoidCallback? onOpenCard;

  @override
  State<FChatView> createState() => _FChatViewState();
}

class _FChatViewState extends State<FChatView> {
  late final List<FMessage> _messages = [...widget.conversation.messages];
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    String two(int n) => n.toString().padLeft(2, '0');
    setState(() => _messages.add(FMessage(text, '${two(now.hour)}:${two(now.minute)}', mine: true)));
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    return FScaffold(
      title: c.title ?? c.name,
      subtitle: c.status,
      trailing: widget.trailing,
      controller: _scroll,
      pinned: c.card == null ? null : FContextCardView(c.card!, onOpen: widget.onOpenCard),
      composer: FComposer(
        hint: c.composerHint,
        controller: _controller,
        onSend: _send,
        onAttach: () => context.toast('Pièces jointes : photo, PDF ou document (10 Mo max).'),
        onCamera: () => context.toast('Appareil photo indisponible en démonstration.'),
        onVoice: () => context.toast('Maintenez le micro pour enregistrer un message vocal.'),
      ),
      children: [
        const SizedBox(height: 14),
        if (_messages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text('Aucun message pour le moment.', style: FTxt.body, textAlign: TextAlign.center),
          ),
        for (final (i, m) in _messages.indexed) ...[if (i > 0) const SizedBox(height: 8.5), FBubble(m)],
      ],
    );
  }
}
