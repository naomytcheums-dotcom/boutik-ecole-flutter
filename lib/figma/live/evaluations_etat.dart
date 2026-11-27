import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'evaluations.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Évaluations (H13) : états explicites du parcours, disponibilité du fournisseur et outils d'administration.
/// Tout vient du serveur (assessment_provider_readiness, assessment_campaign_progress, assessment_dispatch_log_admin, assessment_my_list) : l'application n'affirme jamais
/// qu'un fournisseur est « configuré » sans rapport de santé du serveur, et une lecture en erreur n'affiche jamais un zéro. Aucun secret ne transite : seulement des booléens.

/// Disponibilité du fournisseur : « ready » (booléen) pour tout compte ; le détail par fournisseur et l'état de la file pour l'équipe « intégrations » seulement.
final assessmentReadinessProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final d = await evaluationCall('assessment_provider_readiness');
  if (d is! Map) throw EvaluationException('shape');
  return Map<String, dynamic>.from(d);
}, retry: (_, _) => null);

final assessmentCampaignProgressProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, campaignId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final d = await evaluationCall('assessment_campaign_progress', {'p_campaign': campaignId});
  if (d is! Map) throw EvaluationException('shape');
  return Map<String, dynamic>.from(d);
}, retry: (_, _) => null);

/// `true` / `false` seulement si le serveur l'a dit ; `null` si la lecture a échoué ou n'est pas arrivée (aucune affirmation).
bool? assessmentProviderReady(AsyncValue<Map<String, dynamic>> v) {
  final r = v.value?['ready'];
  return r is bool ? r : null;
}

enum AssessmentPhase { notConfigured, waiting, accepted, running, done, error, unavailable, cancelled }

/// Phase d'une demande du candidat : issue du statut serveur ; « fournisseur non configuré » seulement si le serveur a rapporté que le fournisseur ne l'est pas.
AssessmentPhase assessmentPhase(Map<String, dynamic> r, {bool? providerReady}) => switch ('${r['status']}') {
      'envoyee' => providerReady == false ? AssessmentPhase.notConfigured : AssessmentPhase.waiting,
      'acceptee' => AssessmentPhase.accepted,
      'en_cours' => AssessmentPhase.running,
      'terminee' => AssessmentPhase.done,
      'refusee' || 'echouee' => AssessmentPhase.error,
      'paiement_requis' => AssessmentPhase.unavailable,
      _ => AssessmentPhase.cancelled,
    };

String? assessmentPhaseDetail(Map<String, dynamic> r, {bool? providerReady}) {
  final attempts = (r['dispatch_attempts'] as num?)?.toInt() ?? 0;
  switch (assessmentPhase(r, providerReady: providerReady)) {
    case AssessmentPhase.notConfigured:
      return 'Fournisseur non configuré : votre demande reste en attente côté serveur et partira dès que le fournisseur sera configuré. Votre évaluation gratuite n’est pas consommée.';
    case AssessmentPhase.waiting:
      return attempts > 0
          ? 'Le serveur a tenté l’envoi $attempts fois sur 5 ; il réessaiera automatiquement.'
          : 'Demande enregistrée : le serveur l’envoie au fournisseur attribué.';
    case AssessmentPhase.accepted:
      return '${r['candidate_url'] ?? ''}'.startsWith('https://')
          ? 'Le fournisseur a accepté votre demande : vous pouvez commencer.'
          : 'Le fournisseur a accepté votre demande mais n’a pas encore transmis le lien de démarrage.';
    case AssessmentPhase.running:
      return 'Le fournisseur traite votre évaluation : le résultat apparaîtra ici dès sa réception.';
    case AssessmentPhase.done:
      return r['result_id'] == null ? 'Terminée côté fournisseur : aucun résultat n’est encore disponible ici.' : null;
    case AssessmentPhase.error:
      return '${r['status_note'] ?? ''}'.trim().isEmpty ? 'Le serveur n’a pas transmis de détail sur cette erreur.' : null;
    case AssessmentPhase.unavailable:
    case AssessmentPhase.cancelled:
      return null;
  }
}

/// « Fournisseur attribué par le serveur » : le candidat ne choisit jamais le fournisseur.
String? assessmentProviderLine(Map<String, dynamic> r) {
  final n = '${r['provider_name'] ?? ''}'.trim();
  return n.isEmpty ? null : 'Fournisseur attribué par le serveur : $n';
}

Color assessmentPhaseColor(AssessmentPhase p) => switch (p) {
      AssessmentPhase.error || AssessmentPhase.notConfigured => kRed,
      AssessmentPhase.done => kGreen,
      _ => kViolet,
    };

/// Bandeau « fournisseur non configuré » (étudiant) : affiché seulement si le serveur dit que la configuration n'est pas confirmée.
Widget assessmentNotConfiguredCard() => evaluationCard([
      Row(children: [
        const Icon(Icons.settings_suggest_outlined, size: 20, color: kRed),
        const SizedBox(width: 8),
        Expanded(child: Text('Fournisseur d’évaluation non configuré', style: mst(14, w: FontWeight.w800))),
      ]),
      const SizedBox(height: 6),
      Text(
        'Le fournisseur n’est pas encore configuré côté serveur : aucune évaluation ne peut être lancée pour le moment et votre évaluation gratuite reste intacte. Aucun résultat n’est simulé.',
        style: mst(12.5, c: kGrey).copyWith(height: 1.4),
      ),
    ]);

String _dateTime(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}h${two(d.minute)}';
}

// ============================================================ Organisation : avancement d'une campagne

class AssessmentProgressBlock extends ConsumerWidget {
  const AssessmentProgressBlock({super.key, required this.campaignId});
  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(assessmentCampaignProgressProvider(campaignId)).when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Avancement indisponible : ${e is EvaluationException ? e : Backend.userMessage('$e')}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
        ),
        data: (p) {
          final reused = (p['reused'] as num?)?.toInt() ?? 0;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(
              'Avancement des candidats qui partagent leur évaluation : ${p['waiting']} en attente · ${p['running']} en cours · ${p['done']} terminée(s) · ${p['error']} en erreur',
              style: mst(12.5, c: kGrey).copyWith(height: 1.4),
            ),
            if (reused > 0) Text('Évaluations existantes partagées : $reused', style: mst(12.5, c: kGrey)),
            if (p['status'] == 'ouverte' && p['provider_ready'] == false)
              Text('Fournisseur non configuré pour cette campagne : aucune évaluation ne peut partir pour le moment.', style: mst(12.5, w: FontWeight.w700, c: kRed).copyWith(height: 1.4)),
          ]);
        },
      );
}

// ============================================================ Administration : santé, registre, tests, journal

final assessmentDispatchLogProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final d = await evaluationCall('assessment_dispatch_log_admin', {'p_limit': 100});
  if (d is! List) throw EvaluationException('shape');
  return [for (final x in d) if (x is Map) Map<String, dynamic>.from(x)];
}, retry: (_, _) => null);

String assessmentDispatchEventLabel(String e) => switch (e) {
      'claimed' => 'Envoi tenté',
      'accepted' => 'Acceptée par le fournisseur',
      'failed' => 'Échec',
      'gave_up' => 'Abandon après 5 tentatives',
      'result' => 'Résultat reçu',
      'result_rejected' => 'Résultat refusé par les garde-fous',
      _ => e,
    };

/// Variables de configuration attendues (noms seulement, jamais de valeur) pour un fournisseur.
List<String> assessmentSecretNames(String code) {
  final k = 'ASSESSMENT_${code.toUpperCase()}_';
  return ['${k}BASE_URL', '${k}API_KEY', '${k}WEBHOOK_SECRET'];
}

List<String> assessmentMissingSecrets(Map<String, dynamic> h) {
  final names = assessmentSecretNames('${h['code']}');
  return [
    if (h['has_base_url'] != true) names[0],
    if (h['has_api_key'] != true) names[1],
    if (h['has_webhook_secret'] != true) names[2],
  ];
}

/// Ligne de santé d'un fournisseur du registre, d'après le rapport de la fonction d'envoi (jamais déduite).
String assessmentHealthLine(Map<String, dynamic>? h) {
  if (h == null || h['reported'] != true) return 'Configuration serveur : non vérifiée (aucun rapport de la fonction d’envoi).';
  final when = _dateTime(h['checked_at']);
  if (h['configured'] == true) {
    return 'Configuration serveur : complète (URL, clé et secret de rappel présents) · vérifiée le $when${h['stale'] == true ? ' · rapport ancien, à revérifier' : ''}';
  }
  return 'Configuration serveur : incomplète, il manque ${assessmentMissingSecrets(h).join(', ')} · vérifiée le $when';
}

class AssessmentHealthPanel extends ConsumerWidget {
  const AssessmentHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(assessmentReadinessProvider).when(
        loading: evaluationLoading,
        error: (e, _) => evaluationError(ref, e, assessmentReadinessProvider),
        data: (d) {
          if (d['providers'] is! List) return mNote('Le détail de santé est réservé à l’équipe « intégrations ».');
          final ready = d['ready'] == true;
          final queue = d['queue'] is Map ? Map<String, dynamic>.from(d['queue'] as Map) : const <String, dynamic>{};
          final hours = d['fresh_hours'];
          return evaluationCard([
            Row(children: [
              Icon(ready ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, size: 20, color: ready ? kGreen : kRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ready ? 'Envoi possible : un fournisseur actif est configuré' : 'Envoi impossible : aucun fournisseur actif et configuré', style: mst(14, w: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Le rapport de santé est écrit par la fonction d’envoi (action « health ») : il vérifie la présence des secrets, sans appeler le fournisseur ni consommer de crédit. '
              'Il est considéré à jour pendant $hours heures.',
              style: mst(12.5, c: kGrey).copyWith(height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              'File d’envoi : ${queue['waiting']} en attente · ${queue['running']} en cours · ${queue['failed_24h']} échec(s) sur 24 h'
              '${queue['last_event_at'] == null ? ' · aucun envoi journalisé' : ' · dernier événement le ${_dateTime(queue['last_event_at'])}'}',
              style: mst(12.5, c: kGrey).copyWith(height: 1.4),
            ),
          ]);
        },
      );
}

/// Journal d'envoi : réservé à l'administrateur global par le serveur (une autre équipe voit le refus, jamais un journal vide).
Future<void> showAssessmentDispatchLog(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => const _DispatchLogSheet(),
    );

class _DispatchLogSheet extends ConsumerWidget {
  const _DispatchLogSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Journal d’envoi', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Les 100 derniers événements d’envoi aux fournisseurs (références de demande, sans donnée personnelle).', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
            ref.watch(assessmentDispatchLogProvider).when(
                  loading: evaluationLoading,
                  error: (e, _) => evaluationError(ref, e, assessmentDispatchLogProvider),
                  data: (l) => l.isEmpty
                      ? mNote('Aucun envoi journalisé pour le moment.')
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final x in l)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${assessmentDispatchEventLabel('${x['event']}')} · ${x['provider']}', style: mst(13, w: FontWeight.w700)),
                                Text(
                                  '${_dateTime(x['at'])} · demande ${'${x['request_id']}'.split('-').first}${x['http_status'] == null ? '' : ' · HTTP ${x['http_status']}'}${'${x['detail'] ?? ''}'.isEmpty ? '' : ' · ${x['detail']}'}',
                                  style: mst(12, c: kGrey).copyWith(height: 1.4),
                                ),
                              ]),
                            ),
                        ]),
                ),
            const SizedBox(height: 10),
            mButton('Fermer', () => Navigator.pop(context), dark: false),
          ]),
        ),
      );
}

/// Enregistre un fournisseur au registre (statut « Candidat ») : aucune activation possible sans test d'intégration réussi, vérifié par le serveur.
Future<bool> showAssessmentRegisterSheet(BuildContext context) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    builder: (c) => const _RegisterSheet(),
  );
  return done == true;
}

class _RegisterSheet extends ConsumerStatefulWidget {
  const _RegisterSheet();
  @override
  ConsumerState<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends ConsumerState<_RegisterSheet> {
  final _code = TextEditingController(), _name = TextEditingController();
  final _families = <String>{}, _modes = <String>{};
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[a-z0-9_]{2,40}$').hasMatch(_code.text.trim().toLowerCase()) && _name.text.trim().length >= 2 && _families.isNotEmpty && _modes.isNotEmpty;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await marcheCall('assessment_provider_register', {'p_code': _code.text.trim().toLowerCase(), 'p_name': _name.text.trim(), 'p_families': _families.toList(), 'p_modes': _modes.toList()});
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _message = EvaluationException(r.error).toString();
      });
      return;
    }
    gToast(context, 'Fournisseur enregistré avec le statut « Candidat » : il n’est pas actif.');
    Navigator.pop(context, true);
  }

  Widget _check(String label, bool on, VoidCallback tap) => InkWell(
        onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(children: [
            Icon(on ? Icons.check_box : Icons.check_box_outline_blank, color: on ? kViolet : kGrey, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: mst(13.5))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final families = ref.watch(assessmentFamiliesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enregistrer un fournisseur', style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Le fournisseur est enregistré « Candidat » : il ne reçoit aucune demande. Ses trois secrets (URL, clé, secret de rappel) se posent dans les secrets de la fonction d’envoi, jamais ici.',
            style: mst(12.5, c: kGrey).copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          TextField(controller: _code, maxLength: 40, decoration: const InputDecoration(labelText: 'Code (a-z, 0-9, _)'), onChanged: (_) => setState(() {})),
          TextField(controller: _name, maxLength: 120, decoration: const InputDecoration(labelText: 'Nom du fournisseur'), onChanged: (_) => setState(() {})),
          Text('Modes couverts', style: mst(13.5, w: FontWeight.w800)),
          for (final e in assessmentModes.entries) _check(e.value, _modes.contains(e.key), () => setState(() => _modes.contains(e.key) ? _modes.remove(e.key) : _modes.add(e.key))),
          const SizedBox(height: 8),
          Text('Familles de métiers couvertes', style: mst(13.5, w: FontWeight.w800)),
          families.when(
            loading: evaluationLoading,
            error: (e, _) => evaluationError(ref, e, assessmentFamiliesProvider),
            data: (l) => Column(children: [for (final f in l) _check('${f['label']}', _families.contains('${f['code']}'), () => setState(() => _families.contains('${f['code']}') ? _families.remove('${f['code']}') : _families.add('${f['code']}')))]),
          ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: mst(13, w: FontWeight.w700, c: kRed).copyWith(height: 1.4))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(context, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Enregistrer', _valid ? _send : null, busy: _busy)),
          ]),
        ]),
      ),
    );
  }
}

/// Enregistre le résultat d'un test d'intégration RÉEL (sandbox ou production). Le serveur exige un test réussi pour activer un fournisseur : ne l'enregistrer que s'il a eu lieu.
Future<bool> showAssessmentTestDialog(BuildContext context, Map<String, dynamic> p) async {
  final note = TextEditingController();
  bool? passed;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text('Enregistrer un test d’intégration'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Enregistrez seulement le résultat d’un appel réel (bac à sable ou production) effectué auprès de « ${p['name']} ». Un test réussi ne se déclare jamais sans appel réel.',
              style: mst(12.5, c: kGrey).copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            for (final o in const [(true, 'Test réussi'), (false, 'Test échoué')])
              InkWell(
                onTap: () => setS(() => passed = o.$1),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(children: [
                    Icon(passed == o.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: passed == o.$1 ? kViolet : kGrey, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Text(o.$2, style: mst(13.5))),
                  ]),
                ),
              ),
            TextField(controller: note, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Note (réponse du fournisseur, environnement)'), onChanged: (_) => setS(() {})),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')),
          TextButton(onPressed: passed == null || note.text.trim().length < 5 ? null : () => Navigator.pop(c, true), child: Text('Enregistrer')),
        ],
      ),
    ),
  );
  if (ok != true || passed == null || !context.mounted) return false;
  final r = await marcheCall('assessment_provider_record_test', {'p_code': p['code'], 'p_ok': passed, 'p_note': note.text.trim()});
  if (!context.mounted) return false;
  gToast(context, r.error != null ? EvaluationException(r.error).toString() : 'Test d’intégration enregistré.');
  return r.error == null;
}

/// Accès à la file de validation humaine (route protégée par la permission « tech.assessments »).
void openAssessmentReview(BuildContext context) => GoRouter.of(context).push('/admin/evaluations/validation');
