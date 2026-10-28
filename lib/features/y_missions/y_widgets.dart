import '../g_espace_etudiant/g_widgets.dart';

export '../../data/demo/section_y_demo.dart';
export '../g_espace_etudiant/g_widgets.dart';

const yTileColor = Color(0xFFF1EEFB);
const yNoteColor = Color(0xFFEFECF5);
const yLine = Color(0xFFE6E3EC);
const yDivider = Color(0xFFEDEBF0);

/// Frise horizontale d'étapes : premier et dernier ronds calés sur les marges (191, 204, 205).
class YStepper extends StatelessWidget {
  const YStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Étape ${current + 1} sur ${labels.length} : ${labels[current]}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          const big = 34.0, small = 30.0, edge = 20.0;
          final n = labels.length;
          final step = (c.maxWidth - 2 * edge) / (n - 1);
          double cx(int i) => edge + step * i;
          return SizedBox(
            height: 55,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: cx(0),
                  width: cx(n - 1) - cx(0),
                  top: 12,
                  child: Container(height: 2, color: yLine),
                ),
                if (current > 0)
                  Positioned(
                    left: cx(0),
                    width: cx(current) - cx(0),
                    top: 12,
                    child: Container(height: 2, color: AppColors.ink),
                  ),
                for (var i = 0; i < n; i++) ...[
                  Positioned(
                    left: cx(i) - (i == current ? big : small) / 2,
                    top: 13 - (i == current ? big : small) / 2,
                    child: Container(
                      width: i == current ? big : small,
                      height: i == current ? big : small,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? AppColors.ink : Colors.white,
                        border: i <= current ? null : Border.all(color: yLine, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: i < current ? const AppIcon(AppIcons.check, size: 15, color: Colors.white) : null,
                    ),
                  ),
                  Positioned(
                    left: cx(i) - 45,
                    width: 90,
                    top: 33,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(
                        fontSize: 12,
                        color: i == current ? AppColors.ink : AppColors.textSecondary,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Pictogramme sur carré lavande arrondi.
class YIconTile extends StatelessWidget {
  const YIconTile(this.icon, {super.key, this.size = 40, this.color = yTileColor, this.iconColor = AppColors.ink});

  final String icon;
  final double size;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: AppIcon(icon, size: 20, color: iconColor),
  );
}

/// Ligne « pictogramme · titre · sous-titre · élément à droite ».
class YIconRow extends StatelessWidget {
  const YIconRow({
    super.key,
    this.icon = '',
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.height = 66,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: height,
      child: Row(
        children: [
          leading ?? YIconTile(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppText.small.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Carte blanche arrondie sans bordure, lignes séparées par un filet.
class YCard extends StatelessWidget {
  const YCard({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 12)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: padding,
    radius: 26,
    borderColor: null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: yDivider),
          c,
        ],
      ],
    ),
  );
}

/// Carte « titre + lignes libellé / valeur » (devis, récapitulatif, revenus).
class YKvCard extends StatelessWidget {
  const YKvCard({super.key, this.title, required this.rows, this.rowHeight = 34});

  final String? title;
  final List<(String, String)> rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.fromLTRB(16, title == null ? 6 : 14, 16, title == null ? 8 : 12),
      radius: 26,
      borderColor: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(header: true, child: Text(title!, style: AppText.bodyStrong.copyWith(fontSize: 15))),
            ),
          for (final (i, (l, v)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: yDivider),
            Semantics(
              label: '$l : $v',
              excludeSemantics: true,
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  children: [
                    Expanded(child: Text(l, style: AppText.secondary.copyWith(fontSize: 13))),
                    Text(v, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
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

/// Encadré lavande : pictogramme sur pastille blanche, texte gris.
class YNote extends StatelessWidget {
  const YNote(this.text, {super.key, required this.icon});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
    decoration: BoxDecoration(color: yNoteColor, borderRadius: BorderRadius.circular(20)),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppText.small.copyWith(fontSize: 12, height: 1.45, color: const Color(0xFF55525C))),
        ),
      ],
    ),
  );
}

/// Pastille de statut (fond doux).
class YBadge extends StatelessWidget {
  const YBadge(this.label, this.tone, {super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.success => (const Color(0xFFDDF5EC), AppColors.success),
      Tone.warning => (const Color(0xFFEFEAF8), AppColors.warning),
      Tone.error => (AppColors.errorSoft, AppColors.error),
      Tone.accent => (const Color(0xFFEDE9FC), AppColors.accent),
      Tone.neutral => (Colors.white, AppColors.ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(
        label,
        style: AppText.small.copyWith(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bandeau photo arrondi avec dégradé sombre, titre et sous-titre en blanc.
class YHero extends StatelessWidget {
  const YHero({super.key, this.image, required this.title, required this.subtitle, this.height = 160, this.topAspect});

  /// Sans photo : dégradé gris (194).
  final String? image;
  final String title;
  final String subtitle;
  final double height;

  /// Rapport largeur / hauteur d'une photo calée en haut à pleine largeur : le bas est complété en fondu sombre.
  final double? topAspect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image == null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE4E3E6), Color(0xFF9A989D), Color(0xFF3F3D42)],
                    ),
                  ),
                )
              else if (topAspect != null)
                LayoutBuilder(
                  builder: (context, c) {
                    final h = c.maxWidth / topAspect!;
                    return ColoredBox(
                      color: const Color(0xFF362D30),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: h,
                            child: Image.asset(image!, fit: BoxFit.fill),
                          ),
                          Positioned(
                            top: h - 36,
                            left: 0,
                            right: 0,
                            height: 37,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00362D30), Color(0xFF362D30)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Image.asset(image!, fit: BoxFit.cover),
              if (image != null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [.35, 1],
                      colors: [Color(0x00000000), Color(0xC0141216)],
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.h3.copyWith(color: Colors.white, fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppText.small.copyWith(color: Colors.white.withValues(alpha: .9))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte de 3 compteurs séparés par des filets verticaux.
class YStatsCard extends StatelessWidget {
  const YStatsCard(this.stats, {super.key});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 14),
    radius: 26,
    borderColor: null,
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (final (i, (v, l)) in stats.indexed) ...[
            if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: yDivider),
            Expanded(
              child: Semantics(
                label: '$l : $v',
                excludeSemantics: true,
                child: Column(
                  children: [
                    Text(v, style: AppText.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(l, style: AppText.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Étape d'une frise verticale : 0 faite, 1 en cours, 2 à venir.
class YVStep {
  const YVStep(this.title, this.detail, this.state, {this.proof = false});

  final String title;
  final String detail;
  final int state;
  final bool proof;
}

/// Frise verticale : coches vertes, disque noir pour l'étape en cours, cercles blancs ensuite.
class YVTimeline extends StatelessWidget {
  const YVTimeline({super.key, required this.steps, this.spacing = 62, this.onProof});

  final List<YVStep> steps;
  final double spacing;
  final ValueChanged<int>? onProof;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, s) in steps.indexed)
          SizedBox(
            height: i == steps.length - 1 ? 44 : spacing,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      if (i < steps.length - 1)
                        Positioned(
                          top: 10,
                          bottom: -10,
                          child: Container(width: 2, color: s.state == 0 ? const Color(0xFFBFE5D2) : yLine),
                        ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (s.state) {
                            0 => const Color(0xFF1F9D6B),
                            1 => AppColors.ink,
                            _ => Colors.white,
                          },
                          border: s.state == 2 ? Border.all(color: yLine, width: 1.5) : null,
                        ),
                        alignment: Alignment.center,
                        child: s.state == 0 ? const AppIcon(AppIcons.check, size: 12, color: Colors.white) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Semantics(
                    label: '${s.title}, ${s.detail}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(s.detail, style: AppText.small.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                if (s.proof)
                  Padding(
                    padding: const EdgeInsets.only(right: 66),
                    child: Semantics(
                      button: true,
                      label: 'Voir la preuve : ${s.title}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => onProof?.call(i),
                        child: Container(
                          margin: const EdgeInsets.only(top: 2),
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                            child: Text(
                              'Preuve',
                              style: AppText.small.copyWith(
                                fontSize: 10.5,
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Titre de bloc (« Étapes de validation »).
class YTitle extends StatelessWidget {
  const YTitle(this.text, {super.key, this.top = 20, this.bottom = 12, this.trailing});

  final String text;
  final double top;
  final double bottom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(text, style: AppText.h3.copyWith(fontSize: 16))),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Libellé de champ de formulaire.
class YLabel extends StatelessWidget {
  const YLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: AppText.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
  );
}

/// Champ blanc arrondi (pilule) : pictogramme, valeur, chevron éventuel.
class YPillValue extends StatelessWidget {
  const YPillValue({super.key, required this.icon, required this.value, this.onTap, this.chevron = false, this.label});

  final String icon;
  final String value;
  final VoidCallback? onTap;
  final bool chevron;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: label == null ? value : '$label : $value',
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              const SizedBox(width: 16),
              AppIcon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(value, style: AppText.body.copyWith(color: AppColors.ink, fontSize: 14)),
              ),
              if (chevron) const AppIcon(AppIcons.chevronDown, size: 20),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Grande zone de texte blanche arrondie (description d'un besoin, d'une preuve).
class YTextArea extends StatelessWidget {
  const YTextArea({super.key, this.controller, this.hint, this.validator, this.label});

  final TextEditingController? controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final String? label;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: c == Colors.transparent ? BorderSide.none : BorderSide(color: c, width: 1.5),
    );
    return Semantics(
      label: label,
      textField: true,
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: null,
        minLines: 3,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: AppText.body.copyWith(color: AppColors.ink, fontSize: 13.5, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 3,
          hintStyle: AppText.body.copyWith(fontSize: 14, height: 1.55, color: const Color(0xFF77747F)),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
          border: border(Colors.transparent),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(AppColors.accent),
          errorBorder: border(AppColors.error),
          focusedErrorBorder: border(AppColors.error),
          errorStyle: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Bouton blanc bordé dont le libellé reste sur une ligne (réduit si nécessaire).
class YOutlineButton extends StatelessWidget {
  const YOutlineButton(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFDAD7DF))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: AppText.button.copyWith(color: AppColors.ink)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Onglets « pastilles » (noir pour l'onglet actif, lavande sinon).
class YTabs extends StatelessWidget {
  const YTabs({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
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
                  widthFactor: 1,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    decoration: ShapeDecoration(
                      color: i == selected ? AppColors.ink : const Color(0xFFEDEBF3),
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

/// Écran racine avec titre à gauche et menu bas (201, 203, 204).
class YRootPage extends StatelessWidget {
  const YRootPage({super.key, required this.title, required this.children, this.showBack = false});

  final String title;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) => AppScaffold(
    header: showBack
        ? Padding(padding: const EdgeInsets.only(top: 22), child: TitleHeader(title))
        : Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(title, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    children: children,
  );
}

/// Vignette photo arrondie de liste.
class YThumb extends StatelessWidget {
  const YThumb(this.image, {super.key, this.size = 50});

  final String image;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.asset(image, width: size, height: size, fit: BoxFit.cover),
  );
}
