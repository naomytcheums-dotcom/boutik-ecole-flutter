import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speech_to_text/speech_to_text.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart';
import '../nav.dart';
import 'backend.dart';

/// Assistante Kéla : l'orbe tourne quand elle écoute ou réfléchit, puis s'arrête dès qu'elle a répondu.
enum KelaPhase { idle, listening, thinking, answered }

/// Texte reconnu à la voix, affiché en direct pendant que l'utilisateur parle.
class KelaText extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final kelaTextProvider = NotifierProvider<KelaText, String>(KelaText.new);
/// Réponse de l'IA à ce que la personne vient de dire : en attente, texte, et brouillon de besoin éventuel.
class KelaReply {
  const KelaReply({this.busy = false, this.text = '', this.brief});
  final bool busy;
  final String text;
  final Map<String, dynamic>? brief;
}

class KelaReplyNotifier extends Notifier<KelaReply> {
  @override
  KelaReply build() => const KelaReply();
  void set(KelaReply v) => state = v;
}

final kelaReplyProvider = NotifierProvider<KelaReplyNotifier, KelaReply>(KelaReplyNotifier.new);

/// Envoie le texte reconnu à l'IA et mémorise sa réponse. Sans clé d'IA côté serveur, Kéla le dit : aucune réponse n'est inventée.
Future<void> kelaAsk(WidgetRef ref, String said) async {
  final reply = ref.read(kelaReplyProvider.notifier);
  if (!Backend.ready || said.trim().length < 2) return;
  reply.set(const KelaReply(busy: true));
  try {
    final r = await Supabase.instance.client.functions.invoke('kela-chat', body: {'message': said.trim(), 'history': const []});
    final d = r.data;
    reply.set(KelaReply(text: d is Map && d['reply'] is String ? d['reply'] as String : 'Kéla n’a pas pu répondre pour le moment.', brief: d is Map && d['brief'] is Map ? Map<String, dynamic>.from(d['brief'] as Map) : null));
  } on FunctionException catch (e) {
    final d = e.details;
    reply.set(KelaReply(text: d is Map && d['message'] is String ? d['message'] as String : 'Kéla est momentanément indisponible.'));
  } catch (_) {
    reply.set(const KelaReply(text: 'Kéla est momentanément indisponible. Vérifiez votre connexion.'));
  }
}

/// Crée un brouillon de besoin à partir du brief proposé par l'IA, ou à défaut de ce qui a été dit.
Future<void> kelaCreateDraft(BuildContext context, WidgetRef ref) async {
  final said = ref.read(kelaTextProvider).trim();
  final b = ref.read(kelaReplyProvider).brief;
  if (said.isEmpty && b == null) {
    gToast(context, 'Parlez d’abord à Kéla pour décrire votre besoin.');
    return;
  }
  final budget = (b?['budget'] as num?)?.toInt();
  final title = '${b?['title'] ?? (said.length > 60 ? said.substring(0, 60) : said)}';
  final r = await Backend.rpc('save_mission', {'p_id': null, 'p_title': title, 'p_description': '${b?['description'] ?? said}', 'p_budget_min': budget, 'p_budget_max': budget, 'p_deadline': null, 'p_publish': false, 'p_kind': 'besoin'});
  if (!context.mounted) return;
  gToast(context, r.error != null ? Backend.userMessage(r.error!) : 'Brouillon de besoin créé. Retrouvez-le dans vos besoins pour le publier.');
}

final _speech = SpeechToText();
bool _speechReady = false;

class KelaNotifier extends Notifier<KelaPhase> {
  Timer? _t;
  @override
  KelaPhase build() {
    ref.onDispose(() => _t?.cancel());
    return KelaPhase.idle;
  }

  void toggle(bool listening) {
    _t?.cancel();
    if (listening) {
      state = KelaPhase.listening;
      return;
    }
    state = KelaPhase.thinking;
    _t = Timer(const Duration(milliseconds: 2200), () => state = KelaPhase.answered);
  }
}

final kelaProvider = NotifierProvider<KelaNotifier, KelaPhase>(KelaNotifier.new);

/// Micro de Kéla : transcription vocale réelle (reconnaissance du système), puis ouverture du fil de discussion.
Future<void> kelaToggle(WidgetRef ref, bool listening, BuildContext context) async {
  final n = ref.read(kelaProvider.notifier);
  final text = ref.read(kelaTextProvider.notifier);
  if (listening) {
    text.set('');
    n.toggle(true);
    try {
      _speechReady = _speechReady || await _speech.initialize(onError: (_) {});
      if (!_speechReady) {
        if (context.mounted) gToast(context, 'Reconnaissance vocale indisponible : utilisez Chrome ou autorisez le micro.');
        return;
      }
      await _speech.listen(onResult: (r) => text.set(r.recognizedWords), listenOptions: SpeechListenOptions(partialResults: true, localeId: 'fr_FR'));
    } catch (_) {
      if (context.mounted) gToast(context, 'Micro indisponible sur cet appareil.');
    }
    return;
  }
  try {
    await _speech.stop();
  } catch (_) {}
  n.toggle(false);
  if (ref.read(kelaTextProvider).trim().isEmpty) return;
  unawaited(kelaAsk(ref, ref.read(kelaTextProvider)));
  await Future<void>.delayed(const Duration(milliseconds: 2400));
  if (context.mounted) gOpen(context, '232');
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
