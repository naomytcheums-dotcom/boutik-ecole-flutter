import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


/// Réglages globaux des animations (désactivées dans les tests pour des rendus déterministes).
class GAnim {
  static bool enabled = true;
}

/// Sons de l'application (assets/sounds/*.wav, générés par tool/make_sounds.py).
class GSound {
  static bool enabled = true;
  static final Map<String, AudioPlayer> _players = {};

  static Future<void> play(String name, {double volume = 0.7}) async {
    if (!enabled || !GAnim.enabled) return;
    try {
      final p = _players.putIfAbsent(name, () => AudioPlayer());
      await p.stop();
      await p.play(AssetSource('sounds/$name.wav'), volume: volume);
    } catch (_) {
      // Pas de lecteur audio disponible (tests, navigateur bloquant le son) : on ignore.
    }
  }
}

/// Retour tactile : léger effacement + rebond, son et vibration au toucher.
class GPress extends StatefulWidget {
  const GPress({super.key, required this.child, required this.onTap, this.sound = 'click', this.flash = false});
  final Widget child;
  final VoidCallback onTap;
  final String sound;
  final bool flash;
  @override
  State<GPress> createState() => _GPressState();
}

class _GPressState extends State<GPress> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final child = widget.flash
        ? Stack(fit: StackFit.passthrough, children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  decoration: BoxDecoration(color: down ? const Color(0x14111015) : const Color(0x00111015), borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ])
        : widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: () {
          if (GAnim.enabled) {
            GSound.play(widget.sound);
            HapticFeedback.selectionClick();
          }
          widget.onTap();
        },
        child: AnimatedScale(
          scale: down ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(opacity: down && !widget.flash ? 0.85 : 1, duration: const Duration(milliseconds: 110), child: child),
        ),
      ),
    );
  }
}

/// Apparition douce (fondu + glissement) de chaque élément à l'ouverture d'un écran.
class GEnter extends StatefulWidget {
  const GEnter({super.key, required this.child, required this.delay});
  final Widget child;
  final Duration delay;
  @override
  State<GEnter> createState() => _GEnterState();
}

class _GEnterState extends State<GEnter> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  Timer? t;
  @override
  void initState() {
    super.initState();
    t = Timer(widget.delay, () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    t?.cancel();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(opacity: a.value, child: Transform.translate(offset: Offset(0, (1 - a.value) * 14), child: child)),
      child: widget.child,
    );
  }
}

/// Effets ambiants en boucle : halo qui respire, pastille « en direct » qui pulse, barres d'onde sonore.
class GFx extends StatefulWidget {
  const GFx({super.key, required this.kind, required this.child, this.seed = 0});
  final String kind;
  final Widget child;
  final double seed;
  @override
  State<GFx> createState() => _GFxState();
}

class _GFxState extends State<GFx> with SingleTickerProviderStateMixin {
  late final AnimationController c;
  @override
  void initState() {
    super.initState();
    final ms = switch (widget.kind) { 'halo' => 5200, 'pulse' => 1000, 'wave' => 650 + (widget.seed.abs() % 7).toInt() * 60, _ => 2000 };
    c = AnimationController(vsync: this, duration: Duration(milliseconds: ms))..repeat(reverse: true);
    c.value = (widget.seed.abs() % 10) / 10;
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        child: widget.child,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(c.value);
          switch (widget.kind) {
            case 'halo':
              return Transform.scale(scale: 0.94 + 0.14 * v, child: Opacity(opacity: 0.75 + 0.25 * v, child: child));
            case 'pulse':
              return Opacity(opacity: 0.55 + 0.45 * v, child: child);
            case 'wave':
              return Transform.scale(scaleY: 0.35 + 0.65 * v, child: child);
            default:
              return child!;
          }
        },
      );
}

/// Bouton micro : appui = démarre / arrête l'écoute, avec sons et ondes qui s'étendent.
class GMic extends StatefulWidget {
  const GMic({super.key, required this.child, this.onResult});
  final Widget child;
  final void Function(bool listening)? onResult;
  @override
  State<GMic> createState() => _GMicState();
}

class _GMicState extends State<GMic> with SingleTickerProviderStateMixin {
  bool on = false;
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() => on = !on);
    GSound.play(on ? 'mic_start' : 'mic_stop');
    HapticFeedback.mediumImpact();
    if (on && GAnim.enabled) {
      c.repeat();
    } else {
      c.stop();
      c.value = 0;
    }
    widget.onResult?.call(on);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          if (on)
            for (var i = 0; i < 3; i++)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: c,
                  builder: (_, _) {
                    final t = (c.value + i / 3) % 1;
                    return Transform.scale(
                      scale: 1 + t * 0.9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF6A4DFF).withValues(alpha: (1 - t) * 0.55), width: 2)),
                      ),
                    );
                  },
                ),
              ),
          AnimatedScale(scale: on ? 1.08 : 1, duration: const Duration(milliseconds: 200), child: widget.child),
        ]),
      );
}

/// Cœur « favori » : rebond, rouge plein, son.
class GHeart extends StatefulWidget {
  const GHeart({super.key});
  @override
  State<GHeart> createState() => _GHeartState();
}

class _GHeartState extends State<GHeart> with SingleTickerProviderStateMixin {
  bool on = false;
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => on = !on);
          GSound.play(on ? 'pop' : 'tick');
          HapticFeedback.lightImpact();
          if (GAnim.enabled) c.forward(from: 0);
        },
        child: AnimatedBuilder(
          animation: c,
          builder: (_, _) {
            final s = on ? 1 + 0.45 * math.sin(c.value * math.pi) : 1.0;
            return Center(
              child: on
                  ? Transform.scale(scale: s, child: const FittedBox(child: Icon(Icons.favorite_rounded, color: Color(0xFFE5334B), size: 40)))
                  : const SizedBox.expand(),
            );
          },
        ),
      );
}
