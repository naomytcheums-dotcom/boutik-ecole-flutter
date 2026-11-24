import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'evaluations.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Écran du VALIDATEUR HUMAIN (permission « tech.assessments », migration 20261125096000) : file des résultats qui attendent une validation humaine
/// (validée / non vérifiable à distance, avec un motif obligatoire) et des contestations (ouverte -> en examen -> close avec résolution motivée).
/// Les droits, la double authentification et l'interdiction de valider sa propre évaluation sont contrôlés par le serveur ; aucune confirmation n'apparaît si l'écriture échoue.

final assessmentReviewQueueProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final d = await evaluationCall('assessment_review_queue');
  if (d is! Map) throw EvaluationException('shape');
  return Map<String, dynamic>.from(d);
}, retry: (_, _) => null);

List<Map<String, dynamic>> _maps(Object? v) => v is List ? [for (final x in v) if (x is Map) Map<String, dynamic>.from(x)] : <Map<String, dynamic>>[];

class AssessmentReviewScreen extends ConsumerWidget {
  const AssessmentReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Validation des évaluations',
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          const SizedBox(height: 8),
          ref.watch(assessmentReviewQueueProvider).when(
                loading: evaluationLoading,
                error: (e, _) => evaluationError(ref, e, assessmentReviewQueueProvider),
                data: (q) {
                  final results = _maps(q['results']);
                  final disputes = _maps(q['disputes']);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    mSectionTitle('Résultats à valider'),
                    if (results.isEmpty) mNote('Aucun résultat n’attend de validation humaine.') else for (final r in results) _ReviewCard(r),
                    mSectionTitle('Contestations à traiter'),
                    if (disputes.isEmpty) mNote('Aucune contestation à traiter.') else for (final d in disputes) _DisputeCard(d),
                  ]);
                },
              ),
        ]),
      );
}

Future<String?> _askNote(BuildContext context, String title, String hint, int min) async {
  final txt = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(title),
        content: TextField(controller: txt, maxLines: 5, maxLength: 2000, autofocus: true, onChanged: (_) => setS(() {}), decoration: InputDecoration(labelText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')),
          TextButton(onPressed: txt.text.trim().length < min ? null : () => Navigator.pop(c, true), child: Text('Confirmer')),
        ],
      ),
    ),
  );
  final v = txt.text.trim();
  return ok == true ? v : null;
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard(this.r);
  final Map<String, dynamic> r;
  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _busy = false;

  Future<void> _decide(String outcome) async {
    final note = await _askNote(
      context,
      outcome == 'validee_humainement' ? 'Valider ce résultat' : 'Déclarer non vérifiable à distance',
      'Motif de la décision (10 caractères au minimum)',
      10,
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    final r = await marcheCall('assessment_human_validate', {'p_result': widget.r['result_id'], 'p_outcome': outcome, 'p_note': note});
    if (!mounted) return;
    setState(() => _busy = false);
    gToast(context, r.error != null ? EvaluationException(r.error).toString() : 'Décision enregistrée : le candidat est notifié.');
    if (r.error == null) ref.invalidate(assessmentReviewQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return evaluationCard([
      Text('${r['candidate']}', style: mst(15, w: FontWeight.w800)),
      Text('${r['family_code']} · ${assessmentModes[r['mode']] ?? r['mode']} · ${evaluationDate(r['created_at'])}', style: mst(12, c: kGrey)),
      ...evaluationResultBlocks(r),
      const SizedBox(height: 10),
      mButton('Valider', _busy ? null : () => _decide('validee_humainement'), busy: _busy),
      mButton('Non vérifiable à distance', _busy ? null : () => _decide('non_verifiable_a_distance'), dark: false),
    ]);
  }
}

class _DisputeCard extends ConsumerStatefulWidget {
  const _DisputeCard(this.d);
  final Map<String, dynamic> d;
  @override
  ConsumerState<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends ConsumerState<_DisputeCard> {
  bool _busy = false;

  Future<void> _act(String action) async {
    String? resolution;
    if (action == 'close') {
      resolution = await _askNote(context, 'Clore la contestation', 'Résolution motivée (20 caractères au minimum)', 20);
      if (resolution == null || !mounted) return;
    }
    setState(() => _busy = true);
    final r = await marcheCall('assessment_dispute_handle', {'p_id': widget.d['id'], 'p_action': action, 'p_resolution': ?resolution});
    if (!mounted) return;
    setState(() => _busy = false);
    gToast(context, r.error != null ? EvaluationException(r.error).toString() : (action == 'take' ? 'Contestation prise en examen : le candidat est notifié.' : 'Contestation close : le candidat est notifié.'));
    if (r.error == null) ref.invalidate(assessmentReviewQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final examen = d['status'] == 'en_examen';
    return evaluationCard([
      Text('${d['candidate']}', style: mst(15, w: FontWeight.w800)),
      Text('${d['family_code']} · ${assessmentModes[d['mode']] ?? d['mode']} · ${evaluationDate(d['created_at'])}', style: mst(12, c: kGrey)),
      const SizedBox(height: 4),
      Text('Contestation ${assessmentDisputeLabel('${d['status']}')}', style: mst(12.5, w: FontWeight.w700, c: examen ? kViolet : kRed)),
      const SizedBox(height: 4),
      Text('Motif du candidat : ${d['reason']}', style: mst(13, c: kGrey).copyWith(height: 1.4)),
      if ('${d['limits'] ?? ''}'.isNotEmpty) Text('Limites du résultat : ${d['limits']}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
      const SizedBox(height: 8),
      if (!examen) mButton('Prendre en examen', _busy ? null : () => _act('take'), busy: _busy),
      if (examen) mButton('Clore avec une résolution motivée', _busy ? null : () => _act('close'), busy: _busy),
    ]);
  }
}
