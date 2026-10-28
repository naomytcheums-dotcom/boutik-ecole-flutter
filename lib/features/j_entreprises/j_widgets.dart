import '../../data/demo/section_g_demo.dart' show GBar;
import '../../data/demo/section_j_demo.dart';
import '../common/common.dart';
import '../h_talents/h_widgets.dart' show HIconTile, HListCard, HRow, HHeader;

export '../../data/demo/section_j_demo.dart';
export '../common/common.dart';
export '../f_communication/f_widgets.dart' show FBubble, FMessage;
export '../g_espace_etudiant/g_widgets.dart'
    show GKpi, GBar, GKpiGrid, GKpiCard, GStepper, GOutlineButton, GBars, GNote, GRootHeader, GSectionTitle;
export '../h_talents/h_widgets.dart'
    show HChips, HRow, HListCard, HHeader, HHeaderAction, HCountTitle, HEmpty, HIconTile, HPage, hLavender;
export '../i_projets/i_widgets.dart' show IProgressCard;

/// Lavande des vignettes et pastilles de la section J.
const jLavender = Color(0xFFEFEBFA);

/// Pastille de statut de la section (vert, orange, violet, gris).
class JBadge extends StatelessWidget {
  const JBadge(this.label, this.tone, {super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.success => (const Color(0xFFDDF5EC), AppColors.success),
      Tone.warning => (jLavender, AppColors.warning),
      Tone.error => (AppColors.errorSoft, AppColors.error),
      Tone.accent => (jLavender, AppColors.accent),
      Tone.neutral => (const Color(0xFFF0EEF3), const Color(0xFF4A4752)),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      alignment: Alignment.center,
      child: Text(label, style: AppText.small.copyWith(fontSize: 11.5, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// Vignette lavande à pictogramme (listes de la section).
class JIconTile extends StatelessWidget {
  const JIconTile(this.icon, {super.key});

  final String icon;

  @override
  Widget build(BuildContext context) => HIconTile(icon, color: jLavender);
}

/// Carte de lignes « vignette · titre · détail · pastille ».
class JItemList extends StatelessWidget {
  const JItemList(this.items, {super.key, this.onTap});

  final List<JItem> items;
  final ValueChanged<JItem>? onTap;

  @override
  Widget build(BuildContext context) => HListCard(
    indent: 52,
    children: [
      for (final it in items)
        HRow(
          leading: JIconTile(it.icon),
          title: it.title,
          subtitle: it.detail,
          trailing: JBadge(it.badge, it.tone),
          onTap: () {
            if (onTap != null) {
              onTap!(it);
            } else if (it.target.isNotEmpty) {
              context.openScreen(it.target);
            }
          },
        ),
    ],
  );
}

/// Avatar rond des listes de personnes.
class JAvatar extends StatelessWidget {
  const JAvatar(this.image, {super.key, this.size = 50});

  final String image;
  final double size;

  @override
  Widget build(BuildContext context) =>
      ClipOval(child: Image.asset(image, width: size, height: size, fit: BoxFit.cover));
}

/// En-tête des écrans racines de la section (titre, sous-titre gris, action à droite).
class JRootHeader extends StatelessWidget {
  const JRootHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, 41, 16, subtitle == null ? 10 : 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w600)),
              ),
              if (subtitle != null) Text(subtitle!, style: AppText.small.copyWith(fontSize: 12.5, height: 1.1)),
            ],
          ),
        ),
        if (action != null) Padding(padding: EdgeInsets.only(bottom: subtitle == null ? 0 : 14), child: action),
      ],
    ),
  );
}

/// Titre intermédiaire compact (« Opportunités du moment »), action à droite.
class JSectionTitle extends StatelessWidget {
  const JSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: trailing == null ? 14 : 0, bottom: trailing == null ? 12 : 4),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Histogramme à barres noires posées sur la ligne de base (88).
class JBars extends StatelessWidget {
  const JBars({super.key, required this.bars, required this.unit, this.height = 121});

  final List<GBar> bars;
  final String unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    return Semantics(
      label: bars.map((b) => '${b.label} : ${b.value} $unit').join(', '),
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: i * (height - 1) / 2,
                    child: Container(height: 1, color: const Color(0xFFEDEBF1)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final b in bars)
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 28,
                            height: height * b.value / max,
                            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final b in bars)
                Expanded(
                  child: Text(b.label, textAlign: TextAlign.center, style: AppText.small.copyWith(fontSize: 11)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Page racine avec menu bas : titre seul (et sous-titre / action éventuels).
class JRootPage extends StatelessWidget {
  const JRootPage({super.key, required this.title, required this.children, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppScaffold(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    header: JRootHeader(title, subtitle: subtitle, action: action),
    children: children,
  );
}

/// Page secondaire avec menu bas : flèche retour, titre gras, action à droite.
class JNavPage extends StatelessWidget {
  const JNavPage({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppScaffold(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    header: HHeader(title, trailing: trailing),
    children: children,
  );
}

/// Tableau dans une carte : en-tête lavande, lignes séparées par un filet (93, 94).
class JTable extends StatelessWidget {
  const JTable({super.key, required this.header, required this.rows, this.flex, this.rowHeight = 43});

  final List<String> header;
  final List<List<String>> rows;
  final List<int>? flex;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    Widget line(List<String> cells, {required bool head}) => Row(
      children: [
        for (final (i, c) in cells.indexed)
          Expanded(
            flex: flex?[i] ?? 1,
            child: Text(
              c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: head
                  ? AppText.small.copyWith(fontSize: 11.5, color: const Color(0xFF4A4752))
                  : (i == 0
                        ? AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600)
                        : AppText.body.copyWith(fontSize: 13, color: const Color(0xFF4A4752))),
            ),
          ),
      ],
    );
    return Semantics(
      label: [header.join(', '), for (final r in rows) r.join(', ')].join(' ; '),
      excludeSemantics: true,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F0F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusCard)),
              ),
              alignment: Alignment.centerLeft,
              child: line(header, head: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
              child: Column(
                children: [
                  for (final (i, r) in rows.indexed) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0xFFE9E7EC)),
                    SizedBox(
                      height: rowHeight,
                      child: Align(alignment: Alignment.centerLeft, child: line(r, head: false)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'en-tête d'un interlocuteur (93b, 95b) : avatar, nom, détail, action.
class JPersonCard extends StatelessWidget {
  const JPersonCard({super.key, required this.avatar, required this.name, required this.detail, this.action});

  final String avatar;
  final String name;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
    child: HRow(leading: JAvatar(avatar), title: name, subtitle: detail, trailing: action),
  );
}

/// Encadré d'information gris lavande, pictogramme dans un carré blanc (94, 97).
class JNote extends StatelessWidget {
  const JNote(this.text, {super.key, required this.icon});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
    decoration: BoxDecoration(color: const Color(0xFFF0EEF5), borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppText.small.copyWith(fontSize: 12.5, height: 1.4, color: const Color(0xFF4A4752))),
        ),
      ],
    ),
  );
}

/// Champ de saisie de la section : libellé, pilule blanche, pictogramme encre (90, 95b).
class JTextField extends StatelessWidget {
  const JTextField({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    this.icon,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final String? hint;
  final String? initialValue;
  final String? icon;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : 23),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        TextFormField(
          initialValue: initialValue,
          validator: validator,
          keyboardType: keyboardType,
          minLines: maxLines,
          maxLines: maxLines,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppText.body.copyWith(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.secondary.copyWith(fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(icon == null ? 16 : 0, maxLines > 1 ? 18 : 14, 16, maxLines > 1 ? 25 : 14),
            prefixIcon: icon == null
                ? null
                : Padding(padding: const EdgeInsets.only(left: 13, right: 11), child: AppIcon(icon!, size: 20)),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            border: border(const Color(0xFFF0EEF3)),
            enabledBorder: border(const Color(0xFFF0EEF3)),
            focusedBorder: border(AppColors.accent, 1.5),
            errorBorder: border(AppColors.error),
            focusedErrorBorder: border(AppColors.error, 1.5),
            errorStyle: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}

/// Liste déroulante de la section : pilule blanche, pictogramme, valeur, chevron ; choix en feuille du bas.
class JSelectField extends StatelessWidget {
  const JSelectField({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String icon;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Semantics(header: true, child: Text(label, style: AppText.h3)),
            ),
            for (final o in options)
              ListTile(
                minTileHeight: 48,
                title: Text(o, style: AppText.body),
                trailing: o == value ? const AppIcon(AppIcons.check, size: 18, color: AppColors.accent) : null,
                onTap: () => Navigator.of(ctx).pop(o),
              ),
          ],
        ),
      ),
    );
    if (v != null) onChanged(v);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Semantics(
        button: true,
        label: '$label : $value',
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(side: BorderSide(color: Color(0xFFF0EEF3))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _pick(context),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  const SizedBox(width: 13),
                  AppIcon(icon, size: 20),
                  const SizedBox(width: 15),
                  Expanded(child: Text(value, style: AppText.body.copyWith(fontSize: 14))),
                  const AppIcon(AppIcons.chevronDown, size: 20),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Frise d'étapes pleine largeur (90) : disque noir courant, cercles blancs à venir.
class JStepper extends StatelessWidget {
  const JStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Étape ${current + 1} sur ${labels.length} : ${labels[current]}',
    excludeSemantics: true,
    child: LayoutBuilder(
      builder: (context, c) {
        final step = (c.maxWidth - 40) / (labels.length - 1);
        return SizedBox(
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 20, right: 20, top: 16, child: Container(height: 2, color: Colors.white)),
              if (current > 0)
                Positioned(
                  left: 20,
                  width: step * current,
                  top: 16,
                  child: Container(height: 2, color: AppColors.ink),
                ),
              for (final (i, l) in labels.indexed)
                Positioned(
                  left: 20 + step * i - 50,
                  width: 100,
                  top: 0,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 34,
                        child: Center(
                          child: Container(
                            width: i == current ? 34 : 30,
                            height: i == current ? 34 : 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i <= current ? AppColors.ink : Colors.white,
                              border: i <= current ? null : Border.all(color: const Color(0xFFE6E3EC)),
                            ),
                            alignment: Alignment.center,
                            child: i < current ? const AppIcon(AppIcons.check, size: 15, color: Colors.white) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l,
                        style: AppText.small.copyWith(
                          fontSize: 11.5,
                          color: i == current ? AppColors.ink : AppColors.textSecondary,
                          fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Frise verticale des livrables (93b) : pastille verte cochée, disque noir, cercle blanc.
class JMilestones extends StatelessWidget {
  const JMilestones(this.items, {super.key});

  final List<(String, String, int)> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (i, m) in items.indexed)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (m.$3) {
                          0 => AppColors.success,
                          1 => AppColors.ink,
                          _ => Colors.white,
                        },
                      ),
                      alignment: Alignment.center,
                      child: m.$3 == 0 ? const AppIcon(AppIcons.check, size: 12, color: Colors.white) : null,
                    ),
                    if (i < items.length - 1) Expanded(child: Container(width: 1.5, color: const Color(0xFFB9E2CF))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < items.length - 1 ? 26 : 0),
                  child: Semantics(
                    label: '${m.$1}, ${m.$2}${m.$3 == 0 ? ', fait' : (m.$3 == 1 ? ', en cours' : ', à venir')}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.$1, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                        Text(m.$2, style: AppText.small.copyWith(fontSize: 11.5)),
                      ],
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

/// Onglets soulignés (95) : libellé actif en gras, trait violet dessous.
class JUnderlineTabs extends StatelessWidget {
  const JUnderlineTabs({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E1EA)))),
    child: Row(
      children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: InkWell(
                onTap: () => onSelected(i),
                child: SizedBox(
                  height: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        l,
                        style: AppText.body.copyWith(
                          fontSize: 14,
                          color: i == selected ? AppColors.ink : AppColors.textSecondary,
                          fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == selected ? const Color(0xFF6A4DF0) : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
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
