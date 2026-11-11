import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../gen.dart' show gToast;
import '../../i18n.dart' show Text;
import '../../nav.dart' show gOpenProfile;
import '../auth.dart';
import '../backend.dart';
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Appel à entreprises et projets de l'IUT. Une entreprise publie « Je cherche une solution pour… » (écran 90, déjà existant) ;
/// les étudiants répondent depuis cette page avec un montant, un délai et un message.

final marcheCallsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('open_calls', const {'p_limit': 50});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

final marcheIutProjectsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await marcheCall('iut_projects', const {'p_limit': 60});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

String _budget(Map<String, dynamic> c) {
  final a = c['budget_min'], b = c['budget_max'];
  if (a == null && b == null) return '';
  if (a != null && b != null && a != b) return 'Budget : ${mFcfa(a)} à ${mFcfa(b)}';
  return 'Budget : ${mFcfa(b ?? a)}';
}

class AppelsScreen extends ConsumerWidget {
  const AppelsScreen({super.key});

  Future<void> _propose(BuildContext context, WidgetRef ref, Map<String, dynamic> call) async {
    if (!await requireLogin(context, ref, 'répondre à un appel') || !context.mounted) return;
    final amount = TextEditingController(), days = TextEditingController(), msg = TextEditingController();
    InputDecoration deco(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ma proposition', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${call['title']}', style: mst(13, c: kGrey)),
            const SizedBox(height: 14),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: deco('Montant proposé (FCFA)')),
            const SizedBox(height: 12),
            TextField(controller: days, keyboardType: TextInputType.number, decoration: deco('Délai (jours)')),
            const SizedBox(height: 12),
            TextField(controller: msg, maxLines: 4, decoration: deco('Votre solution', hint: 'Expliquez en quelques lignes comment vous répondez au besoin')),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
              const SizedBox(width: 12),
              Expanded(child: mButton('Envoyer', () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    int? digits(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    final r = await marcheCall('propose_on_mission', {'p_mission': call['id'], 'p_amount': digits(amount.text), 'p_delay_days': digits(days.text), 'p_message': msg.text});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Proposition envoyée. L’entreprise vous répondra.');
    ref.invalidate(marcheCallsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Appel à entreprises',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('Une entreprise publie « Je cherche une solution pour… » ; les étudiants répondent avec un prix, un délai et leur solution.', style: mst(13, c: kGrey).copyWith(height: 1.5)),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: mButton('Publier mon besoin', () => context.push('/s/90'), icon: Icons.add)),
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(marcheCallsProvider),
          (l) => l.isEmpty
              ? mNote('Aucun appel publié pour le moment.\nLes besoins des entreprises apparaîtront ici dès leur publication.')
              : Column(children: [
                  for (final c in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c['company']}', style: mst(11.5, w: FontWeight.w700, c: kViolet)),
                        const SizedBox(height: 4),
                        Text('${c['title']}', style: mst(15, w: FontWeight.w800)),
                        if ('${c['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${c['description']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: mst(13, c: kGrey).copyWith(height: 1.45))),
                        const SizedBox(height: 8),
                        Text([if (_budget(c).isNotEmpty) _budget(c), if ('${c['deadline'] ?? ''}'.isNotEmpty) 'Avant le ${c['deadline']}', '${mInt(c['proposals'])} proposition${mInt(c['proposals']) > 1 ? 's' : ''}'].join(' · '), style: mst(12, c: kGrey)),
                        const SizedBox(height: 12),
                        if (c['own'] == true)
                          Text('Votre besoin', style: mst(12.5, w: FontWeight.w700, c: kGreen))
                        else if (c['proposed'] == true)
                          Text('Proposition envoyée', style: mst(12.5, w: FontWeight.w700, c: kGreen))
                        else
                          mButton('Proposer une solution', () => _propose(context, ref, c), width: double.infinity),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}

/// Projets de l'IUT : les projets validés, regroupés par filière.
class ProjetsIutScreen extends ConsumerWidget {
  const ProjetsIutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Projets de l’IUT',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mAsync<List<Map<String, dynamic>>>(ref.watch(marcheIutProjectsProvider), (l) {
          if (l.isEmpty) return mNote('Aucun projet validé pour le moment.\nLes meilleurs projets de chaque filière apparaîtront ici après validation.');
          final byDept = <String, List<Map<String, dynamic>>>{};
          for (final p in l) {
            byDept.putIfAbsent('${p['department']}', () => []).add(p);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in byDept.entries) ...[
              mSectionTitle(e.key),
              for (final p in e.value)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => gOpenProfile(context, '${p['owner_id']}'),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p['title']}', style: mst(14.5, w: FontWeight.w800)),
                      if ('${p['summary'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p['summary']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: mst(12.5, c: kGrey).copyWith(height: 1.4))),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.verified_outlined, size: 16, color: kGreen),
                        const SizedBox(width: 6),
                        Flexible(child: Text('Projet validé par l’IUT de Douala · ${p['owner']}', style: mst(11.5, w: FontWeight.w700, c: kGreen))),
                      ]),
                    ]),
                  ),
                ),
            ],
          ]);
        }),
      ]),
    );
  }
}
