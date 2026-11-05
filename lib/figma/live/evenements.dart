import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'store.dart' show fcfa, nowProvider;

/// Événements (écran 100) : agenda de la semaine lu sur le serveur (migration 20261105000000), filtre par type et par jour,
/// inscription et désinscription. Hors connexion au serveur, la maquette reste affichée comme démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

const _jours = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'];
const _initiales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _types = [null, 'exposition', 'atelier', 'conference'];

class AppEvent {
  const AppEvent({required this.id, required this.title, required this.kind, required this.startsAt, required this.place, required this.price, required this.capacity, required this.registered, required this.mine});
  final String id, title, kind, place;
  final DateTime startsAt;
  final int price, registered;
  final int? capacity;
  final bool mine;

  static AppEvent fromRow(Map x) => AppEvent(
        id: '${x['id']}',
        title: '${x['title']}',
        kind: '${x['kind']}',
        startsAt: (DateTime.tryParse('${x['starts_at']}') ?? DateTime.now()).toLocal(),
        place: '${x['place'] ?? ''}',
        price: (x['price'] as num?)?.toInt() ?? 0,
        capacity: (x['capacity'] as num?)?.toInt(),
        registered: (x['registered'] as num?)?.toInt() ?? 0,
        mine: x['mine'] == true,
      );

  int? get left => capacity == null ? null : (capacity! - registered).clamp(0, capacity!);
  bool get full => left != null && left == 0;

  /// « Sam. 24 oct. · 10 h · Hall principal ».
  String get when {
    final d = startsAt;
    final h = d.minute == 0 ? '${d.hour} h' : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';
    return [ '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}', h, if (place.isNotEmpty) place ].join(' · ');
  }
}

/// Lundi 00 h de la semaine contenant `d`.
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

class EventKind extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v;
}

final eventKindProvider = NotifierProvider<EventKind, int>(EventKind.new);

/// Jour choisi dans la semaine (null : toute la semaine).
class EventDay extends Notifier<int?> {
  @override
  int? build() => null;
  void toggle(int v) => state = state == v ? null : v;
}

final eventDayProvider = NotifierProvider<EventDay, int?>(EventDay.new);

/// `null` : lecture en cours ou serveur absent ; liste vide : aucun événement. `error` : la lecture a échoué.
class EventsNotifier extends Notifier<List<AppEvent>?> {
  bool error = false;

  @override
  List<AppEvent>? build() {
    if (!Backend.ready) return null;
    final kind = ref.watch(eventKindProvider);
    final start = weekStart(ref.watch(nowProvider));
    Future.microtask(() => _load(start, kind));
    return null;
  }

  Future<void> _load(DateTime start, int kind) async {
    final r = await Backend.rpc('events_between', {'p_from': start.toUtc().toIso8601String(), 'p_to': start.add(const Duration(days: 7)).toUtc().toIso8601String(), 'p_kind': _types[kind.clamp(0, 3)]});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) AppEvent.fromRow(x as Map)];
  }

  Future<void> refresh() => _load(weekStart(ref.read(nowProvider)), ref.read(eventKindProvider));
}

final eventsProvider = NotifierProvider<EventsNotifier, List<AppEvent>?>(EventsNotifier.new);

Future<void> toggleRegistration(BuildContext context, WidgetRef ref, AppEvent e) async {
  if (!await requireLogin(context, ref, 'vous inscrire à un événement') || !context.mounted) return;
  final r = e.mine ? await Backend.rpc('event_unregister', {'p_event': e.id}) : await Backend.rpc('event_register', {'p_event': e.id});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Inscription impossible', Backend.userMessage(r.error!));
  await ref.read(eventsProvider.notifier).refresh();
  if (context.mounted) gToast(context, e.mine ? 'Inscription annulée' : 'Vous êtes inscrit(e) : ${e.title}');
}

/// Bandeau des 7 jours de la semaine : le jour touché filtre la liste ; un point signale les jours qui ont des événements.
class EventsWeekStrip extends ConsumerWidget {
  const EventsWeekStrip({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final start = weekStart(now);
    final sel = ref.watch(eventDayProvider);
    final events = ref.watch(eventsProvider) ?? const <AppEvent>[];
    return SizedBox(
      width: width,
      height: 68,
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(eventDayProvider.notifier).toggle(i),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_initiales[i], style: _st(11, c: _grey)),
                const SizedBox(height: 6),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: sel == i ? _ink : Colors.transparent, border: Border.all(color: sel == null && DateUtils.isSameDay(start.add(Duration(days: i)), now) ? _ink : Colors.transparent, width: 1.4)),
                  child: Text('${start.add(Duration(days: i)).day}', style: _st(15, w: FontWeight.w700, c: sel == i ? Colors.white : _ink)),
                ),
                const SizedBox(height: 3),
                Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: events.any((e) => e.startsAt.weekday == i + 1) ? const Color(0xFF5A3FE0) : Colors.transparent)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Liste des événements de la semaine : chargement, erreur, état vide, puis une ligne par événement avec son inscription.
class EventsList extends ConsumerWidget {
  const EventsList({super.key, this.width = 342, this.height = 480});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(eventsProvider);
    final sel = ref.watch(eventDayProvider);
    Widget note(String t) => Container(
          width: width,
          height: 200,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
          child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
        );
    if (all == null) return note('Chargement des événements…');
    if (ref.read(eventsProvider.notifier).error) return note('Les événements ne peuvent pas être chargés pour le moment.');
    final list = [for (final e in all) if (sel == null || e.startsAt.weekday == sel + 1) e];
    if (list.isEmpty) return note(sel == null ? 'Aucun événement cette semaine.\nLes expositions, ateliers et conférences de l’établissement apparaîtront ici.' : 'Aucun événement ce jour-là.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 22, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final e = list[i];
          final label = e.mine ? 'Inscrit(e)' : (e.full ? 'Complet' : 'Inscription');
          return Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(e.when, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                const SizedBox(height: 3),
                Text([e.price == 0 ? 'Gratuit' : fcfa(e.price), if (e.left != null) '${e.left} place${e.left == 1 ? '' : 's'}'].join(' · '), style: _st(11, w: FontWeight.w600, c: const Color(0xFF0F7A52))),
              ]),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: e.full && !e.mine ? null : () => toggleRegistration(context, ref, e),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: e.mine ? const Color(0xFFEEE9FF) : (e.full ? const Color(0xFFF2EFF6) : _ink), borderRadius: BorderRadius.circular(16)),
                child: Text(label, style: _st(11.5, w: FontWeight.w600, c: e.mine ? const Color(0xFF5A3FE0) : (e.full ? _grey : Colors.white))),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
