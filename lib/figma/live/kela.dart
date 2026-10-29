import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speech_to_text/speech_to_text.dart';

import '../gen.dart';
import '../nav.dart';

/// Assistante Kéla : l'orbe tourne quand elle écoute ou réfléchit, puis s'arrête dès qu'elle a répondu.
enum KelaPhase { idle, listening, thinking, answered }

/// Texte reconnu à la voix, affiché en direct pendant que l'utilisateur parle.
class KelaText extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final kelaTextProvider = NotifierProvider<KelaText, String>(KelaText.new);
final _speech = SpeechToText();
bool _speechReady = false;

class KelaNotifier extends Notifier<KelaPhase> {
  Timer? _t;
  @override
  KelaPhase build() {
    ref.onDispose(() => _t?.cancel());
    return KelaPhase.idle;
  }

  void toggle(bool listening) {
    _t?.cancel();
    if (listening) {
      state = KelaPhase.listening;
      return;
    }
    state = KelaPhase.thinking;
    _t = Timer(const Duration(milliseconds: 2200), () => state = KelaPhase.answered);
  }
}

final kelaProvider = NotifierProvider<KelaNotifier, KelaPhase>(KelaNotifier.new);

/// Micro de Kéla : transcription vocale réelle (reconnaissance du système), puis ouverture du fil de discussion.
Future<void> kelaToggle(WidgetRef ref, bool listening, BuildContext context) async {
  final n = ref.read(kelaProvider.notifier);
  final text = ref.read(kelaTextProvider.notifier);
  if (listening) {
    text.set('');
    n.toggle(true);
    try {
      _speechReady = _speechReady || await _speech.initialize(onError: (_) {});
      if (!_speechReady) {
        if (context.mounted) gToast(context, 'Reconnaissance vocale indisponible : utilisez Chrome ou autorisez le micro.');
        return;
      }
      await _speech.listen(onResult: (r) => text.set(r.recognizedWords), listenOptions: SpeechListenOptions(partialResults: true, localeId: 'fr_FR'));
    } catch (_) {
      if (context.mounted) gToast(context, 'Micro indisponible sur cet appareil.');
    }
    return;
  }
  try {
    await _speech.stop();
  } catch (_) {}
  n.toggle(false);
  if (ref.read(kelaTextProvider).trim().isEmpty) return;
  await Future<void>.delayed(const Duration(milliseconds: 2400));
  if (context.mounted) gOpen(context, '232');
}

/// Même signature que gBox pour l'image de l'orbe, avec rotation pilotée par l'état de Kéla.
Widget kelaOrb({String? image, BoxFit fit = BoxFit.contain, List<BoxShadow>? shadows}) => Consumer(
      builder: (context, ref, _) => _Spin(
        spinning: ref.watch(kelaProvider) == KelaPhase.listening || ref.watch(kelaProvider) == KelaPhase.thinking,
        child: gBox(image: image, fit: fit, shadows: shadows),
      ),
    );

class _Spin extends StatefulWidget {
  const _Spin({required this.spinning, required this.child});
  final bool spinning;
  final Widget child;
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Spin old) {
    super.didUpdateWidget(old);
    if (old.spinning != widget.spinning) _sync();
  }

  void _sync() {
    if (!GAnim.enabled) return;
    if (widget.spinning) {
      c.repeat();
    } else {
      // Ralentit et s'arrête en douceur à la fin du tour en cours.
      c.animateTo(1, duration: Duration(milliseconds: ((1 - c.value) * 3200 * 1.4).round().clamp(1, 4500)), curve: Curves.easeOutCubic).whenComplete(() {
        if (mounted) c.value = 0;
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: c, child: widget.child);
}
