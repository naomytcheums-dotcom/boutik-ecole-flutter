import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// A3 · Voix en texte : conversation avec Kéla (vocal transcrit, photo, messages).
class VoixTexteScreen extends ConsumerStatefulWidget {
  const VoixTexteScreen({super.key});

  @override
  ConsumerState<VoixTexteScreen> createState() => _VoixTexteScreenState();
}

class _VoixTexteScreenState extends ConsumerState<VoixTexteScreen> {
  final _input = TextEditingController();
  final _sent = <String>[];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sent.add(text);
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      header: RefHeader(
        title: 'Voix en texte',
        trailing: RefGlassButton(icon: AppIcons.equal, label: 'Options', onTap: () => context.openScreen('A2')),
      ),
      bottomBarHeight: 70,
      bottomBar: _Composer(controller: _input, onSend: _send, onMic: () => context.openScreen('A1')),
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _VoiceBubble(duration: d.voiceDuration, wave: d.voiceWave),
        ),
        _Time(d.voiceTime, right: true),
        for (final (kela, text, time, image) in d.chat) ...[
          if (image != null)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 140,
                height: 120,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: RefPhoto(image, radius: 18, semanticLabel: 'Photo envoyée'),
              ),
            )
          else if (kela)
            _KelaBubble(text: text, avatar: d.userAvatar)
          else
            _UserBubble(text),
          if (time != null) _Time(time, right: !kela) else const SizedBox(height: 18),
        ],
        for (final t in _sent) ...[_UserBubble(t), const SizedBox(height: 18)],
      ],
    );
  }
}

class _Time extends StatelessWidget {
  const _Time(this.time, {required this.right});

  final String time;
  final bool right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(right ? 0 : 48, 6, 0, 16),
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(time, style: AppText.small.copyWith(fontSize: 11)),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.duration, required this.wave});

  final String duration;
  final List<double> wave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(27)),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Écouter le message vocal',
            excludeSemantics: true,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.only(left: 2),
                child: AppIcon(AppIcons.play, size: 16, color: AppColors.ink),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: RefWaveform(heights: wave, color: Colors.white, barWidth: 2.4, gap: 3.6),
          ),
          Text(duration, style: AppText.small.copyWith(color: Colors.white)),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _KelaBubble extends StatelessWidget {
  const _KelaBubble({required this.text, required this.avatar});

  final String text;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(image: avatar, size: 36),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 276),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Text(text, style: AppText.body.copyWith(fontSize: 13.4, height: 1.48)),
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 152),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
        child: Text(text, style: AppText.body.copyWith(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.onMic});

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: AppIcons.plus,
            label: 'Joindre un fichier',
            bordered: false,
            background: Colors.transparent,
            onTap: () => context.toast('Pièce jointe : bientôt disponible'),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: TextField(
              key: const Key('kela-input'),
              controller: controller,
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Écris ou parle à Kéla…',
                hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          RoundIconButton(
            icon: AppIcons.mic,
            label: 'Parler à Kéla',
            bordered: false,
            background: AppColors.ink,
            foreground: Colors.white,
            onTap: onMic,
          ),
        ],
      ),
    );
  }
}
