import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;

import '../gen.dart' show gToast;
import '../gsound.dart' show GAnim;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'chat_server.dart' show mimeOf;
import 'share.dart' show openUrl;

/// Échanges d'une communauté : chat du groupe, questions et réponses, événements, fichiers partagés.
/// Tout est lu et écrit par des fonctions serveur qui vérifient l'appartenance à la communauté (migration 20261114001000).

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _line = Color(0xFFECE8F2);
const _violet = Color(0xFF5A3FE0);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

Widget _note(String t) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Text(t, textAlign: TextAlign.center, style: _st(13.5, c: _grey).copyWith(height: 1.5))));

Widget _card(Widget child) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _line)), child: child);

Widget _btn(String label, VoidCallback? onTap, {bool dark = true}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: onTap == null ? const Color(0xFFB9B4C7) : (dark ? _ink : Colors.white), borderRadius: BorderRadius.circular(6), border: dark ? null : Border.all(color: _line)),
        child: Text(label, textAlign: TextAlign.center, style: _st(13.5, w: FontWeight.w700, c: dark ? Colors.white : _ink)),
      ),
    );

// ------------------------------------------------------------------ chat du groupe

class CommunityChatTab extends StatefulWidget {
  const CommunityChatTab({super.key, required this.communityId, required this.isMember});
  final String communityId;
  final bool isMember;

  @override
  State<CommunityChatTab> createState() => _ChatState();
}

class _ChatState extends State<CommunityChatTab> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = const [];
  Timer? _timer;
  bool _loaded = false, _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isMember) {
      _load();
      // discussion en direct : le fil se rafraîchit toutes les 4 secondes (jamais dans les tests)
      if (GAnim.enabled) _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final after = _msgs.isEmpty ? 0 : (_msgs.last['id'] as num).toInt();
    final r = await Backend.rpc('community_chat_list', {'p_community': widget.communityId, 'p_after': after, 'p_limit': 60});
    if (!mounted) return;
    if (r.error != null || r.data is! List) return setState(() => _failed = !_loaded);
    final fresh = [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
    setState(() {
      _loaded = true;
      _failed = false;
      if (fresh.isNotEmpty) _msgs = after == 0 ? fresh : [..._msgs, ...fresh];
    });
    if (fresh.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    final r = await Backend.rpc('community_chat_send', {'p_community': widget.communityId, 'p_body': t});
    if (!mounted) return;
    if (r.error != null) {
      _text.text = t;
      return gToast(context, Backend.userMessage(r.error!));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMember) return _note('Le chat est réservé aux membres. Rejoignez la communauté pour discuter en direct.');
    if (_failed) return _note('Le chat est indisponible pour le moment.');
    return Column(children: [
      Expanded(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : _msgs.isEmpty
                ? _note('Aucun message pour le moment.\nSoyez le premier à écrire au groupe.')
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) {
                      final m = _msgs[i];
                      final mine = m['mine'] == true;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: mine ? _ink : Colors.white, borderRadius: BorderRadius.circular(12), border: mine ? null : Border.all(color: _line)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (!mine) Text('${m['author']}', style: _st(11, w: FontWeight.w700, c: _violet)),
                            Text('${m['body']}', style: _st(13.5, c: mine ? Colors.white : _ink).copyWith(height: 1.35)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          Expanded(child: TextField(controller: _text, maxLength: 1000, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'Écrire au groupe…', counterText: '', filled: true, fillColor: const Color(0xFFF2EFF6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
          const SizedBox(width: 8),
          IconButton(tooltip: 'Envoyer', onPressed: _send, icon: const Icon(Icons.send_rounded)),
        ]),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ questions et réponses

class CommunityQaTab extends StatefulWidget {
  const CommunityQaTab({super.key, required this.communityId, required this.isMember});
  final String communityId;
  final bool isMember;

  @override
  State<CommunityQaTab> createState() => _QaState();
}

class _QaState extends State<CommunityQaTab> {
  List<Map<String, dynamic>>? _qs;
  bool _failed = false;
  final _ask = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await Backend.rpc('community_qa', {'p_community': widget.communityId, 'p_limit': 50});
    if (!mounted) return;
    if (r.error != null || r.data is! List) return setState(() => _failed = true);
    setState(() {
      _failed = false;
      _qs = [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
    });
  }

  Future<void> _call(String fn, Map<String, dynamic> params, {String? ok}) async {
    final r = await Backend.rpc(fn, params);
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    if (ok != null) gToast(context, ok);
    await _load();
  }

  Future<void> _answer(Map<String, dynamic> q) async {
    final c = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (s) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(s).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Votre réponse', style: _st(18, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${q['body']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(12.5, c: _grey)),
          const SizedBox(height: 12),
          TextField(controller: c, maxLines: 4, maxLength: 1000, decoration: InputDecoration(hintText: 'Aidez votre camarade…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 8),
          _btn('Publier la réponse', () => Navigator.pop(s, true)),
        ]),
      ),
    );
    if (ok != true) return;
    await _call('community_answer', {'p_question': q['id'], 'p_body': c.text}, ok: 'Réponse publiée.');
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _note('Les questions sont réservées aux membres, ou indisponibles pour le moment.');
    final qs = _qs;
    if (qs == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.isMember)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Poser une question au groupe', style: _st(13.5, w: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _ask, maxLines: 3, maxLength: 600, decoration: InputDecoration(hintText: 'Ex. Quelqu’un a déjà fait le TP de réseaux ?', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 8),
          _btn('Publier la question', () async {
            final t = _ask.text;
            _ask.clear();
            await _call('community_ask', {'p_community': widget.communityId, 'p_body': t});
          }),
        ])),
      if (qs.isEmpty) _note('Aucune question pour le moment.\nPosez la première : le groupe répondra.'),
      for (final q in qs) ...[
        const SizedBox(height: 12),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${q['author']}', style: _st(12.5, w: FontWeight.w700, c: _violet))),
            if (q['solved'] == true) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFDDF5EC), borderRadius: BorderRadius.circular(4)), child: Text('Résolue', style: _st(10.5, w: FontWeight.w700, c: const Color(0xFF0F7A52)))),
          ]),
          const SizedBox(height: 4),
          Text('${q['body']}', style: _st(14, w: FontWeight.w700).copyWith(height: 1.4)),
          for (final a in (q['answers'] as List? ?? const [])) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (a as Map)['accepted'] == true ? const Color(0xFFEFFAF4) : const Color(0xFFF7F4FA), borderRadius: BorderRadius.circular(6), border: a['accepted'] == true ? Border.all(color: const Color(0xFF0F7A52)) : null),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['author']}${a['accepted'] == true ? ' · réponse retenue' : ''}', style: _st(11.5, w: FontWeight.w700, c: a['accepted'] == true ? const Color(0xFF0F7A52) : _grey)),
                Text('${a['body']}', style: _st(13).copyWith(height: 1.4)),
                if (q['mine'] == true && q['solved'] != true) Align(alignment: Alignment.centerRight, child: GestureDetector(onTap: () => _call('community_accept_answer', {'p_answer': a['id']}, ok: 'Réponse retenue.'), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text('Cette réponse m’a aidé', style: _st(12, w: FontWeight.w700, c: _violet))))),
              ]),
            ),
          ],
          if (widget.isMember) Align(alignment: Alignment.centerLeft, child: GestureDetector(onTap: () => _answer(q), child: Padding(padding: const EdgeInsets.only(top: 10), child: Text('Répondre', style: _st(12.5, w: FontWeight.w700, c: _violet))))),
        ])),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ événements

const _eventKinds = {'meeting': 'Réunion', 'live': 'Live', 'revision': 'Révision ensemble', 'other': 'Autre'};
const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String eventWhen(DateTime d) => '${d.day} ${_mois[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')} h ${d.minute.toString().padLeft(2, '0')}';

class CommunityEventsTab extends StatefulWidget {
  const CommunityEventsTab({super.key, required this.communityId, required this.isMember});
  final String communityId;
  final bool isMember;

  @override
  State<CommunityEventsTab> createState() => _EventsState();
}

class _EventsState extends State<CommunityEventsTab> {
  List<Map<String, dynamic>>? _events;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Backend.rpc('community_events_list', {'p_community': widget.communityId});
    if (!mounted) return;
    if (r.error != null || r.data is! List) return setState(() => _failed = true);
    setState(() {
      _failed = false;
      _events = [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
    });
  }

  Future<void> _call(String fn, Map<String, dynamic> params, {String? ok}) async {
    final r = await Backend.rpc(fn, params);
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    if (ok != null) gToast(context, ok);
    await _load();
  }

  Future<void> _create() async {
    final title = TextEditingController(), place = TextEditingController(), desc = TextEditingController();
    var kind = 'revision';
    var when = DateTime.now().add(const Duration(days: 1)).copyWith(minute: 0, second: 0, millisecond: 0);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (s) => StatefulBuilder(
        builder: (s, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(s).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nouvel événement', style: _st(18, w: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: title, maxLength: 100, decoration: InputDecoration(labelText: 'Titre', hintText: 'Ex. Révision Réseaux : examen demain', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in _eventKinds.entries)
                  GestureDetector(onTap: () => set(() => kind = e.key), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: kind == e.key ? _ink : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kind == e.key ? _ink : _line)), child: Text(e.value, style: _st(12.5, w: FontWeight.w600, c: kind == e.key ? Colors.white : _ink)))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _btn('Le ${when.day} ${_mois[when.month - 1]} ${when.year}', () async {
                    final d = await showDatePicker(context: s, initialDate: when, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) set(() => when = DateTime(d.year, d.month, d.day, when.hour, when.minute));
                  }, dark: false),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _btn('À ${when.hour.toString().padLeft(2, '0')} h ${when.minute.toString().padLeft(2, '0')}', () async {
                    final t = await showTimePicker(context: s, initialTime: TimeOfDay.fromDateTime(when));
                    if (t != null) set(() => when = DateTime(when.year, when.month, when.day, t.hour, t.minute));
                  }, dark: false),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(controller: place, maxLength: 100, decoration: InputDecoration(labelText: 'Lieu ou lien (facultatif)', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 10),
              TextField(controller: desc, maxLines: 3, maxLength: 500, decoration: InputDecoration(labelText: 'Détails (facultatif)', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              _btn('Créer l’événement', () => Navigator.pop(s, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _call('community_event_create', {'p_community': widget.communityId, 'p_title': title.text, 'p_kind': kind, 'p_starts': when.toUtc().toIso8601String(), 'p_place': place.text, 'p_description': desc.text}, ok: 'Événement créé : les membres sont prévenus.');
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _note('Les événements sont réservés aux membres, ou indisponibles pour le moment.');
    final evs = _events;
    if (evs == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.isMember) _btn('Créer un événement', _create),
      if (evs.isEmpty) _note('Aucun événement à venir.\nUne réunion, un live ou une révision ensemble : proposez-en un.'),
      for (final e in evs) ...[
        const SizedBox(height: 12),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_eventKinds['${e['kind']}'] ?? 'Événement'} · ${eventWhen(DateTime.parse('${e['starts_at']}').toLocal())}', style: _st(11.5, w: FontWeight.w700, c: _violet)),
          const SizedBox(height: 2),
          Text('${e['title']}', style: _st(14.5, w: FontWeight.w800)),
          if ('${e['place']}'.isNotEmpty) Text('${e['place']}', style: _st(12.5, c: _grey)),
          if ('${e['description']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${e['description']}', style: _st(13).copyWith(height: 1.4))),
          const SizedBox(height: 4),
          Text('${e['going']} participant${(e['going'] as num) > 1 ? 's' : ''} · proposé par ${e['creator']}', style: _st(11.5, c: _grey)),
          if (widget.isMember) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _btn(e['i_go'] == true ? 'Je participe ✓' : 'Je participe', () => _call('community_event_rsvp', {'p_event': e['id'], 'p_going': e['i_go'] != true}), dark: e['i_go'] != true)),
              if (e['mine'] == true) ...[const SizedBox(width: 8), SizedBox(width: 110, child: _btn('Supprimer', () => _call('community_event_delete', {'p_event': e['id']}), dark: false))],
            ]),
          ],
        ])),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ fichiers partagés

const _fileKinds = {'course': 'Cours', 'pdf': 'PDF', 'exam': 'Ancien sujet', 'template': 'Modèle (CV…)', 'other': 'Autre'};

String fileSizeLabel(num bytes) => bytes >= 1048576 ? '${(bytes / 1048576).toStringAsFixed(1)} Mo' : '${(bytes / 1024).ceil()} Ko';

class CommunityFilesTab extends StatefulWidget {
  const CommunityFilesTab({super.key, required this.communityId, required this.isMember});
  final String communityId;
  final bool isMember;

  @override
  State<CommunityFilesTab> createState() => _FilesState();
}

class _FilesState extends State<CommunityFilesTab> {
  List<Map<String, dynamic>>? _files;
  bool _failed = false, _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.isMember) _load();
  }

  Future<void> _load() async {
    final r = await Backend.rpc('community_files_list', {'p_community': widget.communityId});
    if (!mounted) return;
    if (r.error != null || r.data is! List) return setState(() => _failed = true);
    setState(() {
      _failed = false;
      _files = [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
    });
  }

  Future<void> _add() async {
    try {
      final picked = await FilePicker.pickFiles();
      if (picked.isEmpty || !mounted) return;
      final f = picked.first;
      final mime = mimeOf(f.name);
      if (mime == null) return gToast(context, 'Type de fichier non pris en charge (PDF, Word, PowerPoint, Excel, images, texte, zip).');
      final bytes = await f.readAsBytes();
      if (bytes.length > 20 * 1024 * 1024) return gToast(context, 'Fichier trop lourd : 20 Mo au maximum.');
      if (!mounted) return;
      final title = TextEditingController(text: f.name.split('.').first);
      var kind = f.name.toLowerCase().endsWith('.pdf') ? 'pdf' : 'course';
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (s) => StatefulBuilder(
          builder: (s, set) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(s).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Partager un fichier', style: _st(18, w: FontWeight.w800)),
              Text('${f.name} · ${fileSizeLabel(bytes.length)}', style: _st(12, c: _grey)),
              const SizedBox(height: 12),
              TextField(controller: title, maxLength: 120, decoration: InputDecoration(labelText: 'Titre', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in _fileKinds.entries)
                  GestureDetector(onTap: () => set(() => kind = e.key), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: kind == e.key ? _ink : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kind == e.key ? _ink : _line)), child: Text(e.value, style: _st(12.5, w: FontWeight.w600, c: kind == e.key ? Colors.white : _ink)))),
              ]),
              const SizedBox(height: 12),
              _btn('Partager', () => Navigator.pop(s, true)),
            ]),
          ),
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => _busy = true);
      final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '${widget.communityId}/${DateTime.now().millisecondsSinceEpoch}-$safe';
      final err = await Backend.uploadFile('community-files', path, bytes, mime);
      if (err != null) {
        if (mounted) {
          setState(() => _busy = false);
          gToast(context, err);
        }
        return;
      }
      final r = await Backend.rpc('community_file_add', {'p_community': widget.communityId, 'p_title': title.text, 'p_kind': kind, 'p_path': path, 'p_size': bytes.length, 'p_mime': mime});
      if (!mounted) return;
      setState(() => _busy = false);
      if (r.error != null) {
        await Backend.removeFile('community-files', path);
        return gToast(context, Backend.userMessage(r.error!));
      }
      gToast(context, 'Fichier partagé avec le groupe.');
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        gToast(context, 'Impossible d’ouvrir les fichiers.');
      }
    }
  }

  Future<void> _open(Map<String, dynamic> f) async {
    final url = await Backend.signedFileUrl('community-files', '${f['path']}');
    if (!mounted) return;
    if (url == null) return gToast(context, 'Fichier indisponible pour le moment.');
    await openUrl(context, url);
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    final r = await Backend.rpc('community_file_delete', {'p_id': f['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    await Backend.removeFile('community-files', '${r.data}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMember) return _note('Les fichiers sont réservés aux membres. Rejoignez la communauté pour les consulter.');
    if (_failed) return _note('Les fichiers sont indisponibles pour le moment.');
    final files = _files;
    if (files == null) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      _btn(_busy ? 'Envoi en cours…' : 'Partager un fichier', _busy ? null : _add),
      if (files.isEmpty) _note('Aucun fichier partagé.\nCours, PDF, anciens sujets d’examen, modèles de CV : déposez-les ici pour le groupe.'),
      for (final f in files) ...[
        const SizedBox(height: 10),
        _card(Row(children: [
          const Icon(Icons.description_outlined, color: _violet),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(f),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${f['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w700)),
                Text('${_fileKinds['${f['kind']}'] ?? 'Fichier'} · ${fileSizeLabel(f['size'] as num)} · ${f['uploader']}', style: _st(11.5, c: _grey)),
              ]),
            ),
          ),
          if (f['mine'] == true) IconButton(tooltip: 'Supprimer', onPressed: () => _delete(f), icon: const Icon(Icons.delete_outline, size: 20)),
        ])),
      ],
    ]);
  }
}
