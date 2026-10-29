import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';

/// S1 · Écran de démarrage animé : logo qui apparaît, slogan en fondu, barre de chargement.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();
  late final Animation<double> _logo = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
  );
  late final Animation<double> _text = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
  );
  late final Animation<double> _progress = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF2B2420),
      body: Semantics(
        button: true,
        label: 'Entrer dans Boutik-École',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.goScreen('A2'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(d.splashImage, fit: BoxFit.cover, excludeFromSemantics: true),
              LayoutBuilder(
                builder: (context, c) {
                  // Positions relatives de la maquette (390 × 876).
                  final h = c.maxHeight;
                  return AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => Stack(
                      children: [
                        Positioned(
                          top: h * 292 / 876,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Opacity(
                                opacity: _logo.value.clamp(0, 1),
                                child: Transform.scale(
                                  scale: 0.8 + 0.2 * _logo.value,
                                  child: Container(
                                    width: 128,
                                    height: 128,
                                    padding: const EdgeInsets.fromLTRB(9, 10, 9, 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F3F3),
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Image.asset(d.splashLogo, semanticLabel: 'Logo Boutik-École'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              Opacity(
                                opacity: _text.value,
                                child: Transform.translate(
                                  offset: Offset(0, 12 * (1 - _text.value)),
                                  child: Column(
                                    children: [
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          'Boutik-École',
                                          style: AppText.h1.copyWith(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        d.splashTagline,
                                        textAlign: TextAlign.center,
                                        style: AppText.body.copyWith(
                                          color: Colors.white,
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w400,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 85,
                          right: 85,
                          top: h * 803 / 876,
                          child: Column(
                            children: [
                              Semantics(
                                label: 'Chargement',
                                value: '${(_progress.value * 100).round()} %',
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: _progress.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Chargement…',
                                style: AppText.small.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
