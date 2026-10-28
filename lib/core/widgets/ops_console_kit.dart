import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Kit des consoles web d'exploitation (administration globale, finance, kiosques).
/// Couleurs relevées sur les maquettes 127–147 ; textes rouges assombris pour un contraste ≥ 4,5:1.
abstract final class OpsColors {
  static const lavender = Color(0xFFF2EFF6);
  static const tableHeader = Color(0xFFF4F1F8);
  static const iconTile = Color(0xFFF1EEFB);
  static const greyChip = Color(0xFFF1EFEC);
  static const underline = Color(0xFF6A4DFF);
  static const purpleDeep = Color(0xFF4B1D8F);
  static const purple = Color(0xFF8A3FD0);
  static const danger = Color(0xFFC42B32);
}

/// Tonalités des badges d'état des consoles.
enum OpsTone { success, danger, pending, info, neutral, lime, grey }

(Color, Color) opsToneColors(OpsTone tone) => switch (tone) {
  OpsTone.success => (const Color(0xFFDDF5EC), AppColors.success),
  OpsTone.danger => (const Color(0xFFFDE6E7), OpsColors.danger),
  OpsTone.pending => (const Color(0xFFEEE9FF), AppColors.warning),
  OpsTone.info => (const Color(0xFFEFEBFA), AppColors.accent),
  OpsTone.neutral => (const Color(0xFFF1EFEC), const Color(0xFF4A4752)),
  OpsTone.lime => (const Color(0xFFE5F6D3), const Color(0xFF3C6A12)),
  OpsTone.grey => (const Color(0xFFEFEEEC), const Color(0xFF6D6A64)),
};

/// Couleur de texte seule (notes sous les indicateurs).
Color opsToneText(OpsTone tone) => opsToneColors(tone).$2;

/// Badge d'état arrondi (« Actif », « Urgent », « À vérifier »…).
class OpsBadge extends StatelessWidget {
  const OpsBadge(this.label, {super.key, this.tone = OpsTone.neutral, this.onTap, this.minWidth = 0});

  final String label;
  final OpsTone tone;
  final VoidCallback? onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = opsToneColors(tone);
    final badge = Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.small.copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
    );
    if (onTap == null) return badge;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          child: Center(widthFactor: 1, child: badge),
        ),
      ),
    );
  }
}

/// Carte blanche des consoles (rayon 24, bord léger).
class OpsCard extends StatelessWidget {
  const OpsCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.color = Colors.white});

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

/// Indicateur chiffré avec pictogramme en haut à droite et note colorée optionnelle.
class OpsKpi {
  const OpsKpi(this.label, this.value, this.icon, {this.note, this.noteTone = OpsTone.success});

  final String label;
  final String value;
  final String icon;
  final String? note;
  final OpsTone noteTone;
}

class OpsKpiRow extends StatelessWidget {
  const OpsKpiRow(this.kpis, {super.key});

  final List<OpsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        var n = kpis.length;
        while (n > 1 && (c.maxWidth - gap * (n - 1)) / n < 170) {
          n--;
        }
        final w = (c.maxWidth - gap * (n - 1)) / n;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final k in kpis) SizedBox(width: w, child: _KpiCard(k))],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.k);

  final OpsKpi k;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${k.label} : ${k.value}${k.note == null ? '' : ', ${k.note}'}',
      excludeSemantics: true,
      child: OpsCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: SizedBox(
          height: 66,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Text(
                      k.label,
                      style: AppText.secondary.copyWith(color: const Color(0xFF55525C)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(k.value, style: AppText.h2.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2)),
                  ),
                  if (k.note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      k.note!,
                      style: AppText.small.copyWith(color: opsToneText(k.noteTone), fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              Positioned(right: 0, top: 0, child: OpsIconTile(k.icon, size: 28, iconSize: 15, radius: 8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pictogramme sur pastille lavande arrondie.
class OpsIconTile extends StatelessWidget {
  const OpsIconTile(this.icon, {super.key, this.size = 40, this.iconSize = 20, this.radius = 12});

  final String icon;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: OpsColors.iconTile, borderRadius: BorderRadius.circular(radius)),
      alignment: Alignment.center,
      child: AppIcon(icon, size: iconSize),
    );
  }
}

/// Tableau à en-tête lavande : lignes séparées par un filet, colonnes proportionnelles.
class OpsTable extends StatelessWidget {
  const OpsTable({
    super.key,
    required this.columns,
    required this.rows,
    this.flex,
    this.emptyLabel = 'Aucun élément à afficher.',
    this.minWidth = 620,
    this.rowHeight = 44,
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final String emptyLabel;
  final double minWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    Widget line(List<Widget> cells) => Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: flex?[i] ?? 1,
            child: Align(alignment: Alignment.centerLeft, child: cells[i]),
          ),
      ],
    );
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 38,
          color: OpsColors.tableHeader,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: line([
            for (final h in columns)
              Text(h, style: AppText.secondary.copyWith(color: const Color(0xFF55525C)), overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
            child: Text(emptyLabel, style: AppText.secondary, textAlign: TextAlign.center),
          ),
        for (var r = 0; r < rows.length; r++)
          Container(
            constraints: BoxConstraints(minHeight: rowHeight),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: r == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: line(rows[r]),
          ),
        const SizedBox(height: 2),
      ],
    );
    return OpsCard(
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= minWidth) return table;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: table),
          );
        },
      ),
    );
  }
}

/// Cellule texte de [OpsTable].
class OpsCell extends StatelessWidget {
  const OpsCell(this.text, {super.key, this.strong = false, this.color});

  final String text;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(
      text,
      style: AppText.body.copyWith(
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        color: color ?? (strong ? AppColors.ink : const Color(0xFF45424B)),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// Onglets soulignés répartis sur toute la largeur.
class OpsTabs extends StatelessWidget {
  const OpsTabs({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE9E7E3)))),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: SizedBox(
                    height: 44,
                    child: Column(
                      children: [
                        const Spacer(),
                        Text(
                          labels[i],
                          style: AppText.body.copyWith(
                            fontSize: 14.5,
                            fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                            color: i == selected ? AppColors.ink : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        FractionallySizedBox(
                          widthFactor: .7,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i == selected ? OpsColors.underline : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Note d'information lavande avec pictogramme « i ».
class OpsInfoNote extends StatelessWidget {
  const OpsInfoNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(color: OpsColors.lavender, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const AppIcon('assets/icons/info.svg', size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.secondary.copyWith(color: const Color(0xFF3F3C46)))),
        ],
      ),
    );
  }
}

/// Champ de recherche lavande avec bouton de filtres.
class OpsSearchBar extends StatelessWidget {
  const OpsSearchBar({super.key, required this.hint, this.onChanged, this.onFilter, this.controller});

  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilter;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: const ShapeDecoration(color: OpsColors.lavender, shape: StadiumBorder()),
      child: Row(
        children: [
          const AppIcon('assets/icons/search.svg', size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppText.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body.copyWith(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Filtres',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onFilter ?? () {},
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(child: AppIcon('assets/icons/sliders-horizontal.svg', size: 21)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grand bouton arrondi des consoles : sombre (action principale) ou blanc (export).
class OpsBigButton extends StatelessWidget {
  const OpsBigButton({super.key, required this.label, required this.icon, this.onTap, this.dark = true, this.height = 50});

  final String label;
  final String icon;
  final VoidCallback? onTap;
  final bool dark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      child: Container(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          shadows: dark ? const [BoxShadow(color: Color(0x33111015), blurRadius: 14, offset: Offset(0, 6))] : null,
        ),
        child: Material(
          color: dark ? AppColors.ink : Colors.white,
          shape: StadiumBorder(side: dark ? BorderSide.none : const BorderSide(color: AppColors.cardBorder)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap ?? () {},
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(icon, size: 19, color: fg),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(color: fg, fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                    ),
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

/// Recherche + bouton à droite (largeur fixe sur grand écran, empilés sur petit).
class OpsSearchRow extends StatelessWidget {
  const OpsSearchRow({super.key, required this.search, required this.button, this.buttonWidth = 242});

  final Widget search;
  final Widget button;
  final double buttonWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 12), button]);
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 14),
            SizedBox(width: buttonWidth, child: button),
          ],
        );
      },
    );
  }
}

/// Pastilles de filtre : sélection sombre, autres lavande.
class OpsFilterChips extends StatelessWidget {
  const OpsFilterChips({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < labels.length; i++)
          Semantics(
            button: true,
            selected: i == selected,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(i),
              child: SizedBox(
                height: 44,
                child: Center(
                  widthFactor: 1,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: ShapeDecoration(
                      color: i == selected ? AppColors.ink : OpsColors.lavender,
                      shape: const StadiumBorder(),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        labels[i],
                        style: AppText.body.copyWith(
                          fontSize: 14,
                          color: i == selected ? Colors.white : const Color(0xFF45424B),
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
    );
  }
}

/// Interrupteur compact (sombre activé, lavande désactivé), zone tactile 44 px.
class OpsSwitch extends StatelessWidget {
  const OpsSwitch({super.key, required this.value, required this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 24,
              padding: const EdgeInsets.all(3),
              decoration: ShapeDecoration(
                color: value ? AppColors.ink : const Color(0xFFE8E4F3),
                shape: const StadiumBorder(),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 18,
                  height: 18,
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

/// Liste de réglages dans une carte : titre, sous-titre et élément à droite.
class OpsSettingsCard extends StatelessWidget {
  const OpsSettingsCard({super.key, required this.items});

  /// (pictogramme optionnel, titre, sous-titre, élément à droite).
  final List<(String?, String, String, Widget)> items;

  @override
  Widget build(BuildContext context) {
    return OpsCard(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              height: 66,
              decoration: BoxDecoration(
                border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  if (items[i].$1 != null) ...[OpsIconTile(items[i].$1!), const SizedBox(width: 10)],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$2,
                          style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(items[i].$3, style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  items[i].$4,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte « libellé / valeur » avec titre (règles, synthèse).
class OpsKvCard extends StatelessWidget {
  const OpsKvCard({super.key, required this.title, required this.rows, this.trailing});

  final String title;
  final List<(String, String)> rows;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return OpsCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: AppText.body.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600)),
                ),
              ),
              if (trailing != null) Text(trailing!, style: AppText.secondary),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++)
            Container(
              height: 34,
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(rows[i].$1, style: AppText.body.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
                  ),
                  Text(rows[i].$2, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
