import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'company_screens.dart' show companyContextProvider;
import 'evaluations.dart';
import 'evaluations_etat.dart' show AssessmentProgressBlock;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Campagnes d'évaluation d'une ORGANISATION (migration 20261125096100) : créer une campagne (famille de métiers, mode), inviter des candidats, suivre la liste, clôturer,
/// lire les résultats que les candidats ont accepté de partager. Aucun paiement : une campagne naît « en attente de financement » et le reste tant que le financement n'est pas ouvert.
/// Tout vient du serveur ; une erreur est dite erreur (jamais « 0 »), aucune confirmation n'apparaît si l'écriture échoue. Le lecteur d'équipe consulte sans écrire (droits contrôlés par le serveur).

Map<String, dynamic> _args(String? org, [Map<String, dynamic> extra = const {}]) => {...extra, 'p_org': ?org};

String _errorText(Object? e) => EvaluationException(e).toString();

final assessmentCampaignsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final org = ref.watch(companyContextProvider);
  final d = await evaluationCall('assessment_campaigns_list', _args(org));
  if (d is! List) throw EvaluationException('shape');
  return [for (final x in d) if (x is Map) Map<String, dynamic>.from(x)];
}, retry: (_, _) => null);

String assessmentCampaignStatusLabel(String s) => switch (s) {
      'en_attente_financement' => 'En attente de financement · le financement n’est pas encore ouvert',
      'ouverte' => 'Ouverte aux candidats invités',
      'close' => 'Close',
      _ => s,
    };

class AssessmentCampaignsOrgScreen extends ConsumerWidget {
  const AssessmentCampaignsOrgScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final org = ref.read(companyContextProvider);
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _CreateSheet(org: org),
    );
    if (done == true) ref.invalidate(assessmentCampaignsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Campagnes d’évaluation',
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          const SizedBox(height: 8),
          evaluationCard([
            Text('Évaluer des candidats avec leur accord', style: mst(15, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Créez une campagne par famille de métiers et par mode d’évaluation, puis invitez des candidats. Le financement des campagnes n’est pas encore ouvert : '
              'aucun paiement n’est demandé et une campagne reste « en attente » tant qu’il ne l’est pas. Vous ne voyez que les résultats que les candidats ont accepté de partager.',
              style: mst(12.5, c: kGrey).copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            mButton('Créer une campagne', () => _create(context, ref)),
          ]),
          mSectionTitle('Mes campagnes'),
          ref.watch(assessmentCampaignsProvider).when(
                loading: evaluationLoading,
                error: (e, _) => evaluationError(ref, e, assessmentCampaignsProvider),
                data: (l) => l.isEmpty ? mNote('Aucune campagne pour le moment.') : Column(children: [for (final c in l) _CampaignCard(c)]),
              ),
        ]),
      );
}

class _CampaignCard extends ConsumerStatefulWidget {
  const _CampaignCard(this.c);
  final Map<String, dynamic> c;
  @override
  ConsumerState<_CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends ConsumerState<_CampaignCard> {
  bool _busy = false;

  Future<void> _invite() async {
    final txt = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Inviter un candidat'),
        content: TextField(controller: txt, keyboardType: TextInputType.emailAddress, autofocus: true, decoration: const InputDecoration(labelText: 'E-mail du candidat (étudiant ou client)')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Inviter'))],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await marcheCall('assessment_campaign_invite', _args(null, {'p_campaign': widget.c['id'], 'p_email': txt.text.trim()}));
    if (!mounted) return;
    setState(() => _busy = false);
    gToast(context, r.error != null ? _errorText(r.error) : 'Invitation traitée : si ce compte candidat existe, il est invité et notifié.');
    if (r.error == null) ref.invalidate(assessmentCampaignsProvider);
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Clôturer cette campagne ?'),
        content: Text('Plus aucun candidat ne pourra passer d’évaluation sur « ${widget.c['title']} ». Les résultats déjà partagés restent consultables.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Clôturer'))],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await marcheCall('assessment_campaign_close', {'p_campaign': widget.c['id']});
    if (!mounted) return;
    setState(() => _busy = false);
    gToast(context, r.error != null ? _errorText(r.error) : 'Campagne clôturée.');
    if (r.error == null) ref.invalidate(assessmentCampaignsProvider);
  }

  Future<void> _results() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => _ResultsSheet(campaignId: '${widget.c['id']}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final status = '${c['status']}';
    final canWrite = c['shared_results'] != null;
    return evaluationCard([
      Text('${c['title']}', style: mst(15, w: FontWeight.w800)),
      Text('${c['family_label']} · ${assessmentModes[c['mode']] ?? c['mode']} · ${evaluationDate(c['created_at'])}', style: mst(12, c: kGrey)),
      const SizedBox(height: 4),
      Text(assessmentCampaignStatusLabel(status), style: mst(12.5, w: FontWeight.w700, c: status == 'ouverte' ? kGreen : kViolet).copyWith(height: 1.4)),
      if ('${c['note'] ?? ''}'.isNotEmpty) Text('${c['note']}', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
      const SizedBox(height: 4),
      Text('Candidats invités : ${c['invited']}', style: mst(12.5, c: kGrey)),
      if (canWrite) Text('Résultats partagés par les candidats : ${c['shared_results']}', style: mst(12.5, c: kGrey)),
      if (canWrite) AssessmentProgressBlock(campaignId: '${c['id']}'),
      if (canWrite) ...[
        const SizedBox(height: 8),
        mButton('Résultats partagés', _results, dark: false),
        if (status != 'close') mButton('Inviter un candidat', _busy ? null : _invite, dark: false),
        if (status != 'close') mButton('Clôturer la campagne', _busy ? null : _close, dark: false),
      ],
    ]);
  }
}

class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet({required this.org});
  final String? org;
  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  final _title = TextEditingController();
  String? _family, _mode;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await marcheCall('assessment_campaign_create', _args(widget.org, {'p_title': _title.text.trim(), 'p_family': _family, 'p_mode': _mode}));
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _message = _errorText(r.error);
      });
      return;
    }
    gToast(context, r.data is Map && (r.data as Map)['message'] != null ? '${(r.data as Map)['message']}' : 'Campagne enregistrée « en attente de financement ».');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final families = ref.watch(assessmentFamiliesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nouvelle campagne', style: mst(18, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('La campagne sera enregistrée « en attente de financement » : aucun paiement n’est demandé.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 10),
          TextField(controller: _title, maxLength: 160, decoration: const InputDecoration(labelText: 'Titre de la campagne'), onChanged: (_) => setState(() {})),
          Text('Famille de métiers', style: mst(13.5, w: FontWeight.w800)),
          families.when(
            loading: evaluationLoading,
            error: (e, _) => evaluationError(ref, e, assessmentFamiliesProvider),
            data: (l) => l.isEmpty
                ? mNote('Aucune famille de métiers n’est disponible pour le moment.')
                : Column(children: [
                    for (final f in l)
                      InkWell(
                        onTap: () => setState(() => _family = '${f['code']}'),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(children: [
                            Icon(_family == '${f['code']}' ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _family == '${f['code']}' ? kViolet : kGrey, size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${f['label']}', style: mst(13.5))),
                          ]),
                        ),
                      ),
                  ]),
          ),
          const SizedBox(height: 8),
          Text('Mode d’évaluation', style: mst(13.5, w: FontWeight.w800)),
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
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!, style: mst(13, w: FontWeight.w700, c: kRed).copyWith(height: 1.4))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(context, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Créer', _title.text.trim().length < 2 || _family == null || _mode == null ? null : _send, busy: _busy)),
          ]),
        ]),
      ),
    );
  }
}

class _ResultsSheet extends StatefulWidget {
  const _ResultsSheet({required this.campaignId});
  final String campaignId;
  @override
  State<_ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends State<_ResultsSheet> {
  late final Future<Object?> _f = evaluationCall('assessment_campaign_results', {'p_campaign': widget.campaignId});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: FutureBuilder<Object?>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return evaluationLoading();
            if (s.hasError) return mNote('${s.error is EvaluationException ? s.error : Backend.userMessage('${s.error}')}');
            final d = s.data;
            if (d is! Map) return mNote(EvaluationException('shape').toString());
            final results = d['results'] is List ? [for (final x in d['results'] as List) if (x is Map) Map<String, dynamic>.from(x)] : <Map<String, dynamic>>[];
            return SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Résultats partagés', style: mst(18, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Candidats invités : ${d['invited']}. Seuls les résultats que les candidats ont accepté de partager apparaissent ici ; ils peuvent retirer ce partage à tout moment.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
                if (results.isEmpty) mNote('Aucun candidat n’a partagé de résultat pour le moment.'),
                for (final r in results)
                  evaluationCard([
                    Text('${r['candidate']}', style: mst(15, w: FontWeight.w800)),
                    Text('${assessmentValidationLabel('${r['validation_status']}')} · ${evaluationDate(r['created_at'])}${r['reused'] == true ? ' · évaluation existante partagée' : ''}', style: mst(12, c: kGrey)),
                    ...evaluationResultBlocks(r),
                  ]),
                const SizedBox(height: 10),
                mButton('Fermer', () => Navigator.pop(context), dark: false),
              ]),
            );
          },
        ),
      );
}
