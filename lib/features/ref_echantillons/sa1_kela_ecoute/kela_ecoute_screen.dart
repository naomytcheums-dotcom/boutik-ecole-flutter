import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// A1 · Assistante vocale Kéla : écoute en cours, question transcrite en direct.
class KelaEcouteScreen extends ConsumerStatefulWidget {
  const KelaEcouteScreen({super.key});

  @override
  ConsumerState<KelaEcouteScreen> createState() => _KelaEcouteScreenState();
}

class _KelaEcouteScreenState extends ConsumerState<KelaEcouteScreen> {
  bool _listening = true;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    final question = AppText.h1.copyWith(fontSize: 26.8, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: -0.4);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _KelaBackground()),
          SafeArea(
            minimum: const EdgeInsets.only(top: 28),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    children: [
                      RefGlassButton(
                        icon: AppIcons.arrowLeft,
                        label: 'Retour',
                        onTap: () => ScreenHeader.back(context),
                      ),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Column(
                            children: [
                              Text('Assistante vocale Kéla', style: AppText.h3.copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(_listening ? 'À l’écoute…' : 'En pause', style: AppText.small),
                            ],
                          ),
                        ),
                      ),
                      RefGlassButton(
                        icon: AppIcons.equal,
                        label: 'Options de Kéla',
                        onTap: () => context.openScreen('A2'),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: Semantics(
                    liveRegion: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${d.kelaQuestionAsked}\n',
                            style: question.copyWith(color: const Color(0xFF8F8A93)),
                          ),
                          TextSpan(text: d.kelaQuestionLive, style: question),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Opacity(
                  opacity: _listening ? 1 : 0.35,
                  child: RefWaveform(
                    heights: d.kelaWave,
                    gap: 7,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF9D8DF7), Color(0xFF6E5BE6)],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RefGlassButton(text: 'IA', label: 'Écrire à Kéla', onTap: () => context.openScreen('A3')),
                      Semantics(
                        button: true,
                        label: _listening ? 'Mettre l’écoute en pause' : 'Reprendre l’écoute',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => setState(() => _listening = !_listening),
                          child: Container(
                            key: const Key('kela-mic'),
                            width: 84,
                            height: 84,
                            decoration: const BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 8))],
                            ),
                            alignment: Alignment.center,
                            child: AppIcon(_listening ? AppIcons.mic : AppIcons.micOff, size: 26, color: Colors.white),
                          ),
                        ),
                      ),
                      RefGlassButton(icon: AppIcons.x, label: 'Fermer Kéla', onTap: () => ScreenHeader.back(context)),
                    ],
                  ),
                ),
                const SizedBox(height: 57),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fond nacré avec halos pêche et lavande.
class _KelaBackground extends StatelessWidget {
  const _KelaBackground();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFEBE7), Color(0xFFECE2E3), Color(0xFFE7DBE8)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.1, -0.27),
                  radius: 0.62,
                  colors: [Color(0xFFF2CDB6), Color(0x00F2CDB6)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.75, -0.3),
                  radius: 0.6,
                  colors: [Color(0xFFD8C2EE), Color(0x00D8C2EE)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-1.0, 0.95),
                  radius: 0.8,
                  colors: [Color(0xFFF0CCC4), Color(0x00F0CCC4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
