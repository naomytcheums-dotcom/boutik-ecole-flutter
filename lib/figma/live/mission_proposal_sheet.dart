import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart' show authProvider, requireLogin;
import 'marche/marche_data.dart';

/// Action Unique « Postuler » d'un live sur un besoin publié (migration 20261128022000) : fiche du besoin (`mission_public_card`) puis formulaire de proposition (`propose_on_mission`).
/// Le serveur décide de tout (rôle, capacité vendeur, une proposition en attente à la fois, trois essais) : cette feuille n'affiche que ses réponses et ne confirme rien si l'écriture échoue.

final missionCardProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('mission_public_card', {'p_mission': id});
  if (r.error != null) throw MarcheException(r.error);
  if (r.data is! Map) throw MarcheException('Besoin introuvable');
  return Map<String, dynamic>.from(r.data as Map);
}, retry: (_, _) => null);

/// Ce que le demandeur peut faire sur la fiche : `form` (proposer), ou un message d'état honnête sans formulaire.
({bool form, String? note}) missionProposalState(Map<String, dynamic> c) {
  if (c['own'] == true) return (form: false, note: 'C’est votre propre besoin : vous ne pouvez pas y répondre.');
  if (c['open'] != true) return (form: false, note: 'Ce besoin ne reçoit plus de propositions.');
  if ('${c['role']}' != 'student') return (form: false, note: 'Seuls les comptes étudiants peuvent répondre à un besoin.');
  final block = '${c['block_reason'] ?? ''}'.trim();
  if (block.isNotEmpty) return (form: false, note: block);
  final mine = c['my_status'];
  final attempts = c['my_attempts'] is num ? (c['my_attempts'] as num).toInt() : 0;
  if (mine == 'submitted') return (form: false, note: 'Votre proposition est envoyée : l’organisation vous répondra.');
  if (mine == 'accepted') return (form: false, note: 'Votre proposition a été acceptée.');
  if (mine != null && attempts >= 3) return (form: false, note: 'Vous avez déjà fait trois propositions sur ce besoin.');
  return (form: true, note: null);
}

class MissionProposalSheet extends ConsumerStatefulWidget {
  const MissionProposalSheet({super.key, required this.missionId});
  final String missionId;

  @override
  ConsumerState<MissionProposalSheet> createState() => _MissionProposalSheetState();
}

class _MissionProposalSheetState extends ConsumerState<MissionProposalSheet> {
  final _amount = TextEditingController(), _days = TextEditingController(), _msg = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _days.dispose();
    _msg.dispose();
    super.dispose();
  }

  int? _digits(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _send() async {
    if (_busy) return;
    final amount = _digits(_amount.text), days = _digits(_days.text);
    if (amount == null || amount <= 0) return setState(() => _error = 'Indiquez un montant supérieur à 0.');
    if (days == null || days < 1 || days > 365) return setState(() => _error = 'Indiquez un délai de 1 à 365 jours.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await marcheCall('propose_on_mission', {'p_mission': widget.missionId, 'p_amount': amount, 'p_delay_days': days, 'p_message': _msg.text});
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _error = marcheErrorText(r.error);
      });
      return;
    }
    gToast(context, 'Proposition envoyée. L’organisation vous répondra.');
    ref.invalidate(missionCardProvider(widget.missionId));
    setState(() => _busy = false);
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));

  String _budget(Map<String, dynamic> c) {
    final a = c['budget_min'], b = c['budget_max'];
    if (a == null && b == null) return '';
    if (a != null && b != null && a != b) return 'Budget : ${mFcfa(a)} à ${mFcfa(b)}';
    return 'Budget : ${mFcfa(b ?? a)}';
  }

  @override
  Widget build(BuildContext context) {
    final card = ref.watch(missionCardProvider(widget.missionId));
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4FA),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Postuler à un besoin', style: mst(18, w: FontWeight.w800)),
        actions: [IconButton(tooltip: 'Fermer', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop())],
      ),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(e is MarcheException ? e.toString() : marcheErrorText('$e'), key: const Key('mission-card-error'), textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: () => ref.invalidate(missionCardProvider(widget.missionId)), child: Text('Réessayer', style: mst(14, w: FontWeight.w700))),
            ]),
          ),
        ),
        data: (c) {
          final st = missionProposalState(c);
          final meta = [
            if (_budget(c).isNotEmpty) _budget(c),
            if ('${c['deadline'] ?? ''}'.isNotEmpty) 'Avant le ${c['deadline']}',
            '${mInt(c['proposals'])} proposition${mInt(c['proposals']) > 1 ? 's' : ''}',
          ].join(' · ');
          return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.of(context).viewInsets.bottom), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text('${c['company'] ?? ''}', style: mst(11.5, w: FontWeight.w700, c: kViolet), overflow: TextOverflow.ellipsis)),
                  if (c['verified'] == true) ...[const SizedBox(width: 4), const Icon(Icons.verified, size: 14, color: kGreen)],
                ]),
                const SizedBox(height: 4),
                Text('${c['title']}', style: mst(16, w: FontWeight.w800)),
                if ('${c['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${c['description']}', style: mst(13, c: kGrey).copyWith(height: 1.45))),
                const SizedBox(height: 8),
                Text(meta, style: mst(12, c: kGrey)),
              ]),
            ),
            const SizedBox(height: 16),
            if (!st.form)
              Text(st.note ?? '', key: const Key('mission-proposal-note'), style: mst(13.5, c: kGrey).copyWith(height: 1.5))
            else ...[
              Text('Ma proposition', style: mst(16, w: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(key: const Key('mission-amount'), controller: _amount, keyboardType: TextInputType.number, decoration: _deco('Montant proposé (FCFA)')),
              const SizedBox(height: 12),
              TextField(key: const Key('mission-days'), controller: _days, keyboardType: TextInputType.number, decoration: _deco('Délai (jours)')),
              const SizedBox(height: 12),
              TextField(key: const Key('mission-message'), controller: _msg, maxLines: 4, decoration: _deco('Votre solution', hint: 'Expliquez en quelques lignes comment vous répondez au besoin')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const Key('mission-proposal-error'), style: mst(13, w: FontWeight.w600, c: kRed))),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('mission-send'),
                onPressed: _busy ? null : _send,
                style: FilledButton.styleFrom(backgroundColor: kInk, minimumSize: const Size.fromHeight(48)),
                child: Text(_busy ? 'Un instant…' : 'Envoyer ma proposition', style: mst(14, w: FontWeight.w700, c: Colors.white)),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

/// Ouvre la feuille depuis l'Action Unique : le visiteur est d'abord invité à se connecter.
Future<void> openMissionProposal(BuildContext context, WidgetRef ref, String missionId, Future<void> Function(Widget) sheet) async {
  if (!await requireLogin(context, ref, 'postuler à un besoin') || !context.mounted) return;
  return sheet(MissionProposalSheet(missionId: missionId));
}
