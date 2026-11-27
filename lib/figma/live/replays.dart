import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException, Supabase;
import 'package:video_player/video_player.dart';

import 'auth.dart' show requireLogin;
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'replay_quiz_editor.dart' show replayQuizCanEditProvider;
/// Replays des lives (migrations 20261127300000 à 20261127300200). Tout vient du serveur : bibliothèque, fiche, accès (hérité du live), progression, complétion, badge,
/// chapitres, réactions, commentaires, notes, clips. Le lecteur ne s'ouvre qu'avec un ticket serveur (URL signée de 15 minutes) ; la complétion est calculée par le serveur
/// à partir de segments réellement lus (lecture active, sans saut ni vitesse supérieure à 2x) : ouvrir la vidéo ou la laisser tourner en arrière-plan ne compte pas.
/// Aucun replay, aucune statistique ni aucun enregistrement n'est inventé ; un service non configuré est annoncé comme tel.

const kReplaySorts = {'date': 'Récents', 'popularity': 'Populaires', 'rating': 'Mieux notés', 'completion': 'Complétion'};
const kReplayEmojis = {'heart': '❤️', 'fire': '🔥', 'clap': '👏', 'laugh': '😂', 'wow': '😮'};
const kReplaySpeeds = [1.0, 1.25, 1.5, 2.0];
const kReplayShareOrigin = 'https://boutik-ecole.vercel.app';

/// Cadence des rapports de progression (le serveur exige au moins 2 s entre deux rapports et 30 s au plus par segment).
@visibleForTesting
Duration replayTickInterval = const Duration(seconds: 5);

/// Le ticket serveur dure 15 minutes : le lien signé est renouvelé avant son expiration, à la position courante.
@visibleForTesting
Duration replayUrlRefresh = const Duration(minutes: 12);

/// Position de reprise : dernière position connue du serveur (replay_progress_get), sauf replay terminé ou presque fini (on repart alors du début).
double replayResumePosition(Map<String, dynamic> progress, double duration) {
  final pos = ((progress['position_sec'] as num?) ?? 0).toDouble();
  if (progress['completed'] == true || pos < 5 || (duration > 0 && pos > duration - 5)) return 0;
  return pos;
}

/// URL signée courte (le serveur a posé un ticket de 15 minutes, sans lequel le stockage refuse). Remplaçable dans les tests.
@visibleForTesting
Future<String?> Function(String bucket, String path, int seconds) replaySigner = (bucket, path, seconds) async {
  try {
    return await Supabase.instance.client.storage.from(bucket).createSignedUrl(path, seconds);
  } catch (_) {
    return null;
  }
};

class ReplayException implements Exception {
  ReplayException(this.message);
  final String message;
  @override
  String toString() => message;
}

String _errText(Object? e) {
  if (e == 'offline') return 'Les replays sont disponibles une fois l’application connectée au serveur.';
  if (e == 'missing') return 'Les replays ne sont pas encore installés sur le serveur.';
  return Backend.userMessage('$e');
}

Future<Object?> replayCall(String fn, Map<String, dynamic> params) async {
  final r = await marcheCall(fn, params);
  if (r.error != null) throw ReplayException(_errText(r.error));
  return r.data;
}

Map<String, dynamic> _asMap(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
List<Map<String, dynamic>> _asList(Object? o) => [for (final x in (o as List? ?? const [])) _asMap(x)];

String replayClock(num sec) {
  final s = sec.floor();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, r = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(r)}' : '$m:${two(r)}';
}

String replayPercent(Object? v) => '${(((v as num?) ?? 0) * 100).round()} %';

bool get _loggedIn => Backend.ready && Backend.currentUserId != null;

// ------------------------------------------------------------------ données

typedef ReplayQuery = ({String q, String sort, String host});

final replayLibraryProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ReplayQuery>((ref, k) async {
  final r = await replayCall('replay_library', {'p_query': k.q, 'p_sort': k.sort, 'p_limit': 50, 'p_offset': 0, 'p_host': k.host.isEmpty ? null : k.host});
  return _asList(r);
}, retry: (_, _) => null);

final replaySearchProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, q) async {
  if (q.trim().length < 2) return const {};
  return _asMap(await replayCall('replay_search', {'p_query': q.trim(), 'p_limit': 20}));
}, retry: (_, _) => null);

final replayHostsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async => _asList(await replayCall('replay_hosts_directory', {'p_query': '', 'p_limit': 30})), retry: (_, _) => null);

final replayDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async => _asMap(await replayCall('replay_detail', {'p_recording': id})), retry: (_, _) => null);

final replayProgressProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  if (!_loggedIn) return const {};
  return _asMap(await replayCall('replay_progress_get', {'p_recording': id}));
}, retry: (_, _) => null);

final replayCommentsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  if (!_loggedIn) return const [];
  return _asList(await replayCall('replay_comments_list', {'p_recording': id, 'p_limit': 200}));
}, retry: (_, _) => null);

final myReplaysProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async => _asList(await replayCall('my_replays', const {})), retry: (_, _) => null);

// ------------------------------------------------------------------ progression en lecture active

typedef ReplayRpc = Future<({Object? data, String? error})> Function(String fn, Map<String, dynamic> params);

/// Rapporte au serveur uniquement ce qui est réellement lu : lecture en cours, vitesse <= 2x, positions contiguës. Un saut du curseur rouvre une session
/// à la nouvelle position (le saut n'est jamais crédité) ; pause, arrière-plan ou vitesse excessive ferment la session.
class ReplayProgressTracker {
  ReplayProgressTracker(this.recordingId, {ReplayRpc? call, this.maxSpeed = 2.0, DateTime Function()? now})
      : _call = call ?? marcheCall,
        _now = now ?? DateTime.now;
  final String recordingId;
  final double maxSpeed;
  final ReplayRpc _call;
  final DateTime Function() _now;
  bool _open = false, _busy = false;
  double _last = 0;

  bool get isOpen => _open;

  /// Dernière erreur de synchronisation (réseau ou serveur) ; nulle dès qu'un échange réussit. La progression déjà enregistrée par le serveur n'est jamais perdue.
  String? lastError;

  Future<Map<String, dynamic>?> tick({required double position, required bool playing, required double speed}) async {
    if (_busy) return null;
    _busy = true;
    try {
      if (!playing || speed > maxSpeed) {
        await _close(position);
        return null;
      }
      if (!_open) return await _start(position);
      final d = position - _last;
      if (d < -1.5 || d > 30) return await _start(position);
      if (d < 0.5) return null;
      final r = await _call('replay_progress_report', {'p_recording': recordingId, 'p_from': _last, 'p_to': position, 'p_client_ts': _now().millisecondsSinceEpoch});
      final m = _asMap(r.data);
      lastError = r.error;
      if (r.error == null && m['accepted'] == true) {
        _last = position;
        return m;
      }
      _open = false;
      return r.error == null ? m : null;
    } finally {
      _busy = false;
    }
  }

  Future<Map<String, dynamic>?> _start(double position) async {
    final r = await _call('replay_playback_start', {'p_recording': recordingId, 'p_position': position});
    final m = _asMap(r.data);
    lastError = r.error;
    if (r.error == null && m['ok'] == true) {
      _open = true;
      _last = position;
      return m;
    }
    _open = false;
    return null;
  }

  Future<void> _close(double position) async {
    if (!_open) return;
    _open = false;
    await _call('replay_playback_stop', {'p_recording': recordingId, 'p_position': position});
  }

  Future<void> close(double position) => _close(position);
}

// ------------------------------------------------------------------ moteur de lecture

abstract class ReplayEngine extends ChangeNotifier {
  double get position;
  double get duration;
  bool get playing;
  double get speed;
  String? get error;
  Future<void> open(String url, {double start = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(double sec);
  Future<void> setSpeed(double s);
  Widget view({bool audioOnly = false});
  Future<void> shutdown();
}

class VideoPlayerEngine extends ReplayEngine {
  VideoPlayerController? _c;
  String? _error;
  double _speed = 1;

  @override
  double get position => (_c?.value.position.inMilliseconds ?? 0) / 1000;
  @override
  double get duration => (_c?.value.duration.inMilliseconds ?? 0) / 1000;
  @override
  bool get playing => (_c?.value.isPlaying ?? false) && !(_c?.value.isBuffering ?? false);
  @override
  double get speed => _speed;
  @override
  String? get error => _error ?? (_c?.value.hasError == true ? 'La lecture a été interrompue (connexion perdue ou lien expiré). Réessayez : elle reprend à la même position.' : null);

  @override
  Future<void> open(String url, {double start = 0}) async {
    await _c?.dispose();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _c = c;
    try {
      await c.initialize();
      c.addListener(notifyListeners);
      if (start > 0) await c.seekTo(Duration(milliseconds: (start * 1000).round()));
      _error = null;
    } catch (_) {
      _error = 'La lecture n’a pas pu démarrer. Réessayez dans un instant.';
    }
    notifyListeners();
  }

  @override
  Future<void> play() async => _c?.play();
  @override
  Future<void> pause() async => _c?.pause();
  @override
  Future<void> seek(double sec) async => _c?.seekTo(Duration(milliseconds: (sec * 1000).round()));
  @override
  Future<void> setSpeed(double s) async {
    _speed = s;
    await _c?.setPlaybackSpeed(s);
    notifyListeners();
  }

  @override
  Widget view({bool audioOnly = false}) {
    final c = _c;
    if (audioOnly) return const Center(child: Icon(Icons.headphones, size: 56, color: Colors.white70));
    if (c == null || !c.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)));
  }

  @override
  Future<void> shutdown() async {
    final c = _c;
    _c = null;
    c?.removeListener(notifyListeners);
    await c?.dispose();
  }
}

@visibleForTesting
ReplayEngine Function() replayEngineFactory = VideoPlayerEngine.new;

// ------------------------------------------------------------------ bibliothèque

class ReplaysScreen extends StatelessWidget {
  const ReplaysScreen({super.key});

  @override
  Widget build(BuildContext context) => const MarchePage(title: 'Replays', child: ReplaysLibrary());
}

/// Bibliothèque sans cadre de page : embarquée aussi par l'onglet « Replays » de l'Atelier en direct.
class ReplaysLibrary extends ConsumerStatefulWidget {
  const ReplaysLibrary({super.key});

  @override
  ConsumerState<ReplaysLibrary> createState() => _ReplaysScreenState();
}

class _ReplaysScreenState extends ConsumerState<ReplaysLibrary> {
  final _ctl = TextEditingController();
  String q = '', sort = 'date', host = '', hostName = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  ReplayQuery get _key => (q: q, sort: sort, host: host);

  void _search(String v) => setState(() => q = v.trim());

  Future<void> _pickHost() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => const _HostsSheet(),
    );
    if (picked != null && mounted) setState(() { host = '${picked['id']}'; hostName = '${picked['name']}'; });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(replayLibraryProvider(_key));
    final search = q.length >= 2 ? ref.watch(replaySearchProvider(q)) : null;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
        TextField(
          controller: _ctl,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Titre, animateur, chapitre ou contenu',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: q.isEmpty ? null : IconButton(tooltip: 'Effacer la recherche', icon: const Icon(Icons.close), onPressed: () { _ctl.clear(); _search(''); }),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final e in kReplaySorts.entries) ChoiceChip(label: Text(e.value), selected: sort == e.key, onSelected: (_) => setState(() => sort = e.key)),
          ActionChip(avatar: const Icon(Icons.people_outline, size: 18), label: Text(host.isEmpty ? 'Animateurs' : hostName), onPressed: _pickHost),
          if (host.isNotEmpty) ActionChip(label: const Text('Tous les animateurs'), onPressed: () => setState(() { host = ''; hostName = ''; })),
        ]),
        if (search != null) ...search.when(
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
          data: _contentHits,
        ),
        const SizedBox(height: 8),
        ...lib.when(
          loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
          error: (e, _) => [
            mNote(e is ReplayException ? e.message : _errText('$e')),
            Center(child: mButton('Réessayer', () => ref.invalidate(replayLibraryProvider(_key)), dark: false)),
          ],
          data: (rows) => rows.isEmpty
              ? [mNote(q.isNotEmpty || host.isNotEmpty ? 'Aucun replay ne correspond à votre recherche.' : 'Aucun replay publié pour le moment.')]
              : [for (final r in rows) _ReplayCard(r)],
        ),
      ]);
  }

  List<Widget> _contentHits(Map<String, dynamic> s) {
    final hits = _asList(s['hits']).where((h) => h['kind'] != 'title' && h['locked'] != true).toList();
    final note = '${s['message'] ?? ''}';
    if (hits.isEmpty && note.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Text('Dans le contenu des replays', style: mst(15, w: FontWeight.w800)),
      if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: mst(12, c: kGrey))),
      for (final h in hits)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${h['snippet']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w700)),
          subtitle: Text('${h['title']} · à ${replayClock((h['at_sec'] as num?) ?? 0)}', style: mst(12, c: kGrey)),
          onTap: () => context.push('/replay/${h['recording_id']}?t=${((h['at_sec'] as num?) ?? 0).round()}'),
        ),
    ];
  }
}

class _HostsSheet extends ConsumerWidget {
  const _HostsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ref.watch(replayHostsProvider).when(
                loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => mNote(e is ReplayException ? e.message : _errText('$e')),
                data: (rows) => rows.isEmpty
                    ? mNote('Aucun animateur public pour le moment.')
                    : ListView(shrinkWrap: true, children: [
                        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Annuaire des animateurs', style: mst(17, w: FontWeight.w800))),
                        for (final h in rows)
                          ListTile(
                            title: Text('${h['name']}', style: mst(14, w: FontWeight.w700)),
                            subtitle: Text('${mInt(h['replays'])} replay(s) · ${mInt(h['lives'])} live(s) · ${mInt(h['followers'])} abonné(s)', style: mst(12, c: kGrey)),
                            onTap: () => Navigator.of(context).pop(h),
                          ),
                      ]),
              ),
        ),
      );
}

class _ReplayCard extends StatelessWidget {
  const _ReplayCard(this.r);
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final locked = r['locked'] == true;
    final rate = r['completion_rate'];
    final avg = r['rating_avg'];
    return Semantics(
      button: true,
      label: 'Ouvrir le replay ${r['title']}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/replay/${r['id']}'),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(15, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${r['host']} · ${replayClock((r['duration_sec'] as num?) ?? 0)}', style: mst(12.5, c: kGrey)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 2, children: [
              Text('${mInt(r['views'])} vue(s) qualifiée(s)', style: mst(12, c: kGrey)),
              Text('${mInt(r['viewers'])} lecteur(s)', style: mst(12, c: kGrey)),
              Text(rate == null ? 'Complétion non mesurée' : 'Complétion ${'$rate'.replaceAll('.', ',')} %', style: mst(12, c: kGrey)),
              Text(avg == null ? 'Pas encore noté' : '★ ${'$avg'.replaceAll('.', ',')} (${mInt(r['rating_count'])})', style: mst(12, c: kGrey)),
            ]),
            if (locked) Padding(padding: const EdgeInsets.only(top: 8), child: Text('🔒 ${r['message']}', style: mst(12.5, w: FontWeight.w700, c: kViolet))),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ lecteur

class ReplayPlayerScreen extends ConsumerStatefulWidget {
  const ReplayPlayerScreen({super.key, required this.id, this.startAt = 0});
  final String id;
  final double startAt;

  @override
  ConsumerState<ReplayPlayerScreen> createState() => _ReplayPlayerState();
}

class _ReplayPlayerState extends ConsumerState<ReplayPlayerScreen> with WidgetsBindingObserver {
  late final ReplayEngine engine = replayEngineFactory();
  late final ReplayProgressTracker tracker = ReplayProgressTracker(widget.id);
  Timer? _timer;
  String mode = 'complete';
  bool _opened = false, _opening = false, _fromStart = false;
  DateTime _openedAt = DateTime.now();
  String? _mediaError, _toast;
  Map<String, dynamic>? _live; // dernier retour de progression
  final _comment = TextEditingController();
  String? _replyTo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine.addListener(_onEngine);
    _timer = Timer.periodic(replayTickInterval, (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    engine.removeListener(_onEngine);
    final pos = engine.position;
    unawaited(tracker.close(pos));
    unawaited(engine.shutdown());
    _comment.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(engine.pause());
      unawaited(tracker.close(engine.position));
    }
  }

  void _onEngine() {
    if (!mounted) return;
    // Coupure en cours de lecture : le message et « Réessayer » (nouveau lien signé, même position) apparaissent au lieu d'un lecteur figé.
    setState(() {
      if (_opened && engine.error != null) _mediaError = engine.error;
    });
  }

  Future<void> _tick() async {
    if (!_opened) return;
    final before = tracker.lastError;
    final r = await tracker.tick(position: engine.position, playing: engine.playing, speed: engine.speed);
    if (!mounted) return;
    if (_opened && engine.playing && !_opening && DateTime.now().difference(_openedAt) > replayUrlRefresh) unawaited(_openMedia(mode));
    if (r == null) {
      if (before != tracker.lastError) setState(() {});
      return;
    }
    setState(() => _live = r);
    if (r['newly_completed'] == true) {
      ref.invalidate(replayProgressProvider(widget.id));
      final p = await ref.read(replayProgressProvider(widget.id).future).catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      if (p['quiz_defined'] == true && p['quiz_passed'] != true) {
        _say('Bravo : replay terminé. Réussissez le quiz pour obtenir votre badge « J’ai suivi »${p['certificate_enabled'] == true ? ' et votre certificat' : ''}.');
      } else {
        _say('Bravo : replay terminé. Votre badge « J’ai suivi » est attribué.');
      }
    }
  }

  void _say(String m) {
    if (mounted) setState(() => _toast = m);
  }

  Future<void> _openMedia(String kind) async {
    if (_opening) return;
    setState(() { _opening = true; _mediaError = null; });
    await tracker.close(engine.position);
    final r = await marcheCall('replay_play_url', {'p_recording': widget.id, 'p_kind': kind});
    if (r.error != null) {
      if (mounted) setState(() { _opening = false; _mediaError = _errText(r.error); });
      return;
    }
    final d = _asMap(r.data);
    final url = await replaySigner('${d['bucket']}', '${d['path']}', (d['expires_in'] as num?)?.toInt() ?? 900);
    if (url == null) {
      if (mounted) setState(() { _opening = false; _mediaError = 'Le lien de lecture n’a pas pu être créé. Réessayez dans un instant.'; });
      return;
    }
    double start;
    if (_opened) {
      start = engine.position;
    } else if (widget.startAt > 0) {
      start = widget.startAt;
    } else if (_fromStart || !_loggedIn) {
      start = 0;
    } else {
      var failed = false;
      final p = await ref.read(replayProgressProvider(widget.id).future).catchError((_) {
        failed = true;
        return <String, dynamic>{};
      });
      start = replayResumePosition(p, ((p['duration_sec'] as num?) ?? 0).toDouble());
      if (failed) _say('Votre dernière position n’a pas pu être retrouvée (réseau) : lecture depuis le début.');
    }
    await engine.open(url, start: start);
    if (!mounted) return;
    setState(() { _opening = false; _opened = engine.error == null; _mediaError = engine.error; mode = kind; _openedAt = DateTime.now(); });
    if (engine.error == null) await engine.play();
  }

  Future<void> _togglePlay() async {
    if (!_opened) return _openMedia(mode);
    if (engine.playing) {
      await engine.pause();
      await tracker.close(engine.position);
    } else {
      await engine.play();
    }
  }

  Future<void> _seek(double sec) async {
    if (!_opened) {
      await _openMedia(mode);
    }
    await engine.seek(sec);
  }

  Future<void> _login(String why) async {
    await requireLogin(context, ref, why);
    if (mounted) setState(() {});
  }

  Future<void> _act(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _react(String emoji) => _act(() async {
        final r = await marcheCall('replay_react', {'p_recording': widget.id, 'p_at': engine.position, 'p_emoji': emoji});
        _say(r.error == null ? 'Réaction envoyée à ${replayClock(engine.position)}.' : _errText(r.error));
      });

  Future<void> _rate(int stars) => _act(() async {
        final r = await marcheCall('replay_rate', {'p_recording': widget.id, 'p_stars': stars});
        if (r.error == null) ref.invalidate(replayDetailProvider(widget.id));
        _say(r.error == null ? 'Merci pour votre note.' : _errText(r.error));
      });

  Future<void> _post() => _act(() async {
        final t = _comment.text.trim();
        if (t.isEmpty) return;
        final r = await marcheCall('replay_comment_post', {'p_recording': widget.id, 'p_body': t, 'p_parent': _replyTo, 'p_at': _replyTo == null && _opened ? engine.position : null});
        if (r.error == null) {
          _comment.clear();
          _replyTo = null;
          ref.invalidate(replayCommentsProvider(widget.id));
          ref.invalidate(replayDetailProvider(widget.id));
        } else {
          _say(_errText(r.error));
        }
      });

  Future<void> _hide(String id, bool hide) => _act(() async {
        final r = await marcheCall('replay_comment_hide', {'p_comment': id, 'p_hidden': hide});
        if (r.error == null) {
          ref.invalidate(replayCommentsProvider(widget.id));
        } else {
          _say(_errText(r.error));
        }
      });

  Future<void> _clip(int len) => _act(() async {
        final r = await marcheCall('replay_clip_request', {'p_recording': widget.id, 'p_from': engine.position, 'p_len': len});
        _say(r.error == null ? '${_asMap(r.data)['message'] ?? 'Demande de clip enregistrée.'}' : _errText(r.error));
      });

  Future<void> _share() => _act(() async {
        final r = await marcheCall('replay_share_info', {'p_recording': widget.id});
        final m = _asMap(r.data);
        if (r.error != null) return _say(_errText(r.error));
        if (m['available'] != true) return _say('${m['message'] ?? 'Partage indisponible.'}');
        await Clipboard.setData(ClipboardData(text: '$kReplayShareOrigin${m['path']}'));
        _say('Lien du replay copié. La lecture exige un compte et l’accès au live.');
      });

  Future<void> _meta({bool? published, bool? certificate, bool? share, bool? comments, bool? clips}) => _act(() async {
        final r = await marcheCall('replay_meta_set', {'p_recording': widget.id, 'p_published': published, 'p_certificate': certificate, 'p_share': share, 'p_comments': comments, 'p_clips': clips});
                if (r.error == null) {
                  ref.invalidate(replayDetailProvider(widget.id));
                } else {
                  _say(_errText(r.error));
                }
      });

  Future<void> _addChapter() async {
    final ctl = TextEditingController();
    final at = engine.position;
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chapitre à ${replayClock(at)}'),
        content: TextField(controller: ctl, maxLength: 120, decoration: const InputDecoration(hintText: 'Titre du chapitre')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Ajouter'))],
      ),
    );
    if (title == null || title.isEmpty) return;
    await _act(() async {
      final r = await marcheCall('replay_chapter_set', {'p_recording': widget.id, 'p_start': at, 'p_title': title, 'p_id': null});
            if (r.error == null) {
              ref.invalidate(replayDetailProvider(widget.id));
            } else {
              _say(_errText(r.error));
            }
    });
  }

  Future<void> _deleteChapter(String id) => _act(() async {
        final r = await marcheCall('replay_chapter_delete', {'p_chapter': id});
                if (r.error == null) {
                  ref.invalidate(replayDetailProvider(widget.id));
                } else {
                  _say(_errText(r.error));
                }
      });

  Future<void> _quiz() async {
    final r = await marcheCall('replay_quiz_get', {'p_recording': widget.id});
    if (!mounted) return;
    if (r.error != null) return _say(_errText(r.error));
    final qz = _asMap(r.data);
    if (qz['defined'] != true) return _say('Ce replay n’a pas de quiz.');
    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _QuizDialog(recording: widget.id, quiz: qz));
    if (res != null) {
      ref.invalidate(replayProgressProvider(widget.id));
      _say(res['passed'] == true ? 'Quiz réussi (${res['score_pct']} %).' : 'Quiz non réussi (${res['score_pct']} %, ${res['pass_pct']} % demandés). Vous pouvez réessayer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(replayDetailProvider(widget.id));
    return MarchePage(
      title: 'Replay',
      child: detail.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Column(children: [
          mNote(e is ReplayException ? e.message : _errText('$e')),
          mButton('Réessayer', () => ref.invalidate(replayDetailProvider(widget.id)), dark: false),
        ]),
        data: (d) => d['available'] != true ? mNote('${d['message'] ?? 'Replay introuvable ou inaccessible.'}') : _body(d),
      ),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final locked = d['locked'] == true;
    final mine = d['mine'] == true;
    final dur = ((d['duration_sec'] as num?) ?? 0).toDouble();
    final meta = _asMap(d['meta']);
    final chapters = _asList(d['chapters']);
    final modes = _asList(d['modes']);
    final progressAsync = ref.watch(replayProgressProvider(widget.id));
    final progress = progressAsync.asData?.value ?? const <String, dynamic>{};
    final pos = _opened ? engine.position.clamp(0, dur > 0 ? dur : double.infinity).toDouble() : widget.startAt;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
      Text('${d['title']}', style: mst(19, w: FontWeight.w800)),
      Text('${d['host']} · ${replayClock(dur)}', style: mst(13, c: kGrey)),
      if ('${d['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d['description']}', style: mst(13.5, c: kGrey))),
      const SizedBox(height: 12),
      if (locked) _lockedBox(d) else ...[
        _video(modes),
        _controls(dur, pos),
        if (_mediaError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
          Expanded(child: Text(_mediaError!, style: mst(13, c: kRed))),
          TextButton(key: const Key('replay-retry-media'), onPressed: _opening ? null : () => _openMedia(mode), child: const Text('Réessayer')),
        ])),
        if (_loggedIn && progressAsync.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(child: Text('Votre progression n’a pas pu être chargée : ${progressAsync.error is ReplayException ? (progressAsync.error as ReplayException).message : _errText('${progressAsync.error}')}', key: const Key('replay-progress-error'), style: mst(12.5, c: kRed))),
              TextButton(key: const Key('replay-progress-retry'), onPressed: () => ref.invalidate(replayProgressProvider(widget.id)), child: const Text('Réessayer')),
            ]),
          ),
        _resumeHint(progress),
        _syncBanner(),
        if ('${d['modes_message'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d['modes_message']}', style: mst(12, c: kGrey))),
        if (_toast != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_toast!, style: mst(13, w: FontWeight.w700, c: kViolet))),
        _progressCard(progress, dur),
        _reactions(),
        _chapters(chapters, mine),
        _rating(d),
        _clips(meta),
        _comments(d, meta, mine),
        if (mine) _hostTools(meta),
        _quizEditorCard(),
      ],
      const SizedBox(height: 12),
      Center(child: mButton('Partager le replay', _share, dark: false, icon: Icons.ios_share)),
    ]);
  }

  Widget _lockedBox(Map<String, dynamic> d) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Column(children: [
          Text('🔒 ${d['message']}', textAlign: TextAlign.center, style: mst(14, w: FontWeight.w700)),
          if (d['access'] == 'connexion') ...[const SizedBox(height: 12), mButton('Se connecter', () => _login('regarder ce replay'))],
        ]),
      );

  Widget _video(List<Map<String, dynamic>> modes) => Column(children: [
        Container(
          height: 210,
          width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFF15131F), borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: _opened ? engine.view(audioOnly: mode == 'audio') : Center(child: _opening ? const CircularProgressIndicator() : const Icon(Icons.play_circle_outline, size: 64, color: Colors.white70)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final m in modes)
            ChoiceChip(
              label: Text('${m['label']}'),
              selected: mode == m['kind'],
              onSelected: m['available'] == true ? (_) => _openMedia('${m['kind']}') : null,
            ),
        ]),
      ]);

  Widget _controls(double dur, double pos) => Column(children: [
        Slider(value: dur > 0 ? pos.clamp(0, dur).toDouble() : 0, max: dur > 0 ? dur : 1, onChanged: dur > 0 ? (v) => _seek(v) : null),
        Row(children: [
          Text(replayClock(pos), style: mst(12, c: kGrey)),
          const Spacer(),
          IconButton(tooltip: 'Reculer de 10 secondes', icon: const Icon(Icons.replay_10), onPressed: () => _seek((pos - 10).clamp(0, dur).toDouble())),
          IconButton(tooltip: engine.playing ? 'Pause' : 'Lecture', iconSize: 44, icon: Icon(engine.playing ? Icons.pause_circle : Icons.play_circle), onPressed: _togglePlay),
          IconButton(tooltip: 'Avancer de 10 secondes', icon: const Icon(Icons.forward_10), onPressed: () => _seek((pos + 10).clamp(0, dur).toDouble())),
          const Spacer(),
          Text(replayClock(dur), style: mst(12, c: kGrey)),
        ]),
        Wrap(spacing: 6, children: [
          for (final s in kReplaySpeeds) ChoiceChip(label: Text('${s}x'), selected: engine.speed == s, onSelected: (_) => engine.setSpeed(s)),
        ]),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Seule la lecture réelle à vitesse normale ou jusqu’à 2x compte pour votre progression.', style: mst(11.5, c: kGrey))),
      ]);

  Widget _card(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Material(type: MaterialType.transparency, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: mst(15, w: FontWeight.w800)), const SizedBox(height: 6), ...children])),
      );

  /// Reprise après interruption : la dernière position enregistrée par le serveur est proposée avant la première lecture.
  Widget _resumeHint(Map<String, dynamic> p) {
    if (_opened || _opening || widget.startAt > 0 || !_loggedIn) return const SizedBox.shrink();
    final at = replayResumePosition(p, ((p['duration_sec'] as num?) ?? 0).toDouble());
    if (at <= 0) return const SizedBox.shrink();
    return _card('Reprise', [
      Text('Vous en étiez à ${replayClock(at)}.', key: const Key('replay-resume-hint'), style: mst(13.5, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        mButton('Reprendre à ${replayClock(at)}', () => _openMedia(mode), icon: Icons.play_arrow),
        mButton('Recommencer', () { _fromStart = true; _openMedia(mode); }, dark: false, icon: Icons.replay),
      ]),
    ]);
  }

  /// Erreur réseau pendant la lecture : annoncée honnêtement. Ce qui est enregistré est conservé ; le comptage reprend tout seul au retour de la connexion.
  Widget _syncBanner() {
    final e = tracker.lastError;
    if (e == null || !_opened) return const SizedBox.shrink();
    return Container(
      key: const Key('replay-sync-error'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0C27B))),
      child: Row(children: [
        Expanded(child: Text('${e == 'offline' ? 'Connexion indisponible.' : _errText(e)}\nSynchronisation de la progression interrompue : ce qui est déjà enregistré est conservé, le passage lu pendant la coupure ne sera pas compté. Nouvelle tentative automatique.', style: mst(12.5, c: kInk))),
        TextButton(key: const Key('replay-sync-retry'), onPressed: _tick, child: const Text('Réessayer')),
      ]),
    );
  }

  Widget _progressCard(Map<String, dynamic> p, double dur) {
    if (!_loggedIn) return _card('Ma progression', [Text('Connectez-vous pour suivre votre progression et obtenir le badge « J’ai suivi ».', style: mst(13, c: kGrey)), const SizedBox(height: 8), mButton('Se connecter', () => _login('suivre votre progression'), dark: false)]);
    if (p.isEmpty) return const SizedBox.shrink();
    final cov = ((_live?['coverage'] ?? p['coverage']) as num?)?.toDouble() ?? 0;
    final thr = (p['threshold'] as num?)?.toDouble() ?? 0.98;
    final done = p['completed'] == true || _live?['completed'] == true;
    return _card('Ma progression', [
      LinearProgressIndicator(value: cov.clamp(0, 1).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(8)),
      const SizedBox(height: 6),
      Text('${replayPercent(cov)} réellement lu · seuil de complétion ${replayPercent(thr)}', style: mst(13, c: kGrey)),
      if (done) Text('✔ Replay terminé', style: mst(13.5, w: FontWeight.w800, c: kGreen)),
      if (p['badge'] == true) Text('Badge « J’ai suivi » obtenu', style: mst(13, w: FontWeight.w700)),
      if (done && p['badge'] != true && p['quiz_defined'] == true && p['quiz_passed'] != true) Text('Badge « J’ai suivi » : réussissez le quiz pour l’obtenir.', style: mst(12.5, c: kGrey)),
      if (p['certificate'] != null) Text('Certificat de suivi ${p['certificate']} (non diplômant)', style: mst(13, w: FontWeight.w700)),
      if (p['certificate_enabled'] == true && p['certificate'] == null && p['quiz_defined'] == true && p['quiz_passed'] != true) Text('Certificat : terminez le replay puis réussissez le quiz.', style: mst(12.5, c: kGrey)),
      if (p['quiz_defined'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: mButton(p['quiz_passed'] == true ? 'Refaire le quiz' : 'Passer le quiz', _quiz, dark: false)),
    ]);
  }

  Widget _reactions() => _card('Réactions', [
        Wrap(spacing: 8, children: [
          for (final e in kReplayEmojis.entries)
            Semantics(button: true, label: 'Réagir ${e.key}', excludeSemantics: true, child: InkWell(onTap: () => _loggedIn ? _react(e.key) : _login('réagir'), child: Padding(padding: const EdgeInsets.all(10), child: Text(e.value, style: const TextStyle(fontSize: 24))))),
        ]),
        Text('Chaque réaction est horodatée à l’instant de lecture.', style: mst(11.5, c: kGrey)),
      ]);

  Widget _chapters(List<Map<String, dynamic>> chapters, bool mine) {
    if (chapters.isEmpty && !mine) return const SizedBox.shrink();
    return _card('Chapitres', [
      if (chapters.isEmpty) Text('Aucun chapitre pour le moment.', style: mst(13, c: kGrey)),
      for (final c in chapters)
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 8,
          title: Text('${c['title']}', style: mst(13.5, w: FontWeight.w700)),
          subtitle: Text(replayClock((c['start_sec'] as num?) ?? 0), style: mst(12, c: kGrey)),
          trailing: mine ? IconButton(tooltip: 'Supprimer le chapitre', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteChapter('${c['id']}')) : null,
          onTap: () => _seek(((c['start_sec'] as num?) ?? 0).toDouble()),
        ),
      if (mine) mButton('Ajouter un chapitre à cet instant', _addChapter, dark: false),
    ]);
  }

  Widget _rating(Map<String, dynamic> d) {
    final avg = d['rating_avg'];
    final mineStars = (d['my_rating'] as num?)?.toInt() ?? 0;
    return _card('Note', [
      Text(avg == null ? 'Pas encore noté.' : '★ ${'$avg'.replaceAll('.', ',')} sur 5 (${mInt(d['rating_count'])} avis)', style: mst(13, c: kGrey)),
      Row(children: [
        for (var i = 1; i <= 5; i++)
          IconButton(tooltip: 'Noter $i sur 5', icon: Icon(i <= mineStars ? Icons.star : Icons.star_border, color: kViolet), onPressed: () => _loggedIn ? _rate(i) : _login('noter ce replay')),
      ]),
      Text('Une note est possible après avoir regardé une part minimale du replay.', style: mst(11.5, c: kGrey)),
    ]);
  }

  Widget _clips(Map<String, dynamic> meta) {
    if (meta['clips_allowed'] == false && !(ref.read(replayDetailProvider(widget.id)).asData?.value['mine'] == true)) return const SizedBox.shrink();
    return _card('Clips', [
      Text('Clip depuis la position actuelle. Le rendu vidéo dépend d’un service qui n’est pas encore configuré : la demande est enregistrée, aucun fichier n’est créé pour le moment.', style: mst(12.5, c: kGrey)),
      Wrap(spacing: 8, children: [
        for (final e in const {30: '30 s', 60: '1 min', 180: '3 min'}.entries) ActionChip(label: Text('Clip ${e.value}'), onPressed: () => _loggedIn ? _clip(e.key) : _login('demander un clip')),
      ]),
    ]);
  }

  Widget _comments(Map<String, dynamic> d, Map<String, dynamic> meta, bool mine) {
    final list = ref.watch(replayCommentsProvider(widget.id));
    final off = meta['comments_enabled'] == false && !mine;
    return _card('Commentaires (${mInt(d['comments_count'])})', [
      if (!_loggedIn) mButton('Se connecter pour commenter', () => _login('commenter'), dark: false)
      else if (off) Text('Les commentaires sont désactivés par l’hôte.', style: mst(13, c: kGrey))
      else ...[
        if (_replyTo != null) Row(children: [Expanded(child: Text('Réponse en cours', style: mst(12, c: kGrey))), TextButton(onPressed: () => setState(() => _replyTo = null), child: const Text('Annuler'))]),
        TextField(controller: _comment, maxLength: 500, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Votre commentaire')),
        mButton('Publier', _post, busy: _busy),
      ],
      ...list.when(
        loading: () => const <Widget>[Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))],
        error: (e, _) => [Text(e is ReplayException ? e.message : _errText('$e'), style: mst(13, c: kRed))],
        data: (rows) => rows.isEmpty && _loggedIn ? [Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucun commentaire pour le moment.', style: mst(13, c: kGrey)))] : [for (final c in rows) _commentTile(c, mine)],
      ),
    ]);
  }

  Widget _commentTile(Map<String, dynamic> c, bool mine) {
    final reply = c['parent_id'] != null;
    final hidden = c['hidden'] == true;
    return Padding(
      padding: EdgeInsets.only(top: 10, left: reply ? 20 : 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${c['author']}${c['by_host'] == true ? ' · Hôte' : ''}${c['at_sec'] != null ? ' · à ${replayClock(c['at_sec'] as num)}' : ''}${hidden ? ' · masqué' : ''}', style: mst(12, w: FontWeight.w800, c: kGrey)),
        Text('${c['body']}', style: mst(13.5)),
        Row(children: [
          if (!reply) TextButton(onPressed: () => setState(() => _replyTo = '${c['id']}'), child: const Text('Répondre')),
          if (mine) TextButton(onPressed: () => _hide('${c['id']}', !hidden), child: Text(hidden ? 'Afficher' : 'Masquer')),
        ]),
      ]),
    );
  }

  Widget _quizEditorCard() {
    if (ref.watch(replayQuizCanEditProvider(widget.id)).value != true) return const SizedBox.shrink();
    return _card('Quiz du replay', [
      Text('Définissez ou modifiez le quiz facultatif : questions, bonne réponse et seuil de réussite.', style: mst(13, c: kGrey)),
      const SizedBox(height: 8),
      mButton('Gérer le quiz', () => context.push('/replay/${widget.id}/quiz'), dark: false, icon: Icons.quiz_outlined),
    ]);
  }

  Widget _hostTools(Map<String, dynamic> meta) => _card('Réglages de l’hôte', [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Replay publié'), value: meta['published'] != false, onChanged: (v) => _meta(published: v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Certificat de suivi'), subtitle: const Text('Délivré après complétion réelle (et quiz réussi s’il existe)'), value: meta['certificate_enabled'] == true, onChanged: (v) => _meta(certificate: v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Partage externe'), value: meta['share_enabled'] != false, onChanged: (v) => _meta(share: v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Commentaires'), value: meta['comments_enabled'] != false, onChanged: (v) => _meta(comments: v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Clips autorisés'), value: meta['clips_allowed'] != false, onChanged: (v) => _meta(clips: v)),
      ]);
}

class _QuizDialog extends StatefulWidget {
  const _QuizDialog({required this.recording, required this.quiz});
  final String recording;
  final Map<String, dynamic> quiz;

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  late final List<int?> answers = List.filled(_asList(widget.quiz['questions']).length, null);
  bool busy = false;
  String? error;

  Future<void> _submit() async {
    if (answers.any((a) => a == null)) return setState(() => error = 'Répondez à toutes les questions.');
    setState(() { busy = true; error = null; });
    final r = await marcheCall('replay_quiz_submit', {'p_recording': widget.recording, 'p_answers': answers});
    if (!mounted) return;
    if (r.error != null) return setState(() { busy = false; error = _errText(r.error); });
    Navigator.of(context).pop(_asMap(r.data));
  }

  @override
  Widget build(BuildContext context) {
    final qs = _asList(widget.quiz['questions']);
    return AlertDialog(
      title: Text('${widget.quiz['title']}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < qs.length; i++) ...[
              Text('${i + 1}. ${qs[i]['q']}', style: mst(14, w: FontWeight.w800)),
              RadioGroup<int>(
                groupValue: answers[i],
                onChanged: (v) => setState(() => answers[i] = v),
                child: Column(children: [
                  for (var o = 0; o < (qs[i]['options'] as List).length; o++) RadioListTile<int>(dense: true, contentPadding: EdgeInsets.zero, value: o, title: Text('${(qs[i]['options'] as List)[o]}')),
                ]),
              ),
            ],
            if (error != null) Text(error!, style: mst(13, c: kRed)),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')), TextButton(onPressed: busy ? null : _submit, child: Text(busy ? 'Envoi…' : 'Valider'))],
    );
  }
}

// ------------------------------------------------------------------ Mes lives > replays de l'hôte

const _stateLabels = {
  'not_configured': 'Enregistrement non configuré sur ce serveur : aucun replay ne sera créé.',
  'not_requested': 'Enregistrement non demandé pour ce live.',
  'declined': 'Enregistrement non disponible.',
  'awaiting_consent': 'En attente du consentement des intervenants.',
  'waiting': 'Prêt à démarrer l’enregistrement.',
  'recording': 'Enregistrement en cours.',
  'processing': 'Traitement du fichier en cours.',
  'ready': 'Replay prêt.',
  'failed': 'L’enregistrement a échoué.',
};

class MyReplaysScreen extends StatelessWidget {
  const MyReplaysScreen({super.key});

  @override
  Widget build(BuildContext context) => const MarchePage(title: 'Mes replays', child: MyReplaysList());
}

/// Liste des replays de l'hôte sans cadre de page : embarquée par l'onglet « Mes lives » de l'Atelier.
class MyReplaysList extends ConsumerStatefulWidget {
  const MyReplaysList({super.key, this.shrink = false});
  final bool shrink;

  @override
  ConsumerState<MyReplaysList> createState() => _MyReplaysState();
}

class _MyReplaysState extends ConsumerState<MyReplaysList> {
  String? _busyLive, _msg;

  Future<void> _record(String live, String action) async {
    setState(() { _busyLive = live; _msg = null; });
    String text;
    try {
      final r = await Supabase.instance.client.functions.invoke('live-record', body: {'live_id': live, 'action': action});
      final b = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      text = b['ok'] == true ? (action == 'start' ? 'Enregistrement démarré.' : 'Arrêt demandé : le fichier est en cours de traitement.') : '${b['message'] ?? 'Opération impossible.'}';
    } on FunctionException catch (e) {
      final b = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : <String, dynamic>{};
      text = '${b['message'] ?? (e.status == 503 ? 'Enregistrement non configuré sur ce serveur.' : 'Opération impossible.')}';
    } catch (_) {
      text = 'Le serveur n’a pas répondu. Réessayez dans un instant.';
    }
    if (!mounted) return;
    ref.invalidate(myReplaysProvider);
    setState(() { _busyLive = null; _msg = text; });
  }

  Future<void> _request(String live) async {
    setState(() { _busyLive = live; _msg = null; });
    final r = await marcheCall('live_recording_request', {'p_live': live});
    if (!mounted) return;
    ref.invalidate(myReplaysProvider);
    setState(() { _busyLive = null; _msg = r.error == null ? 'Demande d’enregistrement envoyée.' : _errText(r.error); });
  }

  @override
  Widget build(BuildContext context) => ref.watch(myReplaysProvider).when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Column(children: [
          mNote(e is ReplayException ? e.message : _errText('$e')),
          mButton('Réessayer', () => ref.invalidate(myReplaysProvider), dark: false),
        ]),
        data: (rows) => ListView(shrinkWrap: widget.shrink, physics: widget.shrink ? const NeverScrollableScrollPhysics() : null, padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          if (_msg != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_msg!, style: mst(13, w: FontWeight.w700, c: kViolet))),
          if (rows.isEmpty) mNote('Vous n’avez pas encore lancé de live : vos replays apparaîtront ici.'),
          for (final r in rows) _tile(r),
        ]),
      );

  Widget _tile(Map<String, dynamic> r) {
    final live = '${r['live_id']}';
    final rep = _asMap(r['replay']);
    final state = '${rep['state']}';
    final busy = _busyLive == live;
    final liveNow = r['status'] == 'live';
    final label = _stateLabels[state] ?? '${rep['message'] ?? ''}';
    final detail = '${rep['message'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['title']}', style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(state == 'failed' && detail.isNotEmpty ? detail : label, style: mst(13, c: state == 'failed' ? kRed : kGrey)),
        if (state == 'ready' && rep['duration_sec'] != null) Text('Durée ${replayClock(rep['duration_sec'] as num)}', style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (state == 'ready' && rep['recording_id'] != null) mButton('Ouvrir le replay', () => context.push('/replay/${rep['recording_id']}'), dark: false),
          if (state == 'ready' && rep['recording_id'] != null) mButton('Quiz du replay', () => context.push('/replay/${rep['recording_id']}/quiz'), dark: false, icon: Icons.quiz_outlined),
          if (state == 'not_requested' && rep['configured'] == true && r['status'] != 'ended') mButton('Demander l’enregistrement', () => _request(live), busy: busy),
          if (state == 'waiting' && liveNow) mButton('Démarrer l’enregistrement', () => _record(live, 'start'), busy: busy),
          if (state == 'recording') mButton('Arrêter l’enregistrement', () => _record(live, 'stop'), busy: busy, dark: false),
        ]),
      ]),
    );
  }
}
