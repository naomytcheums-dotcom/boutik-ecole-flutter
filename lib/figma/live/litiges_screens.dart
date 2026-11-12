import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Litiges sur les commandes à payer à la livraison : le vendeur signale un refus de payer, l'acheteur répond, l'équipe tranche
/// (clore, ou annuler la commande et remettre le stock). Tout vient du serveur (migration 20261114002000).

final disputesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('my_disputes', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

/// « Le client refuse de payer » : décrit le problème puis ouvre le litige (commande à payer à la livraison, prête ou livrée, non encaissée).
Future<void> openDisputeDialog(BuildContext context, WidgetRef ref, String orderNumber) async {
  final note = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Litige sur $orderNumber', style: mst(18, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('L’acheteur est prévenu et peut répondre. L’équipe de la plateforme tranche.', style: mst(12.5, c: kGrey)),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 4, maxLength: 1000, decoration: InputDecoration(labelText: 'Ce qui s’est passé', hintText: 'Le client a refusé de payer à la remise parce que…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
          const SizedBox(width: 10),
          Expanded(child: mButton('Ouvrir le litige', () => Navigator.pop(c, true))),
        ]),
      ]),
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await marcheCall('dispute_open', {'p_order': orderNumber, 'p_note': note.text});
  if (!context.mounted) return;
  gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Litige ouvert. L’acheteur et l’équipe sont prévenus.');
  ref.invalidate(disputesProvider);
}

String disputeStateLabel(Map<String, dynamic> d) {
  if (d['status'] != 'resolved') return d['buyer_reply'] == null ? 'Ouvert · en attente de réponse' : 'Ouvert · l’acheteur a répondu';
  return d['decision'] == 'cancel' ? 'Tranché · commande annulée' : 'Tranché · litige clos';
}

class DisputesScreen extends ConsumerWidget {
  const DisputesScreen({super.key});

  Future<void> _reply(BuildContext context, WidgetRef ref, Map<String, dynamic> d) async {
    final txt = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Votre réponse'),
        content: TextField(controller: txt, maxLines: 4, maxLength: 1000, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Envoyer'))],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('dispute_reply', {'p_id': d['id'], 'p_reply': txt.text});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Réponse envoyée.');
    ref.invalidate(disputesProvider);
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, Map<String, dynamic> d, String decision) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(decision == 'cancel' ? 'Annuler la commande ?' : 'Clore le litige ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(decision == 'cancel' ? 'La commande est annulée et le stock remis en vente.' : 'La commande reste telle quelle.'),
          TextField(controller: note, maxLength: 500, decoration: const InputDecoration(labelText: 'Note (facultative)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Confirmer'))],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = await marcheCall('dispute_decide', {'p_id': d['id'], 'p_decision': decision, 'p_note': note.text});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Décision enregistrée.');
    ref.invalidate(disputesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Mes litiges',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        mAsync<List<Map<String, dynamic>>>(
          ref.watch(disputesProvider),
          (l) => l.isEmpty
              ? mNote('Aucun litige.\nUn litige s’ouvre quand un client refuse de payer une commande à la remise.')
              : Column(children: [
                  for (final d in l)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Commande ${d['order_number']}', style: mst(15, w: FontWeight.w800)),
                        Text(disputeStateLabel(d), style: mst(12, w: FontWeight.w700, c: d['status'] == 'resolved' ? kGreen : kViolet)),
                        const SizedBox(height: 6),
                        Text('Vendeur : ${d['note']}', style: mst(13, c: kGrey).copyWith(height: 1.4)),
                        if ('${d['buyer_reply'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Acheteur : ${d['buyer_reply']}', style: mst(13, c: kGrey).copyWith(height: 1.4))),
                        if ('${d['decision_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Équipe : ${d['decision_note']}', style: mst(13, c: kGrey).copyWith(height: 1.4))),
                        if (d['status'] == 'open' && d['as'] == 'buyer') Padding(padding: const EdgeInsets.only(top: 10), child: mButton(d['buyer_reply'] == null ? 'Répondre' : 'Modifier ma réponse', () => _reply(context, ref, d), dark: false)),
                        if (d['status'] == 'open' && d['as'] == 'staff')
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(children: [
                              Expanded(child: mButton('Clore', () => _decide(context, ref, d, 'close'), dark: false)),
                              const SizedBox(width: 10),
                              Expanded(child: mButton('Annuler la commande', () => _decide(context, ref, d, 'cancel'))),
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
