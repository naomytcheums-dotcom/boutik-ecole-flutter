import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'dart:async';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'messages.dart';

/// Messagerie : envoi de texte, photo, fichier et message vocal (enregistrement réel).

enum ChatKind { text, image, file, voice }

class ChatMsg {
  const ChatMsg(this.text, this.mine, this.time, {this.kind = ChatKind.text, this.bytes, this.url});
  final String text, time;
  final bool mine;
  final ChatKind kind;
  final Uint8List? bytes;
  final String? url; // enregistrement vocal
}

String _now() {
  final d = DateTime.now();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class ChatStore extends Notifier<Map<String, List<ChatMsg>>> {
  @override
  Map<String, List<ChatMsg>> build() => const {};

  List<ChatMsg> of(String thread, List<ChatMsg> seed) => state[thread] ?? seed;

  void add(String thread, List<ChatMsg> seed, ChatMsg m) => state = {...state, thread: [...of(thread, seed), m]};
}

final chatProvider = NotifierProvider<ChatStore, Map<String, List<ChatMsg>>>(ChatStore.new);

const _f = 'PlusJakartaSans';
TextStyle _st(double s, {FontWeight w = FontWeight.w400, Color c = const Color(0xFF111015)}) =>
    TextStyle(inherit: false, fontFamily: _f, fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

/// Fil de discussion + barre de saisie, placés aux coordonnées de la maquette (écrans 53 et 54).
Widget chatPanel(String thread, List<ChatMsg> seed) => Positioned.fill(child: _ChatPanel(thread: thread, seed: seed));

class _ChatPanel extends ConsumerStatefulWidget {
  const _ChatPanel({required this.thread, required this.seed});
  final String thread;
  final List<ChatMsg> seed;
  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  final c = TextEditingController();
  final f = FocusNode();
  final scroll = ScrollController();
  AudioRecorder? _rec;
  AudioRecorder get rec => _rec ??= AudioRecorder();
  bool recording = false;
  DateTime? started;

  @override
  void dispose() {
    c.dispose();
    f.dispose();
    scroll.dispose();
    _rec?.dispose();
    super.dispose();
  }

  void _add(ChatMsg m) {
    ref.read(chatProvider.notifier).add(widget.thread, widget.seed, m);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    });
  }

  void _send() {
    final t = c.text.trim();
    if (t.isEmpty) return;
    _add(ChatMsg(t, true, _now()));
    c.clear();
    setState(() {});
    GSound.play('pop');
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
      if (x == null) return;
      _add(ChatMsg(x.name, true, _now(), kind: ChatKind.image, bytes: await x.readAsBytes()));
    } catch (_) {
      if (mounted) gToast(context, src == ImageSource.camera ? 'Appareil photo indisponible sur cet appareil.' : 'Impossible d’ouvrir la galerie.');
    }
  }

  Future<void> _pickFile() async {
    try {
      final r = await FilePicker.pickFiles();
      if (r.isEmpty) return;
      _add(ChatMsg(r.first.name, true, _now(), kind: ChatKind.file));
    } catch (_) {
      if (mounted) gToast(context, 'Impossible d’ouvrir les fichiers.');
    }
  }

  Future<void> _toggleVoice() async {
    if (recording) {
      final path = await rec.stop();
      final secs = DateTime.now().difference(started ?? DateTime.now()).inSeconds;
      setState(() => recording = false);
      GSound.play('mic_stop');
      if (path != null) _add(ChatMsg('Message vocal · 0:${secs.toString().padLeft(2, '0')}', true, _now(), kind: ChatKind.voice, url: path));
      return;
    }
    try {
      if (!await rec.hasPermission()) {
        if (mounted) gToast(context, 'Autorisez le micro pour enregistrer un message vocal.');
        return;
      }
      await rec.start(const RecordConfig(), path: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
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
            (Icons.attach_file_rounded, 'Joindre un fichier', _pickFile),
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

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider)[widget.thread] ?? widget.seed;
    final hasText = c.text.trim().isNotEmpty;
    return Stack(children: [
      Positioned(
        left: 0,
        top: 190,
        width: 390,
        height: 540,
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
          itemCount: msgs.length,
          itemBuilder: (_, i) => _Bubble(m: msgs[i]),
        ),
      ),
      if (recording)
        Positioned(
          left: 24,
          top: 716,
          width: 342,
          child: Row(children: [
            const _Dot(),
            const SizedBox(width: 8),
            Text('Enregistrement… touchez le micro pour envoyer', style: _st(12, c: const Color(0xFFD64545), w: FontWeight.w600)),
          ]),
        ),
      // barre de saisie : le texte repose directement sur le fond
      Positioned(
        left: 24,
        top: 748,
        width: 342,
        height: 56,
        child: Row(children: [
          GestureDetector(
            onTap: _attachMenu,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFFF1EEFB), shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF111015)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: c,
              focusNode: f,
              style: _st(13),
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _send(),
              cursorColor: const Color(0xFF6A4DFF),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Écrire un message…',
                hintStyle: _st(13, c: const Color(0xFF66636E)),
              ),
            ),
          ),
          if (!hasText)
            GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.photo_camera_outlined, size: 24, color: Color(0xFF111015))),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: hasText ? _send : _toggleVoice,
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

class _Dot extends StatefulWidget {
  const _Dot();
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: c, child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFD64545), shape: BoxShape.circle)));
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});
  final ChatMsg m;

  @override
  Widget build(BuildContext context) {
    final mine = m.mine;
    final fg = mine ? Colors.white : const Color(0xFF111015);
    Widget body;
    switch (m.kind) {
      case ChatKind.image:
        body = ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(m.bytes!, width: 200, fit: BoxFit.cover));
      case ChatKind.file:
        body = Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insert_drive_file_outlined, color: fg, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(m.text, style: _st(12.5, c: fg, w: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]);
      case ChatKind.voice:
        body = _VoiceBubble(m: m, fg: fg);
      case ChatKind.text:
        body = Text(m.text, style: _st(12.5, c: fg).copyWith(height: 1.45));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Container(
            padding: m.kind == ChatKind.image ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF111015) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: mine ? null : const [BoxShadow(color: Color(0x12403366), offset: Offset(0, 6), blurRadius: 18)],
            ),
            child: body,
          ),
        ),
        const SizedBox(height: 3),
        Text(m.time, style: _st(10, c: const Color(0xFF8793A5))),
      ]),
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({required this.m, required this.fg});
  final ChatMsg m;
  final Color fg;
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final p = AudioPlayer();
  bool playing = false;
  @override
  void initState() {
    super.initState();
    p.onPlayerComplete.listen((_) => mounted ? setState(() => playing = false) : null);
  }

  @override
  void dispose() {
    p.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (playing) {
      await p.stop();
      setState(() => playing = false);
      return;
    }
    try {
      await p.play(kIsWebUrl(widget.m.url!) ? UrlSource(widget.m.url!) : DeviceFileSource(widget.m.url!));
      setState(() => playing = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _toggle,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: widget.fg, size: 30),
          const SizedBox(width: 8),
          Text(widget.m.text, style: _st(12.5, c: widget.fg, w: FontWeight.w600)),
        ]),
      );
}

bool kIsWebUrl(String u) => u.startsWith('blob:') || u.startsWith('http');


/// Panneau de conversation : réel (serveur) quand l'application est connectée, sinon la conversation d'exemple de la maquette.
Widget chatPanelAuto(String thread, List<ChatMsg> seed, {bool order = false}) =>
    demoContent ? chatPanel(thread, seed) : Positioned.fill(child: order ? const _OrderChatNotice() : const _ServerChatPanel());

class _OrderChatNotice extends StatelessWidget {
  const _OrderChatNotice();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(40, 240, 40, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text('Les échanges liés à une commande passent par la messagerie du vendeur : ouvrez « Messages » ou touchez « Contacter le vendeur ».', textAlign: TextAlign.center, style: _st(13, w: FontWeight.w500, c: const Color(0xFF66636E)).copyWith(height: 1.5)),
        ),
      );
}

class _ServerChatPanel extends ConsumerStatefulWidget {
  const _ServerChatPanel();
  @override
  ConsumerState<_ServerChatPanel> createState() => _ServerChatPanelState();
}

class _ServerChatPanelState extends ConsumerState<_ServerChatPanel> {
  final c = TextEditingController();
  final scroll = ScrollController();
  List<ChatMsg> msgs = const [];
  Timer? _poll;
  String _cid = '';
  bool sending = false;

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
    super.dispose();
  }

  String _time(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final cid = ref.read(selectedConversationProvider);
    if (cid.isEmpty) return;
    final rows = await Backend.messages(cid);
    if (!mounted) return;
    final me = Backend.currentUserId;
    final grew = rows.length != msgs.length || cid != _cid;
    setState(() {
      _cid = cid;
      msgs = [for (final r in rows) ChatMsg((r['body'] ?? '').toString(), r['sender_id'] == me, _time((r['created_at'] ?? '').toString()))];
    });
    if (grew) {
      Backend.markConversationRead(cid).then((_) => ref.read(conversationsProvider.notifier).refresh());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _send() async {
    final t = c.text.trim();
    final cid = ref.read(selectedConversationProvider);
    if (t.isEmpty || cid.isEmpty || sending) return;
    setState(() => sending = true);
    final err = await Backend.sendMessage(cid, t);
    if (!mounted) return;
    setState(() => sending = false);
    if (err != null) {
      gToast(context, 'Message non envoyé : $err');
      return;
    }
    c.clear();
    GSound.play('pop');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cid = ref.watch(selectedConversationProvider);
    if (cid.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(40, 240, 40, 0),
        child: Align(alignment: Alignment.topCenter, child: Text('Choisissez une conversation dans « Messages ».', textAlign: TextAlign.center, style: _st(13, w: FontWeight.w500, c: const Color(0xFF66636E)))),
      );
    }
    return Stack(children: [
      Positioned(
        left: 0,
        top: 190,
        width: 390,
        height: 540,
        child: msgs.isEmpty
            ? Center(child: Text('Aucun message pour le moment.', style: _st(13, w: FontWeight.w500, c: const Color(0xFF66636E))))
            : ListView.builder(controller: scroll, padding: const EdgeInsets.fromLTRB(24, 6, 24, 20), itemCount: msgs.length, itemBuilder: (_, i) => _Bubble(m: msgs[i])),
      ),
      Positioned(
        left: 24,
        top: 748,
        width: 342,
        height: 56,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: c,
              style: _st(13),
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              cursorColor: const Color(0xFF6A4DFF),
              decoration: InputDecoration(isCollapsed: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: 'Écrire un message…', hintStyle: _st(13, c: const Color(0xFF66636E))),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFF111015), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
            ),
          ),
        ]),
      ),
    ]);
  }
}
