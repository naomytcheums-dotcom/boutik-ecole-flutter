import 'dart:math' as math;

import '../../data/demo/section_g_demo.dart';
import '../common/common.dart';

export '../../data/demo/section_g_demo.dart';
export '../common/common.dart';

/// Page de la section G sans menu bas : en-tête, contenu défilant, bande blanche d'actions en bas.
class GPage extends StatelessWidget {
  const GPage({super.key, required this.title, required this.children, required this.actions, this.showBack = true});

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: AppScaffold(
              showNav: false,
              header: Padding(padding: const EdgeInsets.only(top: 22), child: TitleHeader(title, showBack: showBack)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: children,
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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

/// Bouton blanc bordé des bandes d'actions (« Brouillon », « Modifier »…).
class GOutlineButton extends StatelessWidget {
  const GOutlineButton(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFDAD7DF))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(height: 54, child: Center(child: Text(label, style: AppText.button.copyWith(color: AppColors.ink)))),
      ),
    ),
  );
}

/// Carte indicateur : libellé, pictogramme en haut à droite, valeur, variation.
class GKpiCard extends StatelessWidget {
  const GKpiCard(this.kpi, {super.key, this.valueSize = 22});

  final GKpi kpi;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${kpi.label} : ${kpi.value}${kpi.delta == null ? '' : ', ${kpi.delta}'}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(kpi.label, style: AppText.small.copyWith(fontSize: 11.5))),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: const Color(0xFFF2F0F5), borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: AppIcon(kpi.icon, size: 15),
                ),
              ],
            ),
            Text(
              kpi.value,
              style: AppText.h1.copyWith(fontSize: valueSize, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
            if (kpi.delta != null) ...[
              const SizedBox(height: 4),
              Text(
                kpi.delta!,
                style: AppText.small.copyWith(fontSize: 11, color: toneToColor(kpi.deltaTone), fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grille 2 × n de cartes indicateurs.
class GKpiGrid extends StatelessWidget {
  const GKpiGrid(this.kpis, {super.key, this.valueSize = 22});

  final List<GKpi> kpis;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < kpis.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: GKpiCard(kpis[r], valueSize: valueSize)),
                const SizedBox(width: 10),
                Expanded(child: r + 1 < kpis.length ? GKpiCard(kpis[r + 1], valueSize: valueSize) : const SizedBox()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Frise horizontale d'étapes : faites (coche), courante (disque noir), à venir (cercle blanc).
class GStepper extends StatelessWidget {
  const GStepper({super.key, required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Étape ${current + 1} sur ${labels.length} : ${labels[current]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 34,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Container(height: 2, color: i == 0 ? null : (i <= current ? AppColors.ink : Colors.white))),
                            Expanded(
                              child: Container(
                                height: 2,
                                color: i == labels.length - 1 ? null : (i < current ? AppColors.ink : Colors.white),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: i == current ? 34 : 26,
                          height: i == current ? 34 : 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= current ? AppColors.ink : Colors.white,
                            border: i <= current ? null : Border.all(color: const Color(0xFFE6E3EC)),
                          ),
                          alignment: Alignment.center,
                          child: i < current ? const AppIcon(AppIcons.check, size: 15, color: Colors.white) : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
  }
}

/// Ligne de liste à vignette : photo arrondie, titre, sous-titre, élément à droite.
class GThumbRow extends StatelessWidget {
  const GThumbRow({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.thumb = 50,
  });

  final String image;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double thumb;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(image, width: thumb, height: thumb, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppText.small.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
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

/// Carte blanche contenant des lignes séparées par un filet.
class GListCard extends StatelessWidget {
  const GListCard({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(12, 6, 12, 6)});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(height: 1, color: AppColors.cardBorder), c],
        ],
      ),
    );
  }
}

/// Pastille de statut compacte (fond doux).
class GBadge extends StatelessWidget {
  const GBadge(this.label, this.tone, {super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.success => (AppColors.successSoft, AppColors.success),
      Tone.warning => (AppColors.warningSoft, AppColors.warning),
      Tone.error => (AppColors.errorSoft, AppColors.error),
      Tone.accent => (AppColors.accentSoft, AppColors.accent),
      Tone.neutral => (const Color(0xFFF0EEF3), const Color(0xFF4A4752)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(label, style: AppText.small.copyWith(fontSize: 11.5, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

(String, Tone) orderStatus(GOrderStatus s) => switch (s) {
  GOrderStatus.toPrepare => ('À préparer', Tone.warning),
  GOrderStatus.newOrder => ('Nouvelle', Tone.accent),
  GOrderStatus.inProgress => ('En cours', Tone.accent),
  GOrderStatus.ready => ('Prête', Tone.success),
  GOrderStatus.delivered => ('Livrée', Tone.success),
};

/// Histogramme à barres noires arrondies avec graduations légères.
class GBars extends StatelessWidget {
  const GBars({super.key, required this.bars, this.height = 150});

  final List<GBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = bars.map((b) => b.value).reduce(math.max).toDouble();
    return Semantics(
      label: bars.map((b) => '${b.label} : ${fcfa(b.value)}').join(', '),
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
                    top: height * (i + 1) / 4,
                    child: Container(height: 1, color: const Color(0xFFF0EEF3)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final b in bars)
                      Expanded(
                        child: Center(
                          child: Container(
                            width: bars.length > 8 ? 14 : 24,
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
              for (final b in bars) Expanded(child: Text(b.label, textAlign: TextAlign.center, style: AppText.small.copyWith(fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Courbe de revenus cumulés (violet, aire dégradée, point final).
class GLineChart extends StatelessWidget {
  const GLineChart({super.key, required this.values, this.height = 130});

  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Revenus cumulés, de ${fcfa(values.first)} à ${fcfa(values.last)}',
    child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _LinePainter(values))),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.reduce(math.max).toDouble();
    final pts = [
      for (final (i, v) in values.indexed)
        Offset(4 + (size.width - 12) * i / (values.length - 1), size.height - 6 - (size.height - 18) * v / max),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x557B5CF5), Color(0x007B5CF5)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFF6A4DF0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(pts.last, 4.5, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}

/// Jauge circulaire de conformité (cadran sombre à graduations vertes).
class GGauge extends StatelessWidget {
  const GGauge({super.key, required this.percent, this.size = 100});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Conformité $percent %',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x6639E06A), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: CustomPaint(
          painter: _GaugePainter(percent / 100),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(AppIcons.zap, size: 11, color: Color(0xFFE6C53A)),
                Text('$percent%', style: AppText.h1.copyWith(color: const Color(0xFF7CF29A), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0E1410));
    const ticks = 72;
    for (var i = 0; i < ticks; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / ticks;
      final on = i / ticks <= value;
      final p = Paint()
        ..color = on ? const Color(0xFF6BEA86) : const Color(0xFF3A443D)
        ..strokeWidth = 1.6;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r - 4), c + Offset(math.cos(a), math.sin(a)) * (r - 14), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value;
}

/// Encadré d'information lavande (icône à gauche).
class GNote extends StatelessWidget {
  const GNote(this.text, {super.key, required this.icon});

  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(color: const Color(0xFFEEEBF5), borderRadius: BorderRadius.circular(18)),
    child: Row(
      children: [
        AppIcon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.small.copyWith(fontSize: 12, color: const Color(0xFF4A4752)))),
      ],
    ),
  );
}

/// Onglets « pastilles » horizontaux défilants (61, 63, 67).
class GTabs extends StatelessWidget {
  const GTabs({super.key, required this.labels, required this.selected, required this.onSelected});

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
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: ShapeDecoration(
                        color: i == selected ? AppColors.ink : Colors.white.withValues(alpha: .7),
                        shape: const StadiumBorder(),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          l,
                          style: AppText.secondary.copyWith(color: i == selected ? Colors.white : const Color(0xFF4A4752)),
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

/// Titre de section intermédiaire (« Articles à surveiller »).
class GSectionTitle extends StatelessWidget {
  const GSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)))),
        ?trailing,
      ],
    ),
  );
}

/// En-tête des écrans racines de l'espace vendeur (titre seul, action à droite).
class GRootHeader extends StatelessWidget {
  const GRootHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 30, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w600))),
              if (subtitle != null) Text(subtitle!, style: AppText.small),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

