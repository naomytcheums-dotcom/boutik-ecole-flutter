import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Séquestre de l'administration : l'argent payé est conservé jusqu'à la livraison, puis réparti selon la règle (70 / 20 / 10 par défaut, modifiable ici).
/// Seul l'administrateur bloque, débloque ou modifie la règle ; la finance consulte. Tout vient du serveur (migration 20261114002800).

final moneyOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('money_admin_overview', const {});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});

final moneyEntriesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, status) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('money_admin_list', {if (status.isNotEmpty) 'p_status': status, 'p_limit': 100});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

final moneyRuleProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('money_split_get', const {});
  if (r.error != null) throw MarcheException(r.error);
  return Map<String, dynamic>.from(r.data as Map);
});

const moneyStatuses = {'': 'Toutes', 'held': 'En séquestre', 'frozen': 'Bloquées', 'released': 'Débloquées', 'cod_due': 'À recouvrer', 'refunded': 'Remboursées'};

String moneyStatusLabel(String s) => switch (s) {
      'held' => 'En séquestre',
      'frozen' => 'Bloqué',
      'released' => 'Débloqué',
      'cod_due' => 'À recouvrer',
      'refunded' => 'Remboursé',
      _ => s,
    };

String moneyFcfa(Object? v) => '${((v as num?) ?? 0).toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ')} FCFA';

class MoneyAdminScreen extends ConsumerStatefulWidget {
  const MoneyAdminScreen({super.key});

  @override
  ConsumerState<MoneyAdminScreen> createState() => _MoneyState();
}

class _MoneyState extends ConsumerState<MoneyAdminScreen> {
  String _status = 'held';

  Future<void> _act(String fn, Map<String, dynamic> params, String ok) async {
    final r = await marcheCall(fn, params);
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : ok);
    ref.invalidate(moneyEntriesProvider);
    ref.invalidate(moneyOverviewProvider);
  }

  Future<void> _freeze(Map<String, dynamic> e) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Bloquer ${moneyFcfa(e['gross'])} ?'),
        content: TextField(controller: ctl, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif du blocage')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Bloquer'))],
      ),
    );
    final reason = ctl.text;
    ctl.dispose();
    if (ok == true && mounted) await _act('money_freeze', {'p_id': e['id'], 'p_reason': reason}, 'Montant bloqué.');
  }

  Future<void> _release(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Débloquer maintenant ?'),
        content: Text('${e['beneficiary']} recevra ${moneyFcfa(e['beneficiary_amount'])} sur son solde (commande ${e['ref']}). À utiliser seulement si la prestation est bien réalisée.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Débloquer'))],
      ),
    );
    if (ok == true && mounted) await _act('money_release_now', {'p_id': e['id']}, 'Montant débloqué.');
  }

  Future<void> _editRule(Map<String, dynamic> cur) async {
    final b = TextEditingController(text: '${cur['beneficiary_pct']}'), i = TextEditingController(text: '${cur['institution_pct']}'), p = TextEditingController(text: '${cur['platform_pct']}'), note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Règle de répartition'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: b, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prestataire (étudiant) %')),
            TextField(controller: i, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fonds de l’institution %')),
            TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Plateforme %')),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Motif (facultatif)')),
            const SizedBox(height: 8),
            Text('Le total doit faire 100 %. La nouvelle règle ne s’applique qu’aux paiements futurs ; l’historique est conservé.', style: mst(12, c: kGrey)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Enregistrer'))],
      ),
    );
    int n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    final vals = [n(b), n(i), n(p)];
    final why = note.text;
    for (final c in [b, i, p, note]) {
      c.dispose();
    }
    if (ok == true && mounted) {
      await _act('money_split_set', {'p_beneficiary': vals[0], 'p_institution': vals[1], 'p_platform': vals[2], 'p_note': why}, 'Règle enregistrée.');
      ref.invalidate(moneyRuleProvider);
    }
  }

  Widget _tile(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.all(5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: mst(15, w: FontWeight.w800)), Text(label, style: mst(11.5, c: kGrey))]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider.select((a) => a.current?.staff == 'Admin global'));
    return MarchePage(
      title: 'Séquestre',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mAsync<Map<String, dynamic>>(
          ref.watch(moneyOverviewProvider),
          (o) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Column(children: [
              Row(children: [_tile('En séquestre', moneyFcfa(o['held'])), _tile('Bloqué', moneyFcfa(o['frozen']))]),
              Row(children: [_tile('Débloqué aux étudiants', moneyFcfa(o['released_beneficiaries'])), _tile('À recouvrer (livraison)', moneyFcfa(o['cod_due']))]),
              Row(children: [_tile('Fonds de l’institution', moneyFcfa(o['institution_fund'])), _tile('Plateforme', moneyFcfa(o['platform']))]),
            ]),
          ),
        ),
        mAsync<Map<String, dynamic>>(
          ref.watch(moneyRuleProvider),
          (r) {
            final c = Map<String, dynamic>.from(r['current'] as Map);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Expanded(child: Text('Règle : ${c['beneficiary_pct']} % étudiant · ${c['institution_pct']} % institution · ${c['platform_pct']} % plateforme', style: mst(13, w: FontWeight.w700))),
                if (admin) TextButton(onPressed: () => _editRule(c), child: Text('Modifier')),
              ]),
            );
          },
        ),
        mSectionTitle('Lignes'),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final e in moneyStatuses.entries)
              GestureDetector(
                onTap: () => setState(() => _status = e.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _status == e.key ? kInk : const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(17)),
                  child: Text(e.value, style: mst(12.5, w: FontWeight.w600, c: _status == e.key ? Colors.white : kGrey)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(moneyEntriesProvider(_status)),
          (l) => l.isEmpty
              ? mNote('Aucune ligne pour ce filtre.')
              : Column(children: [
                  for (final e in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text('${e['ref']} · ${moneyFcfa(e['gross'])}', style: mst(14, w: FontWeight.w800))), Text(moneyStatusLabel('${e['status']}'), style: mst(12, w: FontWeight.w700, c: e['status'] == 'frozen' ? kRed : kViolet))]),
                        Text('${e['beneficiary']} : ${moneyFcfa(e['beneficiary_amount'])} · institution ${moneyFcfa(e['institution_amount'])} · plateforme ${moneyFcfa(e['platform_amount'])}', style: mst(12, c: kGrey)),
                        if ('${e['frozen_reason'] ?? ''}'.isNotEmpty) Text('Motif : ${e['frozen_reason']}', style: mst(12, c: kRed)),
                        if (admin && (e['status'] == 'held' || e['status'] == 'frozen'))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(children: [
                              if (e['status'] == 'held') Expanded(child: mButton('Bloquer', () => _freeze(e), dark: false)) else Expanded(child: mButton('Débloquer le blocage', () => _act('money_unfreeze', {'p_id': e['id']}, 'Blocage levé.'), dark: false)),
                              const SizedBox(width: 10),
                              if ('${e['beneficiary']}' != 'Plateforme') Expanded(child: mButton('Débloquer', () => _release(e))),
                            ]),
                          ),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}
