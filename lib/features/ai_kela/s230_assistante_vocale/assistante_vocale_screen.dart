import '../../common/common.dart';
import '../ai_widgets.dart';

/// 230 · Assistante vocale Kéla : écoute en cours, transcription de la demande.
class AssistanteVocaleScreen extends ConsumerStatefulWidget {
  const AssistanteVocaleScreen({super.key});

  @override
  ConsumerState<AssistanteVocaleScreen> createState() => _AssistanteVocaleScreenState();
}

class _AssistanteVocaleScreenState extends ConsumerState<AssistanteVocaleScreen> {
  bool _listening = true;

  static const _wave = <double>[12.0, 22, 30, 18, 32, 24, 14, 26, 12];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAIDataProvider);
    final speech = AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w500, height: 1.36, letterSpacing: -0.2);
    return AppScaffold(
      showNav: false,
      header: AiKelaHeader(
        title: 'Assistante vocale ${d.assistantName}',
        subtitle: _listening ? 'À l’écoute…' : 'En pause',
        bottom: 0,
        onMenu: () => context.openScreen('231'),
      ),
      bottomBarHeight: 141,
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 45),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AiRoundButton(text: 'IA', label: 'Voir la transcription', onTap: () => context.openScreen('232')),
            Semantics(
              button: true,
              toggled: _listening,
              label: _listening ? 'Mettre l’écoute en pause' : 'Reprendre l’écoute',
              child: GestureDetector(
                onTap: () => setState(() => _listening = !_listening),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 30, offset: Offset(0, 8))],
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(_listening ? AppIcons.mic : AppIcons.micOff, size: 26, color: Colors.white),
                ),
              ),
            ),
            AiRoundButton(icon: AppIcons.x, label: 'Fermer l’assistante', onTap: () => ScreenHeader.back(context)),
          ],
        ),
      ),
      children: [
        const SizedBox(height: 84),
        Center(
          child: SizedBox(
            width: 250,
            height: 246,
            child: Image.asset(
              'assets/images/ai_kela_noeud.png',
              fit: BoxFit.contain,
              semanticLabel: 'Kéla, l’assistante vocale',
            ),
          ),
        ),
        const SizedBox(height: 35),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(d.spokenAlready, style: speech.copyWith(color: const Color(0xFF78747D))),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(d.spokenNow, style: speech.copyWith(color: AppColors.ink)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 27),
        Center(
          child: AnimatedOpacity(
            opacity: _listening ? 1 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: const AiVoiceWave(heights: _wave, barWidth: 3.5, gap: 5),
          ),
        ),
      ],
    );
  }
}
