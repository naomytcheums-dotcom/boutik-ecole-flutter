import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'ops_console_kit.dart';

/// Blocs des tableaux de bord de pilotage (127 plateforme, 139 finance).

/// Carte soleil « Analytique · données en direct » avec vagues et accroche.
class OpsHeroCard extends StatelessWidget {
  const OpsHeroCard({super.key, required this.headline, this.chip = 'Analytique · données en direct', this.height = 232});

  final String headline;
  final String chip;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6C84E), Color(0xFFF9DC8E), Color(0xFFF6C454)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _WavesPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  constraints: const BoxConstraints(minWidth: 160),
                  decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                  child: Text(chip, style: AppText.small.copyWith(color: AppColors.ink, fontSize: 12)),
                ),
                const Spacer(),
                Text(
                  headline,
                  style: AppText.display.copyWith(fontWeight: FontWeight.w400, fontSize: 31, height: 1.13, letterSpacing: -0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final light = Paint()..color = const Color(0x8CFFF4D6);
    final band = Path()
      ..moveTo(0, h * .45)
      ..cubicTo(w * .25, h * .32, w * .45, h * .62, w * .62, h * .42)
      ..cubicTo(w * .78, h * .24, w * .88, h * .12, w, h * .22)
      ..lineTo(w, h * .42)
      ..cubicTo(w * .9, h * .3, w * .8, h * .38, w * .66, h * .55)
      ..cubicTo(w * .5, h * .74, w * .3, h * .5, 0, h * .66)
      ..close();
    canvas.drawPath(band, light);
    final lower = Paint()..color = const Color(0x40F2B33D);
    final wave = Path()
      ..moveTo(0, h * .62)
      ..cubicTo(w * .3, h * .5, w * .45, h * .72, w * .7, h * .6)
      ..lineTo(w * .82, h * .54)
      ..cubicTo(w * .6, h * .78, w * .35, h * .7, 0, h * .9)
      ..close();
    canvas.drawPath(wave, lower);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bouton gris arrondi (« Filtrer », « Trier »).
class OpsGreyChip extends StatelessWidget {
  const OpsGreyChip(this.label, {super.key, this.onTap, this.width = 64});

  final String label;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () {},
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: Container(
              width: width,
              height: 26,
              alignment: Alignment.center,
              decoration: const ShapeDecoration(color: OpsColors.greyChip, shape: StadiumBorder()),
              child: Text(label, style: AppText.small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte « volume » : total, variation, histogramme + courbe et bulle sur le dernier mois.
class OpsTrendCard extends StatelessWidget {
  const OpsTrendCard({
    super.key,
    required this.title,
    required this.total,
    required this.delta,
    required this.deltaNote,
    required this.bars,
    required this.curve,
    required this.highlight,
    required this.tooltipValue,
    required this.tooltipLabel,
    required this.months,
    this.height = 232,
    this.onFilter,
  });

  final String title;
  final String total;
  final String delta;
  final String deltaNote;
  final List<double> bars;
  final List<double> curve;
  final (int, int) highlight;
  final String tooltipValue;
  final String tooltipLabel;
  final List<String> months;
  final double height;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    return OpsCard(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 8),
      child: SizedBox(
        height: height - 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600))),
                OpsGreyChip('Filtrer', onTap: onFilter, width: 80),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(total, style: AppText.amount.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: const ShapeDecoration(color: Color(0xFFCFF29A), shape: StadiumBorder()),
                  child: Text(delta, style: AppText.small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ),
                Text(deltaNote, style: AppText.small.copyWith(fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Semantics(
                label: '$title : $tooltipLabel, $tooltipValue',
                excludeSemantics: true,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _TrendPainter(bars: bars, curve: curve, highlight: highlight)),
                    ),
                    Align(
                      alignment: const Alignment(.6, -.6),
                      child: Container(
                        width: 112,
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Color(0x1F2C1D5E), blurRadius: 12, offset: Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tooltipValue, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                            Text(tooltipLabel, style: AppText.small.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final m in months) Text(m, style: AppText.small.copyWith(fontSize: 11))],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.bars, required this.curve, required this.highlight});

  final List<double> bars;
  final List<double> curve;
  final (int, int) highlight;

  @override
  void paint(Canvas canvas, Size s) {
    final step = s.width / bars.length;
    final barW = math.max(2.0, step * .45);
    final light = Paint()..color = const Color(0xFFEBDFFA);
    final strong = Paint()..color = const Color(0xFFA47BE8);
    for (var i = 0; i < bars.length; i++) {
      final hgt = s.height * bars[i];
      final x = i * step + (step - barW) / 2;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, s.height - hgt, barW, hgt), Radius.circular(barW / 2));
      canvas.drawRRect(r, i >= highlight.$1 && i <= highlight.$2 ? strong : light);
    }
    if (curve.length < 2) return;
    final pts = [
      for (var i = 0; i < curve.length; i++) Offset(s.width * i / (curve.length - 1), s.height * (1 - curve[i])),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i], b = pts[i + 1];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF7B4DD6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.bars != bars || old.curve != curve;
}

/// Ligne d'une liste illustrée (établissements, derniers flux).
class OpsListRow {
  const OpsListRow({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.middle,
    required this.status,
    required this.statusTone,
    required this.amount,
  });

  final String image;
  final String title;
  final String subtitle;
  final String middle;
  final String status;
  final OpsTone statusTone;
  final String amount;
}

/// Carte liste avec vignettes, en-tête gris et première ligne mise en avant.
class OpsListCard extends StatelessWidget {
  const OpsListCard({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.onSort,
    this.onFilter,
    this.onRowTap,
  });

  final String title;
  final List<String> columns;
  final List<OpsListRow> rows;
  final VoidCallback? onSort;
  final VoidCallback? onFilter;
  final ValueChanged<OpsListRow>? onRowTap;

  static const _flex = [500, 240, 280, 128];

  @override
  Widget build(BuildContext context) {
    Widget line(List<Widget> cells) => Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(flex: _flex[i], child: Align(alignment: Alignment.centerLeft, child: cells[i])),
      ],
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 13),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: AppText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            OpsGreyChip('Trier', onTap: onSort, width: 80),
            const SizedBox(width: 10),
            OpsGreyChip('Filtrer', onTap: onFilter, width: 80),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.only(left: 34),
          decoration: BoxDecoration(color: OpsColors.greyChip.withValues(alpha: .7), borderRadius: BorderRadius.circular(12)),
          child: line([for (final c in columns) Text(c, style: AppText.secondary)]),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++)
          Material(
            color: i == 0 ? const Color(0xFFF1F8E6) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
              child: Container(
                height: 52,
                padding: const EdgeInsets.only(left: 28),
                child: line([
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(rows[i].image, width: 32, height: 32, fit: BoxFit.cover, semanticLabel: rows[i].title),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].title,
                              style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              rows[i].subtitle,
                              style: AppText.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(rows[i].middle, style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w400)),
                  _ListBadge(rows[i].status, rows[i].statusTone),
                  Text(
                    rows[i].amount,
                    style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
    return OpsCard(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 520) return content;
          return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: 520, child: content));
        },
      ),
    );
  }
}

class _ListBadge extends StatelessWidget {
  const _ListBadge(this.label, this.tone);

  final String label;
  final OpsTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = opsToneColors(tone);
    return Container(
      width: 78,
      height: 22,
      alignment: Alignment.center,
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(label, style: AppText.small.copyWith(color: fg, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

/// Objectif chiffré : grand pourcentage, jauge à graduations, deux barres de progression.
class OpsGoalCard extends StatelessWidget {
  const OpsGoalCard({
    super.key,
    required this.title,
    required this.percent,
    required this.caption,
    required this.progress,
  });

  final String title;
  final int percent;
  final String caption;

  /// (pourcentage, libellé) des deux barres.
  final List<(int, String)> progress;

  @override
  Widget build(BuildContext context) {
    const ticks = 30;
    final on = (ticks * percent / 100 / 2).round();
    return OpsCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$percent %',
                      style: AppText.amount.copyWith(fontSize: 34, fontWeight: FontWeight.w700, color: OpsColors.purpleDeep, height: 1.05),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(caption, style: AppText.secondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  label: 'Jauge $percent %',
                  child: Row(
                    children: [
                      for (var i = 0; i < ticks; i++)
                        Container(
                          width: 3,
                          height: 22,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: i < on ? Color.lerp(const Color(0xFF7E2FB2), OpsColors.purple, i / on) : const Color(0xFFE9E6EF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, (p, label)) in progress.indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$p %  ',
                              style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: OpsColors.purpleDeep),
                            ),
                            TextSpan(text: label, style: AppText.small),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: p / 100,
                          minHeight: 5,
                          color: OpsColors.purple,
                          backgroundColor: const Color(0xFFE9E6EF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Carte de l'assistante Kéla (dégradé bleu → lavande, question et réponse).
class OpsAssistantCard extends StatelessWidget {
  const OpsAssistantCard({
    super.key,
    required this.avatar,
    required this.question,
    required this.answer,
    this.name = 'Assistante Kéla',
    this.status = 'En ligne',
    this.onAsk,
  });

  final String avatar;
  final String name;
  final String status;
  final String question;
  final String answer;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE3F3)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3EEFC), Color(0xFFECE6FB)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(image: avatar, size: 34),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(status, style: AppText.small),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onAsk,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                child: Text(question, style: AppText.secondary.copyWith(fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text(answer, style: AppText.secondary.copyWith(fontSize: 14, color: const Color(0xFF45424B))),
          ),
        ],
      ),
    );
  }
}
