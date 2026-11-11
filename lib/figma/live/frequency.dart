import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fréquence des alertes : on choisit au calendrier le nombre de fois par jour et les jours de la semaine, sans rien écrire.
class _Freq extends Notifier<String> {
  @override
  String build() => 'Une fois par jour · tous les jours';
  void set(String v) => state = v;
}

final alertFrequencyProvider = NotifierProvider<_Freq, String>(_Freq.new);

const _jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = const Color(0xFF111015)}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

String _label(int n, Set<int> days) {
  final fois = n == 1 ? 'Une fois par jour' : '$n fois par jour';
  final j = days.length == 7 || days.isEmpty ? 'tous les jours' : ([for (final d in (days.toList()..sort())) _jours[d]]).join(', ');
  return '$fois · $j';
}

class FrequencyField extends ConsumerWidget {
  const FrequencyField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(alertFrequencyProvider);
    return Semantics(
      button: true,
      label: 'Fréquence des alertes : $v. Toucher pour modifier',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context, ref),
        child: Container(
          padding: const EdgeInsets.only(left: 48, right: 40),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6E1EE))),
          child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5)),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) {
    var n = 1;
    final days = <int>{0, 1, 2, 3, 4, 5, 6};
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.calendar_month_outlined, size: 22),
              const SizedBox(width: 8),
              Text('Fréquence des alertes', style: _st(17, w: FontWeight.w800)),
            ]),
            const SizedBox(height: 16),
            Text('Nombre de fois par jour', style: _st(13, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(onPressed: n > 1 ? () => set(() => n--) : null, icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 40, child: Text('$n', textAlign: TextAlign.center, style: _st(20, w: FontWeight.w800))),
              IconButton(onPressed: n < 6 ? () => set(() => n++) : null, icon: const Icon(Icons.add_circle_outline)),
            ]),
            const SizedBox(height: 14),
            Text('Jours de la semaine', style: _st(13, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var d = 0; d < 7; d++)
                GestureDetector(
                  onTap: () => set(() => days.contains(d) ? (days.length > 1 ? days.remove(d) : null) : days.add(d)),
                  child: Container(
                    width: 48,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: days.contains(d) ? const Color(0xFF111015) : const Color(0xFFF1EDF7), borderRadius: BorderRadius.circular(14)),
                    child: Text(_jours[d], style: _st(12.5, w: FontWeight.w600, c: days.contains(d) ? Colors.white : const Color(0xFF111015))),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                ref.read(alertFrequencyProvider.notifier).set(_label(n, days));
                Navigator.of(ctx).pop();
              },
              child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF111015), borderRadius: BorderRadius.circular(25)), child: Text('Valider', style: _st(15, w: FontWeight.w700, c: Colors.white))),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Ligne « Notifications de l'application » : toujours actives (application mobile), sans bouton à activer.
class AppNotificationsRow extends StatelessWidget {
  const AppNotificationsRow({super.key, this.width = 342});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6E1EE))),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Notifications de l’application', style: _st(13, w: FontWeight.w600))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFDDF5EC), borderRadius: BorderRadius.circular(10)), child: Text('Actives', style: _st(11, w: FontWeight.w700, c: const Color(0xFF0F7A52)))),
        ]),
      );
}
