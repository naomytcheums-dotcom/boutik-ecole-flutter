import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';

const _defaultFrequency = 'Une fois par jour · tous les jours';

/// Fréquence des alertes : on choisit au calendrier le nombre de fois par jour et les jours de la semaine, sans rien écrire.
/// La valeur enregistrée avec les préférences d'alertes du compte (engagement « alert_prefs ») est relue à la connexion.
class _Freq extends Notifier<String> {
  bool _touched = false;

  @override
  String build() {
    ref.watch(authProvider);
    _touched = false;
    _load();
    return _defaultFrequency;
  }

  Future<void> _load() async {
    final rows = await Backend.myEngagements(kind: 'alert_prefs');
    if (rows.isEmpty || _touched || !ref.mounted) return;
    final d = rows.first['data'];
    final f = d is Map ? d['frequency'] : null;
    if (f is String && f.trim().isNotEmpty) state = f.trim();
  }

  void set(String v) {
    _touched = true;
    state = v;
  }
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

/// Relit un libellé produit par [_label] : nombre de fois par jour et jours retenus ; valeurs par défaut si le texte n'est pas reconnu.
(int, Set<int>) _parse(String v) {
  final parts = v.split(' · ');
  final n = parts.first.startsWith('Une') ? 1 : (int.tryParse(parts.first.split(' ').first) ?? 1).clamp(1, 6);
  final all = <int>{0, 1, 2, 3, 4, 5, 6};
  if (parts.length < 2 || parts[1].trim() == 'tous les jours') return (n, all);
  final days = <int>{for (final d in parts[1].split(',')) if (_jours.indexOf(d.trim()) case final i when i >= 0) i};
  return (n, days.isEmpty ? all : days);
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
    final (start, startDays) = _parse(ref.read(alertFrequencyProvider));
    var n = start;
    final days = <int>{...startDays};
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

/// Appareil réellement enregistré pour recevoir les notifications du compte connecté (table `device_tokens`, lisible par son titulaire).
final _deviceRegisteredProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  if (!Backend.ready || Backend.userId == null) return false;
  final r = await Backend.rows('device_tokens', 'token', limit: 1);
  if (r.error != null) throw StateError('device_tokens');
  return r.rows.isNotEmpty;
});

/// Ligne « Notifications de l'application » : « Actives » seulement quand un appareil est enregistré pour ce compte, sinon « Désactivées ».
class AppNotificationsRow extends ConsumerWidget {
  const AppNotificationsRow({super.key, this.width = 342});
  final double width;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(_deviceRegisteredProvider);
    final on = d.value == true;
    final label = d.isLoading && !d.hasValue ? 'Vérification…' : (d.hasError && !d.hasValue ? 'Indisponible' : (on ? 'Actives' : 'Désactivées'));
    return Container(
        width: width,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6E1EE))),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Notifications de l’application', style: _st(13, w: FontWeight.w600))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: on ? const Color(0xFFDDF5EC) : const Color(0xFFF1EDF7), borderRadius: BorderRadius.circular(10)), child: Text(label, style: _st(11, w: FontWeight.w700, c: on ? const Color(0xFF0F7A52) : const Color(0xFF57545F)))),
        ]),
      );
  }
}
