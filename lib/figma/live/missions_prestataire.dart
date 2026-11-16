import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../i18n.dart' show Text;
import '../nav.dart';
import 'backend.dart';
import 'docs_prestataire.dart' show downloadMissionInvoice, downloadSellerStatement;
import 'lots.dart' show openNeedsDialog, missionDossierDialog, pickAndUpload, payStatusLabel;
import 'missions.dart';

/// Suivi des missions côté prestataire : écran 201 (missions retenues, règlements, propositions envoyées), écran 195 (preuve de livraison)
/// et changement de mission des écrans 192 à 197. Toutes les données viennent des fonctions serveur my_missions, my_proposals, submit_milestone…
/// Aucun séquestre : le règlement de chaque jalon se fait directement avec le client ; l'application le trace (déclaration puis confirmation).

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _st = TextStyle(fontFamily: 'Inter', fontSize: 13, color: _ink);
const _muted = TextStyle(fontFamily: 'Inter', fontSize: 12, color: _grey);

int _n(Object? v) => ((v as num?) ?? 0).toInt();

String _money(Object? v) {
  final s = '${_n(v)}';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b FCFA';
}

List<Map<String, dynamic>> _maps(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

/// Position du jalon que le prestataire peut livrer maintenant : le premier jalon à livrer ou à corriger dont tous les précédents sont validés ;
/// null si un jalon attend la décision du client ou si tout est validé.
int? nextDeliverablePosition(List<Map<String, dynamic>> milestones) {
  final sorted = [...milestones]..sort((a, b) => _n(a['position']).compareTo(_n(b['position'])));
  for (final j in sorted) {
    final s = '${j['status']}';
    if (s == 'pending' || s == 'correction') return _n(j['position']);
    if (s == 'submitted') return null;
  }
  return null;
}

/// Libellé du rôle d'une mission dans les listes de choix.
String missionRoleLabel(String role) => role == 'client' ? 'mon besoin' : 'ma mission de prestataire';

String _statusLabel(String s) => switch (s) {
      'pending' => 'À livrer',
      'submitted' => 'Livré, à valider par le client',
      'validated' => 'Validé',
      'correction' => 'Correction demandée',
      _ => s,
    };

String proposalStatusLabel(String s) => switch (s) {
      'submitted' => 'En attente de réponse du client',
      'accepted' => 'Retenue',
      'declined' => 'Non retenue',
      'withdrawn' => 'Retirée',
      _ => s,
    };

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEEECE8))),
      child: child,
    );

/// Choix de la mission affichée par les écrans 192 à 197 (et facture PDF).
Future<void> missionSwitcherDialog(BuildContext context, WidgetRef ref) async {
  final fetched = await Backend.myMissionsList();
  final List<Map<String, dynamic>> all = (fetched != null && fetched.isNotEmpty) ? fetched : [...ref.read(missionChoicesProvider)];
  if (!context.mounted) return;
  if (all.isEmpty) return gAlert(context, 'Mes missions', 'Aucune mission pour le moment.');
  final current = ref.read(missionProvider).uuid;
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Mes missions', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final m in all)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['title']}${'${m['id']}' == current ? ' (affichée)' : ''}', style: _st.copyWith(fontWeight: FontWeight.w600)),
                  Text('${m['number']} · ${missionStatusLabel('${m['status']}')} · ${missionRoleLabel('${m['role']}')}', style: _muted),
                  Wrap(spacing: 8, children: [
                    TextButton(
                      onPressed: () {
                        selectMission(ref, '${m['id']}');
                        Navigator.pop(ctx);
                      },
                      child: const Text('Afficher'),
                    ),
                    if (m['agreement'] != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          downloadMissionInvoice(context, ref, '${m['id']}');
                        },
                        child: const Text('Facture (PDF)'),
                      ),
                  ]),
                ]),
              ),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
}

/// Écran 201 « Mes missions » : missions retenues avec leurs jalons, règlements à confirmer, propositions envoyées, relevé de ventes.
class ProviderMissionsPanel extends ConsumerStatefulWidget {
  const ProviderMissionsPanel({super.key});

  @override
  ConsumerState<ProviderMissionsPanel> createState() => _ProviderMissionsPanelState();
}

class _ProviderMissionsPanelState extends ConsumerState<ProviderMissionsPanel> {
  List<Map<String, dynamic>>? _missions;
  List<Map<String, dynamic>>? _proposals;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await Backend.myMissionsList();
    final props = await Backend.rpc('my_proposals', const {});
    if (!mounted) return;
    setState(() {
      _error = all == null || props.error != null;
      _missions = [for (final m in all ?? const <Map<String, dynamic>>[]) if (m['role'] == 'provider') m];
      _proposals = props.data is List ? _maps(props.data) : const [];
    });
  }

  Future<void> _act(Future<({Object? data, String? error})> Function() call, String ok) async {
    final r = await call();
    if (!mounted) return;
    if (r.error != null) {
      await gAlert(context, 'Action impossible', r.error!);
      return;
    }
    gToast(context, ok);
    await _load();
    ref.read(missionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final missions = _missions;
    if (missions == null) return const Center(child: Text('Chargement…', style: _muted));
    final built = [for (final m in missions) missionFromMyMissions(m)];
    final active = built.where((m) => m.status == 'assigned' || m.status == 'in_progress').length;
    final paid = built.fold(0, (a, m) => a + m.confirmedPaid);
    final toPay = built.fold(0, (a, m) => a + m.validatedUnpaid);
    final waiting = built.fold(0, (a, m) => a + m.awaitingValidation);
    final proposals = _proposals ?? const [];
    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: _st.copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: _muted, textAlign: TextAlign.center),
          ]),
        );
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card(
          child: Column(children: [
            Row(children: [stat('En cours', '$active'), stat('Réglé par les clients', _money(paid))]),
            const SizedBox(height: 10),
            Row(children: [stat('Validé, à régler', _money(toPay)), stat('Livré, à valider', _money(waiting))]),
            const SizedBox(height: 8),
            Text('Montants des jalons selon l’état convenu avec chaque client. Boutik-École ne bloque ni ne verse l’argent d’une mission : chaque règlement se fait directement et se confirme ici.', style: _muted),
          ]),
        ),
        if (_error) _card(child: Text('Lecture incomplète : réessayez dans un instant.', style: _muted)),
        if (missions.isEmpty && proposals.isEmpty)
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aucune mission retenue pour le moment.', style: _st.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Proposez-vous sur un besoin : vos propositions et leur état apparaîtront ici.', style: _muted),
              TextButton(onPressed: () => openNeedsDialog(context, ref), child: const Text('Voir les besoins à pourvoir')),
            ]),
          ),
        for (final m in missions) _missionCard(m),
        if (proposals.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text('Mes propositions', style: _st.copyWith(fontWeight: FontWeight.w700))),
          for (final p in proposals)
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['title']}', style: _st.copyWith(fontWeight: FontWeight.w600)),
                Text('${_money(p['amount'])} en ${p['delay_days']} j · ${proposalStatusLabel('${p['status']}')}', style: _muted),
                if (p['status'] == 'submitted')
                  TextButton(onPressed: () => _act(() => Backend.rpc('withdraw_proposal', {'p_id': p['id']}), 'Proposition retirée.'), child: const Text('Retirer ma proposition')),
              ]),
            ),
        ],
        TextButton(onPressed: () => downloadSellerStatement(context, ref), child: const Text('Relevé de ventes et de missions (PDF)')),
        TextButton(onPressed: () => openNeedsDialog(context, ref), child: const Text('Besoins à pourvoir')),
      ]),
    );
  }

  Widget _missionCard(Map<String, dynamic> m) {
    final miles = _maps(m['milestones']);
    final next = nextDeliverablePosition(miles);
    final mission = missionFromMyMissions(m);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${m['title']}', style: _st.copyWith(fontWeight: FontWeight.w700)),
        Text('${m['number']} · ${missionStatusLabel('${m['status']}')} · ${mission.pct} % · ${_money(m['total'])}${mission.invoice.isEmpty ? '' : ' · facture ${mission.invoice}'}', style: _muted),
        const SizedBox(height: 8),
        for (final j in miles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Jalon ${j['position']} · ${j['title']} · ${_money(j['amount'])}', style: _st.copyWith(fontWeight: FontWeight.w600)),
              Text(_statusLabel('${j['status']}') + (j['status'] == 'validated' ? '\n${payStatusLabel('${j['pay_status']}', '${j['pay_method'] ?? ''}')}' : '') + (j['status'] == 'correction' && '${j['note'] ?? ''}'.isNotEmpty ? '\nCorrection : ${j['note']}' : ''), style: _muted),
              Wrap(spacing: 6, children: [
                if (next == _n(j['position']))
                  TextButton(
                    onPressed: () {
                      selectMission(ref, '${m['id']}');
                      gOpen(context, '195');
                    },
                    child: Text(j['status'] == 'correction' ? 'Livrer la correction' : 'Livrer ce jalon'),
                  ),
                if (j['pay_status'] == 'declared') ...[
                  TextButton(
                    onPressed: () => _act(() => Backend.rpc('milestone_pay_confirm', {'p_mission': m['id'], 'p_position': j['position'], 'p_received': true}), 'Réception confirmée : le client est prévenu.'),
                    child: const Text('Confirmer la réception'),
                  ),
                  TextButton(
                    onPressed: () => _act(() => Backend.rpc('milestone_pay_confirm', {'p_mission': m['id'], 'p_position': j['position'], 'p_received': false}), 'Le client est prévenu : paiement non reçu.'),
                    child: const Text('Paiement non reçu'),
                  ),
                ],
              ]),
            ]),
          ),
        Wrap(spacing: 6, children: [
          TextButton(
            onPressed: () {
              selectMission(ref, '${m['id']}');
              gOpen(context, '194');
            },
            child: const Text('Suivi'),
          ),
          TextButton(
            onPressed: () {
              selectMission(ref, '${m['id']}');
              missionDossierDialog(context, ref);
            },
            child: const Text('Dossier'),
          ),
          if (m['agreement'] != null) TextButton(onPressed: () => downloadMissionInvoice(context, ref, '${m['id']}'), child: const Text('Facture (PDF)')),
        ]),
      ]),
    );
  }
}

/// Écran 195 « Ajouter une preuve » : décrit le travail réalisé et joint des photos ou fichiers (compartiment privé project-files, enregistrés
/// dans le dossier de la mission), puis envoie le jalon pour validation (submit_milestone). Le client voit la preuve avant de valider.
class ProofPanel extends ConsumerStatefulWidget {
  const ProofPanel({super.key});

  @override
  ConsumerState<ProofPanel> createState() => _ProofPanelState();
}

class _ProofPanelState extends ConsumerState<ProofPanel> {
  List<Map<String, dynamic>>? _missions;
  String _missionId = '';
  final _note = TextEditingController();
  final List<String> _files = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await Backend.myMissionsList();
    if (!mounted) return;
    final mine = [for (final m in all ?? const <Map<String, dynamic>>[]) if (m['role'] == 'provider' && (m['status'] == 'assigned' || m['status'] == 'in_progress')) m];
    final current = ref.read(missionProvider);
    setState(() {
      _missions = mine;
      if (!mine.any((m) => '${m['id']}' == _missionId)) {
        _missionId = current.isProvider && mine.any((m) => '${m['id']}' == current.uuid) ? current.uuid : (mine.isEmpty ? '' : '${mine.first['id']}');
        _files.clear();
      }
    });
  }

  Future<void> _attach(String missionId) async {
    if (_files.length >= 5) return gToast(context, 'Cinq pièces au plus par livraison.');
    final id = await pickAndUpload(context, ref, 'mission', missionId);
    if (id != null && mounted) setState(() => _files.add(id));
  }

  Future<void> _send(String missionId, int position) async {
    final note = _note.text.trim();
    if (note.length < 10 && _files.isEmpty) {
      return gAlert(context, 'Preuve manquante', 'Décrivez ce qui a été réalisé (10 caractères minimum) ou ajoutez une photo ou un fichier.');
    }
    setState(() => _busy = true);
    final r = await Backend.rpc('submit_milestone', {'p_mission': missionId, 'p_position': position, 'p_note': note, 'p_files': _files});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Envoi impossible', r.error!);
    _note.clear();
    _files.clear();
    gToast(context, 'Jalon envoyé pour validation : le client est notifié et voit votre preuve.');
    ref.read(missionProvider.notifier).refresh();
    gOpen(context, '201');
  }

  @override
  Widget build(BuildContext context) {
    final missions = _missions;
    if (missions == null) return const Center(child: Text('Chargement…', style: _muted));
    if (missions.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aucune mission à livrer.', style: _st.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('La preuve s’ajoute sur un jalon d’une mission qui vous est attribuée. Vos propositions en attente sont dans « Mes missions ».', style: _muted),
            TextButton(onPressed: () => gOpen(context, '201'), child: const Text('Mes missions')),
            TextButton(onPressed: () => openNeedsDialog(context, ref), child: const Text('Besoins à pourvoir')),
          ]),
        ),
      ]);
    }
    final m = missions.firstWhere((x) => '${x['id']}' == _missionId, orElse: () => missions.first);
    final miles = _maps(m['milestones']);
    final next = nextDeliverablePosition(miles);
    final target = next == null ? null : miles.firstWhere((j) => _n(j['position']) == next);
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (missions.length > 1)
          Wrap(spacing: 8, children: [
            for (final x in missions)
              ChoiceChip(
                label: Text('${x['title']}'),
                selected: '${x['id']}' == '${m['id']}',
                onSelected: (_) => setState(() {
                  _missionId = '${x['id']}';
                  _files.clear();
                }),
              ),
          ]),
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['title']}', style: _st.copyWith(fontWeight: FontWeight.w700)),
            Text('${m['number']} · ${missionStatusLabel('${m['status']}')}', style: _muted),
            const SizedBox(height: 8),
            for (final j in miles) Text('Jalon ${j['position']} · ${j['title']} — ${_statusLabel('${j['status']}')} · ${_money(j['amount'])}', style: _st.copyWith(fontSize: 12.5)),
          ]),
        ),
        if (target == null)
          _card(child: Text(miles.any((j) => j['status'] == 'submitted') ? 'Un jalon est en attente de validation du client : vous pourrez livrer le suivant une fois qu’il sera validé.' : 'Tous les jalons sont livrés.', style: _muted))
        else
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Jalon ${target['position']} · ${target['title']}', style: _st.copyWith(fontWeight: FontWeight.w700)),
              if (target['status'] == 'correction' && '${target['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Correction demandée : ${target['note']}', style: _muted)),
              const SizedBox(height: 10),
              Text('Ce qui a été réalisé', style: _st.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(controller: _note, maxLines: 4, maxLength: 2000, style: _st, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: 'Décrivez le travail livré (10 caractères minimum)')),
              Text(_files.isEmpty ? 'Aucune pièce jointe (photo, PDF, vidéo MP4 ou ZIP).' : '${_files.length} pièce(s) jointe(s) au dossier.', style: _muted),
              Wrap(spacing: 8, children: [
                TextButton(onPressed: _busy ? null : () => _attach('${m['id']}'), child: const Text('Ajouter une photo ou un fichier')),
                if (_files.isNotEmpty) TextButton(onPressed: _busy ? null : () => setState(_files.clear), child: const Text('Retirer les pièces')),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _busy ? null : () => _send('${m['id']}', _n(target['position'])), child: Text(_busy ? 'Envoi…' : 'Envoyer pour validation')),
              ),
              const SizedBox(height: 6),
              Text('Le client est notifié, voit votre texte et vos pièces, puis valide ou demande une correction. Le règlement se fait directement avec lui.', style: _muted),
            ]),
          ),
      ]),
    );
  }
}
