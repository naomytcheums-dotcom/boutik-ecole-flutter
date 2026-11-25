import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/money.dart' show fcfa;
import '../gen.dart' show gAlert, gDialog, gToast;
import '../i18n.dart' show Text;
import '../nav.dart' show gOpenProfile;
import 'atelier_action.dart';
import 'auth.dart' show authProvider, requireLogin;
import 'backend.dart';
import 'lives.dart' show canBroadcastLive, liveBroadcastRule, openHostConsole, openLive, showGiftSheet;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'replays.dart' show MyReplaysList, ReplaysLibrary, kReplayShareOrigin;
import 'share.dart' show shareText;

/// Atelier en direct (/atelier) : quatre onglets (En direct, À venir, Replays, Mes lives) construits sur les lives réels (lives_now, lives_agenda, my_lives), leurs réglages
/// (live_settings_get / lives_atelier_extras, migration 20261127500000) et la bibliothèque de replays. Aucune donnée d'exemple, aucun aperçu vidéo simulé : sans flux, vignette neutre.
/// Définitions affichées : « spectateurs en direct » = personnes connectées au live en ce moment ; « vues totales » = personnes identifiées ayant rejoint ce live au moins une fois.

const kAtelierTabs = ['En direct', 'À venir', 'Replays', 'Mes lives'];

const kAtelierDefinitions = 'Spectateurs en direct : personnes connectées au live en ce moment. Vues totales : personnes identifiées ayant rejoint ce live au moins une fois (comptées une seule fois). '
    'Un aperçu affiché dans une liste n’est jamais compté comme une vue.';

const kAtelierRoles = {
  'student': 'Étudiant',
  'client': 'Client',
  'company': 'Entreprise',
  'dept': 'Département',
  'direction': 'Direction',
  'admin': 'Administration',
};

String liveShareLink(String id) => '$kReplayShareOrigin/s/222?live=$id';

class AtelierException implements Exception {
  AtelierException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _err(Object? e) {
  if (e == 'offline') return 'L’Atelier en direct est disponible une fois l’application connectée au serveur.';
  if (e == 'missing') return 'L’Atelier en direct n’est pas encore installé sur le serveur.';
  return Backend.userMessage('$e');
}

Future<List<Map<String, dynamic>>> _rows(String fn, Map<String, dynamic> p) async {
  final r = await marcheCall(fn, p);
  if (r.error != null) throw AtelierException(_err(r.error));
  return [for (final x in (r.data as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
}

/// Ajoute à chaque live ses réglages et compteurs réels (lives_atelier_extras). Si le serveur ne les fournit pas, les compteurs restent « non disponibles » (jamais 0).
Future<List<Map<String, dynamic>>> mergeAtelierExtras(List<Map<String, dynamic>> rows) async {
  if (rows.isEmpty) return rows;
  final r = await marcheCall('lives_atelier_extras', {'p_live_ids': [for (final x in rows) '${x['id']}']});
  if (r.error != null || r.data is! List) return [for (final x in rows) {...x, 'extras_unavailable': true}];
  final byId = {for (final x in r.data as List) if (x is Map) '${x['id']}': Map<String, dynamic>.from(x)};
  final out = <Map<String, dynamic>>[];
  for (final x in rows) {
    final extra = byId['${x['id']}'];
    final m = <String, dynamic>{...?extra};
    x.forEach((k, v) {
      if (v != null || !m.containsKey(k)) m[k] = v;
    });
    if (extra == null) m['extras_unavailable'] = true;
    out.add(m);
  }
  return out;
}

final atelierNowProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  final rows = (await _rows('lives_now', {'p_limit': 60})).where((x) => x['status'] == 'live').toList();
  return mergeAtelierExtras(rows);
}, retry: (_, _) => null);

/// `true` : seulement les lives dont j'ai activé le rappel.
final atelierUpcomingProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, bool>((ref, remindersOnly) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  final rows = (await _rows('lives_agenda', {'p_scope': remindersOnly ? 'mine' : 'all', 'p_limit': 100})).where((x) => x['status'] == 'scheduled').toList();
  return mergeAtelierExtras(rows);
}, retry: (_, _) => null);

final atelierMineProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.current == null))) return const [];
  return mergeAtelierExtras(await _rows('my_lives', const {}));
}, retry: (_, _) => null);

final liveStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await marcheCall('live_host_stats', {'p_live': id});
  if (r.error != null) throw AtelierException(_err(r.error));
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}, retry: (_, _) => null);

// ------------------------------------------------------------------ filtres (côté application, sur les lives chargés)

class AtelierFilter {
  const AtelierFilter({this.q = '', this.filiere = '', this.sector = '', this.category = '', this.role = '', this.when = 'all'});
  final String q, filiere, sector, category, role, when;

  AtelierFilter copyWith({String? q, String? filiere, String? sector, String? category, String? role, String? when}) =>
      AtelierFilter(q: q ?? this.q, filiere: filiere ?? this.filiere, sector: sector ?? this.sector, category: category ?? this.category, role: role ?? this.role, when: when ?? this.when);

  bool get active => q.isNotEmpty || filiere.isNotEmpty || sector.isNotEmpty || category.isNotEmpty || role.isNotEmpty || when != 'all';
}

bool _same(String wanted, Object? v) => wanted.isEmpty || '${v ?? ''}'.trim().toLowerCase() == wanted.toLowerCase();

/// Recherche par titre, animateur et hashtag ; filtres filière, secteur, catégorie, type de profil et période.
List<Map<String, dynamic>> applyAtelierFilter(List<Map<String, dynamic>> rows, AtelierFilter f, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final q = f.q.trim().toLowerCase().replaceFirst(RegExp(r'^#+'), '');
  bool inWindow(Map<String, dynamic> x) {
    if (f.when == 'all' || x['status'] == 'live') return true;
    final d = DateTime.tryParse('${x['scheduled_at'] ?? ''}')?.toLocal();
    if (d == null) return false;
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    return switch (f.when) {
      'today' => day == today,
      'week' => !day.isBefore(today) && day.isBefore(today.add(const Duration(days: 7))),
      'month' => !day.isBefore(today) && day.isBefore(today.add(const Duration(days: 31))),
      _ => true,
    };
  }

  return [
    for (final x in rows)
      if (_same(f.filiere, x['filiere']) && _same(f.sector, x['sector']) && _same(f.category, x['category']) && _same(f.role, x['host_role']) && inWindow(x))
        if (q.isEmpty ||
            '${x['title'] ?? ''}'.toLowerCase().contains(q) ||
            '${x['host'] ?? ''}'.toLowerCase().contains(q) ||
            [for (final t in (x['hashtags'] as List? ?? const [])) '$t'.toLowerCase()].any((t) => t.contains(q)))
          x,
  ];
}

/// Valeurs distinctes d'une colonne parmi les lives chargés (les filtres ne proposent que ce qui existe réellement).
List<String> atelierOptions(List<Map<String, dynamic>> rows, String key) {
  final seen = <String, String>{};
  for (final x in rows) {
    final v = '${x[key] ?? ''}'.trim();
    if (v.isNotEmpty) seen.putIfAbsent(v.toLowerCase(), () => v);
  }
  return seen.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String atelierWhen(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  final h = d.minute == 0 ? '${d.hour} h' : '${d.hour} h ${d.minute.toString().padLeft(2, '0')}';
  return '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]} · $h';
}

String _plural(int n, String one, String many) => '$n ${n > 1 ? many : one}';

/// Prix d'un live = prix de l'événement lié (aucune règle financière propre au live).
String atelierPrice(Map<String, dynamic> x) {
  if (x['extras_unavailable'] == true && !x.containsKey('free')) return '';
  final price = (x['price'] as num?)?.toInt() ?? 0;
  return price > 0 ? 'Payant · ${fcfa(price)}' : 'Gratuit';
}

Future<void> toggleLiveReminder(BuildContext context, WidgetRef ref, Map<String, dynamic> l) async {
  if (!await requireLogin(context, ref, 'activer un rappel') || !context.mounted) return;
  final on = l['remind'] != true;
  final r = await Backend.rpc('live_remind_set', {'p_live': l['id'], 'p_on': on});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Rappel impossible', Backend.userMessage(r.error!));
  ref.invalidate(atelierUpcomingProvider);
  gToast(context, on ? 'Rappel activé : vous serez prévenu environ 30 minutes avant le début.' : 'Rappel retiré.');
}

Future<void> enterLive(BuildContext context, WidgetRef ref, String id) async {
  if (!await requireLogin(context, ref, 'regarder et commenter ce live') || !context.mounted) return;
  openLive(context, id);
}

// ------------------------------------------------------------------ écran

class AtelierScreen extends ConsumerStatefulWidget {
  const AtelierScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AtelierScreen> createState() => _AtelierScreenState();
}

class _AtelierScreenState extends ConsumerState<AtelierScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: kAtelierTabs.length, vsync: this, initialIndex: widget.initialTab.clamp(0, kAtelierTabs.length - 1));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Atelier en direct',
        child: Column(children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kInk,
            unselectedLabelColor: kGrey,
            indicatorColor: kViolet,
            labelStyle: mst(14, w: FontWeight.w800),
            unselectedLabelStyle: mst(14, w: FontWeight.w600),
            tabs: [for (final t in kAtelierTabs) Tab(text: t)],
          ),
          Expanded(child: TabBarView(controller: _tabs, children: const [_NowTab(), _UpcomingTab(), ReplaysLibrary(), _MineTab()])),
        ]),
      );
}

// ------------------------------------------------------------------ barre de recherche et de filtres

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.rows, required this.filter, required this.onChanged, this.temporal = false});
  final List<Map<String, dynamic>> rows;
  final AtelierFilter filter;
  final ValueChanged<AtelierFilter> onChanged;
  final bool temporal;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _pick(String title, List<String> options, String current, AtelierFilter Function(String) apply, {String Function(String)? show}) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(title, style: mst(17, w: FontWeight.w800))),
          ListTile(title: const Text('Tous'), trailing: current.isEmpty ? const Icon(Icons.check) : null, onTap: () => Navigator.of(context).pop('')),
          for (final o in options) ListTile(title: Text(show?.call(o) ?? o), trailing: current.toLowerCase() == o.toLowerCase() ? const Icon(Icons.check) : null, onTap: () => Navigator.of(context).pop(o)),
        ]),
      ),
    );
    if (v != null) widget.onChanged(apply(v));
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    final filieres = atelierOptions(widget.rows, 'filiere'), sectors = atelierOptions(widget.rows, 'sector'), cats = atelierOptions(widget.rows, 'category');
    final roles = atelierOptions(widget.rows, 'host_role');
    Widget chip(String label, String current, List<String> options, AtelierFilter Function(String) apply, {String Function(String)? show}) => options.isEmpty && current.isEmpty
        ? const SizedBox.shrink()
        : ActionChip(label: Text(current.isEmpty ? label : '$label : ${show?.call(current) ?? current}'), onPressed: () => _pick(label, options, current, apply, show: show));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ctl,
        textInputAction: TextInputAction.search,
        onChanged: (v) => widget.onChanged(f.copyWith(q: v.trim())),
        decoration: InputDecoration(
          hintText: 'Titre, animateur ou #hashtag',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: f.q.isEmpty ? null : IconButton(tooltip: 'Effacer la recherche', icon: const Icon(Icons.close), onPressed: () { _ctl.clear(); widget.onChanged(f.copyWith(q: '')); }),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (widget.temporal)
          for (final e in const {'all': 'Toutes les dates', 'today': 'Aujourd’hui', 'week': 'Cette semaine', 'month': 'Ce mois-ci'}.entries)
            ChoiceChip(label: Text(e.value), selected: f.when == e.key, onSelected: (_) => widget.onChanged(f.copyWith(when: e.key))),
        chip('Filière', f.filiere, filieres, (v) => f.copyWith(filiere: v)),
        chip('Secteur', f.sector, sectors, (v) => f.copyWith(sector: v)),
        chip('Catégorie', f.category, cats, (v) => f.copyWith(category: v)),
        if (widget.temporal) chip('Profil', f.role, roles, (v) => f.copyWith(role: v), show: (v) => kAtelierRoles[v] ?? v),
        if (f.active) ActionChip(avatar: const Icon(Icons.filter_alt_off_outlined, size: 18), label: const Text('Réinitialiser'), onPressed: () { _ctl.clear(); widget.onChanged(const AtelierFilter()); }),
      ]),
    ]);
  }
}

Widget _error(Object e, VoidCallback retry) => ListView(padding: const EdgeInsets.all(16), children: [
      mNote(e is AtelierException ? e.message : _err('$e')),
      Center(child: mButton('Réessayer', retry, dark: false)),
    ]);

Widget _loading() => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));

// ------------------------------------------------------------------ onglet En direct

class _NowTab extends ConsumerStatefulWidget {
  const _NowTab();
  @override
  ConsumerState<_NowTab> createState() => _NowTabState();
}

class _NowTabState extends ConsumerState<_NowTab> {
  AtelierFilter _f = const AtelierFilter();

  @override
  Widget build(BuildContext context) => ref.watch(atelierNowProvider).when(
        loading: _loading,
        error: (e, _) => _error(e, () => ref.invalidate(atelierNowProvider)),
        data: (rows) {
          final shown = applyAtelierFilter(rows, _f);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(atelierNowProvider.future),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
              _FilterBar(rows: rows, filter: _f, onChanged: (v) => setState(() => _f = v)),
              const SizedBox(height: 8),
              Text(kAtelierDefinitions, style: mst(11.5, c: kGrey)),
              if (rows.isEmpty) mNote('Aucun live en cours pour le moment.\nLes ateliers programmés sont dans l’onglet « À venir ».')
              else if (shown.isEmpty) mNote('Aucun live en cours ne correspond à votre recherche.')
              else for (final x in shown) AtelierLiveTile(x, upcoming: false),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ onglet À venir

class _UpcomingTab extends ConsumerStatefulWidget {
  const _UpcomingTab();
  @override
  ConsumerState<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends ConsumerState<_UpcomingTab> {
  AtelierFilter _f = const AtelierFilter();
  bool _mine = false;

  Future<void> _setMine(bool v) async {
    if (v && !await requireLogin(context, ref, 'retrouver vos rappels') || !mounted) return;
    setState(() => _mine = v);
  }

  @override
  Widget build(BuildContext context) => ref.watch(atelierUpcomingProvider(_mine)).when(
        loading: _loading,
        error: (e, _) => _error(e, () => ref.invalidate(atelierUpcomingProvider(_mine))),
        data: (rows) {
          final shown = applyAtelierFilter(rows, _f);
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(atelierUpcomingProvider(_mine).future),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
              _FilterBar(rows: rows, filter: _f, onChanged: (v) => setState(() => _f = v), temporal: true),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Tous les lives'), selected: !_mine, onSelected: (_) => _setMine(false)),
                ChoiceChip(label: const Text('Mes rappels'), selected: _mine, onSelected: (_) => _setMine(true)),
              ]),
              if (rows.isEmpty) mNote(_mine ? 'Vous n’avez activé aucun rappel.\nTouchez la cloche d’un live pour être prévenu.' : 'Aucun live programmé pour le moment.')
              else if (shown.isEmpty) mNote('Aucun live programmé ne correspond à votre recherche.')
              else for (final x in shown) AtelierLiveTile(x, upcoming: true),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ carte d'un live

class AtelierLiveTile extends ConsumerWidget {
  const AtelierLiveTile(this.x, {super.key, required this.upcoming});
  final Map<String, dynamic> x;
  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = x['status'] == 'live';
    final unavailable = x['extras_unavailable'] == true;
    final viewers = (x['viewers'] as num?)?.toInt() ?? (x['viewer_count'] as num?)?.toInt() ?? 0;
    final tags = [for (final t in (x['hashtags'] as List? ?? const [])) '#$t'];
    final orgs = [for (final o in (x['tagged_orgs'] as List? ?? const [])) if (o is Map) '${o['name']}'];
    final price = atelierPrice(x);
    final cover = '${x['cover_path'] ?? ''}';
    final meta = [if ('${x['category'] ?? ''}'.isNotEmpty) '${x['category']}', if ('${x['filiere'] ?? ''}'.isNotEmpty) '${x['filiere']}', if ('${x['sector'] ?? ''}'.isNotEmpty) '${x['sector']}'];
    return Semantics(
      button: true,
      label: 'Ouvrir le live ${x['title']}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAtelierLiveSheet(context, x),
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // vignette neutre : jamais d'aperçu vidéo simulé
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(12)),
              child: cover.isEmpty ? Icon(live ? Icons.sensors : Icons.event_outlined, color: kViolet, size: 28) : ClipRRect(borderRadius: BorderRadius.circular(12), child: MImage(Backend.postMediaUrl(cover))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(15, w: FontWeight.w800))),
                  if (live) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFDE6E7), borderRadius: BorderRadius.circular(8)), child: Text('EN DIRECT', style: mst(10.5, w: FontWeight.w800, c: const Color(0xFFE5484D)))),
                ]),
                const SizedBox(height: 2),
                Text([if ('${x['host'] ?? ''}'.isNotEmpty) '${x['host']}', if (upcoming) atelierWhen(x['scheduled_at'])].where((e) => e.isNotEmpty).join(' · '), style: mst(12.5, c: kGrey)),
                if (meta.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta.join(' · '), style: mst(12, c: kGrey))),
                if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(tags.join(' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12, w: FontWeight.w700, c: kViolet))),
                if (orgs.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Avec : ${orgs.join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey))),
                const SizedBox(height: 6),
                if (live)
                  Wrap(spacing: 12, runSpacing: 2, children: [
                    Text(_plural(viewers, 'spectateur en direct', 'spectateurs en direct'), style: mst(12, w: FontWeight.w700)),
                    Text(unavailable ? 'Vues totales : non disponibles' : _plural((x['total_views'] as num?)?.toInt() ?? 0, 'vue totale', 'vues totales'), style: mst(12, c: kGrey)),
                  ])
                else
                  Wrap(spacing: 12, runSpacing: 2, children: [
                    if (price.isNotEmpty) Text(price, style: mst(12, w: FontWeight.w700)),
                    Text(unavailable ? 'Inscrits : non disponible' : _plural((x['registered'] as num?)?.toInt() ?? 0, 'inscrit', 'inscrits'), style: mst(12, c: kGrey)),
                    if (x['frequency'] == 'weekly') Text('Chaque semaine', style: mst(12, c: kGrey)),
                    if ((x['duration_min'] as num?) != null) Text('${(x['duration_min'] as num).toInt()} min', style: mst(12, c: kGrey)),
                  ]),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (live) mButton('Regarder', () => enterLive(context, ref, '${x['id']}'), width: 120),
                  if (!live && x['mine'] != true && x['reminders_enabled'] != false)
                    TextButton.icon(
                      onPressed: () => toggleLiveReminder(context, ref, x),
                      icon: Icon(x['remind'] == true ? Icons.notifications_active : Icons.notifications_none, size: 18),
                      label: Text(x['remind'] == true ? 'Rappel activé' : 'Me rappeler'),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ fiche d'un live

Future<void> showAtelierLiveSheet(BuildContext context, Map<String, dynamic> x) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _LiveSheet(x),
    );

class _LiveSheet extends ConsumerWidget {
  const _LiveSheet(this.x);
  final Map<String, dynamic> x;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = '${x['id']}';
    final live = x['status'] == 'live';
    final price = (x['price'] as num?)?.toInt() ?? 0;
    final unavailable = x['extras_unavailable'] == true;
    final tags = [for (final t in (x['hashtags'] as List? ?? const [])) '#$t'];
    final orgs = [for (final o in (x['tagged_orgs'] as List? ?? const [])) if (o is Map) '${o['name']}'];
    final description = '${x['description'] ?? ''}'.trim();
    final others = [for (final l in [...?ref.watch(atelierUpcomingProvider(false)).value, ...?ref.watch(atelierNowProvider).value]) if ('${l['host_id']}' == '${x['host_id']}' && '${l['id']}' != id) l];
    final conditions = [
      if (x['visibilite'] == 'prive') 'Sur invitation de l’hôte.',
      if (x['event_id'] != null && price > 0) 'Inscription à l’événement lié (billet payant) nécessaire pour entrer.',
      if (x['event_id'] != null && price == 0) 'Inscription gratuite à l’événement lié possible.',
      if (x['reminders_enabled'] == false) 'Rappels désactivés par l’hôte.',
      if (x['comments_mode'] == 'off') 'Commentaires désactivés.',
      if (x['participation_mode'] == 'off') 'Participation en direct désactivée.',
    ];
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), shrinkWrap: true, children: [
        Row(children: [
          Expanded(child: Text('${x['title']}', style: mst(19, w: FontWeight.w800))),
          IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 4),
        InkWell(onTap: () => gOpenProfile(context, '${x['host_id']}'), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${x['host'] ?? ''} · voir le profil de l’animateur', style: mst(13, w: FontWeight.w700, c: kViolet)))),
        if (!live && '${x['scheduled_at'] ?? ''}'.isNotEmpty) Text(atelierWhen(x['scheduled_at']), style: mst(14, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 2, children: [
          if (atelierPrice(x).isNotEmpty) Text(atelierPrice(x), style: mst(13, w: FontWeight.w700)),
          if (x['frequency'] == 'weekly') Text('Chaque semaine', style: mst(13, c: kGrey)),
          if ((x['duration_min'] as num?) != null) Text('Durée prévue : ${(x['duration_min'] as num).toInt()} min', style: mst(13, c: kGrey)),
          if (live) Text(_plural((x['viewers'] as num?)?.toInt() ?? (x['viewer_count'] as num?)?.toInt() ?? 0, 'spectateur en direct', 'spectateurs en direct'), style: mst(13, w: FontWeight.w700)),
          Text(unavailable ? 'Vues totales : non disponibles' : _plural((x['total_views'] as num?)?.toInt() ?? 0, 'vue totale', 'vues totales'), style: mst(13, c: kGrey)),
          if (!live) Text(unavailable ? 'Inscrits : non disponible' : _plural((x['registered'] as num?)?.toInt() ?? 0, 'inscrit', 'inscrits'), style: mst(13, c: kGrey)),
        ]),
        if (description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(description, style: mst(14).copyWith(height: 1.45))),
        if ([x['category'], x['filiere'], x['sector']].any((e) => '${e ?? ''}'.isNotEmpty))
          Padding(padding: const EdgeInsets.only(top: 10), child: Text([for (final e in [x['category'], x['filiere'], x['sector']]) if ('${e ?? ''}'.isNotEmpty) '$e'].join(' · '), style: mst(13, c: kGrey))),
        if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tags.join(' '), style: mst(13, w: FontWeight.w700, c: kViolet))),
        if (orgs.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Entreprises : ${orgs.join(', ')}', style: mst(13, c: kGrey))),
        if (conditions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Conditions : ${conditions.join(' ')}', style: mst(12.5, c: kGrey).copyWith(height: 1.4))),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(kAtelierDefinitions, style: mst(11.5, c: kGrey))),
        const SizedBox(height: 14),
        LiveActionButton(liveId: id, hostId: '${x['host_id']}', onGift: live ? () => showGiftSheet(context, id, '${x['host_id']}') : null),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: [
          if (live) mButton('Regarder', () async { Navigator.of(context).pop(); await enterLive(context, ref, id); }, icon: Icons.play_arrow_rounded),
          if (!live && x['mine'] != true && x['reminders_enabled'] != false) mButton(x['remind'] == true ? 'Retirer le rappel' : 'Me rappeler', () => toggleLiveReminder(context, ref, x), dark: false, icon: Icons.notifications_none),
          if (!live && x['event_id'] != null && x['mine'] != true) mButton('S’inscrire à l’événement', () => openEventRegistration(context, ref, '${x['event_id']}'), dark: false, icon: Icons.event_available_outlined),
          mButton('Partager', () => shareText(context, '${x['title']} sur Boutik-École : ${liveShareLink(id)}', subject: '${x['title']}'), dark: false, icon: Icons.ios_share_rounded),
        ]),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Autres lives de ${x['host']}', style: mst(15, w: FontWeight.w800)),
          for (final o in others.take(5))
            ListTile(contentPadding: EdgeInsets.zero, title: Text('${o['title']}', maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(o['status'] == 'live' ? 'En direct' : atelierWhen(o['scheduled_at'])), onTap: () { Navigator.of(context).pop(); showAtelierLiveSheet(context, o); }),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ onglet Mes lives

class _MineTab extends ConsumerWidget {
  const _MineTab();

  Future<void> _prepare(BuildContext context, WidgetRef ref, {required bool now}) async {
    if (!await requireLogin(context, ref, 'créer un live') || !context.mounted) return;
    if (Backend.ready && !canBroadcastLive(ref.read(authProvider).current)) return gAlert(context, 'Diffusion réservée', liveBroadcastRule);
    context.push(now ? '/atelier/preparer?mode=now' : '/atelier/preparer');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signed = ref.watch(authProvider.select((a) => a.current != null));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      Wrap(spacing: 10, runSpacing: 8, children: [
        mButton('Lancer un live', () => _prepare(context, ref, now: true), icon: Icons.videocam_rounded),
        mButton('Programmer un live', () => _prepare(context, ref, now: false), dark: false, icon: Icons.event_outlined),
      ]),
      if (!signed) mNote('Connectez-vous pour lancer ou programmer un live, retrouver vos lives, vos replays et vos statistiques d’audience.')
      else ...[
        const SizedBox(height: 12),
        ...ref.watch(atelierMineProvider).when(
              loading: () => [_loading()],
              error: (e, _) => [mNote(e is AtelierException ? e.message : _err('$e')), Center(child: mButton('Réessayer', () => ref.invalidate(atelierMineProvider), dark: false))],
              data: (rows) => rows.isEmpty ? [mNote('Vous n’avez pas encore créé de live.')] : [for (final x in rows) _MineTile(x)],
            ),
        const SizedBox(height: 18),
        Text('Mes replays', style: mst(17, w: FontWeight.w800)),
        const MyReplaysList(shrink: true),
        const SizedBox(height: 6),
        Text('Statistiques commerciales, financières et de recrutement : non disponibles par live. Les statistiques d’audience sont dans chaque live terminé.', style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        Text('Intégration vocale de Kéla : service à configurer.', style: mst(12, c: kGrey)),
        TextButton(onPressed: () => context.push('/createur/statistiques'), child: const Text('Statistiques de créateur')),
      ],
    ]);
  }
}

String _statusLabel(String s) => switch (s) { 'live' => 'En direct', 'scheduled' => 'Programmé', 'ended' => 'Terminé', 'cancelled' => 'Annulé', _ => s };

/// Confirmation d'annulation : renvoie le motif (éventuellement vide) ou null si l'hôte garde le live.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog();
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _why = TextEditingController();

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Annuler ce live ?', style: mst(17, w: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Les personnes qui ont activé un rappel seront prévenues.', style: mst(13, c: kGrey)),
          const SizedBox(height: 8),
          TextField(controller: _why, maxLength: 200, decoration: const InputDecoration(hintText: 'Motif (facultatif)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Garder le live')),
          TextButton(onPressed: () => Navigator.of(context).pop(_why.text.trim()), child: Text('Annuler le live', style: mst(14, w: FontWeight.w800, c: kRed))),
        ],
      );
}

class _MineTile extends ConsumerWidget {
  const _MineTile(this.x);
  final Map<String, dynamic> x;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await gDialog<String>(context: context, builder: (_) => const _CancelDialog());
    if (reason == null || !context.mounted) return;
    final r = await Backend.rpc('live_cancel', {'p_live': x['id'], 'p_reason': reason.isEmpty ? null : reason});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Live non annulé', Backend.userMessage(r.error!));
    ref.invalidate(atelierMineProvider);
    ref.invalidate(atelierUpcomingProvider);
    gToast(context, 'Live annulé.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = '${x['id']}';
    final st = '${x['status']}';
    final unavailable = x['extras_unavailable'] == true;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 2),
        Text([_statusLabel(st), if (st == 'scheduled') atelierWhen(x['scheduled_at']), if (st == 'ended') 'pic ${(x['peak_viewers'] as num?)?.toInt() ?? 0} spectateur(s)'].where((e) => e.isNotEmpty).join(' · '), style: mst(12.5, c: kGrey)),
        if (st == 'scheduled' && !unavailable) Text('${_plural((x['registered'] as num?)?.toInt() ?? 0, 'inscrit', 'inscrits')} · ${atelierPrice(x)}', style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (st == 'scheduled') ...[
            mButton('Lancer', () => openHostConsole(context, id), icon: Icons.videocam_rounded),
            mButton('Modifier', () => context.push('/atelier/preparer?live=$id'), dark: false, icon: Icons.edit_outlined),
            mButton('Annuler', () => _cancel(context, ref), dark: false, icon: Icons.cancel_outlined),
          ],
          if (st == 'live') mButton('Ouvrir la régie', () => openHostConsole(context, id), icon: Icons.settings_remote_outlined),
          if (st == 'ended' || st == 'live') mButton('Statistiques', () => showLiveStatsSheet(context, id, '${x['title']}'), dark: false, icon: Icons.insights_outlined),
          if (st == 'scheduled' || st == 'live') mButton('Partager', () => shareText(context, '${x['title']} sur Boutik-École : ${liveShareLink(id)}', subject: '${x['title']}'), dark: false, icon: Icons.ios_share_rounded),
        ]),
      ]),
    );
  }
}

Future<void> showLiveStatsSheet(BuildContext context, String id, String title) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _StatsSheet(id, title),
    );

class _StatsSheet extends ConsumerWidget {
  const _StatsSheet(this.id, this.title);
  final String id, title;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
          Row(children: [
            Expanded(child: Text('Audience · $title', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(18, w: FontWeight.w800))),
            IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ]),
          ...ref.watch(liveStatsProvider(id)).when(
                loading: () => [_loading()],
                error: (e, _) => [mNote(e is AtelierException ? e.message : _err('$e')), Center(child: mButton('Réessayer', () => ref.invalidate(liveStatsProvider(id)), dark: false))],
                data: (s) {
                  Widget row(String label, Object? v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: mst(14))), Text('${mInt(v)}', style: mst(15, w: FontWeight.w800))]));
                  return [
                    const SizedBox(height: 8),
                    row('Spectateurs en direct maintenant', s['viewers_now']),
                    row('Pic de spectateurs', s['peak_viewers']),
                    row('Vues totales (personnes distinctes)', s['total_views']),
                    row('Inscrits', s['registered']),
                    row('Messages du chat', s['chat_messages']),
                    row('Réactions', s['reactions']),
                    const SizedBox(height: 8),
                    Text(kAtelierDefinitions, style: mst(11.5, c: kGrey)),
                    const SizedBox(height: 10),
                    Text('Ventes, revenus et recrutement liés à ce live : non disponibles (aucune mesure par live n’est enregistrée).', style: mst(12, c: kGrey)),
                  ];
                },
              ),
        ]),
      );
}
