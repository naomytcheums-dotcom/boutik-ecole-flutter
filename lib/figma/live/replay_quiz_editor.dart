import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart' show Text;
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'replays.dart' show ReplayException, replayCall;

/// Quiz facultatif d'un replay côté hôte, co-hôte approuvé et administration (migration 20261128021000).
/// Le serveur est seul juge : droits (replay_quiz_can_edit), validation (replay_quiz_set) et correction ; les bonnes réponses ne quittent le serveur que pour ces éditeurs.
/// Badge « J'ai suivi » et certificat : complétion réelle du replay ET quiz réussi (si un quiz existe).

const kQuizMaxQuestions = 20, kQuizMinOptions = 2, kQuizMaxOptions = 6, kQuizMaxStatement = 300, kQuizMaxOption = 200;

/// Brouillon d'une question (énoncé, options, index de la bonne réponse).
class QuizQuestionDraft {
  QuizQuestionDraft({String statement = '', List<String>? options, this.correct}) : statement = TextEditingController(text: statement), options = [for (final o in options ?? const ['', '']) TextEditingController(text: o)];
  final TextEditingController statement;
  final List<TextEditingController> options;
  int? correct;

  void dispose() {
    statement.dispose();
    for (final o in options) {
      o.dispose();
    }
  }

  Map<String, dynamic> toJson() => {'q': statement.text.trim(), 'options': [for (final o in options) o.text.trim()], 'correct': correct};
}

/// Même contrôle que le serveur (qui reste décisif) : message lisible ou null si le quiz peut être envoyé.
String? validateReplayQuiz(List<QuizQuestionDraft> questions, int passPct) {
  if (passPct < 50 || passPct > 100) return 'Le seuil de réussite est compris entre 50 % et 100 %.';
  if (questions.isEmpty) return 'Ajoutez au moins une question.';
  if (questions.length > kQuizMaxQuestions) return 'Un quiz comporte $kQuizMaxQuestions questions au plus.';
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i], n = i + 1;
    final s = q.statement.text.trim();
    if (s.isEmpty) return 'Question $n : écrivez l’énoncé.';
    if (s.length > kQuizMaxStatement) return 'Question $n : énoncé de $kQuizMaxStatement caractères au plus.';
    if (q.options.length < kQuizMinOptions) return 'Question $n : au moins $kQuizMinOptions options.';
    final seen = <String>{};
    for (final o in q.options) {
      final t = o.text.trim();
      if (t.isEmpty) return 'Question $n : une option est vide (supprimez-la ou remplissez-la).';
      if (t.length > kQuizMaxOption) return 'Question $n : option de $kQuizMaxOption caractères au plus.';
      if (!seen.add(t.toLowerCase())) return 'Question $n : deux options sont identiques.';
    }
    if (q.correct == null || q.correct! < 0 || q.correct! >= q.options.length) return 'Question $n : choisissez la bonne réponse.';
  }
  return null;
}

final replayQuizCanEditProvider = FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  if (!(Backend.ready && Backend.currentUserId != null)) return false;
  try {
    return await replayCall('replay_quiz_can_edit', {'p_recording': id}) == true;
  } catch (_) {
    return false;
  }
}, retry: (_, _) => null);

final replayQuizHostProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await replayCall('replay_quiz_get_host', {'p_recording': id});
  return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
}, retry: (_, _) => null);

class ReplayQuizEditorScreen extends StatelessWidget {
  const ReplayQuizEditorScreen({super.key, required this.recordingId});
  final String recordingId;

  @override
  Widget build(BuildContext context) => MarchePage(title: 'Quiz du replay', child: ReplayQuizEditor(recordingId: recordingId));
}

class ReplayQuizEditor extends ConsumerStatefulWidget {
  const ReplayQuizEditor({super.key, required this.recordingId});
  final String recordingId;

  @override
  ConsumerState<ReplayQuizEditor> createState() => _ReplayQuizEditorState();
}

class _ReplayQuizEditorState extends ConsumerState<ReplayQuizEditor> {
  final _title = TextEditingController();
  final List<QuizQuestionDraft> _qs = [];
  int _pass = 70;
  bool _loaded = false, _busy = false;
  String? _error, _info;

  @override
  void dispose() {
    _title.dispose();
    for (final q in _qs) {
      q.dispose();
    }
    super.dispose();
  }

  void _load(Map<String, dynamic> d) {
    _loaded = true;
    for (final q in _qs) {
      q.dispose();
    }
    _qs.clear();
    if (d['defined'] == true) {
      _title.text = '${d['title'] ?? ''}';
      _pass = ((d['pass_pct'] as num?) ?? 70).toInt();
      for (final raw in (d['questions'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(raw as Map);
        _qs.add(QuizQuestionDraft(statement: '${m['q']}', options: [for (final o in (m['options'] as List? ?? const [])) '$o'], correct: (m['correct'] as num?)?.toInt()));
      }
    } else {
      _title.text = 'Quiz';
      _pass = 70;
      _qs.add(QuizQuestionDraft());
    }
  }

  Future<void> _save() async {
    final err = validateReplayQuiz(_qs, _pass);
    if (err != null) return setState(() { _error = err; _info = null; });
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      await replayCall('replay_quiz_set', {'p_recording': widget.recordingId, 'p_title': _title.text.trim(), 'p_pass_pct': _pass, 'p_questions': [for (final q in _qs) q.toJson()]});
      ref.invalidate(replayQuizHostProvider(widget.recordingId));
      if (mounted) setState(() { _busy = false; _info = 'Quiz enregistré. Les étudiants le voient dès maintenant ; les bonnes réponses restent sur le serveur.'; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = e is ReplayException ? e.message : '$e'; });
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le quiz ?'),
        content: const Text('Les personnes qui ont terminé le replay et attendaient la réussite du quiz recevront leur badge. Les tentatives déjà faites restent enregistrées.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer'))],
      ),
    );
    if (yes != true) return;
    setState(() { _busy = true; _error = null; _info = null; });
    try {
      await replayCall('replay_quiz_delete', {'p_recording': widget.recordingId});
      _loaded = false;
      ref.invalidate(replayQuizHostProvider(widget.recordingId));
      if (mounted) setState(() { _busy = false; _info = 'Quiz supprimé.'; });
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = e is ReplayException ? e.message : '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) => ref.watch(replayQuizHostProvider(widget.recordingId)).when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Column(children: [
          mNote(e is ReplayException ? e.message : 'Le quiz n’a pas pu être chargé.'),
          mButton('Réessayer', () => ref.invalidate(replayQuizHostProvider(widget.recordingId)), dark: false),
        ]),
        data: (d) {
          if (!_loaded) _load(d);
          return _form(d);
        },
      );

  Widget _form(Map<String, dynamic> d) {
    final defined = d['defined'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      Text('Quiz facultatif : il s’affiche sous le lecteur. Si vous en définissez un, le badge « J’ai suivi » et le certificat exigent d’avoir terminé le replay ET réussi le quiz.', style: mst(13, c: kGrey)),
      if (defined) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${mInt(d['attempts'])} tentative(s) · ${mInt(d['takers'])} participant(s) · ${mInt(d['passers'])} réussite(s)', style: mst(13, w: FontWeight.w700))),
      const SizedBox(height: 12),
      TextField(key: const Key('quiz-title'), controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Titre du quiz')),
      Text('Seuil de réussite : $_pass %', style: mst(14, w: FontWeight.w800)),
      Slider(key: const Key('quiz-pass'), value: _pass.toDouble(), min: 50, max: 100, divisions: 10, label: '$_pass %', onChanged: (v) => setState(() => _pass = v.round())),
      for (var i = 0; i < _qs.length; i++) _question(i),
      if (_qs.length < kQuizMaxQuestions) Padding(padding: const EdgeInsets.only(top: 8), child: mButton('Ajouter une question', () => setState(() => _qs.add(QuizQuestionDraft())), dark: false, icon: Icons.add)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const Key('quiz-error'), style: mst(13, w: FontWeight.w700, c: kRed))),
      if (_info != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_info!, key: const Key('quiz-info'), style: mst(13, w: FontWeight.w700, c: kGreen))),
      const SizedBox(height: 12),
      mButton('Enregistrer le quiz', _busy ? null : _save, busy: _busy),
      if (defined) Padding(padding: const EdgeInsets.only(top: 8), child: mButton('Supprimer le quiz', _busy ? null : _delete, dark: false, icon: Icons.delete_outline)),
    ]);
  }

  Widget _question(int i) {
    final q = _qs[i];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: Material(
        type: MaterialType.transparency,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Question ${i + 1}', style: mst(14, w: FontWeight.w800))),
            if (_qs.length > 1) IconButton(tooltip: 'Supprimer la question ${i + 1}', icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _qs.removeAt(i).dispose())),
          ]),
          TextField(key: Key('quiz-q-$i'), controller: q.statement, maxLength: kQuizMaxStatement, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Énoncé')),
          Text('Cochez la bonne réponse', style: mst(12, c: kGrey)),
          RadioGroup<int>(
            groupValue: q.correct,
            onChanged: (v) => setState(() => q.correct = v),
            child: Column(children: [
              for (var o = 0; o < q.options.length; o++)
                Row(children: [
                  Radio<int>(key: Key('quiz-correct-$i-$o'), value: o),
                  Expanded(child: TextField(key: Key('quiz-o-$i-$o'), controller: q.options[o], maxLength: kQuizMaxOption, decoration: InputDecoration(labelText: 'Option ${o + 1}', counterText: ''))),
                  if (q.options.length > kQuizMinOptions)
                    IconButton(
                      tooltip: 'Supprimer l’option ${o + 1}',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        q.options.removeAt(o).dispose();
                        if (q.correct == o) {
                          q.correct = null;
                        } else if (q.correct != null && q.correct! > o) {
                          q.correct = q.correct! - 1;
                        }
                      }),
                    ),
                ]),
            ]),
          ),
          if (q.options.length < kQuizMaxOptions) TextButton.icon(onPressed: () => setState(() => q.options.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Ajouter une option')),
        ]),
      ),
    );
  }
}
