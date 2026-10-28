import '../../common/common.dart';
import '../ai_widgets.dart';

/// 232 · Voix en texte : note vocale transcrite, réponses de Kéla, création de mission.
class VoixEnTexteScreen extends ConsumerStatefulWidget {
  const VoixEnTexteScreen({super.key});

  @override
  ConsumerState<VoixEnTexteScreen> createState() => _VoixEnTexteScreenState();
}

class _VoixEnTexteScreenState extends ConsumerState<VoixEnTexteScreen> {
  final _sent = <String>[];

  static const _wave = <double>[10.0, 16, 22, 12, 26, 18, 10, 22, 14, 26, 16, 20, 12, 18];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAIDataProvider);
    final chat = d.voiceChat;
    final firstIncoming = chat.indexWhere((m) => m.kind == AiMsgKind.incoming);
    return AppScaffold(
      padding: const EdgeInsets.fromLTRB(20, 0, 24, 0),
      header: AiKelaHeader(title: 'Voix en texte', onMenu: () => context.openScreen('231')),
      bottomBarHeight: 74,
      bottomBar: AiKelaComposer(onSend: (t) => setState(() => _sent.add(t))),
      children: [
        for (final (i, m) in chat.indexed) ...[
          if (i > 0) SizedBox(height: _gapBefore(m.kind, chat[i - 1])),
          _message(m, avatar: i == firstIncoming),
        ],
        for (final t in _sent) ...[
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: AiKelaBubble(t, outgoing: true, maxWidth: 240)),
        ],
      ],
    );
  }

  double _gapBefore(AiMsgKind kind, AiMessage previous) {
    if (previous.kind == AiMsgKind.outgoing) return 20;
    if (kind == AiMsgKind.outgoing) return 12;
    return previous.kind == AiMsgKind.voice ? 11 : 16;
  }

  Widget _time(String time, {required bool right}) => Padding(
    padding: EdgeInsets.only(top: 7, left: right ? 0 : 48),
    child: Text(
      time,
      textAlign: right ? TextAlign.end : TextAlign.start,
      style: AppText.small.copyWith(fontSize: 11, color: const Color(0xFF6E6A73)),
    ),
  );

  Widget _message(AiMessage m, {required bool avatar}) {
    final showTime = m.kind != AiMsgKind.outgoing && !(m.kind == AiMsgKind.incoming && !avatar);
    final body = switch (m.kind) {
      AiMsgKind.voice => Align(
        alignment: Alignment.centerRight,
        child: _VoiceNote(duration: m.text, wave: _wave),
      ),
      AiMsgKind.image => Align(
        alignment: Alignment.centerRight,
        child: Semantics(
          image: true,
          label: 'Image envoyée',
          child: Container(
            width: 138,
            height: 118,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
            ),
          ),
        ),
      ),
      AiMsgKind.outgoing => Align(
        alignment: Alignment.centerRight,
        child: AiKelaBubble(m.text, outgoing: true, maxWidth: 152),
      ),
      _ => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: avatar
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Semantics(
                      label: 'Kéla',
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                      ),
                    ),
                  )
                : null,
          ),
          Flexible(child: AiKelaBubble(m.text)),
        ],
      ),
    };
    if (!showTime) return body;
    final right = m.kind != AiMsgKind.incoming;
    return Column(
      crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        body,
        _time(m.time, right: right),
      ],
    );
  }
}

/// Note vocale envoyée : bouton lecture, onde, durée.
class _VoiceNote extends StatefulWidget {
  const _VoiceNote({required this.duration, required this.wave});

  final String duration;
  final List<double> wave;

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      height: 56,
      padding: const EdgeInsets.only(left: 10, right: 20),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(28)),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: _playing ? 'Mettre la note vocale en pause' : 'Écouter la note vocale',
            child: GestureDetector(
              onTap: () => setState(() => _playing = !_playing),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: _playing
                      ? const AppIcon(AppIcons.pause, size: 16)
                      : const Padding(padding: EdgeInsets.only(left: 2), child: AiPlayGlyph(size: 15)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AiVoiceWave(heights: widget.wave, color: Colors.white, barWidth: 2.5, gap: 4),
          ),
          Text(widget.duration, style: AppText.small.copyWith(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
