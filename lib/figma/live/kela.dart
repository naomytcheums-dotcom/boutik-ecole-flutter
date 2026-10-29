import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';

/// Assistante Kéla : l'orbe tourne quand elle écoute ou réfléchit, puis s'arrête dès qu'elle a répondu.
enum KelaPhase { idle, listening, thinking, answered }

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

void kelaToggle(WidgetRef ref, bool listening) => ref.read(kelaProvider.notifier).toggle(listening);

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
