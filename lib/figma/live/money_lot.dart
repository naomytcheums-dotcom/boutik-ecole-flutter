import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'backend.dart';
import 'finance.dart' show financeOverviewProvider, financePayoutsProvider;
import 'lots.dart' show copyText, formDialog;
import 'seller.dart';
import 'store.dart' show fcfa, ordersProvider, viewedOrderProvider;
import 'vendeur.dart' show sellerRevenueProvider;

/// Argent des ventes (lot MONEY, migrations 20261117040000 à 20261117040500) : remise en main propre avec le code de retrait,
/// confirmation de réception par l'acheteur, demande d'annulation / remboursement, réclamations avec fil d'échanges,
/// demande de retrait du vendeur, relevé de ventes. Chaque action appelle une fonction serveur ; aucun montant n'est calculé ici.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

int _i(Object? v) => ((v as num?) ?? 0).toInt();
List<Map<String, dynamic>> _rows(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

Future<({bool ok, Object? data})> _run(BuildContext context, String fn, Map<String, dynamic> params, {String title = 'Action impossible'}) async {
  if (!Backend.ready) {
    if (context.mounted) await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return (ok: false, data: null);
  }
  final r = await Backend.rpc(fn, params);
  if (r.error != null) {
    if (context.mounted) await gAlert(context, title, r.error!);
    return (ok: false, data: null);
  }
  return (ok: true, data: r.data);
}

Future<bool> _ask(BuildContext context, String title, String text, String yes) async {
  final v = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: _st(16, w: FontWeight.w700)),
      content: Text(text, style: _st(12.5, c: _grey)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes))],
    ),
  );
  return v == true;
}

// ------------------------------------------------------------------ remise en main propre (écran 64)

/// Le vendeur saisit le code de retrait que l'acheteur affiche : la remise est prouvée et la part du vendeur est libérée tout de suite.
Future<void> enterHandoverCode(WidgetRef ref, BuildContext context) async {
  final o = ref.read(currentSellerOrderProvider);
  if (o.id.isEmpty) return gToast(context, 'Aucune commande ouverte.');
  final v = await formDialog(context, 'Code de retrait du client', [('Code à 6 chiffres', '')],
      submit: 'Confirmer la remise', numeric: true, intro: 'Le client affiche son code dans « Mon code de retrait ». Un code juste prouve la remise en main propre : votre part est débloquée immédiatement. Sans code, « Marquer livrée » la débloque après la confirmation du client ou après le délai de garde.');
  if (v == null || !context.mounted) return;
  final r = await _run(context, 'seller_confirm_handover', {'p_number': o.id, 'p_code': v[0]}, title: 'Remise non confirmée');
  if (!r.ok || !context.mounted) return;
  if (r.data == 'incorrect') return gAlert(context, 'Code incorrect', 'Ce code ne correspond pas à la commande. Vérifiez-le avec le client (5 essais au plus).');
  await ref.read(serverSellerOrdersProvider.notifier).refresh();
  if (!context.mounted) return;
  gToast(context, 'Remise confirmée : votre part est débloquée.');
  gOpen(context, '63');
}

// ------------------------------------------------------------------ acheteur : réception, annulation d'une commande payée (écrans 29, 47)

bool _real(WidgetRef ref) => Backend.ready && ref.read(viewedOrderProvider).id.isNotEmpty;

/// « Confirmer la réception » : commande payée (ou à payer à la livraison), non annulée, que le vendeur a déclarée livrée.
bool canConfirmReceipt(WidgetRef ref) {
  final o = ref.watch(viewedOrderProvider);
  return Backend.ready && (o.paid || o.cod) && !o.cancelled && o.status >= 3;
}

/// « Demander l'annulation » : commande payée en ligne, non annulée, pas encore livrée.
bool canRequestRefund(WidgetRef ref) {
  final o = ref.watch(viewedOrderProvider);
  return Backend.ready && o.paid && !o.cod && !o.cancelled && o.status < 3;
}

Future<void> confirmViewedOrderReceipt(WidgetRef ref, BuildContext context) async {
  if (!_real(ref)) return;
  final o = ref.read(viewedOrderProvider);
  final cod = o.cod;
  if (!await _ask(context, 'Confirmer la réception ?', cod
          ? 'Vous confirmez avoir reçu la commande ${o.id} en bon état. Le paiement a lieu à la remise, en main propre. En cas de problème, déposez plutôt une réclamation.'
          : 'Vous confirmez avoir reçu la commande ${o.id} en bon état. Le paiement est alors versé au vendeur. En cas de problème, déposez plutôt une réclamation : l’argent reste bloqué jusqu’à la décision.', 'Oui, j’ai tout reçu') || !context.mounted) return;
  final r = await _run(context, 'confirm_receipt', {'p_number': o.id}, title: 'Confirmation impossible');
  if (!r.ok || !context.mounted) return;
  await ref.read(ordersProvider.notifier).refresh();
  if (!context.mounted) return;
  gToast(context, r.data == 'already' ? 'Vous aviez déjà confirmé la réception de cette commande.' : 'Réception confirmée. Merci !');
}

Future<void> requestViewedOrderRefund(WidgetRef ref, BuildContext context) async {
  if (!_real(ref)) return;
  final o = ref.read(viewedOrderProvider);
  final v = await formDialog(context, 'Annuler une commande payée', [('Raison (10 caractères minimum)', '')],
      submit: 'Envoyer la demande', intro: 'L’équipe examine la demande (support ou finance). Si elle est acceptée, la commande est annulée et vous êtes remboursé sur votre numéro Mobile Money enregistré (Moyens de paiement). En attendant, l’argent reste bloqué.');
  if (v == null || !context.mounted) return;
  final r = await _run(context, 'order_refund_request', {'p_order': o.id, 'p_reason': v[0]}, title: 'Demande non envoyée');
  if (r.ok && context.mounted) {
    await ref.read(ordersProvider.notifier).refresh();
    if (context.mounted) gToast(context, 'Demande envoyée. Le vendeur et l’équipe sont prévenus.');
  }
}

// ------------------------------------------------------------------ réclamations : fil d'échanges

String claimStatusLabel(String status, String? decision) => switch (status) {
      'open' => 'En attente de réponse',
      'answered' => 'Répondue : décision de l’équipe attendue',
      _ => decision == 'refund' ? 'Close : acheteur remboursé' : 'Close : réclamation non retenue',
    };

/// Réclamations de la personne connectée (acheteur ou vendeur concerné, y compris sur une commande multi-vendeurs).
Future<void> claimsCenter(BuildContext context, WidgetRef ref) async {
  final r = await _run(context, 'my_claims', const {}, title: 'Lecture impossible');
  if (!r.ok || !context.mounted) return;
  final rows = _rows(r.data);
  if (rows.isEmpty) return gAlert(context, 'Réclamations', 'Aucune réclamation pour le moment.');
  String? open;
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Réclamations', style: _st(16, w: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: ListView(shrinkWrap: true, children: [
          for (final c in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c['order_number']} · ${c['as'] == 'buyer' ? 'ma réclamation' : 'sur ma vente'}', style: _st(13.5, w: FontWeight.w600)),
              subtitle: Text('${c['details']}\n${claimStatusLabel('${c['status']}', c['decision'] as String?)}', style: _st(12, c: _grey)),
              isThreeLine: true,
              trailing: TextButton(
                  onPressed: () {
                    open = '${c['id']}';
                    Navigator.pop(ctx);
                  },
                  child: const Text('Ouvrir')),
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
  if (open != null && context.mounted) await claimThreadDialog(context, open!);
}

/// Fil d'une réclamation : tous les échanges horodatés ; répondre tant qu'elle n'est pas close ; l'acheteur peut la retirer.
/// Répondre ne débloque jamais l'argent : seule la décision de l'équipe (ou le retrait par l'acheteur) le fait.
Future<void> claimThreadDialog(BuildContext context, String claimId) async {
  final r = await _run(context, 'claim_thread', {'p_claim': claimId}, title: 'Lecture impossible');
  if (!r.ok || !context.mounted) return;
  final t = Map<String, dynamic>.from(r.data as Map);
  final msgs = _rows(t['messages']);
  final c = TextEditingController();
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Réclamation ${t['order_number']}', style: _st(16, w: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(claimStatusLabel('${t['status']}', t['decision'] as String?), style: _st(12.5, w: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final m in msgs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m['author']} · ${'${m['at']}'.length >= 16 ? '${m['at']}'.substring(0, 16).replaceFirst('T', ' ') : m['at']}', style: _st(11, c: _grey)),
                  Text('${m['body']}', style: _st(12.5)),
                ]),
              ),
            if (t['can_reply'] == true) TextField(controller: c, maxLines: 3, maxLength: 2000, style: _st(13), decoration: const InputDecoration(hintText: 'Votre message (5 caractères minimum)')),
            if (t['can_reply'] != true) Text('Cette réclamation est clôturée : elle ne peut plus être modifiée.', style: _st(12, c: _grey)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        if (t['can_reply'] == true && t['as'] == 'buyer')
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (!context.mounted || !await _ask(context, 'Retirer la réclamation ?', 'Elle sera close et le paiement suivra son cours vers le vendeur.', 'Retirer') || !context.mounted) return;
                final w = await _run(context, 'claim_withdraw', {'p_claim': claimId}, title: 'Retrait impossible');
                if (w.ok && context.mounted) gToast(context, 'Réclamation retirée.');
              },
              child: const Text('Retirer')),
        if (t['can_reply'] == true)
          FilledButton(
              onPressed: () async {
                final err = await Backend.answerClaim(claimId, c.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                if (err != null) {
                  await gAlert(context, 'Message non envoyé', err);
                } else {
                  gToast(context, t['as'] == 'buyer' ? 'Message envoyé. Les vendeurs sont prévenus.' : 'Réponse envoyée. L’acheteur est prévenu ; l’argent reste bloqué jusqu’à la décision.');
                }
              },
              child: const Text('Envoyer')),
      ],
    ),
  );
  c.dispose();
}

// ------------------------------------------------------------------ retraits du vendeur (écran 66)

String payoutStatusLabel(String s) => switch (s) { 'demande' => 'En attente de traitement', 'prevu' => 'Accepté, versement en cours', 'verse' => 'Versé', 'rejete' => 'Rejeté', _ => s };

String _providerName(String? p) => switch (p) { 'orange_money' => 'Orange Money', 'mtn_momo' => 'MTN MoMo', _ => 'Mobile Money' };

Future<void> requestPayoutDialog(BuildContext context, WidgetRef ref) async {
  final r = await _run(context, 'my_payouts', const {}, title: 'Lecture impossible');
  if (!r.ok || !context.mounted) return;
  final d = Map<String, dynamic>.from(r.data as Map);
  final methods = _rows(d['methods']);
  final avail = _i(ref.read(sellerRevenueProvider)?['available']);
  if (methods.isEmpty) {
    return gAlert(context, 'Numéro Mobile Money requis', 'Votre retrait est versé sur un numéro Orange Money ou MTN MoMo enregistré dans votre compte. Ajoutez-le dans « Moyens de paiement », puis revenez ici.');
  }
  final def = methods.first;
  final v = await formDialog(context, 'Demander un retrait', [('Montant (FCFA)', avail >= _i(d['min']) ? '$avail' : '')],
      submit: 'Envoyer la demande', numeric: true,
      intro: 'Disponible : ${fcfa(avail)}. Versement sur ${_providerName(def['provider'] as String?)} ${def['phone']} (numéro par défaut de « Moyens de paiement »). Minimum ${fcfa(_i(d['min']))}, maximum ${fcfa(_i(d['max']))} par demande. La finance traite la demande et vous prévient du versement.');
  if (v == null || !context.mounted) return;
  final n = int.tryParse(v[0].replaceAll(RegExp(r'[^0-9]'), ''));
  if (n == null) return gAlert(context, 'Montant invalide', 'Saisissez un montant en FCFA.');
  final res = await _run(context, 'request_seller_payout', {'p_amount': n}, title: 'Demande non envoyée');
  if (!res.ok || !context.mounted) return;
  ref.invalidate(sellerRevenueProvider);
  gToast(context, 'Demande de retrait envoyée : la finance est prévenue.');
}

Future<void> payoutHistoryDialog(BuildContext context, WidgetRef ref) async {
  final r = await _run(context, 'my_payouts', const {}, title: 'Lecture impossible');
  if (!r.ok || !context.mounted) return;
  final rows = _rows((r.data as Map)['rows']);
  if (rows.isEmpty) return gAlert(context, 'Mes retraits', 'Aucun retrait pour le moment.');
  String? cancelId;
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Mes retraits', style: _st(16, w: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: ListView(shrinkWrap: true, children: [
          for (final b in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${b['number']} · ${fcfa(_i(b['amount']))}', style: _st(13.5, w: FontWeight.w600)),
              subtitle: Text(
                  [payoutStatusLabel('${b['status']}'), if (b['phone'] != null) '${b['method']} ${b['phone']}', if (b['reference'] != null) 'réf. ${b['reference']}', if (b['note'] != null) '${b['note']}'].join(' · '),
                  style: _st(12, c: _grey)),
              isThreeLine: true,
              trailing: b['status'] == 'demande'
                  ? TextButton(
                      onPressed: () {
                        cancelId = '${b['id']}';
                        Navigator.pop(ctx);
                      },
                      child: const Text('Annuler'))
                  : null,
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
  if (cancelId != null && context.mounted) {
    final c = await _run(context, 'payout_cancel_request', {'p_id': cancelId}, title: 'Annulation impossible');
    if (c.ok && context.mounted) {
      ref.invalidate(sellerRevenueProvider);
      gToast(context, 'Demande annulée : le montant est de nouveau disponible.');
    }
  }
}

/// Relevé de ventes : parts nettes lues dans le registre des paiements (12 derniers mois), copiable.
Future<void> statementDialog(BuildContext context) async {
  final r = await _run(context, 'seller_money_statement', const {}, title: 'Relevé indisponible');
  if (!r.ok || !context.mounted) return;
  final s = Map<String, dynamic>.from(r.data as Map);
  final t = Map<String, dynamic>.from(s['totals'] as Map);
  final rows = _rows(s['rows']);
  final text = StringBuffer('Relevé de ventes · ${s['seller']} · du ${s['from']} au ${s['to']}\nRépartition ${s['rule']}\n');
  for (final e in rows) {
    text.writeln('${e['date']} · ${e['ref']} · brut ${_i(e['gross'])} FCFA · ma part ${_i(e['mine'])} FCFA · ${_statusLabel('${e['status']}')}');
  }
  text.writeln('Total brut ${_i(t['gross'])} FCFA · mes parts ${_i(t['mine'])} FCFA · débloqué ${_i(t['released'])} FCFA · en séquestre ${_i(t['held'])} FCFA');
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Relevé de ventes', style: _st(16, w: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Du ${s['from']} au ${s['to']} · règle ${s['rule']}', style: _st(12, c: _grey)),
            const SizedBox(height: 8),
            Text('${_i(t['count'])} vente${_i(t['count']) > 1 ? 's' : ''} · brut ${fcfa(_i(t['gross']))}', style: _st(13, w: FontWeight.w700)),
            Text('Mes parts : ${fcfa(_i(t['mine']))} (débloqué ${fcfa(_i(t['released']))}, en séquestre ${fcfa(_i(t['held']))})', style: _st(12.5)),
            const SizedBox(height: 10),
            if (rows.isEmpty) Text('Aucune vente sur la période.', style: _st(12.5, c: _grey)),
            for (final e in rows.take(60)) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${e['date']} · ${e['ref']}\nbrut ${fcfa(_i(e['gross']))} · ma part ${fcfa(_i(e['mine']))} · ${_statusLabel('${e['status']}')}', style: _st(12))),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () async {
              final ok = await copyText(text.toString());
              if (ctx.mounted) gToast(ctx, ok ? 'Relevé copié.' : 'Copie impossible.');
            },
            child: const Text('Copier')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
      ],
    ),
  );
}

String _statusLabel(String s) => switch (s) { 'held' => 'en séquestre', 'frozen' => 'bloqué', 'released' => 'débloqué', 'refunded' => 'remboursé', 'cod_due' => 'payé à la livraison', _ => s };

/// Raison pour laquelle un montant n'est pas encore disponible (renvoyée par seller_revenue).
String holdReasonLabel(Map<String, dynamic> h) => switch ('${h['reason']}') {
      'frozen' => 'Bloqué par la plateforme : ${h['frozen_reason'] ?? 'motif communiqué par le support'}. Contestez-le via l’aide.',
      'claim' => 'Réclamation en cours : l’argent reste bloqué jusqu’à la décision.',
      'dispute' => 'Litige en cours : décision de l’équipe attendue.',
      'refund' => 'Demande d’annulation en cours : décision de l’équipe attendue.',
      'delivery' => 'En attente de la livraison.',
      _ => h['releases_at'] == null ? 'Livrée : libération à la confirmation de l’acheteur.' : 'Libération le ${'${h['releases_at']}'.length >= 10 ? '${h['releases_at']}'.substring(0, 10) : h['releases_at']} sans réclamation, ou dès la confirmation de l’acheteur.',
    };

// ------------------------------------------------------------------ finance et support : retraits et remboursements à traiter (écran 143)

Future<void> _choose(BuildContext context, String title, List<(String, VoidCallback)> actions) => gDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: _st(15, w: FontWeight.w700)),
        children: [for (final a in actions) SimpleDialogOption(onPressed: () { Navigator.pop(ctx); a.$2(); }, child: Text(a.$1, style: _st(13.5)))],
      ),
    );

/// Demandes de retrait des vendeurs : accepter, verser (référence de la transaction Mobile Money obligatoire) ou rejeter (motif obligatoire).
Future<void> payoutQueueDialog(BuildContext context, WidgetRef ref) async {
  final r = await _run(context, 'finance_payouts', const {'p_limit': 100}, title: 'Lecture impossible');
  if (!r.ok || !context.mounted) return;
  final rows = _rows(r.data).where((b) => b['status'] == 'demande' || b['status'] == 'prevu').toList();
  if (rows.isEmpty) return gAlert(context, 'Retraits à traiter', 'Aucune demande de retrait en attente.');
  Map<String, dynamic>? picked;
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Retraits à traiter (${rows.length})', style: _st(16, w: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: ListView(shrinkWrap: true, children: [
          for (final b in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${b['number']} · ${b['seller']} · ${fcfa(_i(b['amount']))}', style: _st(13.5, w: FontWeight.w600)),
              subtitle: Text('${payoutStatusLabel('${b['status']}')} · ${b['phone'] == null ? 'aucun numéro enregistré' : '${_providerName(b['provider'] as String?)} ${b['phone']}'} · solde disponible ${fcfa(_i(b['available']))}', style: _st(12, c: _grey)),
              isThreeLine: true,
              onTap: () {
                picked = b;
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
  final b = picked;
  if (b == null || !context.mounted) return;
  Future<void> set(String status, {String? reference, String? note}) async {
    final s = await _run(context, 'payout_set_status', {'p_id': b['id'], 'p_status': status, if (reference != null) 'p_reference': reference, if (note != null) 'p_note': note}, title: 'Traitement impossible');
    if (s.ok && context.mounted) {
      ref.read(financePayoutsProvider.notifier).refresh();
      ref.invalidate(financeOverviewProvider);
      gToast(context, 'Retrait ${b['number']} mis à jour : le vendeur est prévenu.');
    }
  }

  await _choose(context, '${b['number']} · ${fcfa(_i(b['amount']))}', [
    if (b['status'] == 'demande') ('Accepter (versement en cours)', () => set('prevu')),
    (
      'Marquer versé',
      () async {
        final v = await formDialog(context, 'Versement effectué', [('Référence de la transaction Mobile Money', '')], submit: 'Confirmer', intro: 'À ne faire qu’après avoir réellement envoyé ${fcfa(_i(b['amount']))} sur ${b['phone'] ?? 'le numéro du vendeur'}.');
        if (v != null) await set('verse', reference: v[0]);
      }
    ),
    (
      'Rejeter',
      () async {
        final v = await formDialog(context, 'Rejeter le retrait', [('Motif (communiqué au vendeur)', '')], submit: 'Rejeter');
        if (v != null) await set('rejete', note: v[0]);
      }
    ),
  ]);
}

/// Demandes d'annulation / remboursement d'une commande payée : le support ou la finance acceptent ou refusent ; la finance inscrit le remboursement versé.
Future<void> refundQueueDialog(BuildContext context, WidgetRef ref) async {
  final r = await _run(context, 'my_refunds', const {}, title: 'Lecture impossible');
  if (!r.ok || !context.mounted) return;
  final rows = _rows(r.data).where((x) => x['status'] == 'requested' || x['status'] == 'approved').toList();
  if (rows.isEmpty) return gAlert(context, 'Remboursements', 'Aucune demande en attente.');
  Map<String, dynamic>? picked;
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Remboursements (${rows.length})', style: _st(16, w: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: ListView(shrinkWrap: true, children: [
          for (final x in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${x['order_number']} · ${fcfa(_i(x['amount']))}', style: _st(13.5, w: FontWeight.w600)),
              subtitle: Text('${x['status'] == 'approved' ? 'Acceptée : à rembourser' : 'À examiner'} · ${x['requester_role'] == 'seller' ? 'demandée par le vendeur' : x['requester_role'] == 'staff' ? 'décision de réclamation' : 'demandée par l’acheteur'}\n${x['reason']}${x['refund_phone'] == null ? '' : '\n${_providerName(x['refund_provider'] as String?)} ${x['refund_phone']}'}', style: _st(12, c: _grey)),
              isThreeLine: true,
              onTap: () {
                picked = x;
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
    ),
  );
  final x = picked;
  if (x == null || !context.mounted) return;
  Future<void> call(String fn, Map<String, dynamic> p) async {
    final s = await _run(context, fn, {'p_id': x['id'], ...p}, title: 'Traitement impossible');
    if (s.ok && context.mounted) {
      ref.invalidate(financeOverviewProvider);
      gToast(context, 'Remboursement ${x['order_number']} mis à jour.');
    }
  }

  if (x['status'] == 'approved') {
    final v = await formDialog(context, 'Remboursement versé', [('Référence de la transaction Mobile Money', '')], submit: 'Confirmer', intro: 'À ne faire qu’après avoir réellement remboursé ${fcfa(_i(x['amount']))} à l’acheteur.');
    if (v != null) await call('order_refund_set_paid', {'p_reference': v[0]});
    return;
  }
  await _choose(context, '${x['order_number']} · ${fcfa(_i(x['amount']))}', [
    ('Accepter : annuler la commande et rembourser', () => call('order_refund_decide', {'p_decision': 'approve', 'p_note': ''})),
    (
      'Refuser',
      () async {
        final v = await formDialog(context, 'Refuser la demande', [('Motif (communiqué)', '')], submit: 'Refuser');
        if (v != null) await call('order_refund_decide', {'p_decision': 'reject', 'p_note': v[0]});
      }
    ),
  ]);
}

/// Boutons de la console finance (143) : retraits à traiter et remboursements à traiter.
class FinanceMoneyActions extends ConsumerWidget {
  const FinanceMoneyActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(financeOverviewProvider);
    final n = _i(o?['payout_requests']);
    final m = _i(o?['refunds_to_pay']);
    return Row(children: [
      OutlinedButton(onPressed: () => payoutQueueDialog(context, ref), child: Text('Traiter les retraits${n > 0 ? ' ($n)' : ''}')),
      const SizedBox(width: 12),
      OutlinedButton(onPressed: () => refundQueueDialog(context, ref), child: Text('Remboursements${m > 0 ? ' ($m à verser)' : ''}')),
    ]);
  }
}