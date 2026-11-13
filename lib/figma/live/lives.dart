import 'form_options.dart' show pickDate;
import '../gdata.dart' show gNetImage;
import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/paths.dart';
import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'live_transport.dart';
import 'modules.dart' show LiveRoom;
import 'reels.dart' show compactCount, relativeTime;
import 'social_posts.dart';

/// Lives réels : liste, création, console de l'hôte, spectateur. Vidéo temps réel via LiveKit (jeton émis par l'Edge Function
/// « live-token »), chat / réactions / cadeaux via Supabase Realtime. Rien n'est inventé : sans live, des états vides explicites.

const _bg = Color(0xFF0E0D14);

String? liveIdOf(BuildContext context) {
  try {
    final v = GoRouterState.of(context).uri.queryParameters['live'];
    return (v == null || v.isEmpty) ? null : v;
  } catch (_) {
    return null;
  }
}

void openLive(BuildContext context, String id) => GoRouter.of(context).push('${screenPath('222')}?live=$id');
void openHostConsole(BuildContext context, String id) => GoRouter.of(context).push('${screenPath('L1')}?live=$id');

class LiveItem {
  const LiveItem({required this.id, required this.hostId, required this.host, required this.avatar, required this.verified, required this.title, required this.description, required this.cover, required this.status, required this.scheduledAt, required this.viewers});
  final String id, hostId, host, avatar, title, description, cover, status;
  final bool verified;
  final DateTime? scheduledAt;
  final int viewers;
  bool get isLive => status == 'live';

  static LiveItem fromRow(Map x) => LiveItem(
        id: '${x['id']}',
        hostId: '${x['host_id']}',
        host: '${x['host']}',
        avatar: '${x['host_avatar'] ?? ''}',
        verified: x['host_verified'] == true,
        title: '${x['title']}',
        description: '${x['description'] ?? ''}',
        cover: (x['cover_path'] == null || '${x['cover_path']}'.isEmpty) ? '' : Backend.postMediaUrl('${x['cover_path']}'),
        status: '${x['status']}',
        scheduledAt: DateTime.tryParse('${x['scheduled_at'] ?? ''}')?.toLocal(),
        viewers: (x['viewer_count'] as num?)?.toInt() ?? 0,
      );
}

final livesNowProvider = FutureProvider.autoDispose<List<LiveItem>>((ref) async {
  final r = await Backend.rpc('lives_now', {'p_limit': 40});
  if (r.error != null || r.data is! List) throw Exception('Les lives ne peuvent pas être chargés pour le moment.');
  return [for (final x in r.data as List) LiveItem.fromRow(x as Map)];
});

final myLivesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  if (ref.watch(authProvider.select((a) => a.current == null))) return const [];
  final r = await Backend.rpc('my_lives', const {});
  if (r.error != null || r.data is! List) return const [];
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
});

/// Jeton LiveKit émis par l'Edge Function (rôle hôte ou spectateur). Erreur lisible sinon.
Future<({String? url, String? token, String? error, String role})> fetchLiveToken(String liveId) async {
  try {
    final r = await Supabase.instance.client.functions.invoke('live-token', body: {'live_id': liveId});
    final d = r.data;
    if (d is Map && d['token'] != null) return (url: '${d['url']}', token: '${d['token']}', error: null, role: '${d['role'] ?? 'viewer'}');
    return (url: null, token: null, error: d is Map ? '${d['message'] ?? 'La diffusion est indisponible.'}' : 'La diffusion est indisponible.', role: 'viewer');
  } on FunctionException catch (e) {
    final d = e.details;
    if (e.status == 503) return (url: null, token: null, error: 'La diffusion en direct n’est pas encore activée sur ce serveur (clés du fournisseur vidéo à configurer).', role: 'viewer');
    return (url: null, token: null, error: d is Map && d['message'] != null ? '${d['message']}' : 'La connexion au direct a échoué (code ${e.status}).', role: 'viewer');
  } catch (_) {
    return (url: null, token: null, error: 'Connexion impossible. Vérifiez votre réseau puis réessayez.', role: 'viewer');
  }
}

// ------------------------------------------------------------------ liste (246)

class LivesHome extends ConsumerStatefulWidget {
  const LivesHome({super.key});
  @override
  ConsumerState<LivesHome> createState() => _LivesHomeState();
}

class _LivesHomeState extends ConsumerState<LivesHome> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 15), (_) => ref.invalidate(livesNowProvider));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lives = ref.watch(livesNowProvider);
    final mine = ref.watch(myLivesProvider).value ?? const [];
    final signed = ref.watch(authProvider.select((a) => a.current != null));
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(livesNowProvider.future),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        _btn('Aller en direct', Icons.videocam_rounded, () async {
          if (!await requireLogin(context, ref, 'passer en direct') || !context.mounted) return;
          gOpen(context, 'L1');
        }),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _ghost('Mon portefeuille', Icons.account_balance_wallet_outlined, () => signed ? showWalletSheet(context) : gToast(context, 'Connectez-vous pour voir votre portefeuille.'))),
          const SizedBox(width: 10),
          Expanded(child: _ghost('Espace créateur', Icons.insights_outlined, () => signed ? showCreatorDashboard(context) : gToast(context, 'Connectez-vous pour voir votre tableau de bord.'))),
        ]),
        const SizedBox(height: 18),
        lives.when(
          loading: () => Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Chargement des lives…', style: sty(13, c: kGrey)))),
          error: (e, _) => Padding(padding: const EdgeInsets.only(top: 40), child: Column(children: [Text('Les lives ne peuvent pas être chargés pour le moment.', textAlign: TextAlign.center, style: sty(13, c: kGrey)), TextButton(onPressed: () => ref.invalidate(livesNowProvider), child: Text('Réessayer', style: sty(13, w: FontWeight.w700)))])),
          data: (list) {
            final now = [for (final l in list) if (l.isLive) l];
            final soon = [for (final l in list) if (!l.isLive) l];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('En direct maintenant', style: sty(15, w: FontWeight.w700)),
              const SizedBox(height: 10),
              if (now.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Aucun live en cours pour le moment.', style: sty(13, c: kGrey))),
              for (final l in now) Padding(padding: const EdgeInsets.only(bottom: 14), child: _LiveCard(l)),
              const SizedBox(height: 8),
              Text('Prochains lives', style: sty(15, w: FontWeight.w700)),
              const SizedBox(height: 10),
              if (soon.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Aucun live programmé pour le moment.', style: sty(13, c: kGrey))),
              for (final l in soon) _UpcomingRow(l),
            ]);
          },
        ),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('Mes lives', style: sty(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final m in mine)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${m['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(13.5, w: FontWeight.w600)),
              subtitle: Text(_statusLabel('${m['status']}', (m['peak_viewers'] as num?)?.toInt() ?? 0), style: sty(11.5, c: kGrey)),
              trailing: ('${m['status']}' == 'ended') ? null : const Icon(Icons.chevron_right),
              onTap: ('${m['status']}' == 'ended') ? null : () => openHostConsole(context, '${m['id']}'),
            ),
        ],
      ]),
    );
  }

  String _statusLabel(String s, int peak) => switch (s) { 'live' => 'En direct', 'scheduled' => 'Programmé — touchez pour ouvrir la régie', 'ended' => 'Terminé · pic de $peak spectateur${peak > 1 ? 's' : ''}', _ => s };

  Widget _btn(String label, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(height: 50, alignment: Alignment.center, color: kInk, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 21), const SizedBox(width: 8), Text(label, style: sty(14, w: FontWeight.w700, c: Colors.white))])),
      );

  Widget _ghost(String label, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: kInk.withValues(alpha: 0.25))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: kInk), const SizedBox(width: 6), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(12, w: FontWeight.w600)))])),
      );
}

class _LiveCard extends StatelessWidget {
  const _LiveCard(this.l);
  final LiveItem l;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => openLive(context, l.id),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                l.cover.isEmpty ? Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2B2740), Color(0xFF15131F)])), child: const Icon(Icons.videocam_rounded, color: Colors.white38, size: 54)) : gNetImage(l.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF2B2740))),
                Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), color: const Color(0xFFFF2D55), child: Text('EN DIRECT', style: sty(10.5, w: FontWeight.w800, c: Colors.white)))),
                Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), color: const Color(0xB3111015), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 13), const SizedBox(width: 4), Text(compactCount(l.viewers), style: sty(10.5, w: FontWeight.w700, c: Colors.white))]))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                socialAvatar(l.avatar, l.host, 38),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(13.5, w: FontWeight.w700)), NameWithBadge(name: l.host, verified: l.verified, style: sty(11.5, c: kGrey), badgeSize: 12)])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), color: kInk, child: Text('Regarder', style: sty(11.5, w: FontWeight.w700, c: Colors.white))),
              ]),
            ),
          ]),
        ),
      );
}

class _UpcomingRow extends ConsumerWidget {
  const _UpcomingRow(this.l);
  final LiveItem l;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = l.scheduledAt;
    final mine = l.hostId == ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: socialAvatar(l.avatar, l.host, 40),
      title: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: sty(13, w: FontWeight.w600)),
      subtitle: Text('${l.host}${when == null ? '' : ' · ${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')} à ${when.hour.toString().padLeft(2, '0')}h${when.minute.toString().padLeft(2, '0')}'}', style: sty(11.5, c: kGrey)),
      trailing: mine ? Text('Ouvrir la régie', style: sty(11.5, w: FontWeight.w700, c: const Color(0xFF5A3FE0))) : null,
      onTap: mine ? () => openHostConsole(context, l.id) : null,
    );
  }
}

// ------------------------------------------------------------------ création (L1)

class LiveCreateForm extends ConsumerStatefulWidget {
  const LiveCreateForm({super.key});
  @override
  ConsumerState<LiveCreateForm> createState() => _LiveCreateFormState();
}

class _LiveCreateFormState extends ConsumerState<LiveCreateForm> {
  final _title = TextEditingController(), _desc = TextEditingController();
  PlatformFile? _cover;
  DateTime? _when;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final t = _title.text.trim();
    if (t.length < 3) return gToast(context, 'Donnez un titre d’au moins 3 caractères.');
    setState(() => _busy = true);
    String? cover;
    if (_cover != null) {
      final up = await uploadPostMedia(context, _cover!);
      if (!mounted) return;
      if (up == null || up.kind != 'image') {
        setState(() => _busy = false);
        if (up != null) gToast(context, 'La couverture doit être une image.');
        return;
      }
      cover = up.path;
    }
    final r = await Backend.rpc('create_live', {'p_title': t, 'p_description': _desc.text.trim(), 'p_cover_path': cover, 'p_scheduled_at': _when?.toUtc().toIso8601String()});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Live non créé', Backend.userMessage(r.error!));
    ref.invalidate(myLivesProvider);
    ref.invalidate(livesNowProvider);
    final id = '${r.data}';
    GoRouter.of(context).pushReplacement('${screenPath('L1')}?live=$id');
  }

  Future<void> _pickWhen() async {
    final d = await pickDate(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null || !mounted) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        TextField(controller: _title, enabled: !_busy, maxLength: 100, style: sty(14), decoration: InputDecoration(labelText: 'Titre du live', labelStyle: sty(13, c: kGrey), border: const OutlineInputBorder(), counterText: '')),
        const SizedBox(height: 12),
        TextField(controller: _desc, enabled: !_busy, maxLength: 500, minLines: 3, maxLines: 5, style: sty(14), decoration: InputDecoration(labelText: 'Description (facultatif)', labelStyle: sty(13, c: kGrey), border: const OutlineInputBorder(), counterText: '')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () async {
            final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
            if (p.isNotEmpty && mounted) setState(() => _cover = p.first);
          }, icon: const Icon(Icons.image_outlined), label: Text(_cover == null ? 'Image de couverture' : _cover!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(12.5, w: FontWeight.w600)))),
          if (_cover != null) IconButton(onPressed: () => setState(() => _cover = null), icon: const Icon(Icons.close, size: 18)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _pickWhen, icon: const Icon(Icons.event_outlined), label: Text(_when == null ? 'Programmer à une date (facultatif)' : '${_when!.day.toString().padLeft(2, '0')}/${_when!.month.toString().padLeft(2, '0')}/${_when!.year} ${_when!.hour.toString().padLeft(2, '0')}h${_when!.minute.toString().padLeft(2, '0')}', style: sty(12.5, w: FontWeight.w600)))),
          if (_when != null) IconButton(onPressed: () => setState(() => _when = null), icon: const Icon(Icons.close, size: 18)),
        ]),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _create, style: FilledButton.styleFrom(backgroundColor: kInk, minimumSize: const Size.fromHeight(50), shape: const RoundedRectangleBorder()), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Créer et ouvrir la régie', style: sty(14, w: FontWeight.w700, c: Colors.white))),
        const SizedBox(height: 10),
        Text('Vous démarrez le direct depuis la régie, après avoir autorisé la caméra et le micro. Vos abonnés sont prévenus au démarrage.', style: sty(12, c: kGrey, h: 1.5)),
      ]);
}

// ------------------------------------------------------------------ chat temps réel

class LiveMsg {
  LiveMsg({required this.id, required this.userId, required this.author, required this.kind, required this.body, required this.payload});
  final int id;
  final String userId, author, kind, body;
  final Map payload;
  static LiveMsg fromRow(Map x) => LiveMsg(id: (x['id'] as num).toInt(), userId: '${x['user_id'] ?? ''}', author: '${x['author'] ?? ''}', kind: '${x['kind']}', body: '${x['body'] ?? ''}', payload: (x['payload'] as Map?) ?? const {});
}

/// Abonnement Realtime aux messages et à l'état d'un live. Reconnexion : relecture des derniers messages au retour du réseau.
class LiveFeed extends ChangeNotifier {
  LiveFeed(this.liveId, {this.onGift, this.onReaction, this.onStatus});
  final String liveId;
  final void Function(LiveMsg)? onGift, onReaction;
  final void Function(String status, int viewers)? onStatus;
  final List<LiveMsg> messages = [];
  int viewers = 0;
  String status = 'live';
  bool connected = false, _disposed = false;
  RealtimeChannel? _ch;
  int _last = 0;

  SupabaseClient get _c => Supabase.instance.client;

  Future<void> start() async {
    await _load();
    _ch = _c
        .channel('live-$liveId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'live_id', value: liveId),
          callback: (p) => _add(LiveMsg.fromRow(p.newRecord)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'lives',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: liveId),
          callback: (p) {
            status = '${p.newRecord['status']}';
            viewers = (p.newRecord['viewer_count'] as num?)?.toInt() ?? viewers;
            onStatus?.call(status, viewers);
            _notify();
          },
        )
        .subscribe((s, _) {
      final ok = s == RealtimeSubscribeStatus.subscribed;
      if (ok && !connected) _load();
      connected = ok;
      _notify();
    });
  }

  Future<void> _load() async {
    try {
      final rows = await _c.from('live_messages').select('id,user_id,author,kind,body,payload').eq('live_id', liveId).gt('id', _last).order('id', ascending: false).limit(60);
      for (final x in (rows as List).reversed) {
        final m = LiveMsg.fromRow(x as Map);
        if (messages.every((e) => e.id != m.id)) {
          messages.add(m);
          _last = math.max(_last, m.id);
        }
      }
      final l = await _c.from('lives').select('status,viewer_count').eq('id', liveId).maybeSingle();
      if (l != null) {
        status = '${l['status']}';
        viewers = (l['viewer_count'] as num?)?.toInt() ?? 0;
        onStatus?.call(status, viewers);
      }
      _notify();
    } catch (_) {}
  }

  void _add(LiveMsg m) {
    if (messages.any((e) => e.id == m.id)) return;
    messages.add(m);
    _last = math.max(_last, m.id);
    if (messages.length > 200) messages.removeRange(0, messages.length - 200);
    if (m.kind == 'gift') onGift?.call(m);
    if (m.kind == 'reaction') onReaction?.call(m);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final ch = _ch;
    if (ch != null) _c.removeChannel(ch);
    super.dispose();
  }
}

const _emoji = {'heart': '❤️', 'fire': '🔥', 'clap': '👏', 'laugh': '😂', 'wow': '😮'};

class _ChatList extends StatelessWidget {
  const _ChatList({required this.feed, this.onLongPress});
  final LiveFeed feed;
  final void Function(LiveMsg)? onLongPress;
  @override
  Widget build(BuildContext context) {
    final list = [for (final m in feed.messages) if (m.kind != 'reaction') m];
    final shown = list.length > 40 ? list.sublist(list.length - 40) : list;
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.zero,
      itemCount: shown.length,
      itemBuilder: (_, i) {
        final m = shown[shown.length - 1 - i];
        final TextSpan span;
        switch (m.kind) {
          case 'gift':
            span = TextSpan(children: [TextSpan(text: '${m.author} ', style: sty(12.5, w: FontWeight.w700, c: Colors.white)), TextSpan(text: 'a offert ${m.payload['qty'] ?? 1} × ${m.payload['name'] ?? 'cadeau'} ${m.payload['emoji'] ?? ''}', style: sty(12.5, w: FontWeight.w600, c: const Color(0xFFFFD166)))]);
          case 'system':
            span = TextSpan(text: m.body, style: sty(12, c: const Color(0xCCFFFFFF)).copyWith(fontStyle: FontStyle.italic));
          default:
            span = TextSpan(children: [TextSpan(text: '${m.author}  ', style: sty(12.5, w: FontWeight.w700, c: const Color(0xFFFFD166))), TextSpan(text: m.body, style: sty(12.5, c: Colors.white))]);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: m.kind == 'chat' && onLongPress != null ? () => onLongPress!(m) : null,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text.rich(span, style: const TextStyle(shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)]))),
        );
      },
    );
  }
}

/// Animation des cadeaux et réactions reçus en direct.
class _Floaters extends StatefulWidget {
  const _Floaters({super.key});
  @override
  State<_Floaters> createState() => _FloatersState();
}

class _FloatersState extends State<_Floaters> {
  final List<({int id, String text, bool big})> _items = [];
  int _n = 0;

  void add(String text, {bool big = false}) {
    if (!mounted) return;
    final id = _n++;
    setState(() => _items.add((id: id, text: text, big: big)));
    Future.delayed(Duration(milliseconds: big ? 2600 : 1900), () {
      if (mounted) setState(() => _items.removeWhere((e) => e.id == id));
    });
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(children: [
          for (final it in _items)
            Positioned.fill(
              key: ValueKey(it.id),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: it.big ? 2400 : 1800),
                curve: Curves.easeOut,
                builder: (_, v, _) => Align(
                  alignment: it.big ? Alignment(0, 0.2 - 0.5 * v) : Alignment(0.7 + 0.15 * math.sin(it.id * 1.7 + v * 5), 0.8 - 1.1 * v),
                  child: Opacity(opacity: (1 - v * v).clamp(0, 1), child: Transform.scale(scale: it.big ? 0.8 + 0.6 * math.min(1, v * 3) : 1, child: Text(it.text, textAlign: TextAlign.center, style: TextStyle(fontSize: it.big ? 30 : 28, fontWeight: FontWeight.w700, color: Colors.white, shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 10)])))),
                ),
              ),
            ),
        ]),
      );
}

String _idemKey() {
  final r = math.Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

// ------------------------------------------------------------------ console de l'hôte (227)

class LiveHostConsole extends ConsumerStatefulWidget {
  const LiveHostConsole({super.key});
  @override
  ConsumerState<LiveHostConsole> createState() => _LiveHostConsoleState();
}

class _LiveHostConsoleState extends ConsumerState<LiveHostConsole> {
  final _transport = createLiveTransport();
  final _floaters = GlobalKey<_FloatersState>();
  LiveFeed? _feed;
  Map<String, dynamic>? _live;
  String? _error, _id;
  String _conn = 'idle';
  bool _starting = false, _cam = true, _mic = true, _ended = false;
  int _viewers = 0;
  List<Map<String, dynamic>> _guests = [];
  Timer? _guestPoll;

  @override
  void initState() {
    super.initState();
    _guestPoll = Timer.periodic(const Duration(seconds: 6), (_) => _refreshGuests());
  }

  Future<void> _refreshGuests() async {
    final id = _id;
    if (id == null || !mounted || _ended) return;
    final r = await Backend.rpc('list_cohost_requests', {'p_live': id});
    if (!mounted || r.error != null || r.data is! List) return;
    setState(() => _guests = [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)]);
  }

  Future<void> _answerGuest(String uid, bool ok) async {
    final r = await Backend.rpc('respond_cohost', {'p_live': _id, 'p_user': uid, 'p_approve': ok});
    if (!mounted) return;
    if (r.error != null) gToast(context, Backend.userMessage(r.error!));
    await _refreshGuests();
  }

  Future<void> _removeGuest(String uid) async {
    await Backend.rpc('remove_cohost', {'p_live': _id, 'p_user': uid});
    await _refreshGuests();
  }

  /// Invités : demandes de participation des spectateurs ; l'hôte accepte (3 invités au plus), refuse ou retire.
  Future<void> _showGuests() async {
    await _refreshGuests();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invités du direct', style: sty(17, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Un invité accepté diffuse avec vous (3 au plus).', style: sty(12, c: kGrey)),
            const SizedBox(height: 12),
            if (_guests.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text('Aucune demande pour le moment.', style: sty(13, c: kGrey))),
            for (final g in _guests)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  socialAvatar('${g['avatar'] ?? ''}', '${g['name']}', 38),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${g['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(13.5, w: FontWeight.w700))),
                  if (g['status'] == 'requested') ...[
                    TextButton(onPressed: () async { await _answerGuest('${g['user_id']}', false); set(() {}); }, child: Text('Refuser', style: sty(12.5, c: kGrey))),
                    FilledButton(onPressed: () async { await _answerGuest('${g['user_id']}', true); set(() {}); }, style: FilledButton.styleFrom(backgroundColor: kInk), child: Text('Accepter', style: sty(12.5, w: FontWeight.w700, c: Colors.white))),
                  ] else
                    TextButton(onPressed: () async { await _removeGuest('${g['user_id']}'); set(() {}); }, child: Text('Retirer', style: sty(12.5, w: FontWeight.w700, c: kLike))),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = liveIdOf(context);
    if (id != null && id != _id) {
      _id = id;
      _load(id);
    }
  }

  @override
  void dispose() {
    _guestPoll?.cancel();
    _feed?.dispose();
    _transport.disconnect();
    super.dispose();
  }

  Future<void> _load(String id) async {
    final r = await Backend.rpc('live_get', {'p_live': id});
    if (!mounted) return;
    if (r.error != null || r.data is! Map) return setState(() => _error = 'Ce live est introuvable.');
    final live = Map<String, dynamic>.from(r.data as Map);
    if (live['mine'] != true) return setState(() => _error = 'Seul l’hôte peut ouvrir la régie de ce live.');
    setState(() {
      _live = live;
      _ended = live['status'] == 'ended';
    });
    if (live['status'] == 'live') _attachFeed(id);
  }

  void _attachFeed(String id) {
    _feed?.dispose();
    _feed = LiveFeed(id, onGift: (m) => _floaters.currentState?.add('${m.payload['emoji'] ?? '🎁'}\n${m.author}', big: true), onReaction: (m) => _floaters.currentState?.add(_emoji[m.body] ?? '❤️'), onStatus: (s, v) {
      if (!mounted) return;
      setState(() => _viewers = v);
    })..addListener(() {
        if (mounted) setState(() {});
      });
    _feed!.start();
  }

  Future<void> _start() async {
    final id = _id;
    if (id == null || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    if (!_transport.supported) {
      setState(() {
        _starting = false;
        _error = liveErrorMessage('unsupported');
      });
      return;
    }
    final t = await fetchLiveToken(id);
    if (!mounted) return;
    if (t.token == null) {
      setState(() {
        _starting = false;
        _error = t.error;
      });
      return;
    }
    String? failure;
    final ok = await _transport.connect(
      url: t.url!,
      token: t.token!,
      publish: true,
      onState: (s) {
        if (mounted) setState(() => _conn = s);
        if (s == 'disconnected' && !_ended && mounted && _live?['status'] == 'live') setState(() => _error = 'La connexion vidéo a été interrompue. Touchez « Reprendre » pour vous reconnecter.');
      },
      onParticipants: (n) {},
      onError: (e) => failure = e,
    );
    if (!mounted) return;
    if (!ok || failure != null) {
      await _transport.disconnect();
      return setState(() {
        _starting = false;
        _error = liveErrorMessage(failure ?? 'connect_failed');
      });
    }
    // caméra et micro publiés : le live peut être déclaré « en direct » (et les abonnés prévenus)
    final r = await Backend.rpc('start_live', {'p_live': id});
    if (!mounted) return;
    if (r.error != null) {
      await _transport.disconnect();
      return setState(() {
        _starting = false;
        _error = Backend.userMessage(r.error!);
      });
    }
    setState(() {
      _starting = false;
      _live = {...?_live, 'status': 'live'};
    });
    _attachFeed(id);
    ref.invalidate(livesNowProvider);
    ref.invalidate(myLivesProvider);
  }

  Future<void> _resume() async {
    final id = _id;
    if (id == null) return;
    setState(() => _error = null);
    final t = await fetchLiveToken(id);
    if (!mounted) return;
    if (t.token == null) return setState(() => _error = t.error);
    String? failure;
    await _transport.connect(url: t.url!, token: t.token!, publish: true, onState: (s) {
      if (mounted) setState(() => _conn = s);
    }, onParticipants: (_) {}, onError: (e) => failure = e);
    if (mounted && failure != null) setState(() => _error = liveErrorMessage(failure!));
  }

  Future<void> _end() async {
    final id = _id;
    if (id == null) return;
    final yes = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Terminer le direct ?', style: sty(16, w: FontWeight.w700)),
        content: Text('Les spectateurs seront déconnectés. Cette action est définitive.', style: sty(13.5, c: kGrey, h: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Continuer', style: sty(14))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Terminer', style: sty(14, w: FontWeight.w700, c: kLike)))],
      ),
    );
    if (yes != true || !mounted) return;
    await _transport.disconnect();
    final r = await Backend.rpc('end_live', {'p_live': id});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    ref.invalidate(livesNowProvider);
    ref.invalidate(myLivesProvider);
    setState(() => _ended = true);
  }

  Future<void> _moderate(LiveMsg m) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.visibility_off_outlined), title: Text('Masquer ce message', style: sty(14)), onTap: () => Navigator.pop(ctx, 'hide')),
        ListTile(leading: const Icon(Icons.block, color: kLike), title: Text('Bannir ${m.author} du live', style: sty(14, c: kLike)), onTap: () => Navigator.pop(ctx, 'ban')),
      ])),
    );
    if (act == null || _id == null) return;
    final r = await Backend.rpc('moderate_live_viewer', {'p_live': _id, 'p_user': act == 'ban' ? m.userId : null, 'p_message': m.id});
    if (mounted) gToast(context, r.error != null ? Backend.userMessage(r.error!) : (act == 'ban' ? 'Spectateur banni' : 'Message masqué'));
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    if (_id == null) return _msg('Aucun live sélectionné.');
    if (_error != null && live == null) return _msg(_error!);
    if (live == null) return _msg('Chargement…');
    final isLive = live['status'] == 'live';
    final title = '${live['title']}';
    return ColoredBox(
      color: _bg,
      child: Stack(fit: StackFit.expand, children: [
        _transport.videoView(),
        if (!isLive && !_ended)
          Container(
            color: const Color(0xCC0E0D14),
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 54),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: sty(18, w: FontWeight.w700, c: Colors.white)),
              const SizedBox(height: 10),
              Text('Au démarrage, votre navigateur demande l’accès à la caméra et au micro. Vos abonnés sont prévenus dès que le direct commence.', textAlign: TextAlign.center, style: sty(13, c: const Color(0xCCFFFFFF), h: 1.5)),
              const SizedBox(height: 22),
              FilledButton(onPressed: _starting ? null : _start, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF2D55), padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 15), shape: const StadiumBorder()), child: _starting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Démarrer le direct', style: sty(15, w: FontWeight.w800, c: Colors.white))),
              TextButton(onPressed: () async {
                final r = await Backend.rpc('end_live', {'p_live': _id});
                if (!mounted) return;
                ref.invalidate(myLivesProvider);
                ref.invalidate(livesNowProvider);
                if (r.error == null && mounted) gBack(context);
              }, child: Text('Annuler ce live', style: sty(13, c: const Color(0xCCFFFFFF)))),
            ]),
          ),
        if (_ended)
          Container(color: const Color(0xE60E0D14), alignment: Alignment.center, padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 54),
            const SizedBox(height: 12),
            Text('Le direct est terminé', style: sty(18, w: FontWeight.w700, c: Colors.white)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => showCreatorDashboard(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)), child: Text('Voir mon espace créateur', style: sty(13, w: FontWeight.w700, c: Colors.white))),
            TextButton(onPressed: () => gBack(context), child: Text('Retour', style: sty(13, c: Colors.white))),
          ])),
        if (isLive && !_ended) ...[
          Positioned(top: 52, left: 16, right: 16, child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), color: const Color(0xFFFF2D55), child: Text('EN DIRECT', style: sty(10.5, w: FontWeight.w800, c: Colors.white))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), color: const Color(0xB3111015), child: Row(children: [const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14), const SizedBox(width: 4), Text(compactCount(_feed?.viewers ?? _viewers), style: sty(11, w: FontWeight.w700, c: Colors.white))])),
            const Spacer(),
            _round(Icons.stop_circle_outlined, _end, 'Terminer', color: kLike),
          ])),
          Positioned(left: 16, right: 90, bottom: 24, height: 200, child: _feed == null ? const SizedBox.shrink() : _ChatList(feed: _feed!, onLongPress: _moderate)),
          Positioned(right: 14, bottom: 24, child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              _round(Icons.group_add_outlined, _showGuests, 'Invités'),
              if (_guests.any((g) => g['status'] == 'requested')) Positioned(right: -2, top: -2, child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFFFF2D55), shape: BoxShape.circle))),
            ]),
            const SizedBox(height: 10),
            _round(_cam ? Icons.videocam : Icons.videocam_off, () async {
              setState(() => _cam = !_cam);
              await _transport.setCamera(_cam);
            }, 'Caméra'),
            const SizedBox(height: 10),
            _round(_mic ? Icons.mic : Icons.mic_off, () async {
              setState(() => _mic = !_mic);
              await _transport.setMic(_mic);
            }, 'Micro'),
          ])),
          _Floaters(key: _floaters),
        ],
        if (_conn == 'reconnecting') Positioned(top: 100, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), color: const Color(0xCCB26A00), child: Text('Reconnexion en cours…', style: sty(12.5, w: FontWeight.w600, c: Colors.white))))),
        if (_error != null)
          Positioned(left: 16, right: 16, top: 100, child: Container(padding: const EdgeInsets.all(12), color: const Color(0xF2FFFFFF), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, style: sty(12.5, c: kInk, h: 1.45)),
            if (isLive) TextButton(onPressed: _resume, child: Text('Reprendre', style: sty(13, w: FontWeight.w700))),
            TextButton(onPressed: () => setState(() => _error = null), child: Text('Fermer', style: sty(12.5, c: kGrey))),
          ]))),
        Positioned(top: 48, left: 8, child: isLive ? const SizedBox.shrink() : _round(Icons.arrow_back, () => gBack(context), 'Retour')),
      ]),
    );
  }

  Widget _msg(String t) => ColoredBox(color: _bg, child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(t, textAlign: TextAlign.center, style: sty(14, c: Colors.white, h: 1.5)), TextButton(onPressed: () => gBack(context), child: Text('Retour', style: sty(13, c: Colors.white)))]))));
}

Widget _round(IconData icon, VoidCallback onTap, String label, {Color color = Colors.white}) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(onTap: onTap, child: Container(width: 46, height: 46, decoration: const BoxDecoration(color: Color(0x80111015), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24))),
    );

// ------------------------------------------------------------------ spectateur (222)

class LiveViewer extends ConsumerStatefulWidget {
  const LiveViewer({super.key});
  @override
  ConsumerState<LiveViewer> createState() => _LiveViewerState();
}

class _LiveViewerState extends ConsumerState<LiveViewer> {
  final _transport = createLiveTransport();
  final _floaters = GlobalKey<_FloatersState>();
  LiveFeed? _feed;
  Map<String, dynamic>? _live;
  String? _error, _id;
  String _conn = 'idle';
  bool _ended = false, _joining = false, _publishing = false;
  String _co = 'none'; // demande de co-diffusion : none, requested, approved, refused, removed
  Timer? _beat, _coPoll;

  /// Co-diffusion : l'hôte peut inviter un spectateur à diffuser avec lui (caméra et micro), puis le retirer.
  void _startCoPoll() {
    _coPoll?.cancel();
    _coPoll = Timer.periodic(const Duration(seconds: 5), (_) async {
      final id = _id;
      if (id == null || !mounted || _ended) return;
      final r = await Backend.rpc('my_cohost_status', {'p_live': id});
      if (!mounted || r.error != null) return;
      final st = '${r.data}';
      if (st == _co) return;
      final was = _co;
      setState(() => _co = st);
      if (st == 'approved' && !_publishing) {
        gToast(context, 'L’hôte vous a accepté : vous passez en direct.');
        _switchRole(true);
      } else if (was == 'approved' && st != 'approved' && _publishing) {
        gToast(context, 'Vous ne diffusez plus avec l’hôte.');
        _switchRole(false);
      } else if (st == 'refused') {
        gToast(context, 'L’hôte n’a pas accepté votre demande.');
      }
    });
  }

  Future<void> _switchRole(bool publish) async {
    final id = _id;
    if (id == null) return;
    await _transport.disconnect();
    final t = await fetchLiveToken(id);
    if (!mounted) return;
    if (t.token == null) return gToast(context, t.error ?? 'Connexion impossible.');
    String? failure;
    await _transport.connect(url: t.url!, token: t.token!, publish: publish && t.role == 'cohost', onState: (s) {
      if (mounted) setState(() => _conn = s);
    }, onParticipants: (_) {}, onError: (e) => failure = e);
    if (!mounted) return;
    setState(() => _publishing = publish && t.role == 'cohost');
    if (failure != null) gToast(context, liveErrorMessage(failure!));
  }

  Future<void> _askCohost() async {
    final id = _id;
    if (id == null) return;
    if (_publishing) {
      await Backend.rpc('remove_cohost', {'p_live': id, 'p_user': ref.read(authProvider).current?.serverId ?? ''});
      setState(() => _co = 'removed');
      return _switchRole(false);
    }
    final r = await Backend.rpc('request_cohost', {'p_live': id});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    setState(() => _co = 'requested');
    gToast(context, 'Demande envoyée à l’hôte.');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = liveIdOf(context);
    if (id != null && id != _id) {
      _id = id;
      _join(id);
    }
  }

  @override
  void dispose() {
    _coPoll?.cancel();
    _beat?.cancel();
    _feed?.dispose();
    _transport.disconnect();
    final id = _id;
    if (id != null && Backend.ready) Backend.rpc('leave_live', {'p_live': id});
    super.dispose();
  }

  Future<void> _join(String id) async {
    if (_joining) return;
    _joining = true;
    setState(() {
      _error = null;
      _conn = 'connecting';
    });
    final g = await Backend.rpc('live_get', {'p_live': id});
    if (!mounted) return;
    if (g.error != null || g.data is! Map) {
      _joining = false;
      return setState(() => _error = 'Ce live est introuvable.');
    }
    final live = Map<String, dynamic>.from(g.data as Map);
    setState(() => _live = live);
    if (live['status'] != 'live') {
      _joining = false;
      return setState(() => _ended = true);
    }
    if (ref.read(authProvider).current == null) {
      _joining = false;
      return setState(() => _error = 'Connectez-vous pour regarder un live.');
    }
    final j = await Backend.rpc('join_live', {'p_live': id});
    if (!mounted) return;
    if (j.error != null) {
      _joining = false;
      return setState(() => _error = Backend.userMessage(j.error!));
    }
    _feed?.dispose();
    _feed = LiveFeed(id, onGift: (m) => _floaters.currentState?.add('${m.payload['emoji'] ?? '🎁'}\n${m.author}', big: true), onReaction: (m) => _floaters.currentState?.add(_emoji[m.body] ?? '❤️'), onStatus: (s, v) {
      if (s == 'ended' && mounted) {
        _transport.disconnect();
        setState(() => _ended = true);
      }
    })..addListener(() {
        if (mounted) setState(() {});
      });
    _feed!.start();
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(seconds: 30), (_) => Backend.rpc('heartbeat_live', {'p_live': id}));
    final t = await fetchLiveToken(id);
    if (!mounted) return;
    if (t.token == null) {
      _joining = false;
      return setState(() => _error = t.error);
    }
    if (!_transport.supported) {
      _joining = false;
      return setState(() => _error = liveErrorMessage('unsupported'));
    }
    String? failure;
    await _transport.connect(url: t.url!, token: t.token!, publish: t.role == 'cohost', onState: (s) {
      if (!mounted) return;
      setState(() => _conn = s);
    }, onParticipants: (_) {}, onError: (e) => failure = e);
    _publishing = t.role == 'cohost';
    _startCoPoll();
    _joining = false;
    if (mounted && failure != null) setState(() => _error = liveErrorMessage(failure!));
  }

  Future<void> _react(String key) async {
    if (_id == null) return;
    _floaters.currentState?.add(_emoji[key] ?? '❤️');
    final r = await Backend.rpc('react_live', {'p_live': _id, 'p_emoji': key});
    if (r.error != null && mounted) gToast(context, Backend.userMessage(r.error!));
  }

  Future<void> _write() async {
    if (_id == null) return;
    final c = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var busy = false;
        return StatefulBuilder(builder: (ctx, set) {
          final mq = MediaQuery.of(ctx);
          Future<void> send() async {
            final t = c.text.trim();
            if (t.isEmpty || busy) return;
            set(() => busy = true);
            final r = await Backend.rpc('post_live_message', {'p_live': _id, 'p_body': t});
            if (!ctx.mounted) return;
            if (r.error != null) {
              set(() => busy = false);
              return gToast(ctx, Backend.userMessage(r.error!));
            }
            Navigator.pop(ctx);
          }

          return Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (mq.viewInsets.bottom > 0 ? 0 : mq.viewPadding.bottom)),
              child: Row(children: [
                Expanded(child: TextField(controller: c, autofocus: true, maxLength: 300, style: sty(14), onSubmitted: (_) => send(), decoration: InputDecoration(counterText: '', hintText: 'Écrire un message…', hintStyle: sty(14, c: kGrey), filled: true, fillColor: const Color(0xFFF3F1F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), isDense: true))),
                IconButton(onPressed: send, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
              ]),
            ),
          );
        });
      },
    );
    c.dispose();
  }

  Future<void> _reportLive([LiveMsg? m]) async {
    final why = await _askReason();
    if (why == null || _id == null) return;
    final r = await Backend.rpc('report_live', {'p_live': _id, 'p_message': m?.id, 'p_reason': why});
    if (mounted) gToast(context, r.error != null ? Backend.userMessage(r.error!) : 'Signalement transmis à la modération');
  }

  Future<String?> _askReason() async {
    final c = TextEditingController();
    final v = await gDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Signaler', style: sty(16, w: FontWeight.w700)),
        content: TextField(controller: c, autofocus: true, maxLength: 300, style: sty(14), decoration: InputDecoration(hintText: 'Pourquoi ? (3 caractères au moins)', hintStyle: sty(13, c: kGrey))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: sty(14))), TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text('Signaler', style: sty(14, w: FontWeight.w700, c: kLike)))],
      ),
    );
    c.dispose();
    return (v == null || v.length < 3) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    final host = live == null ? null : '${live['host']}';
    return ColoredBox(
      color: _bg,
      child: Stack(fit: StackFit.expand, children: [
        _transport.videoView(),
        if (_ended) Container(color: const Color(0xE60E0D14), alignment: Alignment.center, padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.live_tv_outlined, color: Colors.white, size: 52),
          const SizedBox(height: 12),
          Text(live == null ? 'Live introuvable' : (live['status'] == 'ended' ? 'Ce live est terminé' : 'Ce live n’a pas encore commencé'), style: sty(17, w: FontWeight.w700, c: Colors.white)),
          TextButton(onPressed: () => gBack(context), child: Text('Retour', style: sty(13.5, c: Colors.white))),
        ])),
        if (_error != null && !_ended)
          Container(color: const Color(0xE60E0D14), alignment: Alignment.center, padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 46),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: sty(13.5, c: Colors.white, h: 1.5)),
            const SizedBox(height: 10),
            if (_id != null) FilledButton(onPressed: () => _join(_id!), style: FilledButton.styleFrom(backgroundColor: Colors.white), child: Text('Réessayer', style: sty(13.5, w: FontWeight.w700))),
            TextButton(onPressed: () => gBack(context), child: Text('Retour', style: sty(13, c: Colors.white))),
          ])),
        if (live != null && !_ended && _error == null) ...[
          Positioned(top: 48, left: 12, right: 12, child: Row(children: [
            GestureDetector(onTap: () => gOpenProfile(context, '${live['host_id']}'), child: socialAvatar('${live['host_avatar'] ?? ''}', host ?? '', 36)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [NameWithBadge(name: host ?? '', verified: live['host_verified'] == true, style: sty(13, w: FontWeight.w700, c: Colors.white), badgeSize: 13), Text('${live['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(11, c: const Color(0xCCFFFFFF)))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), color: const Color(0xFFFF2D55), child: Text('DIRECT', style: sty(10, w: FontWeight.w800, c: Colors.white))),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), color: const Color(0xB3111015), child: Row(children: [const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 13), const SizedBox(width: 3), Text(compactCount(_feed?.viewers ?? 0), style: sty(10.5, w: FontWeight.w700, c: Colors.white))])),
            const SizedBox(width: 6),
            GestureDetector(onTap: () => gBack(context), child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, color: Colors.white, size: 24))),
          ])),
          if (_conn == 'reconnecting' || _conn == 'connecting') Positioned(top: 98, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), color: const Color(0xCCB26A00), child: Text(_conn == 'connecting' ? 'Connexion au direct…' : 'Reconnexion en cours…', style: sty(12, w: FontWeight.w600, c: Colors.white))))),
          if (_feed != null && !_feed!.connected) Positioned(top: 98, right: 14, child: Text('Chat hors ligne', style: sty(10.5, c: const Color(0xCCFFFFFF)))),
          Positioned(left: 14, right: 88, bottom: 76, height: 190, child: _feed == null ? const SizedBox.shrink() : _ChatList(feed: _feed!, onLongPress: _reportLive)),
          Positioned(right: 10, bottom: 70, child: Column(children: [
            for (final k in const ['heart', 'fire', 'clap']) GestureDetector(onTap: () => _react(k), child: Container(width: 46, height: 46, alignment: Alignment.center, child: Text(_emoji[k]!, style: const TextStyle(fontSize: 28)))),
            _round(Icons.card_giftcard, () => showGiftSheet(context, _id!, '${live['host_id']}'), 'Offrir un cadeau'),
            const SizedBox(height: 10),
            _round(_publishing ? Icons.call_end : (_co == 'requested' ? Icons.hourglass_top : Icons.video_call_outlined), _co == 'requested' && !_publishing ? () => gToast(context, 'Demande en attente de la réponse de l’hôte.') : _askCohost, _publishing ? 'Quitter la diffusion' : 'Demander à participer', color: _publishing ? kLike : Colors.white),
          ])),
          Positioned(left: 12, right: 12, bottom: 16, child: Row(children: [
            Expanded(child: GestureDetector(onTap: _write, child: Container(height: 44, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0x80111015), borderRadius: BorderRadius.circular(22)), child: Text('Écrire un message…', style: sty(13, c: const Color(0xCCFFFFFF)))))),
            const SizedBox(width: 8),
            _round(Icons.flag_outlined, _reportLive, 'Signaler ce live'),
          ])),
          _Floaters(key: _floaters),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ cadeaux, portefeuille, tableau créateur

class Gift {
  const Gift(this.code, this.name, this.emoji, this.credits);
  final String code, name, emoji;
  final int credits;
}

final giftCatalogProvider = FutureProvider.autoDispose<List<Gift>>((ref) async {
  final rows = await Supabase.instance.client.from('gift_catalog').select('code,name,emoji,credits').order('sort');
  return [for (final x in rows) Gift('${x['code']}', '${x['name']}', '${x['emoji']}', (x['credits'] as num).toInt())];
});

final walletProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final r = await Backend.rpc('my_wallet', const {});
  if (r.error != null || r.data is! Map) throw Exception('Portefeuille indisponible.');
  return Map<String, dynamic>.from(r.data as Map);
});

const rechargeUnavailable = 'La recharge de crédits n’est pas encore ouverte : le paiement des crédits sera activé prochainement. Aucun solde n’est jamais ajouté sans paiement confirmé.';

Future<void> showGiftSheet(BuildContext context, String liveId, String hostId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GiftSheet(liveId: liveId),
    );

class _GiftSheet extends ConsumerStatefulWidget {
  const _GiftSheet({required this.liveId});
  final String liveId;
  @override
  ConsumerState<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<_GiftSheet> {
  Gift? _sel;
  int _qty = 1;
  bool _busy = false;
  String? _key; // clé de transaction : conservée tant que l'envoi n'est pas définitivement réglé (nouvel essai sans double débit)

  Future<void> _send(Gift g, int bal) async {
    final total = g.credits * _qty;
    final yes = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Confirmer l’envoi', style: sty(16, w: FontWeight.w700)),
        content: Text('Offrir $_qty × ${g.name} ${g.emoji} pour $total crédit${total > 1 ? 's' : ''} ?\nVotre solde passera de $bal à ${bal - total} crédits. Un cadeau envoyé n’est pas remboursable.', style: sty(13.5, c: kGrey, h: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: sty(14))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Envoyer', style: sty(14, w: FontWeight.w700)))],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    _key ??= _idemKey();
    final r = await Backend.rpc('send_gift', {'p_live': widget.liveId, 'p_gift': g.code, 'p_qty': _qty, 'p_key': _key});
    if (!mounted) return;
    setState(() => _busy = false);
    final networkError = r.error != null && Backend.userMessage(r.error!).startsWith('Connexion impossible');
    if (r.error != null) {
      if (!networkError) _key = null; // refus définitif du serveur : le prochain essai sera une nouvelle transaction
      return gToast(context, networkError ? 'Réseau indisponible : touchez « Envoyer » pour réessayer, vous ne serez débité qu’une fois.' : Backend.userMessage(r.error!));
    }
    _key = null;
    ref.invalidate(walletProvider);
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    gToast(context, 'Cadeau envoyé');
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final catalog = ref.watch(giftCatalogProvider);
    final wallet = ref.watch(walletProvider);
    final bal = (wallet.value?['balance'] as num?)?.toInt() ?? 0;
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + mq.viewPadding.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Offrir un cadeau', style: sty(16, w: FontWeight.w700))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: const Color(0xFFF3F1F7), child: Text(wallet.isLoading ? '…' : '$bal crédit${bal > 1 ? 's' : ''}', style: sty(12.5, w: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          catalog.when(
            loading: () => Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('Chargement…', style: sty(13, c: kGrey)))),
            error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Le catalogue est indisponible pour le moment.', style: sty(13, c: kGrey))),
            data: (gifts) => Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in gifts)
                GestureDetector(
                  onTap: () => setState(() {
                    _sel = g;
                    _key = null;
                  }),
                  child: Container(
                    width: (mq.size.width - 32 - 24) / 4,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: _sel?.code == g.code ? kInk : kLine, width: _sel?.code == g.code ? 2 : 1)),
                    child: Column(children: [Text(g.emoji, style: const TextStyle(fontSize: 28)), Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(11, w: FontWeight.w600)), Text('${g.credits} cr.', style: sty(10.5, c: kGrey))]),
                  ),
                ),
            ]),
          ),
          if (_sel != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text('Quantité', style: sty(13, w: FontWeight.w600)),
              const Spacer(),
              IconButton(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$_qty', style: sty(15, w: FontWeight.w700)),
              IconButton(onPressed: _qty < 50 ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add_circle_outline)),
            ]),
            Text('Total : ${_sel!.credits * _qty} crédits', style: sty(13, w: FontWeight.w700)),
            const SizedBox(height: 10),
            if (bal < _sel!.credits * _qty) ...[
              Text('Crédits insuffisants.', style: sty(12.5, w: FontWeight.w600, c: kLike)),
              const SizedBox(height: 4),
              Text(rechargeUnavailable, style: sty(12, c: kGrey, h: 1.45)),
            ] else
              FilledButton(onPressed: _busy ? null : () => _send(_sel!, bal), style: FilledButton.styleFrom(backgroundColor: kInk, minimumSize: const Size.fromHeight(48), shape: const RoundedRectangleBorder()), child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Envoyer', style: sty(14, w: FontWeight.w700, c: Colors.white))),
          ] else
            Padding(padding: const EdgeInsets.only(top: 14), child: Text('Choisissez un cadeau. Les crédits ne sont jamais ajoutés sans paiement confirmé.', style: sty(12, c: kGrey, h: 1.45))),
        ]),
      ),
    );
  }
}

Future<void> showWalletSheet(BuildContext context) => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _WalletSheet());

class _WalletSheet extends ConsumerStatefulWidget {
  const _WalletSheet();
  @override
  ConsumerState<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<_WalletSheet> {
  String _dir = 'sent';
  Future<List<Map<String, dynamic>>>? _hist;

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await Backend.rpc('my_gift_history', {'p_direction': _dir, 'p_limit': 60});
    if (r.error != null || r.data is! List) return const [];
    return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wallet = ref.watch(walletProvider);
    _hist ??= _load();
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + mq.viewPadding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Mon portefeuille', style: sty(16, w: FontWeight.w700)),
        const SizedBox(height: 10),
        wallet.when(
          loading: () => Text('Chargement…', style: sty(13, c: kGrey)),
          error: (_, _) => Text('Portefeuille indisponible pour le moment.', style: sty(13, c: kGrey)),
          data: (w) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w['balance']} crédits', style: sty(26, w: FontWeight.w800)),
            Text('1 crédit = ${w['credit_price_fcfa']} FCFA à la recharge', style: sty(12, c: kGrey)),
            const SizedBox(height: 6),
            Text(rechargeUnavailable, style: sty(12, c: kGrey, h: 1.45)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          for (final e in const [('sent', 'Envoyés'), ('received', 'Reçus')])
            Expanded(child: GestureDetector(onTap: () => setState(() {
              _dir = e.$1;
              _hist = _load();
            }), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.center, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _dir == e.$1 ? kInk : kLine, width: _dir == e.$1 ? 2 : 1))), child: Text(e.$2, style: sty(13, w: _dir == e.$1 ? FontWeight.w700 : FontWeight.w500))))),
        ]),
        Flexible(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _hist,
            builder: (_, s) {
              if (!s.hasData) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Chargement…', style: sty(13, c: kGrey))));
              if (s.data!.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(_dir == 'sent' ? 'Aucun cadeau envoyé pour le moment.' : 'Aucun cadeau reçu pour le moment.', style: sty(13, c: kGrey))));
              return ListView(shrinkWrap: true, children: [
                for (final h in s.data!)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text('${h['emoji']}', style: const TextStyle(fontSize: 26)),
                    title: Text('${h['quantity']} × ${h['gift_name']} · ${_dir == 'sent' ? 'à' : 'de'} ${h['other']}', style: sty(13, w: FontWeight.w600)),
                    subtitle: Text('${h['live_title']} · ${relativeTime(DateTime.tryParse('${h['created_at']}')?.toLocal() ?? DateTime.now(), DateTime.now())}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sty(11, c: kGrey)),
                    trailing: Text(_dir == 'sent' ? '-${h['credits']}' : '+${h['creator_credits']}', style: sty(13, w: FontWeight.w700, c: _dir == 'sent' ? kInk : const Color(0xFF1E8E5A))),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

Future<void> showCreatorDashboard(BuildContext context) => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _CreatorSheet());

class _CreatorSheet extends StatelessWidget {
  const _CreatorSheet();
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.8),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + mq.viewPadding.bottom),
      child: FutureBuilder(
        future: Backend.rpc('creator_dashboard', const {}),
        builder: (_, s) {
          if (!s.hasData) return SizedBox(height: 120, child: Center(child: Text('Chargement…', style: sty(13, c: kGrey))));
          final r = s.data!;
          if (r.error != null || r.data is! Map) return SizedBox(height: 120, child: Center(child: Text('Tableau de bord indisponible pour le moment.', style: sty(13, c: kGrey))));
          final d = Map<String, dynamic>.from(r.data as Map);
          Widget stat(String label, String value) => Expanded(child: Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: kLine)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: sty(20, w: FontWeight.w800)), Text(label, style: sty(11, c: kGrey))])));
          final fcfa = ((d['creator_credits'] as num? ?? 0) * (d['credit_price_fcfa'] as num? ?? 0)).toInt();
          return SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Espace créateur', style: sty(16, w: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [stat('Lives réalisés', '${d['lives']}'), stat('Pic de spectateurs', '${d['peak_viewers']}')]),
              Row(children: [stat('Cadeaux reçus', '${d['gifts_received']}'), stat('Crédits reçus (total)', '${d['credits_received']}')]),
              Row(children: [stat('Vos gains (${d['creator_share_pct']} %)', '${d['creator_credits']} cr.'), stat('Commission plateforme', '${d['platform_credits']} cr.')]),
              const SizedBox(height: 8),
              Text('Valeur estimée de vos gains : $fcfa FCFA.', style: sty(12.5, w: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Retrait : indisponible pour le moment. Le versement de ces gains en argent suppose un prestataire de paiement agréé et un cadre juridique validé ; il n’est pas ouvert tant que ce n’est pas en place. Vos gains restent enregistrés et ne sont pas perdus.', style: sty(12, c: kGrey, h: 1.5)),
            ]),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ points d'entrée des écrans

/// Écran 222 : spectateur d'un live (`?live=<id>`) ; sans identifiant, les ateliers en direct programmés par l'administration
/// (liste existante, avec leurs commentaires) sous l'en-tête de l'écran.
class LiveViewerEntry extends StatelessWidget {
  const LiveViewerEntry({super.key});
  @override
  Widget build(BuildContext context) => liveIdOf(context) != null ? const LiveViewer() : const Padding(padding: EdgeInsets.fromLTRB(24, 125, 24, 0), child: LiveRoom(width: 342, height: 620));
}

/// Écran L1 « Aller en direct » : formulaire de création, puis régie de l'hôte (`?live=<id>`).
class LiveHostEntry extends StatelessWidget {
  const LiveHostEntry({super.key});
  @override
  Widget build(BuildContext context) => liveIdOf(context) != null ? const LiveHostConsole() : const Padding(padding: EdgeInsets.only(top: 118), child: LiveCreateForm());
}
