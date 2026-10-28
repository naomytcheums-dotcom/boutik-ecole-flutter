import 'dart:math' as math;

import '../ad_widgets.dart';

/// 225 · Jumeau 3D (aperçu 360° du produit, angles, réalité augmentée).
class Jumeau3dScreen extends ConsumerStatefulWidget {
  const Jumeau3dScreen({super.key});

  @override
  ConsumerState<Jumeau3dScreen> createState() => _Jumeau3dScreenState();
}

class _Jumeau3dScreenState extends ConsumerState<Jumeau3dScreen> {
  int _angle = 0;
  double _turn = -.32;

  static const _presets = [-.32, 1.2, math.pi - .3, -.05];
  static const _alignments = [Alignment.center, Alignment.centerLeft, Alignment.centerRight, Alignment(0, -.4)];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final p = d.liveProduct;
    return AppScaffold(
      showNav: false,
      header: const AdCenterHeader('Jumeau 3D'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 4),
        _Viewer(
          image: p.image,
          turn: _turn,
          alignment: _alignments[_angle],
          onDrag: (dx) => setState(() => _turn += dx / 120),
        ),
        const AdSectionTitle('Angles', top: 18, bottom: 8),
        Row(
          children: [
            for (final (i, a) in d.twinAngles.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _angle,
                  label: 'Vue $a',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _angle = i;
                      _turn = _presets[i];
                    }),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            padding: EdgeInsets.all(i == _angle ? 3 : 0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: i == _angle ? const Color(0xFF6A4DFF) : Colors.transparent,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(i == _angle ? 17 : 20),
                              child: Image.asset(p.image, fit: BoxFit.cover, alignment: _alignments[i]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a,
                          style: AppText.small.copyWith(
                            fontSize: 12,
                            color: i == _angle ? AppColors.accent : AppColors.textSecondary,
                            fontWeight: i == _angle ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        AdCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.title, style: AppText.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final s in d.twinSpecs)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: const ShapeDecoration(color: adLavender, shape: StadiumBorder()),
                      child: Text(s, style: AppText.small.copyWith(fontSize: 12.5, color: const Color(0xFF4A3DB8))),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(d.twinDescription, style: AppText.small.copyWith(fontSize: 11.5, color: const Color(0xFF5E5B66))),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Voir chez moi en réalité augmentée',
                height: 40,
                onPressed: () => context.toast('Ouverture de la caméra en réalité augmentée…'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({required this.image, required this.turn, required this.alignment, required this.onDrag});

  final String image;
  final double turn;
  final Alignment alignment;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    // Inclinaison de la vignette selon la rotation (effet de perspective).
    final tilt = math.sin(turn) * .9;
    return Semantics(
      label: 'Aperçu 3D du produit. Glissez horizontalement pour le faire tourner.',
      child: GestureDetector(
        onHorizontalDragUpdate: (e) => onDrag(e.delta.dx),
        child: Container(
          height: 372,
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFFEDE9F5)),
            boxShadow: adShadow,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 20, right: 20, bottom: 30, height: 58, child: CustomPaint(painter: _OrbitPainter())),
              const Positioned(
                bottom: 28,
                child: CustomPaint(
                  size: Size(190, 40),
                  painter: _BlurOval(Color(0xF0111015), 7, inset: EdgeInsets.symmetric(horizontal: 14, vertical: 11)),
                ),
              ),
              const Positioned(
                top: 40,
                child: CustomPaint(
                  size: Size(250, 290),
                  painter: _BlurOval(Color(0x2E7C5CFF), 22, inset: EdgeInsets.all(30)),
                ),
              ),
              Positioned(
                top: 56,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0016)
                    ..rotateY(tilt)
                    ..rotateZ(.04),
                  child: Container(
                    width: 186,
                    height: 248,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: const Border(top: BorderSide(color: Color(0xFF22D3EE), width: 4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(image, fit: BoxFit.cover, alignment: alignment, excludeFromSemantics: true),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 22,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                  alignment: Alignment.center,
                  child: Text(
                    '360°',
                    style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: 54,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
                  alignment: Alignment.center,
                  child: const AppIcon(AppIcons.rotateCw, size: 12, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 12,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder(), shadows: adShadow),
                  alignment: Alignment.center,
                  child: Text(
                    'Glissez pour tourner',
                    style: AppText.small.copyWith(fontSize: 12, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ovale flou (ombre portée, halo).
class _BlurOval extends CustomPainter {
  const _BlurOval(this.color, this.sigma, {this.inset = EdgeInsets.zero});

  final Color color;
  final double sigma;
  final EdgeInsets inset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      inset.deflateRect(Offset.zero & size),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(_BlurOval old) => old.color != color || old.sigma != sigma;
}

/// Ellipse pointillée violette de l'orbite de rotation.
class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7C5CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()..addOval(Offset.zero & size);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => false;
}
