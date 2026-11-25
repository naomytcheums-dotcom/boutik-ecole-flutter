import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Évaluations de compétences (« Talent Assessment », migration 20261125095000) : socle FOURNISSEUR-AGNOSTIQUE.
/// Tout vient du serveur : familles de métiers, quota gratuit du mois, demandes et résultats. Aucun fournisseur d'évaluation n'est intégré :
/// tant que le registre est vide, aucune évaluation ne peut être lancée. Une erreur de lecture n'affiche jamais un zéro ni une donnée inventée.

class EvaluationException implements Exception {
  EvaluationException(this.code);
  final Object? code;
  @override
  String toString() {
    if (code == 'offline') return 'Les évaluations sont disponibles une fois l’application connectée au serveur.';
    if (code == 'missing') return 'Le module d’évaluation n’est pas encore installé sur le serveur.';
    if (code == 'shape') return 'Réponse inattendue du serveur. Réessayez plus tard.';
    return Backend.userMessage('$code');
  }
}

Future<Object?> _call(String fn, [Map<String, dynamic> params = const {}]) async {
  final r = await marcheCall(fn, params);
  if (r.error != null) throw EvaluationException(r.error);
  return r.data;
}

Future<List<Map<String, dynamic>>> _callList(String fn) async {
  final d = await _call(fn);
  if (d is! List) throw EvaluationException('shape');
  return [for (final x in d) if (x is Map) Map<String, dynamic>.from(x)];
}

Future<Map<String, dynamic>> _callMap(String fn, [Map<String, dynamic> params = const {}]) async {
  final d = await _call(fn, params);
  if (d is! Map) throw EvaluationException('shape');
  return Map<String, dynamic>.from(d);
}

final assessmentFamiliesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callList('assessment_families');
}, retry: (_, _) => null);

final assessmentQuotaProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callMap('assessment_quota');
}, retry: (_, _) => null);

final assessmentRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callList('assessment_my_list');
}, retry: (_, _) => null);

final assessmentInvitationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callList('assessment_my_invitations');
}, retry: (_, _) => null);

final assessmentProvidersAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  return _callList('assessment_providers_admin_list');
}, retry: (_, _) => null);

const assessmentModes = {
  'ecrit': 'Questions écrites',
  'etude_cas': 'Étude de cas',
  'entretien_oral_ia': 'Entretien oral avec IA',
  'analyse_documents': 'Analyse de documents',
  'exercice_pratique': 'Exercice pratique',
  'simulation': 'Simulation professionnelle',
  'analyse_fichiers': 'Analyse de fichiers',
  'evaluation_projets': 'Évaluation de projets',
  'analyse_images_videos': 'Analyse d’images ou de vidéos',
  'presentation_video': 'Présentation vidéo',
  'validation_humaine': 'Validation humaine ou en présentiel',
};

String assessmentStatusLabel(String s) => switch (s) {
      'envoyee' => 'Envoyée · en attente de la réponse du fournisseur',
      'paiement_requis' => 'Paiement requis · le paiement n’est pas encore en service, demande non envoyée',
      'acceptee' => 'Acceptée par le fournisseur',
      'en_cours' => 'En cours',
      'terminee' => 'Terminée',
      'refusee' => 'Refusée par le fournisseur · rien n’a été consommé',
      'echouee' => 'Échouée · rien n’a été consommé',
      'annulee' => 'Annulée',
      _ => s,
    };

String assessmentProviderStatusLabel(String s) => switch (s) {
      'candidat' => 'Candidat',
      'en_test' => 'En test',
      'actif' => 'Actif',
      'suspendu' => 'Suspendu',
      _ => s,
    };

String _date(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String _item(Object? x) {
  if (x is Map) {
    for (final k in const ['name', 'label', 'title', 'text', 'kind']) {
      final v = x[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v';
    }
    return x.values.where((v) => v is String || v is num).join(' · ');
  }
  return '$x';
}

Widget _error(WidgetRef ref, Object e, ProviderOrFamily retry) => Column(children: [
      mNote(e is EvaluationException ? e.toString() : Backend.userMessage('$e')),
      Center(child: mButton('Réessayer', () => ref.invalidate(retry), dark: false)),
    ]);

Widget _card(List<Widget> children) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

Widget _loading() => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));

/// Aides partagées avec les écrans d'organisation et de validateur (evaluations_org.dart, evaluations_validateur.dart).
Future<Object?> evaluationCall(String fn, [Map<String, dynamic> params = const {}]) => _call(fn, params);
String evaluationDate(Object? iso) => _date(iso);
String evaluationItem(Object? x) => _item(x);
Widget evaluationCard(List<Widget> children) => _card(children);
Widget evaluationLoading() => _loading();
Widget evaluationError(WidgetRef ref, Object e, ProviderOrFamily retry) => _error(ref, e, retry);

String assessmentValidationLabel(String s) => switch (s) {
      'automatique' => 'Résultat automatique',
      'validation_humaine_requise' => 'Validation humaine requise',
      'validee_humainement' => 'Validée par un évaluateur',
      'non_verifiable_a_distance' => 'Non vérifiable à distance',
      _ => s,
    };

String assessmentDisputeLabel(String s) => switch (s) {
      'ouverte' => 'ouverte',
      'en_examen' => 'en cours d’examen',
      'close' => 'close',
      _ => s,
    };

/// Bloc de lecture d'un résultat : compétences, critères, preuves, limites, recommandations (partagé candidat / organisation / validateur).
List<Widget> evaluationResultBlocks(Map<String, dynamic> d) {
  List<Widget> list(String title, Object? v) {
    final items = v is List ? v : const [];
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Text(title, style: mst(13.5, w: FontWeight.w800)),
      for (final x in items) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• ${_item(x)}', style: mst(13, c: kGrey).copyWith(height: 1.4))),
    ];
  }

  return [
    ...list('Compétences évaluées', d['competences']),
    ...list('Critères', d['criteria']),
    ...list('Preuves', d['evidence']),
    if ('${d['limits'] ?? ''}'.isNotEmpty) ...[
      const SizedBox(height: 10),
      Text('Limites de l’évaluation', style: mst(13.5, w: FontWeight.w800)),
      Text('${d['limits']}', style: mst(13, c: kGrey).copyWith(height: 1.4)),
    ],
    ...list('Recommandations', d['recommendations']),
  ];
}

/// Écran étudiant : quota, 33 familles de métiers, mes demandes et résultats.
class AssessmentsScreen extends ConsumerWidget {
  const AssessmentsScreen({super.key});

  Widget _quota(BuildContext context, WidgetRef ref) => ref.watch(assessmentQuotaProvider).when(
        loading: _loading,
        error: (e, _) => _error(ref, e, assessmentQuotaProvider),
        data: (q) {
          final eligible = q['eligible'] == true;
          final noProvider = (q['active_providers'] as num?)?.toInt() == 0;
          final extra = q['extra'] is Map ? Map<String, dynamic>.from(q['extra'] as Map) : const <String, dynamic>{};
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _card([
              Text('Évaluation gratuite du mois', style: mst(15, w: FontWeight.w800)),
              const SizedBox(height: 6),
              if (eligible) ...[
                Text('${q['remaining']} restante sur ${q['monthly_free']} ce mois-ci', style: mst(14, w: FontWeight.w700, c: kViolet)),
                Text('Utilisée : ${q['used']} · remise à zéro le ${_date(q['next_reset'])}', style: mst(12.5, c: kGrey)),
                const SizedBox(height: 4),
                Text('Elle n’est consommée que lorsqu’un fournisseur accepte votre demande, jamais pour une demande refusée ou échouée.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
              ] else
                Text('${q['message'] ?? 'L’évaluation gratuite du mois est réservée aux comptes étudiants.'}', style: mst(13, c: kGrey).copyWith(height: 1.4)),
            ]),
            if (noProvider)
              _card([
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: kViolet),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Aucun fournisseur d’évaluation actif pour le moment', style: mst(14, w: FontWeight.w800))),
                ]),
                const SizedBox(height: 6),
                Text('Les demandes ne peuvent pas être envoyées tant qu’aucun fournisseur n’est actif. Votre évaluation gratuite reste intacte.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
              ]),
            _card([
              Text('Évaluations supplémentaires', style: mst(15, w: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${extra['message'] ?? 'Information indisponible.'}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
            ]),
          ]);
        },
      );

  Future<void> _ask(BuildContext context, WidgetRef ref, Map<String, dynamic> family, Map<String, dynamic>? quota) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _RequestSheet(family: family, quota: quota),
    );
    if (done == true) {
      ref.invalidate(assessmentQuotaProvider);
      ref.invalidate(assessmentRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quota = ref.watch(assessmentQuotaProvider).value;
    return MarchePage(
      title: 'Évaluations',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        const SizedBox(height: 8),
        _quota(context, ref),
        ref.watch(assessmentInvitationsProvider).when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => mNote('Invitations indisponibles : ${e is EvaluationException ? e : Backend.userMessage('$e')}'),
              data: (l) => l.isEmpty
                  ? const SizedBox.shrink()
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      mSectionTitle('Invitations des organisations'),
                      for (final i in l) _InvitationCard(i),
                    ]),
            ),
        mSectionTitle('Mes demandes et résultats'),
        ref.watch(assessmentRequestsProvider).when(
              loading: _loading,
              error: (e, _) => _error(ref, e, assessmentRequestsProvider),
              data: (l) => l.isEmpty
                  ? mNote('Aucune évaluation pour le moment.')
                  : Column(children: [for (final r in l) _RequestCard(r)]),
            ),
        mSectionTitle('Familles de métiers'),
        ref.watch(assessmentFamiliesProvider).when(
              loading: _loading,
              error: (e, _) => _error(ref, e, assessmentFamiliesProvider),
              data: (l) => l.isEmpty
                  ? mNote('Aucune famille de métiers n’est disponible pour le moment.')
                  : Column(children: [
                      for (final f in l)
                        Semantics(
                          button: true,
                          label: '${f['label']}',
                          child: InkWell(
                            onTap: () => _ask(context, ref, f, quota),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              constraints: const BoxConstraints(minHeight: 48),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                              child: Row(children: [
                                Expanded(child: Text('${f['label']}', style: mst(14, w: FontWeight.w700))),
                                if (f['covered'] == true) Text('Fournisseur actif', style: mst(11.5, w: FontWeight.w700, c: kGreen)),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded, color: kGrey),
                              ]),
                            ),
                          ),
                        ),
                    ]),
            ),
      ]),
    );
  }
}

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.family, required this.quota});
  final Map<String, dynamic> family;
  final Map<String, dynamic>? quota;
  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  String? _mode;
  bool _consent = false, _busy = false;
  String? _message;

  Map<String, dynamic> get _q => widget.quota ?? const {};
  bool get _free => _q['eligible'] == true && ((_q['remaining'] as num?)?.toInt() ?? 0) > 0;
  Map<String, dynamic> get _extra => _q['extra'] is Map ? Map<String, dynamic>.from(_q['extra'] as Map) : const {};

  Future<void> _send() async {
    setState(() => _busy = true);
    final params = <String, dynamic>{
      'p_family': widget.family['code'],
      'p_mode': _mode,
      'p_consent': _consent,
      'p_funding': _free ? 'gratuite_mensuelle' : 'payee_candidat',
      if (!_free) 'p_announced_price': _extra['price_xaf'],
    };
    final r = await marcheCall('assessment_request', params);
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _message = EvaluationException(r.error).toString();
      });
      return;
    }
    final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
    if (d['ok'] == true) {
      gToast(context, '${d['message'] ?? 'Demande enregistrée.'}');
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _message = '${d['message'] ?? 'Demande refusée.'}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final noQuota = widget.quota == null;
    final canPay = !_free && _extra['available'] == true;
    final blocked = noQuota || (!_free && !canPay);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.family['label']}', style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            noQuota
                ? 'Votre quota n’a pas pu être lu : réessayez avant de lancer une évaluation.'
                : _free
                    ? 'Évaluation gratuite du mois. Elle n’est consommée que si un fournisseur accepte la demande.'
                    : canPay
                        ? 'Évaluation supplémentaire : ${_extra['message']}'
                        : '${_extra['message'] ?? 'Aucune évaluation disponible pour votre compte.'}',
            style: mst(12.5, c: kGrey).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final e in assessmentModes.entries)
            InkWell(
              onTap: () => setState(() => _mode = e.key),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(children: [
                  Icon(_mode == e.key ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _mode == e.key ? kViolet : kGrey, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value, style: mst(13.5))),
                ]),
              ),
            ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _consent = !_consent),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(children: [
                Icon(_consent ? Icons.check_box : Icons.check_box_outline_blank, color: _consent ? kViolet : kGrey, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('J’accepte que mes réponses soient transmises à un fournisseur d’évaluation pour être évaluées.', style: mst(12.5, c: kGrey).copyWith(height: 1.4))),
              ]),
            ),
          ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: mst(13, w: FontWeight.w700, c: kRed).copyWith(height: 1.4))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(context, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Demander', blocked || _mode == null || !_consent ? null : _send, busy: _busy)),
          ]),
        ]),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard(this.r);
  final Map<String, dynamic> r;
  String get _requestId => '${r['id']}';

  Future<void> _openProvider(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && context.mounted) gToast(context, 'Impossible d’ouvrir le lien du fournisseur. Réessayez.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultId = r['result_id'];
    final humain = r['validation_status'] == 'validation_humaine_requise';
    return _card([
      Text('${r['family_label']}', style: mst(15, w: FontWeight.w800)),
      Text('${assessmentModes[r['mode']] ?? r['mode']} · ${_date(r['created_at'])}', style: mst(12, c: kGrey)),
      const SizedBox(height: 4),
      Text(assessmentStatusLabel('${r['status']}'), style: mst(12.5, w: FontWeight.w700, c: kViolet)),
      if ('${r['status_note'] ?? ''}'.isNotEmpty) Text('${r['status_note']}', style: mst(12.5, c: kGrey)),
      if (humain) Text('Validation humaine requise', style: mst(12.5, w: FontWeight.w700, c: kRed)),
      if ('${r['candidate_url'] ?? ''}'.startsWith('https://'))
        mButton('Commencer l’évaluation', () => _openProvider(context, '${r['candidate_url']}'), dark: false),
      if (r['dispute_status'] != null) Text('Contestation : ${assessmentDisputeLabel('${r['dispute_status']}')}', style: mst(12, c: kGrey)),
      if (r['campaign_id'] != null && r['status'] != 'annulee') ...[
        const SizedBox(height: 4),
        Text(
          r['shared_with_org'] == true ? 'Résultat partagé avec l’organisation qui vous a invité(e).' : 'Résultat non partagé : l’organisation ne le voit pas.',
          style: mst(12.5, w: FontWeight.w700, c: r['shared_with_org'] == true ? kGreen : kGrey),
        ),
        if (r['reuse_of'] != null)
          mButton('Retirer le partage', () => _revoke(context, ref), dark: false)
        else if (r['status'] != 'refusee' && r['status'] != 'echouee')
          mButton(r['shared_with_org'] == true ? 'Ne plus partager' : 'Partager avec l’organisation', () => _share(context, ref, r['shared_with_org'] != true), dark: false),
      ],
      if (resultId != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: mButton('Voir le résultat', () => _showResult(context, ref, '$resultId'), dark: false),
        ),
    ]);
  }

  Future<void> _share(BuildContext context, WidgetRef ref, bool share) async {
    final res = await marcheCall('assessment_share_set', {'p_request': _requestId, 'p_share': share});
    if (!context.mounted) return;
    gToast(context, res.error != null ? EvaluationException(res.error).toString() : (share ? 'Résultat partagé avec l’organisation.' : 'Partage retiré : l’organisation ne voit plus ce résultat.'));
    if (res.error == null) ref.invalidate(assessmentRequestsProvider);
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final res = await marcheCall('assessment_reuse_revoke', {'p_request': _requestId});
    if (!context.mounted) return;
    gToast(context, res.error != null ? EvaluationException(res.error).toString() : 'Partage retiré : l’organisation ne voit plus cette évaluation.');
    if (res.error == null) ref.invalidate(assessmentRequestsProvider);
  }

  Future<void> _showResult(BuildContext context, WidgetRef ref, String id) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _ResultSheet(id: id),
    );
    ref.invalidate(assessmentRequestsProvider);
  }
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.id});
  final String id;
  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late Future<Map<String, dynamic>> _f = _callMap('assessment_result', {'p_id': widget.id});

  Future<void> _dispute() async {
    final txt = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Contester ce résultat'),
        content: TextField(controller: txt, maxLines: 4, maxLength: 2000, autofocus: true, decoration: const InputDecoration(labelText: 'Votre explication (10 caractères au minimum)')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Envoyer'))],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await marcheCall('assessment_dispute', {'p_id': widget.id, 'p_reason': txt.text});
    if (!mounted) return;
    gToast(context, r.error != null ? EvaluationException(r.error).toString() : 'Contestation envoyée. Le résultat sera réexaminé.');
    if (r.error == null) {
      setState(() {
        _f = _callMap('assessment_result', {'p_id': widget.id});
      });
    }
  }

  List<Widget> _list(String title, Object? v) {
    final items = v is List ? v : const [];
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Text(title, style: mst(13.5, w: FontWeight.w800)),
      for (final x in items) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• ${_item(x)}', style: mst(13, c: kGrey).copyWith(height: 1.4))),
    ];
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return _loading();
            if (s.hasError) return mNote('${s.error is EvaluationException ? s.error : Backend.userMessage('${s.error}')}');
            final d = s.data!;
            final disputes = d['disputes'] is List ? d['disputes'] as List : const [];
            final open = disputes.any((x) => x is Map && (x['status'] == 'ouverte' || x['status'] == 'en_examen'));
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Résultat de l’évaluation', style: mst(18, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Statut : ${assessmentValidationLabel('${d['validation_status'] ?? 'automatique'}')}', style: mst(13, w: FontWeight.w700, c: kViolet)),
                if (d['human_validation_required'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Validation humaine requise : une partie de ces compétences ne peut pas être vérifiée à distance.', style: mst(13, w: FontWeight.w700, c: kRed).copyWith(height: 1.4)),
                  ),
                if ('${d['review_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Avis de l’évaluateur : ${d['review_note']}', style: mst(13, c: kGrey).copyWith(height: 1.4))),
                ...evaluationResultBlocks(d),
                ..._list('Contestations', [for (final x in disputes) if (x is Map) '${assessmentDisputeLabel('${x['status']}')} : ${x['reason']}${x['resolution'] == null ? '' : ' → ${x['resolution']}'}']),
                const SizedBox(height: 14),
                if (d['dispute_possible'] == true && !open) mButton('Contester ce résultat', _dispute, dark: false),
              ]),
            );
          },
        ),
      );
}

class _InvitationCard extends ConsumerStatefulWidget {
  const _InvitationCard(this.i);
  final Map<String, dynamic> i;
  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _busy = false;

  Future<void> _take() async {
    final i = widget.i;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Passer cette évaluation ?'),
        content: Text('Vos réponses seront transmises à un fournisseur d’évaluation. Le résultat n’est partagé avec « ${i['organization']} » que si vous le décidez ensuite ; vous pourrez le retirer à tout moment.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('J’accepte'))],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await marcheCall('assessment_request', {'p_family': i['family_code'], 'p_mode': i['mode'], 'p_consent': true, 'p_funding': 'financee_organisation', 'p_campaign': i['campaign_id']});
    if (!mounted) return;
    setState(() => _busy = false);
    final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
    gToast(context, r.error != null ? EvaluationException(r.error).toString() : '${d['message'] ?? (d['ok'] == true ? 'Demande enregistrée.' : 'Demande refusée.')}');
    if (r.error == null && d['ok'] == true) {
      ref.invalidate(assessmentInvitationsProvider);
      ref.invalidate(assessmentRequestsProvider);
    }
  }

  Future<void> _reuse() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _ReuseSheet(campaignId: '${widget.i['campaign_id']}'),
    );
    if (done == true) {
      ref.invalidate(assessmentInvitationsProvider);
      ref.invalidate(assessmentRequestsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.i;
    final open = i['status'] == 'ouverte';
    final requested = i['requested'] == true;
    return _card([
      Text('${i['title']}', style: mst(15, w: FontWeight.w800)),
      Text('${i['organization']} · ${i['family_label']} · ${assessmentModes[i['mode']] ?? i['mode']}', style: mst(12, c: kGrey)),
      const SizedBox(height: 4),
      Text(
        switch ('${i['status']}') {
          'ouverte' => requested ? 'Évaluation déjà demandée pour cette campagne.' : 'Campagne ouverte : vous restez libre de la passer ou non.',
          'close' => 'Campagne close.',
          _ => 'Campagne pas encore ouverte : le financement des campagnes n’est pas encore ouvert. Rien ne vous est demandé.',
        },
        style: mst(12.5, w: FontWeight.w700, c: open ? kGreen : kGrey).copyWith(height: 1.4),
      ),
      if (open && !requested) ...[
        const SizedBox(height: 8),
        mButton('Passer l’évaluation', _busy ? null : _take, busy: _busy),
        mButton('Partager une évaluation récente', _reuse, dark: false),
      ],
    ]);
  }
}

class _ReuseSheet extends StatefulWidget {
  const _ReuseSheet({required this.campaignId});
  final String campaignId;
  @override
  State<_ReuseSheet> createState() => _ReuseSheetState();
}

class _ReuseSheetState extends State<_ReuseSheet> {
  late final Future<Map<String, dynamic>> _f = _callMap('assessment_reuse_options', {'p_campaign': widget.campaignId});
  bool _consent = false, _busy = false;
  String? _message;

  Future<void> _grant(String resultId) async {
    setState(() => _busy = true);
    final r = await marcheCall('assessment_reuse_grant', {'p_result': resultId, 'p_campaign': widget.campaignId, 'p_consent': _consent});
    if (!mounted) return;
    final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
    if (r.error == null && d['ok'] == true) {
      gToast(context, 'Évaluation partagée avec votre accord. Vous pouvez retirer ce partage à tout moment.');
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _message = r.error != null ? EvaluationException(r.error).toString() : '${d['message'] ?? 'Partage refusé.'}';
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return _loading();
            if (s.hasError) return mNote('${s.error is EvaluationException ? s.error : Backend.userMessage('${s.error}')}');
            final d = s.data!;
            final options = d['options'] is List ? [for (final x in d['options'] as List) if (x is Map) Map<String, dynamic>.from(x)] : <Map<String, dynamic>>[];
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Partager une évaluation récente', style: mst(18, w: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${d['message'] ?? ''}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                if (d['available'] == true && options.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucune évaluation récente ne correspond à cette campagne.', style: mst(13, w: FontWeight.w700))),
                if (d['available'] == true && options.isNotEmpty) ...[
                  InkWell(
                    onTap: () => setState(() => _consent = !_consent),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(children: [
                        Icon(_consent ? Icons.check_box : Icons.check_box_outline_blank, color: _consent ? kViolet : kGrey, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text('J’accepte de partager cette évaluation avec l’organisation. Je peux retirer ce partage à tout moment.', style: mst(12.5, c: kGrey).copyWith(height: 1.4))),
                      ]),
                    ),
                  ),
                  for (final o in options)
                    _card([
                      Text('Évaluation du ${_date(o['created_at'])}', style: mst(14, w: FontWeight.w800)),
                      Text(assessmentValidationLabel('${o['validation_status']}'), style: mst(12.5, c: kGrey)),
                      const SizedBox(height: 6),
                      mButton('Partager celle-ci', _consent && !_busy ? () => _grant('${o['result_id']}') : null, busy: _busy),
                    ]),
                ],
                if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: mst(13, w: FontWeight.w700, c: kRed).copyWith(height: 1.4))),
                const SizedBox(height: 10),
                mButton('Fermer', () => Navigator.pop(context, false), dark: false),
              ]),
            );
          },
        ),
      );
}

/// Administration : registre des fournisseurs d'évaluation (permission « intégrations »). L'activation est réservée à l'administrateur global
/// (double authentification, journal d'audit) et refusée par le serveur sans test d'intégration réussi.
class AssessmentProvidersAdminScreen extends ConsumerWidget {
  const AssessmentProvidersAdminScreen({super.key});

  Future<void> _setStatus(BuildContext context, WidgetRef ref, Map<String, dynamic> p, String status) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(status == 'actif' ? 'Activer ce fournisseur ?' : 'Suspendre ce fournisseur ?'),
        content: Text(status == 'actif'
            ? 'Les demandes des candidats seront envoyées à « ${p['name']} ». Le serveur refuse l’activation sans test d’intégration réussi.'
            : 'Plus aucune demande ne sera envoyée à « ${p['name']} ».'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Confirmer'))],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('assessment_provider_set_status', {'p_code': p['code'], 'p_status': status});
    if (!context.mounted) return;
    gToast(context, r.error != null ? EvaluationException(r.error).toString() : 'Statut enregistré.');
    ref.invalidate(assessmentProvidersAdminProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Fournisseurs d’évaluation',
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          const SizedBox(height: 8),
          ref.watch(assessmentProvidersAdminProvider).when(
                loading: _loading,
                error: (e, _) => _error(ref, e, assessmentProvidersAdminProvider),
                data: (l) => l.isEmpty
                    ? mNote('Aucun fournisseur d’évaluation enregistré.\nAucun fournisseur n’est actif : aucune évaluation ne peut être lancée.')
                    : Column(children: [
                        for (final p in l)
                          _card([
                            Text('${p['name']}', style: mst(15, w: FontWeight.w800)),
                            Text('${p['code']} · ${assessmentProviderStatusLabel('${p['status']}')}', style: mst(12.5, w: FontWeight.w700, c: p['status'] == 'actif' ? kGreen : kViolet)),
                            const SizedBox(height: 4),
                            Text('Familles couvertes : ${(p['family_codes'] as List? ?? const []).length} · modes : ${[for (final m in (p['modes'] as List? ?? const [])) assessmentModes['$m'] ?? '$m'].join(', ')}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                            Text(
                              p['last_test'] is Map
                                  ? 'Dernier test d’intégration : ${(p['last_test'] as Map)['ok'] == true ? 'réussi' : 'échoué'} le ${_date((p['last_test'] as Map)['tested_at'])}'
                                  : 'Aucun test d’intégration enregistré : activation impossible.',
                              style: mst(12.5, c: kGrey),
                            ),
                            const SizedBox(height: 8),
                            if (p['status'] != 'actif') mButton('Activer', () => _setStatus(context, ref, p, 'actif'), dark: false),
                            if (p['status'] == 'actif') mButton('Suspendre', () => _setStatus(context, ref, p, 'suspendu'), dark: false),
                          ]),
                      ]),
              ),
        ]),
      );
}
