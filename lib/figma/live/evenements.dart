import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
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

/// Mois affiché par le calendrier (1er jour du mois) ; l'année se change aussi.
class EventMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = ref.read(nowProvider);
    return DateTime(n.year, n.month);
  }

  void set(DateTime v) => state = DateTime(v.year, v.month);
  void shift(int months) => state = DateTime(state.year, state.month + months);
  void shiftYears(int years) => state = DateTime(state.year + years, state.month);
}

final eventMonthProvider = NotifierProvider<EventMonth, DateTime>(EventMonth.new);

/// Jour touché dans le calendrier (null : tout le mois).
class EventDate extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void toggle(DateTime v) => state = state != null && DateUtils.isSameDay(state, v) ? null : v;
  void clear() => state = null;
}

final eventDateProvider = NotifierProvider<EventDate, DateTime?>(EventDate.new);

/// Premier jour (lundi) de la grille d'un mois.
DateTime gridStart(DateTime month) => weekStart(DateTime(month.year, month.month, 1));

/// `null` : lecture en cours ou serveur absent ; liste vide : aucun événement. `error` : la lecture a échoué.
class EventsNotifier extends Notifier<List<AppEvent>?> {
  bool error = false;

  @override
  List<AppEvent>? build() {
    if (!Backend.ready) return null;
    final kind = ref.watch(eventKindProvider);
    final start = gridStart(ref.watch(eventMonthProvider));
    Future.microtask(() => _load(start, kind));
    return null;
  }

  Future<void> _load(DateTime start, int kind) async {
    final r = await Backend.rpc('events_between', {'p_from': start.toUtc().toIso8601String(), 'p_to': start.add(const Duration(days: 42)).toUtc().toIso8601String(), 'p_kind': _types[kind.clamp(0, 3)]});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) AppEvent.fromRow(x as Map)];
  }

  Future<void> refresh() => _load(gridStart(ref.read(eventMonthProvider)), ref.read(eventKindProvider));
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
              child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
              ])),
            ),
          ),
      ]),
    );
  }
}

const _moisLong = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

/// Calendrier complet du mois (comme celui d'un téléphone) : tous les jours en grille, changement de mois et d'année par flèches ou balayage,
/// dates avec événements encerclées et titrées dans la case, jour d'aujourd'hui entouré ; toucher un jour filtre la liste placée dessous.
class EventsCalendar extends ConsumerWidget {
  const EventsCalendar({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(eventMonthProvider);
    final sel = ref.watch(eventDateProvider);
    final now = ref.watch(nowProvider);
    final events = ref.watch(eventsProvider) ?? const <AppEvent>[];
    final start = gridStart(month);
    Widget arrow(IconData i, VoidCallback f, String tip) => IconButton(onPressed: f, tooltip: tip, icon: Icon(i, size: 20, color: _ink));
    final cell = width / 7;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        ref.read(eventDateProvider.notifier).clear();
        ref.read(eventMonthProvider.notifier).shift(v < 0 ? 1 : -1);
      },
      child: SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            arrow(Icons.keyboard_double_arrow_left, () { ref.read(eventDateProvider.notifier).clear(); ref.read(eventMonthProvider.notifier).shiftYears(-1); }, 'Année précédente'),
            arrow(Icons.chevron_left, () { ref.read(eventDateProvider.notifier).clear(); ref.read(eventMonthProvider.notifier).shift(-1); }, 'Mois précédent'),
            Expanded(
              child: GestureDetector(
                onTap: () { ref.read(eventDateProvider.notifier).clear(); ref.read(eventMonthProvider.notifier).set(DateTime(now.year, now.month)); },
                child: Text('${_moisLong[month.month - 1]} ${month.year}', textAlign: TextAlign.center, style: _st(16, w: FontWeight.w800)),
              ),
            ),
            arrow(Icons.chevron_right, () { ref.read(eventDateProvider.notifier).clear(); ref.read(eventMonthProvider.notifier).shift(1); }, 'Mois suivant'),
            arrow(Icons.keyboard_double_arrow_right, () { ref.read(eventDateProvider.notifier).clear(); ref.read(eventMonthProvider.notifier).shiftYears(1); }, 'Année suivante'),
          ]),
          Row(children: [for (final l in _initiales) SizedBox(width: cell, child: Text(l, textAlign: TextAlign.center, style: _st(11, c: _grey)))]),
          const SizedBox(height: 4),
          for (var w = 0; w < 6; w++)
            Row(children: [
              for (var i = 0; i < 7; i++)
                Builder(builder: (_) {
                  final d = start.add(Duration(days: w * 7 + i));
                  final inMonth = d.month == month.month;
                  final dayEvents = [for (final e in events) if (DateUtils.isSameDay(e.startsAt, d)) e];
                  final isSel = sel != null && DateUtils.isSameDay(sel, d);
                  final today = DateUtils.isSameDay(d, now);
                  final has = dayEvents.isNotEmpty;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(eventDateProvider.notifier).toggle(d),
                    child: SizedBox(
                      width: cell,
                      height: 54,
                      child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? _ink : Colors.transparent,
                            border: Border.all(color: has ? const Color(0xFF5A3FE0) : (today ? _ink : Colors.transparent), width: 1.6),
                          ),
                          child: Text('${d.day}', style: _st(13.5, w: has || today ? FontWeight.w800 : FontWeight.w500, c: isSel ? Colors.white : (inMonth ? _ink : const Color(0xFFB8B4C2)))),
                        ),
                        if (has)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(dayEvents.first.title, maxLines: 1, overflow: TextOverflow.clip, textAlign: TextAlign.center, style: _st(7.5, c: const Color(0xFF5A3FE0))),
                          ),
                      ]),
                    ),
                  );
                }),
            ]),
        ]),
      ),
    );
  }
}

/// Liste des événements de la semaine : chargement, erreur, état vide, puis une ligne par événement avec son inscription.
class EventsList extends ConsumerWidget {
  const EventsList({super.key, this.width = 342, this.height = 480, this.calendar = false});
  final double width, height;

  /// Mode calendrier : le mois affiché et le jour touché filtrent la liste.
  final bool calendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(eventsProvider);
    final sel = ref.watch(eventDayProvider);
    Widget note(String t) => Container(
          width: width,
          height: 200,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)),
        );
    if (all == null) return note('Chargement des événements…');
    if (ref.read(eventsProvider.notifier).error) return note('Les événements ne peuvent pas être chargés pour le moment.');
    final month = ref.watch(eventMonthProvider);
    final date = ref.watch(eventDateProvider);
    final list = calendar
        ? [for (final e in all) if (date != null ? DateUtils.isSameDay(e.startsAt, date) : (e.startsAt.year == month.year && e.startsAt.month == month.month)) e]
        : [for (final e in all) if (sel == null || e.startsAt.weekday == sel + 1) e];
    if (list.isEmpty) return note(calendar ? (date == null ? 'Aucun événement ce mois-ci.\nLes expositions, ateliers et conférences de l’établissement apparaîtront ici.' : 'Aucun événement ce jour-là.') : (sel == null ? 'Aucun événement cette semaine.\nLes expositions, ateliers et conférences de l’établissement apparaîtront ici.' : 'Aucun événement ce jour-là.'));
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
              child: GestureDetector(
               behavior: HitTestBehavior.opaque,
               onTap: () => eventDetail(context, ref, e),
               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(e.when, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                const SizedBox(height: 3),
                Text([e.price == 0 ? 'Gratuit' : fcfa(e.price), if (e.left != null) '${e.left} place${e.left == 1 ? '' : 's'}'].join(' · '), style: _st(11, w: FontWeight.w600, c: const Color(0xFF0F7A52))),
              ]),
              ),
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

class AdminEvent {
  const AdminEvent({required this.title, required this.startsAt, required this.place, required this.registered, required this.capacity, required this.status});
  final String title, place, status;
  final DateTime startsAt;
  final int registered;
  final int? capacity;

  String get statusLabel => switch (status) { 'published' => 'Publié', 'cancelled' => 'Annulé', _ => 'Brouillon' };
  String get dateLabel => '${startsAt.day} ${_mois[startsAt.month - 1]} ${startsAt.year}';
  String get registeredLabel => capacity == null ? '$registered' : '$registered / $capacity';
}

/// Tous les événements (écran 124, réservé à la gestion : le serveur ne renvoie que ce que le rôle peut voir).
/// `null` : lecture en cours ou serveur absent.
class AdminEventsNotifier extends Notifier<List<AdminEvent>?> {
  bool error = false;

  @override
  List<AdminEvent>? build() {
    if (!Backend.ready) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rows('events', 'title,starts_at,place,capacity,status,event_registrations(count)', order: 'starts_at', ascending: false, limit: 100);
    if (!ref.mounted) return;
    error = r.error != null;
    state = [
      for (final x in r.rows)
        AdminEvent(
          title: '${x['title']}',
          startsAt: (DateTime.tryParse('${x['starts_at']}') ?? DateTime.now()).toLocal(),
          place: '${x['place'] ?? ''}',
          registered: (((x['event_registrations'] as List?)?.firstOrNull as Map?)?['count'] as num?)?.toInt() ?? 0,
          capacity: (x['capacity'] as num?)?.toInt(),
          status: '${x['status']}',
        ),
    ];
  }
}

final adminEventsProvider = NotifierProvider<AdminEventsNotifier, List<AdminEvent>?>(AdminEventsNotifier.new);

/// Tableau des événements de la console de gestion : mêmes colonnes que la maquette, lignes réelles, états vide et erreur.
class AdminEventsTable extends ConsumerWidget {
  const AdminEventsTable({super.key, this.width = 940, this.height = 420});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(adminEventsProvider);
    final failed = ref.read(adminEventsProvider.notifier).error;
    Widget note(String t) => SizedBox(width: width, height: height, child: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(left: 16, top: 12), child: Text(t, style: _st(13, c: _grey)))));
    if (list == null) return note('Chargement des événements…');
    if (failed) return note('Les événements ne peuvent pas être chargés pour le moment (accès réservé à la gestion).');
    if (list.isEmpty) return note('Aucun événement enregistré.');
    Widget cell(double x, double w, String t, {FontWeight fw = FontWeight.w500, Color? c}) => Positioned(left: x, width: w, top: 0, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, w: fw, c: c ?? const Color(0xFF3D3B37))));
    return SizedBox(
      width: width,
      height: height,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        itemExtent: 44,
        itemBuilder: (_, i) {
          final e = list[i];
          return Stack(children: [
            cell(16, 270, e.title, fw: FontWeight.w600, c: _ink),
            cell(301.6, 140, e.dateLabel),
            cell(453.9, 160, e.place.isEmpty ? '—' : e.place),
            cell(625.3, 120, e.registeredLabel),
            cell(758.6, 150, e.statusLabel, fw: FontWeight.w600, c: e.status == 'published' ? const Color(0xFF0F7A52) : _grey),
          ]);
        },
      ),
    );
  }
}


/// Détail d'un événement (touché dans la liste) : type, date, lieu, tarif, places restantes et inscription / désinscription.
Future<void> eventDetail(BuildContext context, WidgetRef ref, AppEvent e) async {
  const kinds = {'exposition': 'Exposition', 'atelier': 'Atelier', 'conference': 'Conférence'};
  final soon = e.startsAt.isAfter(DateTime.now()) && e.startsAt.difference(DateTime.now()).inDays < 7;
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(e.title, style: _st(17, w: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(kinds[e.kind] ?? e.kind, style: _st(12, w: FontWeight.w600, c: const Color(0xFF5A3FE0))),
        const SizedBox(height: 8),
        Text(e.when, style: _st(13.5)),
        const SizedBox(height: 6),
        Text(e.price == 0 ? 'Entrée gratuite' : 'Tarif : ${fcfa(e.price)}', style: _st(13)),
        if (e.left != null) Text(e.full ? 'Complet' : '${e.left} place${e.left == 1 ? '' : 's'} restante${e.left == 1 ? '' : 's'}', style: _st(13)),
        if (soon) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Bientôt : cet événement a lieu dans moins de 7 jours.', style: _st(12, c: const Color(0xFF8F5400)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Fermer', style: _st(14, w: FontWeight.w600, c: _grey))),
        if (e.mine || !e.full)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              toggleRegistration(context, ref, e);
            },
            child: Text(e.mine ? 'Annuler mon inscription' : 'M’inscrire', style: _st(14, w: FontWeight.w700)),
          ),
      ],
    ),
  );
}
