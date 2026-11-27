import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'company_screens.dart' show companyContextProvider;
import 'lots.dart' show formDialog;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Suivi des missions de l'ORGANISATION, équipe comprise (migration 20261128060000) : jalons, preuves, paiement déclaré entre les parties (Boutik-École ne reçoit ni ne bloque d'argent), clôture et avis.
/// Les droits viennent du serveur (`can_decide`, `can_pay`) : propriétaire et administrateurs décident ; la finance déclare le paiement ; le lecteur consulte. Une erreur est dite erreur, jamais « 0 ».

const missionStatusLabels = {
  'published': 'Besoin publié',
  'assigned': 'Prestataire retenu',
  'in_progress': 'En cours',
  'delivered': 'Livrée',
  'closed': 'Clôturée',
};
const milestoneStatusLabels = {'pending': 'À venir', 'submitted': 'Livré, à examiner', 'validated': 'Validé', 'correction': 'Correction demandée'};

String missionMoney(Object? v) => v is num ? '${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA' : '—';

String missionPayLabel(Object? payStatus, Object? method) {
  final m = '${method ?? ''}'.trim();
  return switch ('$payStatus') {
    'confirmed' => 'Réglé : réception confirmée par le prestataire${m.isEmpty ? '' : ' ($m)'}',
    'declared' => 'Paiement déclaré${m.isEmpty ? '' : ' ($m)'} : en attente de confirmation du prestataire',
    _ => 'À régler directement avec le prestataire',
  };
}

final orgMissionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final org = ref.watch(companyContextProvider);
  final r = await marcheCall('org_missions', {'p_owner': ?org});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
}, retry: (_, _) => null);

class OrgMissionsTrackingScreen extends ConsumerWidget {
  const OrgMissionsTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(orgMissionsProvider);
    return MarchePage(
      title: 'Suivi des missions',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(orgMissionsProvider),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
          Text('Les missions de votre organisation, visibles par toute l’équipe. Les décisions sont réservées au propriétaire et aux administrateurs ; la finance déclare les paiements.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
          const SizedBox(height: 10),
          data.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Column(children: [
              Text('$e', textAlign: TextAlign.center, style: mst(13.5, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 8),
              mButton('Réessayer', () => ref.invalidate(orgMissionsProvider), dark: false, icon: Icons.refresh_rounded),
            ]),
            data: (l) => l.isEmpty ? mNote('Aucune mission en cours.\nQuand vous retenez un prestataire pour un besoin publié, la mission et ses jalons apparaissent ici.') : Column(children: [for (final m in l) _MissionCard(m: m, onChanged: () => ref.invalidate(orgMissionsProvider))]),
          ),
        ]),
      ),
    );
  }
}

class _MissionCard extends StatefulWidget {
  const _MissionCard({required this.m, required this.onChanged});
  final Map<String, dynamic> m;
  final VoidCallback onChanged;

  @override
  State<_MissionCard> createState() => _MissionCardState();
}

class _MissionCardState extends State<_MissionCard> {
  bool _busy = false;

  Future<void> _run(String fn, Map<String, dynamic> p, String done, {String title = 'Action non enregistrée'}) async {
    setState(() => _busy = true);
    final r = await marcheCall(fn, p);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, title, marcheErrorText(r.error));
      widget.onChanged();
      return;
    }
    gToast(context, done);
    widget.onChanged();
  }

  Future<void> _decide(Map<String, dynamic> j, bool validate) async {
    var note = '';
    if (!validate) {
      final v = await formDialog(context, 'Demander une correction', [('Correction attendue', '')], submit: 'Envoyer');
      if (v == null || !mounted) return;
      note = v.first;
    }
    await _run('decide_milestone', {'p_mission': widget.m['id'], 'p_position': j['position'], 'p_validate': validate, 'p_note': note}, validate ? 'Jalon validé.' : 'Correction demandée au prestataire.');
  }

  Future<void> _pay(Map<String, dynamic> j) async {
    final v = await formDialog(context, 'Déclarer le paiement', [('Moyen utilisé (Orange Money, MTN MoMo, espèces…)', ''), ('Référence de la transaction (facultatif)', '')],
        intro: 'Boutik-École ne reçoit ni ne bloque cet argent : vous réglez le prestataire directement. Cette déclaration est tracée et le prestataire doit confirmer la réception.', submit: 'Déclarer');
    if (v == null || !mounted) return;
    await _run('milestone_pay_declare', {'p_mission': widget.m['id'], 'p_position': j['position'], 'p_method': v[0], 'p_reference': v[1]}, 'Paiement déclaré : le prestataire est prévenu.');
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clôturer la mission ?'),
        content: const Text('Tous les jalons sont validés. Le prestataire est prévenu.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clôturer'))],
      ),
    );
    if (ok != true || !mounted) return;
    await _run('mission_close', {'p_mission': widget.m['id']}, 'Mission clôturée.');
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final status = '${m['status']}';
    final canDecide = m['can_decide'] == true, canPay = m['can_pay'] == true;
    final ms = [for (final x in (m['milestones'] as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${m['title']}', style: mst(15, w: FontWeight.w800)),
        Text([missionStatusLabels[status] ?? status, if ('${m['counterpart'] ?? ''}'.isNotEmpty) 'Prestataire : ${m['counterpart']}', missionMoney(m['total']), if ('${m['deadline'] ?? ''}'.isNotEmpty) 'avant le ${m['deadline']}'].join(' · '), style: mst(12.5, c: kGrey)),
        const SizedBox(height: 8),
        for (final j in ms)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF7F5FB), borderRadius: BorderRadius.circular(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Jalon ${j['position']} · ${j['title']} (${missionMoney(j['amount'])})', style: mst(13, w: FontWeight.w700)),
              Text(milestoneStatusLabels['${j['status']}'] ?? '${j['status']}', style: mst(12, c: kGrey)),
              if ('${j['proof_note'] ?? ''}'.isNotEmpty) Text('Preuve : ${j['proof_note']}', style: mst(12.5)),
              if ((j['proof_files'] as List? ?? const []).isNotEmpty) Text('${(j['proof_files'] as List).length} pièce(s) jointe(s)', style: mst(12, c: kGrey)),
              if ('${j['note'] ?? ''}'.isNotEmpty) Text('Note : ${j['note']}', style: mst(12.5)),
              if (j['status'] == 'validated') Text(missionPayLabel(j['pay_status'], j['pay_method']), style: mst(12, w: FontWeight.w600)),
              if (j['status'] == 'submitted' && canDecide)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(child: mButton('Correction', _busy ? null : () => _decide(j, false), dark: false)),
                    const SizedBox(width: 8),
                    Expanded(child: mButton('Valider', _busy ? null : () => _decide(j, true))),
                  ]),
                ),
              if (j['status'] == 'validated' && j['pay_status'] != 'confirmed' && j['pay_status'] != 'declared' && canPay)
                Padding(padding: const EdgeInsets.only(top: 6), child: mButton('Déclarer le paiement', _busy ? null : () => _pay(j), dark: false)),
            ]),
          ),
        if (status == 'delivered' && canDecide) mButton('Clôturer la mission', _busy ? null : _close),
        if (status == 'delivered' && !canDecide) Text('En attente de la clôture par le propriétaire ou un administrateur.', style: mst(12, c: kGrey)),
        if (status == 'closed') MissionReviewSection(missionId: '${m['id']}', canReview: canDecide),
      ]),
    );
  }
}

/// Avis de fin de mission (une fois la mission clôturée) : le client note le prestataire, le prestataire note le client, une fois chacun.
class MissionReviewSection extends StatefulWidget {
  const MissionReviewSection({super.key, required this.missionId, this.canReview = true});
  final String missionId;
  final bool canReview;

  @override
  State<MissionReviewSection> createState() => _MissionReviewSectionState();
}

class _MissionReviewSectionState extends State<MissionReviewSection> {
  List<Map<String, dynamic>>? _reviews;
  String? _error;
  int _rating = 0;
  bool _busy = false;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await marcheCall('mission_reviews_get', {'p_mission': widget.missionId});
    if (!mounted) return;
    setState(() {
      _error = r.error == null ? null : marcheErrorText(r.error);
      _reviews = r.error != null ? null : [for (final x in (r.data as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
    });
  }

  Future<void> _save() async {
    if (_rating < 1) return;
    setState(() => _busy = true);
    final r = await marcheCall('mission_review_save', {'p_mission': widget.missionId, 'p_rating': _rating, 'p_comment': _comment.text.trim()});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, 'Avis non enregistré', marcheErrorText(r.error));
      await _load();
      return;
    }
    gToast(context, 'Merci : votre avis est enregistré.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: mst(12.5, c: kGrey)));
    final l = _reviews;
    if (l == null) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    final mine = l.any((r) => r['mine'] == true);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text('Avis', style: mst(13.5, w: FontWeight.w800)),
      for (final r in l)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${r['mine'] == true ? 'Votre avis' : 'Avis reçu'} : ${r['rating']}/5${'${r['comment'] ?? ''}'.isEmpty ? '' : ' · ${r['comment']}'}', style: mst(12.5)),
        ),
      if (l.isEmpty && !widget.canReview) Text('Aucun avis pour le moment.', style: mst(12.5, c: kGrey)),
      if (!mine && widget.canReview) ...[
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 1; i <= 5; i++) IconButton(tooltip: '$i sur 5', onPressed: () => setState(() => _rating = i), icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_border_rounded, color: kViolet)),
        ]),
        TextField(
          controller: _comment,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(hintText: 'Commentaire (facultatif)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: kLine))),
        ),
        mButton('Publier mon avis', _rating < 1 || _busy ? null : _save, busy: _busy),
      ],
    ]);
  }
}
