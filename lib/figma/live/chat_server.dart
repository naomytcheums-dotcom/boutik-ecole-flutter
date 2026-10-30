import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../gen.dart';
import 'backend.dart';
import 'messages.dart';
import 'share.dart';

/// Conversation réelle (écrans 53 et 54) : messages texte, photos, fichiers et vocaux enregistrés sur le serveur.
/// Les pièces jointes sont dans un stockage privé : seuls les deux participants obtiennent un lien temporaire.
class SMsg {
  const SMsg({required this.id, required this.mine, required this.time, required this.kind, required this.body, this.path, this.name, this.size, this.status = 'ok', this.retry});
  final String id, time, kind, body;
  final bool mine;
  final String? path, name;
  final int? size;
  final String status; // ok · sending · failed
  final VoidCallback? retry;
}

TextStyle _st(double s, {FontWeight w = FontWeight.w400, Color c = const Color(0xFF111015)}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

const _mimes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

String? mimeOf(String name) => _mimes[name.split('.').last.toLowerCase()];

class ServerChatPanel extends ConsumerStatefulWidget {
  const ServerChatPanel({super.key});
  @override
  ConsumerState<ServerChatPanel> createState() => _ServerChatPanelState();
}

class _ServerChatPanelState extends ConsumerState<ServerChatPanel> {
  final c = TextEditingController();
  final scroll = ScrollController();
  List<SMsg> msgs = const [];
  final List<SMsg> pending = [];
  Timer? _poll;
  String _cid = '';
  bool loading = true;
  AudioRecorder? _rec;
  AudioRecorder get rec => _rec ??= AudioRecorder();
  bool recording = false;
  DateTime? started;
  final _urls = <String, Future<String?>>{};

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load());
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _poll?.cancel();
    c.dispose();
    scroll.dispose();
    _rec?.dispose();
    super.dispose();
  }

  String _time(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<String?> _url(String path) => _urls.putIfAbsent(path, () => Backend.chatFileUrl(path));

  Future<void> _load() async {
    final cid = ref.read(selectedConversationProvider);
    if (cid.isEmpty) {
      if (mounted && loading) setState(() => loading = false);
      return;
    }
    final rows = await Backend.messages(cid);
    if (!mounted) return;
    final me = Backend.currentUserId;
    final grew = rows.length != msgs.length || cid != _cid;
    setState(() {
      _cid = cid;
      loading = false;
      msgs = [
        for (final r in rows)
          SMsg(
            id: '${r['id']}',
            mine: r['sender_id'] == me,
            time: _time((r['created_at'] ?? '').toString()),
            kind: (r['kind'] ?? 'text').toString(),
            body: (r['body'] ?? '').toString(),
            path: r['attachment_path']?.toString(),
            name: r['attachment_name']?.toString(),
            size: (r['attachment_size'] as num?)?.toInt(),
          ),
      ];
    });
    if (grew) {
      Backend.markConversationRead(cid).then((_) => ref.read(conversationsProvider.notifier).refresh());
      _toEnd();
    }
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent + 80);
      });

  /// Envoi avec état visible : « Envoi… », puis disparition si réussi, ou « Échec · réessayer ».
  Future<void> _run(SMsg draft, Future<String?> Function() send) async {
    setState(() => pending.add(draft));
    _toEnd();
    final err = await send();
    if (!mounted) return;
    setState(() => pending.removeWhere((p) => p.id == draft.id));
    if (err == null) {
      GSound.play('pop');
      await _load();
      return;
    }
    final failed = SMsg(id: draft.id, mine: true, time: draft.time, kind: draft.kind, body: draft.body, name: draft.name, status: 'failed', retry: () {
      setState(() => pending.removeWhere((p) => p.id == draft.id));
      _run(draft, send);
    });
    setState(() => pending.add(failed));
    gToast(context, 'Message non envoyé : $err');
    _toEnd();
  }

  void _sendText() {
    final t = c.text.trim();
    final cid = ref.read(selectedConversationProvider);
    if (t.isEmpty || cid.isEmpty) return;
    c.clear();
    setState(() {});
    _run(SMsg(id: 'p${DateTime.now().microsecondsSinceEpoch}', mine: true, time: '', kind: 'text', body: t, status: 'sending'), () => Backend.sendMessage(cid, t));
  }

  void _sendFile(String kind, Uint8List bytes, String name, String mime) {
    final cid = ref.read(selectedConversationProvider);
    if (cid.isEmpty) return;
    if (bytes.length > 10 * 1024 * 1024) {
      gToast(context, 'Fichier trop volumineux (10 Mo maximum).');
      return;
    }
    final label = kind == 'image' ? 'Photo' : (kind == 'voice' ? 'Message vocal' : name);
    _run(SMsg(id: 'p${DateTime.now().microsecondsSinceEpoch}', mine: true, time: '', kind: kind, body: label, name: name, status: 'sending'),
        () => Backend.sendAttachment(cid, kind, bytes, name, mime, label));
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
      if (x == null) return;
      final mime = x.mimeType ?? mimeOf(x.name) ?? 'image/jpeg';
      if (!mime.startsWith('image/')) return gToast(context, 'Format d’image non pris en charge.');
      _sendFile('image', await x.readAsBytes(), x.name, mime);
    } catch (_) {
      if (mounted) gToast(context, src == ImageSource.camera ? 'Appareil photo indisponible sur cet appareil.' : 'Impossible d’ouvrir la galerie.');
    }
  }

  Future<void> _pickFile() async {
    try {
      final r = await FilePicker.pickFiles();
      if (r.isEmpty) return;
      final f = r.first;
      final mime = mimeOf(f.name);
      if (mime == null) return gToast(context, 'Type de fichier non pris en charge (images, PDF, Word, Excel, texte).');
      final bytes = await f.readAsBytes();
      _sendFile(mime.startsWith('image/') ? 'image' : 'file', bytes, f.name, mime);
    } catch (_) {
      if (mounted) gToast(context, 'Impossible d’ouvrir les fichiers.');
    }
  }

  Future<void> _toggleVoice() async {
    if (recording) {
      final path = await rec.stop();
      setState(() => recording = false);
      GSound.play('mic_stop');
      if (path == null) return;
      final secs = DateTime.now().difference(started ?? DateTime.now()).inSeconds;
      try {
        final bytes = await XFile(path).readAsBytes();
        _sendFile('voice', bytes, 'vocal_${secs}s.${kIsWeb ? 'webm' : 'm4a'}', kIsWeb ? 'audio/webm' : 'audio/mp4');
      } catch (_) {
        if (mounted) gToast(context, 'Enregistrement illisible.');
      }
      return;
    }
    try {
      if (!await rec.hasPermission()) {
        if (mounted) gToast(context, 'Autorisez le micro pour enregistrer un message vocal.');
        return;
      }
      await rec.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc), path: 'voice_${DateTime.now().millisecondsSinceEpoch}.${kIsWeb ? 'webm' : 'm4a'}');
      started = DateTime.now();
      GSound.play('mic_start');
      setState(() => recording = true);
    } catch (_) {
      if (mounted) gToast(context, 'Micro indisponible sur cet appareil.');
    }
  }

  void _attachMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF4EFE6),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          for (final (icon, label, act) in <(IconData, String, VoidCallback)>[
            (Icons.photo_library_outlined, 'Photo depuis la galerie', () => _pickImage(ImageSource.gallery)),
            (Icons.photo_camera_outlined, 'Prendre une photo', () => _pickImage(ImageSource.camera)),
            (Icons.attach_file_rounded, 'Joindre un fichier (10 Mo max)', _pickFile),
          ])
            ListTile(
              leading: Icon(icon, color: const Color(0xFF111015)),
              title: Text(label, style: _st(14, w: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                act();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _bubble(SMsg m) {
    final fg = m.mine ? Colors.white : const Color(0xFF111015);
    Widget body;
    switch (m.kind) {
      case 'image':
        body = m.path == null
            ? Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.image_outlined, color: fg, size: 20), const SizedBox(width: 8), Text('Photo', style: _st(12.5, c: fg, w: FontWeight.w600))])
            : FutureBuilder<String?>(
                future: _url(m.path!),
                builder: (_, s) => s.data == null
                    ? SizedBox(width: 200, height: 120, child: Center(child: Text(s.connectionState == ConnectionState.done ? 'Photo indisponible' : 'Chargement…', style: _st(11.5, c: fg))))
                    : GestureDetector(onTap: () => openUrl(context, s.data!), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(s.data!, width: 200, fit: BoxFit.cover, errorBuilder: (_, _, _) => SizedBox(width: 200, height: 80, child: Center(child: Text('Photo indisponible', style: _st(11.5, c: fg))))))),
              );
      case 'file':
        body = GestureDetector(
          onTap: m.path == null ? null : () async {
            final u = await _url(m.path!);
            if (u != null && mounted) openUrl(context, u);
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.insert_drive_file_outlined, color: fg, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(m.name ?? m.body, style: _st(12.5, c: fg, w: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ]),
        );
      case 'voice':
        body = m.path == null ? Text('Message vocal', style: _st(12.5, c: fg)) : _VoiceTile(url: _url(m.path!), fg: fg, label: m.name ?? 'Message vocal');
      default:
        body = Text(m.body, style: _st(12.5, c: fg).copyWith(height: 1.45));
    }
    final sending = m.status == 'sending';
    final failed = m.status == 'failed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: sending ? 0.55 : 1,
        child: Column(crossAxisAlignment: m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Container(
              padding: m.kind == 'image' && m.path != null ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: failed ? const Color(0xFFFDE6E7) : (m.mine ? const Color(0xFF111015) : Colors.white),
                borderRadius: BorderRadius.circular(18),
                boxShadow: m.mine ? null : const [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18)],
              ),
              child: failed ? DefaultTextStyle.merge(style: const TextStyle(color: Color(0xFF111015)), child: body) : body,
            ),
          ),
          const SizedBox(height: 3),
          if (failed)
            GestureDetector(onTap: m.retry, child: Text('Échec de l’envoi · Réessayer', style: _st(10.5, c: const Color(0xFFD64545), w: FontWeight.w600)))
          else
            Text(sending ? 'Envoi…' : m.time, style: _st(10, c: const Color(0xFF8793A5))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cid = ref.watch(selectedConversationProvider);
    if (cid.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(40, 240, 40, 0),
        child: Align(alignment: Alignment.topCenter, child: Text('Choisissez une conversation dans « Messages », ou touchez « Contacter le vendeur » depuis une commande.', textAlign: TextAlign.center, style: _st(13, w: FontWeight.w500, c: const Color(0xFF66636E)).copyWith(height: 1.5))),
      );
    }
    final all = [...msgs, ...pending];
    final hasText = c.text.trim().isNotEmpty;
    return Stack(children: [
      Positioned(
        left: 0,
        top: 190,
        width: 390,
        height: 540,
        child: loading && all.isEmpty
            ? Center(child: Text('Chargement…', style: _st(13, w: FontWeight.w500, c: const Color(0xFF66636E))))
            : all.isEmpty
                ? Center(child: Text('Aucun message pour le moment.', style: _st(13, w: FontWeight.w500, c: const Color(0xFF66636E))))
                : ListView.builder(controller: scroll, padding: const EdgeInsets.fromLTRB(24, 6, 24, 20), itemCount: all.length, itemBuilder: (_, i) => _bubble(all[i])),
      ),
      if (recording)
        Positioned(
          left: 24,
          top: 716,
          width: 342,
          child: Text('● Enregistrement… touchez le micro pour envoyer', style: _st(12, c: const Color(0xFFD64545), w: FontWeight.w600)),
        ),
      Positioned(
        left: 24,
        top: 748,
        width: 342,
        height: 56,
        child: Row(children: [
          GestureDetector(
            onTap: _attachMenu,
            child: Container(width: 38, height: 38, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFF1EEFB), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF111015))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              style: _st(13),
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendText(),
              cursorColor: const Color(0xFF6A4DFF),
              decoration: InputDecoration(isCollapsed: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: 'Écrire un message…', hintStyle: _st(13, c: const Color(0xFF66636E))),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: hasText ? _sendText : _toggleVoice,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: recording ? const Color(0xFFD64545) : const Color(0xFF111015), shape: BoxShape.circle),
              child: Icon(hasText ? Icons.arrow_upward_rounded : (recording ? Icons.stop_rounded : Icons.mic_none_rounded), size: 20, color: Colors.white),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _VoiceTile extends StatefulWidget {
  const _VoiceTile({required this.url, required this.fg, required this.label});
  final Future<String?> url;
  final Color fg;
  final String label;
  @override
  State<_VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends State<_VoiceTile> {
  AudioPlayer? _p;
  bool playing = false;

  @override
  void dispose() {
    _p?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final p = _p ??= AudioPlayer()..onPlayerComplete.listen((_) => mounted ? setState(() => playing = false) : null);
    if (playing) {
      await p.pause();
      setState(() => playing = false);
      return;
    }
    final u = await widget.url;
    if (u == null) {
      if (mounted) gToast(context, 'Message vocal indisponible.');
      return;
    }
    await p.play(UrlSource(u));
    if (mounted) setState(() => playing = true);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _toggle,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: widget.fg, size: 28),
          const SizedBox(width: 8),
          Text('Message vocal', style: _st(12.5, c: widget.fg, w: FontWeight.w600)),
        ]),
      );
}
