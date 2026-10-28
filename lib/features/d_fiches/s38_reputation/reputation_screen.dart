import 'dart:math' as math;

import '../../common/common.dart';
import '../d_widgets.dart';

/// 38 · Réputation du vendeur : note globale, répartition, badges et derniers avis.
class ReputationScreen extends ConsumerWidget {
  const ReputationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionDDataProvider);
    return DScaffold(
      title: 'Réputation',
      children: [
        const SizedBox(height: 2),
        DCard(
          child: SizedBox(
            height: 180,
            child: Column(
              children: [
                const SizedBox(height: 16),
                DAvatar(d.creatorAvatar, size: 72, label: 'Photo de ${d.repName}'),
                const SizedBox(height: 10),
                Text(d.repName, style: AppText.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(d.repMeta, style: DTxt.kvLabel),
                const SizedBox(height: 9),
                DBadge(d.repBadge, background: DColors.lowSoft, foreground: DColors.lowText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DCard(
          child: SizedBox(
            height: 120,
            child: Row(
              children: [
                const SizedBox(width: 15),
                _ScoreGauge(percent: d.repScorePercent),
                const SizedBox(width: 23),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.repRating, style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 150,
                          child: Text(d.repSummary, style: DTxt.kvLabel.copyWith(fontSize: 12.5, height: 1.42)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        DCard(
          padding: const EdgeInsets.fromLTRB(16, 12.5, 16, 17.5),
          child: Column(
            children: [
              for (final (i, r) in d.repDistribution.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                _DistributionRow(label: r.$1, percent: r.$2),
              ],
            ],
          ),
        ),
        const SizedBox(height: 15),
        const DSectionTitle('Badges de confiance'),
        const SizedBox(height: 17),
        Wrap(spacing: 12, runSpacing: 9, children: [for (final b in d.repTrustBadges) _TrustChip(b)]),
        const SizedBox(height: 2),
        DSectionTitle('Derniers avis', trailing: DLink('Voir tout', onTap: () => context.toast('38 avis'))),
        const SizedBox(height: 6),
        DCard(
          child: Column(
            children: [
              for (final (i, r) in d.repReviews.indexed) ...[
                if (i > 0) const DDivider(),
                _ReviewRow(name: r.$1, text: r.$2, score: r.$3, avatar: r.$4),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Jauge sombre à graduations (pourcentage de satisfaction) avec halo vert.
class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Satisfaction $percent %',
      excludeSemantics: true,
      child: SizedBox(
        width: 92,
        height: 96,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(child: CustomPaint(painter: _GaugePainter(percent / 100))),
            const Positioned(top: 18, child: AppIcon(AppIcons.zap, size: 13, color: Color(0xFFFFD43B))),
            Positioned(
              top: 30,
              child: Text(
                '$percent%',
                style: AppText.h1.copyWith(
                  fontSize: 29,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9BE58F),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
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
    final r = size.width / 2;
    final c = Offset(r, r);
    // Halo vert sous la jauge.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r, size.width - 4), width: size.width * .8, height: 22),
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
      final paint = Paint()
        ..color = i < lit ? const Color(0xFFF2F2F2) : const Color(0xFF3A3A3A)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + dir * (r - 13), c + dir * (r - 4), paint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $percent %',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: DTxt.item.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text('$percent %', style: DTxt.item.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: DColors.track),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: math.max(percent, 3) / 100,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: DColors.star,
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 17),
    decoration: ShapeDecoration(
      color: const Color(0xCCFFFFFF),
      shape: const StadiumBorder(side: BorderSide(color: DColors.line)),
    ),
    child: Center(
      widthFactor: 1,
      child: Text(label, style: DTxt.label.copyWith(fontWeight: FontWeight.w500)),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.name, required this.text, required this.score, required this.avatar});

  final String name;
  final String text;
  final String score;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avis de $name, note $score : $text',
      excludeSemantics: true,
      child: SizedBox(
        height: 65,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 14, bottom: 5),
          child: Row(
            children: [
              DAvatar(avatar, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DTxt.item),
                    const SizedBox(height: 4),
                    Text(text, style: DTxt.meta.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DBadge(score, background: DColors.lowSoft, foreground: DColors.lowText),
            ],
          ),
        ),
      ),
    );
  }
}
