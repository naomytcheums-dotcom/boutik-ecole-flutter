import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gDialog, gToast;
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart';
import 'feedback.dart' show claimReasonLabels, claimReasons;
import 'finance.dart' show financePaymentsProvider, paymentReconciliationNote, paymentState;
import 'money_lot.dart' show claimThreadDialog;
import 'store.dart' show fcfa;

/// Réseau d'établissements, vœux, lives, litiges et paiements déclarés : listes lues sur le serveur, chargement, état vide et erreur
/// explicites, aucune ligne de maquette hors démonstration. Les droits de lecture sont ceux des tables (RLS).

final institutionsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('institutions', 'name,short_name,kind,city,status', order: 'created_at'));
final departmentsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('departments', 'name,status,institutions(name)', order: 'name', ascending: true, eq: {'status': 'verified'}, limit: 500, publicRead: true));
final claimsListProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('claims', 'id,reason,details,status,created_at', order: 'created_at'));

String institutionStatus(Object? s) => switch ('$s') { 'verified' => 'Vérifié', 'rejected' => 'Refusé', _ => 'Proposé' };
String institutionKind(Object? s) => switch ('$s') { 'universite_etat' => 'Université d’État', 'institut' => 'Institut', 'ecole' => 'École', 'prive' => 'Privé', _ => 'Autre' };
String claimStatus(Object? s) => switch ('$s') { 'answered' => 'Répondue', 'closed' => 'Clôturée', _ => 'Ouverte' };
String claimReason(Object? r) {
  final i = claimReasons.indexOf('$r');
  return i < 0 ? '$r' : claimReasonLabels[i];
}

Widget institutionsList({double width = 984, double height = 640}) => MobileList(
      provider: institutionsProvider,
      title: (r) => '${r['name']}',
      subtitle: (r) => [institutionKind(r['kind']), if ('${r['city'] ?? ''}'.isNotEmpty) '${r['city']}'].join(' · '),
      trailing: (r) => institutionStatus(r['status']),
      emptyText: 'Aucun établissement enregistré pour le moment.',
      width: width,
      height: height,
    );

Widget departmentsList({double width = 342, double height = 600}) => MobileList(
      provider: departmentsListProvider,
      where: (r) => '${r['status']}' == 'verified', // déjà filtré par le serveur ; garde-fou si un compte du département voit aussi les propositions
      title: (r) => '${r['name']}',
      subtitle: (r) => '${(r['institutions'] as Map?)?['name'] ?? ''}',
      emptyText: 'Aucun département publié pour le moment.',
      width: width,
      height: height,
    );

Widget claimsTable({double width = 984, double height = 640}) => MobileList(
      provider: claimsListProvider,
      title: (r) => claimReason(r['reason']),
      subtitle: (r) => '${r['details']} · ${dateCourte(r['created_at'])}',
      trailing: (r) => claimStatus(r['status']),
      emptyText: 'Aucune réclamation pour le moment.',
      onRow: claimStaffDialog,
      width: width,
      height: height,
    );

/// Réclamation touchée dans la liste de la gestion : lire le fil et répondre, rejeter ou rembourser l'acheteur.
/// Les gardes sont celles du serveur (permission « réclamations » ; la décision de remboursement exige en plus le droit de rembourser) : un refus est annoncé tel quel.
Future<void> claimStaffDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
  final id = '${r['id'] ?? ''}';
  if (id.isEmpty) return;
  final closed = '${r['status']}' == 'closed';
  Future<void> decide(String decision, String note) async {
    final res = await Backend.rpc('claim_decide', {'p_id': id, 'p_decision': decision, 'p_note': note});
    if (!context.mounted) return;
    gToast(context, res.error != null ? Backend.userMessage('${res.error}') : (decision == 'refund' ? 'Acheteur remboursé : commande annulée.' : 'Réclamation non retenue : l’argent du vendeur suit son cours.'));
    if (res.error == null) await ref.read(claimsListProvider.notifier).refresh();
  }

  await gDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(title: Text(claimReason(r['reason'])), children: [
      SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            claimThreadDialog(context, id);
          },
          child: const Text('Voir le fil et répondre')),
      if (!closed)
        SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              decide('release', '');
            },
            child: const Text('Rejeter la réclamation')),
      if (!closed)
        SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              final c = TextEditingController();
              final ok = await showDialog<bool>(
                  context: context,
                  builder: (x) => AlertDialog(
                        title: const Text('Motif du remboursement'),
                        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Motif (obligatoire)')),
                        actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Rembourser'))],
                      ));
              final note = c.text;
              c.dispose();
              if (ok == true) await decide('refund', note);
            },
            child: const Text('Rembourser l’acheteur')),
    ]),
  );
}

Widget declaredPayments({double width = 984, double height = 640}) => MobileList(
      provider: financePaymentsProvider,
      title: (r) => '${r['reference']} · ${r['order']}',
      subtitle: (r) => '${r['method'] ?? '—'} · ${fcfa(((r['amount'] as num?) ?? 0).toInt())}${paymentReconciliationNote(r)}',
      trailing: (r) => paymentState(r['state']),
      emptyText: 'Aucun paiement déclaré pour le moment.',
      width: width,
      height: height,
    );

Widget certificatesWide({double width = 984, double height = 640}) => MobileList(
      provider: certificatesProvider,
      title: (r) => '${r['subject_title']}',
      subtitle: (r) => 'Certificat n° ${r['code']} · ${r['holder_name'] ?? ''} · délivré le ${dateCourte(r['issued_at'])}',
      trailing: (r) => r['revoked'] == true ? 'Révoqué' : 'Valide',
      emptyText: 'Aucun certificat émis pour le moment.',
      width: width,
      height: height,
    );
