import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speech_to_text/speech_to_text.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart';
import '../i18n.dart' show Text;
import '../nav.dart';
import 'auth.dart' show authProvider, requireLogin;
import 'backend.dart';
import 'lots.dart' show myNeedsDialog;

/// Assistante Kéla : l'orbe tourne quand elle écoute ou réfléchit, puis s'arrête dès qu'elle a répondu.
enum KelaPhase { idle, listening, thinking, answered }

/// Texte reconnu à la voix, affiché en direct pendant que l'utilisateur parle.
class KelaText extends Notifier<String> {
  @override
  String build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return '';
  }
  void set(String v) => state = v;
  String get current => state;
}

final kelaTextProvider = NotifierProvider<KelaText, String>(KelaText.new);
/// Dernière réponse de l'IA : en attente, texte, et brouillon de besoin éventuel.
class KelaReply {
  const KelaReply({this.busy = false, this.text = '', this.brief});
  final bool busy;
  final String text;
  final Map<String, dynamic>? brief;
}

class KelaReplyNotifier extends Notifier<KelaReply> {
  @override
  KelaReply build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return const KelaReply();
  }
  void set(KelaReply v) => state = v;
}

final kelaReplyProvider = NotifierProvider<KelaReplyNotifier, KelaReply>(KelaReplyNotifier.new);

/// Un message du fil de discussion avec Kéla. [failed] : message sans réponse ou erreur, jamais renvoyé à l'IA comme historique.
class KelaMessage {
  const KelaMessage({required this.mine, required this.text, this.failed = false});
  final bool mine, failed;
  final String text;
}

class KelaThreadState {
  const KelaThreadState({this.messages = const [], this.busy = false});
  final List<KelaMessage> messages;
  final bool busy;

  /// Ce que la personne a dit à Kéla (échanges réussis), du plus ancien au plus récent.
  List<String> get said => [for (final m in messages) if (m.mine && !m.failed) m.text];
}

const kelaNotConfigured = 'Kéla n’est pas encore activée sur ce serveur : la clé de l’intelligence artificielle n’est pas configurée. Aucune réponse n’est inventée. En attendant, vous pouvez déposer votre besoin vous-même (« Déposer un besoin »).';

String _kelaFailure(FunctionException e) {
  final d = e.details;
  final server = d is Map && d['message'] is String ? d['message'] as String : '';
  if (e.status == 503) return kelaNotConfigured;
  if (e.status == 401) return 'Votre session a expiré. Reconnectez-vous pour parler à Kéla.';
  if (e.status == 429) return server.isNotEmpty ? server : 'Vous avez atteint la limite de messages par heure. Réessayez plus tard.';
  return server.isNotEmpty ? server : 'Kéla est momentanément indisponible. Réessayez dans un instant.';
}

/// Kéla est-elle activée sur le serveur ? `false` : la clé de l'IA manque (le serveur répond 503) ; `true` : activée ou état inconnu
/// (panne réseau : on laisse essayer, l'échec sera annoncé tel quel). Aucune réponse n'est jamais simulée.
final kelaAvailableProvider = FutureProvider<bool>((ref) async {
  if (!Backend.ready) return true;
  try {
    await Supabase.instance.client.functions.invoke('kela-chat', body: {'status': true});
    return true;
  } on FunctionException catch (e) {
    return e.status != 503;
  } catch (_) {
    return true;
  }
});

/// Fil de conversation avec Kéla : l'historique est gardé pour la session et renvoyé à chaque message pour que Kéla s'en souvienne.
class KelaThread extends Notifier<KelaThreadState> {
  @override
  KelaThreadState build() {
    ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    return const KelaThreadState();
  }

  Future<void> send(String raw) async {
    final said = raw.trim();
    if (!Backend.ready || said.length < 2 || state.busy) return;
    final past = [for (final m in state.messages) if (!m.failed) {'role': m.mine ? 'user' : 'assistant', 'content': m.text}];
    final history = past.length > 8 ? past.sublist(past.length - 8) : past;
    final mine = KelaMessage(mine: true, text: said);
    state = KelaThreadState(messages: [...state.messages, mine], busy: true);
    ref.read(kelaTextProvider.notifier).set(said);
    ref.read(kelaReplyProvider.notifier).set(const KelaReply(busy: true));
    String? answer;
    Map<String, dynamic>? brief;
    var failed = false;
    try {
      final r = await Supabase.instance.client.functions.invoke('kela-chat', body: {'message': said, 'history': history});
      final d = r.data;
      if (d is Map && d['reply'] is String && (d['reply'] as String).trim().isNotEmpty) {
        answer = d['reply'] as String;
        brief = d['brief'] is Map ? Map<String, dynamic>.from(d['brief'] as Map) : null;
      } else {
        answer = 'Kéla n’a pas pu répondre pour le moment. Réessayez.';
        failed = true;
      }
    } on FunctionException catch (e) {
      answer = _kelaFailure(e);
      failed = true;
    } catch (_) {
      answer = 'Kéla est momentanément indisponible. Vérifiez votre connexion puis réessayez.';
      failed = true;
    }
    if (!ref.mounted) return;
    final msgs = [...state.messages];
    if (failed) msgs[msgs.lastIndexOf(mine)] = KelaMessage(mine: true, text: said, failed: true);
    state = KelaThreadState(messages: [...msgs, KelaMessage(mine: false, text: answer, failed: failed)]);
    ref.read(kelaReplyProvider.notifier).set(KelaReply(text: answer, brief: brief));
  }
}

final kelaThreadProvider = NotifierProvider<KelaThread, KelaThreadState>(KelaThread.new);

/// Envoie un message à Kéla (texte écrit ou dicté).
Future<void> kelaAsk(WidgetRef ref, String said) => ref.read(kelaThreadProvider.notifier).send(said);

/// Crée un brouillon de besoin à partir du brief proposé par l'IA, ou à défaut de ce qui a été dit dans la conversation.
Future<void> kelaCreateDraft(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'créer un brouillon') || !context.mounted) return;
  final said = ref.read(kelaThreadProvider).said;
  final b = ref.read(kelaReplyProvider).brief;
  final all = said.join('\n').trim();
  if (all.isEmpty && b == null) {
    gToast(context, 'Parlez d’abord à Kéla pour décrire votre besoin.');
    return;
  }
  final first = said.isEmpty ? '' : said.first.trim();
  var title = '${b?['title'] ?? (first.length > 60 ? first.substring(0, 60) : first)}'.trim();
  if (title.length > 120) title = title.substring(0, 120);
  if (title.length < 3) {
    gToast(context, 'Décrivez votre besoin en quelques mots (3 caractères au moins) pour créer le brouillon.');
    return;
  }
  var description = '${b?['description'] ?? all}'.trim();
  if (description.length > 4000) description = description.substring(0, 4000);
  final budget = (b?['budget'] as num?)?.toInt();
  final r = await Backend.rpc('save_mission', {'p_id': null, 'p_title': title, 'p_description': description, 'p_budget_min': budget, 'p_budget_max': budget, 'p_deadline': null, 'p_publish': false, 'p_kind': 'besoin'});
  if (!context.mounted) return;
  if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
  gToast(context, 'Brouillon de besoin créé : « $title ».');
  await myNeedsDialog(context, ref);
}

final _speech = SpeechToText();
bool _speechReady = false;
void Function()? _speechEnded;

class KelaNotifier extends Notifier<KelaPhase> {
  @override
  KelaPhase build() => KelaPhase.idle;

  bool get listening => state == KelaPhase.listening;
  void start() => state = KelaPhase.listening;
  void thinking() => state = KelaPhase.thinking;
  void answered() => state = KelaPhase.answered;
  void reset() => state = KelaPhase.idle;
}

final kelaProvider = NotifierProvider<KelaNotifier, KelaPhase>(KelaNotifier.new);

/// Libellé d'état affiché sous le titre de l'écran d'écoute.
String kelaStatusLabel(KelaPhase p) => switch (p) {
      KelaPhase.listening => 'À l’écoute…',
      KelaPhase.thinking => 'Kéla réfléchit…',
      KelaPhase.answered => 'Réponse prête',
      KelaPhase.idle => 'Touchez le micro',
    };

const _noSpeech = 'La reconnaissance vocale n’est pas disponible sur cet appareil ou le micro n’est pas autorisé. Écrivez votre message à Kéla.';

/// Fin de l'écoute (appui sur le micro, silence ou erreur de la reconnaissance) : le texte reconnu part chez Kéla ; l'écran de discussion s'ouvre tout de suite.
Future<void> _kelaFinish(KelaNotifier n, KelaText text, KelaThread thread, BuildContext context, bool openThread) async {
  if (!n.listening) return;
  n.thinking();
  _speechEnded = null;
  try {
    await _speech.stop();
  } catch (_) {}
  final said = text.current.trim();
  if (said.length < 2) {
    n.reset();
    if (context.mounted) gToast(context, 'Je n’ai rien entendu : touchez le micro et parlez, ou écrivez votre message.');
    return;
  }
  if (openThread && context.mounted) gOpen(context, '232');
  await thread.send(said);
  n.answered();
}

/// Micro de Kéla : transcription vocale réelle (reconnaissance du système). Sans reconnaissance vocale, le clavier prend le relais.
Future<void> kelaToggle(WidgetRef ref, bool listening, BuildContext context, {bool openThread = true}) async {
  final n = ref.read(kelaProvider.notifier);
  final text = ref.read(kelaTextProvider.notifier);
  final thread = ref.read(kelaThreadProvider.notifier);
  if (!listening) return _kelaFinish(n, text, thread, context, openThread);
  if (n.listening) return;
  if (!await requireLogin(context, ref, 'parler à Kéla') || !context.mounted) return;
  if (!await ref.read(kelaAvailableProvider.future) || !context.mounted) {
    if (context.mounted) {
      gToast(context, kelaNotConfigured);
      if (openThread) gOpen(context, '232');
    }
    return;
  }
  text.set('');
  n.start();
  _speechEnded = () => unawaited(_kelaFinish(n, text, thread, context, openThread));
  try {
    _speechReady = _speechReady || await _speech.initialize(onError: (_) => _speechEnded?.call(), onStatus: (s) {
      if (s == 'done' || s == 'notListening') _speechEnded?.call();
    });
    if (!_speechReady) throw StateError('speech');
    await _speech.listen(onResult: (r) => text.set(r.recognizedWords), listenOptions: SpeechListenOptions(partialResults: true, localeId: 'fr_FR'));
  } catch (_) {
    _speechEnded = null;
    n.reset();
    if (!context.mounted) return;
    gToast(context, _noSpeech);
    if (openThread) gOpen(context, '232');
  }
}

/// Micro de Kéla dont l'état suit l'écoute réelle (un échec de la reconnaissance le désactive).
Widget kelaMic(BuildContext context, {required Widget child, bool openThread = true}) => Consumer(
      builder: (context, ref, _) => GMic(
        active: ref.watch(kelaProvider.select((p) => p == KelaPhase.listening)),
        onResult: (on) => kelaToggle(ref, on, context, openThread: openThread),
        child: child,
      ),
    );

/// Texte reconnu en direct sur l'écran d'écoute ; invitation à parler tant que rien n'a été dit.
Widget kelaHeardText({double size = 26, double lh = 34, int maxLines = 4}) => Consumer(
      builder: (context, ref, _) {
        final t = ref.watch(kelaTextProvider);
        return gText(t.isEmpty ? 'Touche le micro et parle…' : t, size, const Color(0xFF111015), weight: 500, lh: lh, wrap: true, maxLines: maxLines);
      },
    );

/// Libellé d'état de l'écran d'écoute (à l'écoute, réflexion, réponse prête).
Widget kelaStatusText() => Consumer(builder: (context, ref, _) => gText(kelaStatusLabel(ref.watch(kelaProvider)), 12.5, const Color(0xFF57545F), align: TextAlign.center));

/// Fil de discussion écrit et dicté avec Kéla (écrans 232 et A3) : messages, saisie au clavier, envoi, micro et création du brouillon.
class KelaThreadPanel extends ConsumerStatefulWidget {
  const KelaThreadPanel({super.key});
  @override
  ConsumerState<KelaThreadPanel> createState() => _KelaThreadPanelState();
}

class _KelaThreadPanelState extends ConsumerState<KelaThreadPanel> {
  final _field = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _field.text.trim();
    if (t.length < 2 || ref.read(kelaThreadProvider).busy) return;
    if (!await requireLogin(context, ref, 'écrire à Kéla') || !mounted) return;
    if (!await ref.read(kelaAvailableProvider.future) || !mounted) {
      if (mounted) gToast(context, kelaNotConfigured);
      return;
    }
    _field.clear();
    setState(() {});
    await ref.read(kelaThreadProvider.notifier).send(t);
  }

  static const _ink = Color(0xFF111015);
  static TextStyle _st(double s, {Color c = _ink, FontWeight w = FontWeight.w500}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: s, height: 1.45, color: c, fontWeight: w);

  Widget _bubble(String text, {required bool mine, bool failed = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              const SizedBox(width: 32, height: 32, child: Image(image: AssetImage('assets/figma/img/2b51b5d6469cca917952ac344a2ddf9cc1440830.png'), fit: BoxFit.contain)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 270),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: mine ? _ink : const Color(0xB3FFFFFF),
                  borderRadius: BorderRadius.circular(18),
                  border: mine ? null : Border.all(color: failed ? const Color(0xFFE5484D) : Colors.white, width: 1.2),
                ),
                child: SelectableText(text, style: _st(13, c: mine ? Colors.white : (failed ? const Color(0xFFB3261E) : _ink))),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(kelaThreadProvider);
    final phase = ref.watch(kelaProvider);
    final heard = ref.watch(kelaTextProvider);
    final canDraft = t.said.isNotEmpty || ref.watch(kelaReplyProvider.select((r) => r.brief != null));
    ref.listen(kelaThreadProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      });
    });
    final hasText = _field.text.trim().length >= 2;
    final available = ref.watch(kelaAvailableProvider).value ?? true;
    return Column(children: [
      if (!available)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0x33F5A524), borderRadius: BorderRadius.circular(14)),
          child: Text(kelaNotConfigured, style: _st(12, c: const Color(0xFF7A4B00))),
        ),
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
          children: [
            _bubble(available ? 'Décris-moi ton besoin : ce que tu veux, ton style et ton budget. Je prépare le brief.' : 'Kéla n’est pas encore disponible.', mine: false),
            for (final m in t.messages) _bubble(m.text, mine: m.mine, failed: m.failed),
            if (phase == KelaPhase.listening) _bubble(heard.isEmpty ? 'Je t’écoute…' : heard, mine: true),
            if (t.busy) _bubble('Kéla réfléchit…', mine: false),
          ],
        ),
      ),
      if (canDraft)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => kelaCreateDraft(context, ref),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(23)),
                child: Text('Crée la mission pour moi', style: _st(12.5, c: Colors.white)),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
          decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(31), border: Border.all(color: Colors.white, width: 1.5)),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _field,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _send(),
                style: _st(13),
                cursorColor: const Color(0xFF6A4DFF),
                decoration: InputDecoration(isCollapsed: true, border: InputBorder.none, hintText: available ? 'Écris ou parle à Kéla…' : 'Kéla n’est pas encore activée', hintStyle: _st(13, c: const Color(0xFF57545F), w: FontWeight.w400)),
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: 'Envoyer le message',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasText && !t.busy && available ? _send : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: hasText && !t.busy && available ? _ink : const Color(0x33111015)),
                  child: const Icon(Icons.arrow_upward_rounded, size: 22, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              height: 44,
              child: Semantics(
                button: true,
                label: 'Dicter à Kéla',
                child: kelaMic(context, openThread: false, child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.fromBorderSide(BorderSide(color: Color(0xFFE6E1EE)))), child: const Icon(Icons.mic_none_rounded, size: 22, color: _ink))),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Même signature que gBox pour l'image de l'orbe, avec rotation pilotée par l'état de Kéla.
Widget kelaOrb({String? image, BoxFit fit = BoxFit.contain, List<BoxShadow>? shadows}) => Consumer(
      builder: (context, ref, _) => _Spin(
        spinning: ref.watch(kelaProvider) == KelaPhase.listening || ref.watch(kelaProvider) == KelaPhase.thinking,
        child: gBox(image: image, fit: fit, shadows: shadows),
      ),
    );

class _Spin extends StatefulWidget {
  const _Spin({required this.spinning, required this.child});
  final bool spinning;
  final Widget child;
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Spin old) {
    super.didUpdateWidget(old);
    if (old.spinning != widget.spinning) _sync();
  }

  void _sync() {
    if (!GAnim.enabled) return;
    if (widget.spinning) {
      c.repeat();
    } else {
      // Ralentit et s'arrête en douceur à la fin du tour en cours.
      c.animateTo(1, duration: Duration(milliseconds: ((1 - c.value) * 3200 * 1.4).round().clamp(1, 4500)), curve: Curves.easeOutCubic).whenComplete(() {
        if (mounted) c.value = 0;
      });
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: c, child: widget.child);
}
