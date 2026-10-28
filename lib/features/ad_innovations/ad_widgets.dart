import 'dart:math' as math;

import '../i_projets/i_widgets.dart';

export '../../data/demo/section_ad_demo.dart';
export '../i_projets/i_widgets.dart';

/// Orange des montants de précommande (maquettes 216 et 217).
const adAmber = Color(0xFFF5A81E);

/// Lavande des pastilles et encadrés de la section.
const adLavender = Color(0xFFF2EFF6);

/// Ombre douce des cartes blanches.
const adShadow = [BoxShadow(color: Color(0x0D595080), blurRadius: 18, offset: Offset(0, 4))];

/// Page mobile de la section AD : en-tête, contenu défilant, menu bas ou bande blanche d'actions.
class AdPage extends StatelessWidget {
  const AdPage({
    super.key,
    required this.header,
    required this.children,
    this.actions = const [],
    this.showNav = false,
    this.tab = NavTab.home,
    this.floatingAction,
  });

  final Widget header;
  final List<Widget> children;
  final List<Widget> actions;
  final bool showNav;
  final NavTab tab;

  /// Bouton posé directement sur le fond, sans bande blanche (228).
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final page = AppScaffold(
      showNav: showNav,
      tab: tab,
      header: header,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      bottomBar: floatingAction == null
          ? null
          : Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: floatingAction),
      bottomBarHeight: 60,
      children: children,
    );
    if (actions.isEmpty) return page;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(child: page),
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

/// En-tête des écrans racines : grand titre à gauche, action à droite.
class AdRootHeader extends StatelessWidget {
  const AdRootHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 32, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.h1.copyWith(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.3),
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// En-tête « flèche + titre gras » des écrans secondaires.
class AdBackHeader extends StatelessWidget {
  const AdBackHeader(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 32, 16, 8),
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: AppText.h1.copyWith(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.3),
              ),
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// En-tête centré à boutons ronds blancs ombrés (220, 222, 225).
class AdCenterHeader extends StatelessWidget {
  const AdCenterHeader(this.title, {super.key, this.onShare});

  final String title;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(30, 42, 30, 6),
    child: Row(
      children: [
        AdSoftRoundButton(icon: AppIcons.arrowLeft, label: 'Retour', onTap: () => ScreenHeader.back(context)),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        AdSoftRoundButton(
          icon: AppIcons.share,
          label: 'Partager',
          onTap: onShare ?? () => context.toast('Lien de partage copié.'),
        ),
      ],
    ),
  );
}

/// Bouton rond blanc à ombre lavande diffuse.
class AdSoftRoundButton extends StatelessWidget {
  const AdSoftRoundButton({super.key, required this.icon, required this.label, required this.onTap, this.size = 44});

  final String icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x33A58BD8), blurRadius: 14, offset: Offset(0, 5))],
        ),
        alignment: Alignment.center,
        child: AppIcon(icon, size: 20),
      ),
    ),
  );
}

/// Icône d'en-tête nue (recherche, partage, cloche).
Widget adHeaderIcon(BuildContext context, String icon, String label, VoidCallback onTap) =>
    RoundIconButton(icon: icon, label: label, bordered: false, background: Colors.transparent, onTap: onTap);

/// Carte blanche arrondie à ombre douce.
class AdCard extends StatelessWidget {
  const AdCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius), boxShadow: adShadow),
    child: child,
  );
}

/// Encadré lavande avec pictogramme sur carré blanc (216–219).
class AdNote extends StatelessWidget {
  const AdNote(this.text, {super.key, required this.icon, this.padding = const EdgeInsets.fromLTRB(12, 13, 16, 13)});

  final String text;
  final String icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: adLavender, borderRadius: BorderRadius.circular(20)),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: AppIcon(icon, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppText.small.copyWith(fontSize: 12.5, color: const Color(0xFF4A4752), height: 1.35),
          ),
        ),
      ],
    ),
  );
}

/// Pastilles de filtre : noire si sélectionnée, lavande sinon. [expand] répartit la largeur.
class AdPills extends StatelessWidget {
  const AdPills({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.expand = false,
    this.height = 34,
    this.unselectedColor = const Color(0xFFECE8F1),
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool expand;
  final double height;
  final Color unselectedColor;

  Widget _pill(int i) {
    final on = i == selected;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(i),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: height,
              padding: EdgeInsets.symmetric(horizontal: expand ? 6 : 18),
              decoration: ShapeDecoration(color: on ? AppColors.ink : unselectedColor, shape: const StadiumBorder()),
              alignment: Alignment.center,
              child: Text(
                labels[i],
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: AppText.body.copyWith(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  color: on ? Colors.white : const Color(0xFF4A4752),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (expand) {
      return Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: _pill(i))],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[if (i > 0) const SizedBox(width: 8), _pill(i)],
        ],
      ),
    );
  }
}

/// Frise horizontale à 4 étapes réparties sur toute la largeur (218, 219).
class AdStepper extends StatelessWidget {
  const AdStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    const node = 34.0;
    return Semantics(
      label: 'Étape ${current + 1} sur ${labels.length} : ${labels[current]}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final step = (c.maxWidth - node) / (labels.length - 1);
          return SizedBox(
            height: node + 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < labels.length - 1; i++)
                  Positioned(
                    left: node / 2 + step * i,
                    width: step,
                    top: node / 2 - 1,
                    height: 2,
                    child: ColoredBox(color: i < current ? AppColors.ink : const Color(0xFFE4E0EA)),
                  ),
                for (var i = 0; i < labels.length; i++) ...[
                  Positioned(
                    left: step * i,
                    top: 0,
                    child: Container(
                      width: node,
                      height: node,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? AppColors.ink : Colors.white,
                        border: i <= current ? null : Border.all(color: const Color(0xFFE4E0EA)),
                      ),
                      alignment: Alignment.center,
                      child: i < current ? const AppIcon(AppIcons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
                  Positioned(
                    left: step * i + node / 2 - 50,
                    width: 100,
                    top: node + 4,
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: AppText.small.copyWith(
                        fontSize: 11.5,
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

/// Carte « titre + lignes libellé / valeur » séparées par des filets (217, 219, 221).
class AdKvCard extends StatelessWidget {
  const AdKvCard({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => AdCard(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.bodyStrong.copyWith(fontSize: 15))),
        const SizedBox(height: 6),
        for (final (i, r) in rows.indexed)
          Container(
            height: 34,
            decoration: BoxDecoration(
              border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFEDEBF0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(r.$1, style: AppText.secondary.copyWith(fontSize: 12.5, color: const Color(0xFF5E5B66))),
                ),
                Text(r.$2, style: AppText.label.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Barre de progression lavande / violette (216).
class AdProgress extends StatelessWidget {
  const AdProgress({super.key, required this.value, this.color = const Color(0xFF6A4DFF), this.height = 8});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Container(
      height: height,
      width: double.infinity,
      color: adLavender,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0, 1),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
        ),
      ),
    ),
  );
}

/// Petit bouton noir en pilule (« Précommander », « S’abonner »…).
class AdChipButton extends StatelessWidget {
  const AdChipButton(
    this.label, {
    super.key,
    required this.onTap,
    this.height = 28,
    this.fontSize = 12,
    this.padding = 9,
  });

  final double padding;
  final String label;
  final VoidCallback onTap;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: padding),
            decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppText.label.copyWith(color: Colors.white, fontSize: fontSize),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Jauge sombre à graduations avec halo vert (217).
class AdGauge extends StatelessWidget {
  const AdGauge({super.key, required this.percent, this.size = 88});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Progression $percent %',
    excludeSemantics: true,
    child: SizedBox(
      width: size,
      height: size + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(child: CustomPaint(painter: _AdGaugePainter(percent / 100))),
          Positioned(
            top: size * .2,
            child: const AppIcon(AppIcons.zap, size: 12, color: Color(0xFFFFD43B)),
          ),
          Positioned(
            top: size * .33,
            child: Text(
              '$percent%',
              style: AppText.h1.copyWith(
                fontSize: size * .3,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9BE58F),
                letterSpacing: -.5,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdGaugePainter extends CustomPainter {
  _AdGaugePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r, size.width - 2), width: size.width * .8, height: 22),
      Paint()
        ..color = const Color(0xFF6CF545)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 1),
          radius: .85,
          colors: [Color(0xFF3CC236), Color(0xFF0E3A10), Color(0xFF030303)],
          stops: [0, .5, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    const ticks = 64;
    final lit = (ticks * value).round();
    for (var i = 0; i < ticks; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / ticks;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r - 12),
        c + dir * (r - 4),
        Paint()
          ..color = i < lit ? const Color(0xFFF2F2F2) : const Color(0xFF3A3A3A)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_AdGaugePainter old) => old.value != value;
}

/// Bannière photo arrondie avec titre et sous-titre en bas (217, 221, 223, 229).
class AdHero extends StatelessWidget {
  const AdHero({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    this.height = 170,
    this.onTap,
    this.titleSize = 19,
  });

  final String image;
  final String title;
  final String subtitle;
  final double height;
  final VoidCallback? onTap;
  final double titleSize;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: '$title. $subtitle',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xC0141228)],
                    stops: [.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.h2.copyWith(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppText.small.copyWith(color: Colors.white, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Avatar photo rond.
class AdAvatar extends StatelessWidget {
  const AdAvatar(this.image, {super.key, this.size = 32});

  final String image;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset(image, width: size, height: size, fit: BoxFit.cover, excludeFromSemantics: true),
  );
}

/// Vignette photo arrondie.
class AdThumb extends StatelessWidget {
  const AdThumb(
    this.image, {
    super.key,
    this.size = 50,
    this.radius = 12,
    this.height,
    this.alignment = Alignment.center,
  });

  final Alignment alignment;

  final String image;
  final double size;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Image.asset(
      image,
      width: size,
      height: height ?? size,
      fit: BoxFit.cover,
      alignment: alignment,
      excludeFromSemantics: true,
    ),
  );
}

/// Titre de section intermédiaire.
class AdSectionTitle extends StatelessWidget {
  const AdSectionTitle(this.title, {super.key, this.top = 20, this.bottom = 10});

  final String title;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: bottom),
    child: Semantics(
      header: true,
      child: Text(title, style: AppText.h3.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600)),
    ),
  );
}
