import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'tp_ui.dart' show tpBackground, GlassBack, TpFrame;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../nav.dart';
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'store.dart' show fcfa, ordersProvider, payableOrderProvider;
import 'talents.dart' show askText;

/// Paiement par messagerie (écrans 289 et 290) : un fil de discussion à la manière de WhatsApp ou Dikalo, généré par le serveur
/// (migration 20261105001200). Aucun prestataire n'est appelé : le payeur déclare son paiement Mobile Money avec la référence reçue par SMS,
/// la finance le vérifie. Le champ « prestataire » (dikalo, tara) attend la documentation et les clés officielles ; aucune clé n'est ici.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class SelectedPayment extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedPaymentProvider = NotifierProvider<SelectedPayment, String?>(SelectedPayment.new);
final myPaymentsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('my_payments'));

/// Paiements déclarés en attente de vérification (finance et administration, migration 20261114004100).
final paymentsToVerifyProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('payments_to_verify'));

/// Finance et administration vérifient les paiements déclarés.
bool _isFinanceRole(String role) => role == 'finance' || role == 'admin';

class PaymentThread extends Notifier<Map<String, dynamic>?> {
  bool error = false;
  @override
  Map<String, dynamic>? build() {
    final id = ref.watch(selectedPaymentProvider);
    if (!Backend.ready || id == null) return null;
    Future.microtask(refresh);
    return null;
  }

  /// [silent] : relecture périodique ; un échec ponctuel ne remplace pas le fil déjà affiché.
  Future<void> refresh({bool silent = false}) async {
    final id = ref.read(selectedPaymentProvider);
    if (id == null) return;
    final r = await Backend.rpc('payment_thread', {'p_id': id});
    if (!ref.mounted) return;
    final failed = r.error != null || r.data is! Map;
    if (silent && failed) return;
    error = failed;
    state = error ? const {} : Map<String, dynamic>.from(r.data as Map);
  }
}

final paymentThreadProvider = NotifierProvider<PaymentThread, Map<String, dynamic>?>(PaymentThread.new);

String paymentStatusLabel(Object? s) => switch ('$s') { 'pending' => 'En attente de vérification', 'confirmed' => 'Confirmé', 'failed' => 'Non retrouvé', 'cancelled' => 'Annulé', _ => 'À payer' };

/// Crée la demande de paiement et ouvre le fil (depuis le récapitulatif de commande, un abonnement, une campagne ou un événement).
Future<void> startMessagePayment(BuildContext context, WidgetRef ref, {required String kind, required String subject, required int amount}) async {
  if (amount <= 0) {
    gToast(context, 'Montant invalide : il n’y a rien à payer pour le moment.');
    return;
  }
  if (!await requireLogin(context, ref, 'payer par messagerie') || !context.mounted) return;
  final r = await Backend.rpc('payment_start', {'p_kind': kind, 'p_subject': subject, 'p_amount': amount, 'p_provider': 'manual'});
  if (!context.mounted) return;
  if (r.error != null || r.data == null) {
    gToast(context, Backend.userMessage(r.error ?? 'Paiement impossible'));
    return;
  }
  ref.read(selectedPaymentProvider.notifier).select('${r.data}');
  ref.invalidate(myPaymentsProvider);
  GoRouter.of(context).push('/paiement');
}

/// Écran 43 « Payer par messagerie » : le paiement vise la commande enregistrée la plus récente qui n'est ni payée ni annulée.
Future<void> payOrderByMessage(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'payer par messagerie') || !context.mounted) return;
  final o = ref.read(payableOrderProvider);
  if (o == null) {
    gToast(context, ref.read(ordersProvider).isEmpty ? 'Aucune commande enregistrée : validez d’abord votre commande pour la payer par messagerie.' : 'Aucune commande à payer.');
    return;
  }
  await startMessagePayment(context, ref, kind: 'order', subject: 'Commande ${o.id}', amount: o.total);
}

DateTime? _t(Object? v) => DateTime.tryParse('$v')?.toLocal();
String _hm(Object? v) {
  final d = _t(v);
  return d == null ? '' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Écran 289 : le fil de discussion d'un paiement.
class PaymentChatScreen extends ConsumerStatefulWidget {
  const PaymentChatScreen({super.key});
  @override
  ConsumerState<PaymentChatScreen> createState() => _PaymentChatState();
}

class _PaymentChatState extends ConsumerState<PaymentChatScreen> {
  final _ref = TextEditingController();
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Tant que l'écran est ouvert et que le paiement attend la finance, le fil est relu toutes les 15 s.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || ref.read(selectedPaymentProvider) == null) return;
      if ('${ref.read(paymentThreadProvider)?['status']}' == 'pending') ref.read(paymentThreadProvider.notifier).refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _declare(String id) async {
    final txt = _ref.text.trim();
    if (txt.length < 4) {
      gToast(context, 'Saisissez la référence reçue par SMS (4 caractères au moins).');
      return;
    }
    setState(() => _busy = true);
    final r = await Backend.rpc('payment_declare', {'p_id': id, 'p_provider_ref': txt});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage(r.error!));
      return;
    }
    _ref.clear();
    await ref.read(paymentThreadProvider.notifier).refresh();
    ref.invalidate(myPaymentsProvider);
  }

  /// Finance et administration : confirme le paiement, ou le déclare non retrouvé avec un motif.
  Future<void> _decide(Map<String, dynamic> t, String status) async {
    String? note;
    if (status == 'failed') {
      note = await askText(context, title: 'Paiement non retrouvé', body: 'Indiquez le motif : il sera communiqué au payeur.', hint: 'Ex. : aucune transaction avec cette référence', ok: 'Envoyer', min: 3);
      if (note == null || !mounted) return;
    }
    setState(() => _busy = true);
    final r = await Backend.rpc('payment_set_status', {'p_id': '${t['id']}', 'p_status': status, 'p_note': ?note});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage(r.error!));
      return;
    }
    final isOrder = '${t['subject'] ?? ''}'.startsWith('Commande');
    gToast(context, status == 'confirmed' ? (isOrder ? 'Paiement confirmé : la commande est marquée payée.' : 'Paiement confirmé.') : 'Paiement marqué « non retrouvé » : le payeur en est informé.');
    await ref.read(paymentThreadProvider.notifier).refresh();
    ref.invalidate(myPaymentsProvider);
    ref.invalidate(paymentsToVerifyProvider);
  }

  Widget _decisionBar(Map<String, dynamic> t) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Paiement déclaré${'${t['provider_ref'] ?? ''}'.isEmpty ? '' : ' · référence ${t['provider_ref']}'}. Vérifiez la transaction avant de décider.', textAlign: TextAlign.center, style: _st(12.5, c: _grey)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(onTap: _busy ? null : () => _decide(t, 'failed'), child: Container(padding: const EdgeInsets.symmetric(vertical: 13), alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFD9D3E6), width: 1.5)), child: Text('Non retrouvé', style: _st(13, w: FontWeight.w700))))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: _busy ? null : () => _decide(t, 'confirmed'), child: Container(padding: const EdgeInsets.symmetric(vertical: 13), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF1F9D6B), borderRadius: BorderRadius.circular(22)), child: Text(_busy ? '…' : 'Confirmer le paiement', style: _st(13, w: FontWeight.w700, c: Colors.white))))),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final id = ref.watch(selectedPaymentProvider);
    final t = ref.watch(paymentThreadProvider);
    final signedOut = ref.watch(authProvider.select((a) => a.current == null));
    final staff = ref.watch(authProvider.select((a) => _isFinanceRole(roleKey(a.current))));
    Widget body;
    if (signedOut) {
      body = const Center(child: Text('Connectez-vous pour voir ce paiement.'));
    } else if (id == null) {
      body = Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Aucun paiement ouvert.\nPayez depuis votre commande, un abonnement ou une campagne.', textAlign: TextAlign.center, style: _st(14, c: _grey))));
    } else if (t == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (ref.read(paymentThreadProvider.notifier).error) {
      body = Center(child: Text('Ce paiement est introuvable.', style: _st(14, c: _grey)));
    } else {
      final msgs = [for (final m in (t['messages'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)];
      final status = '${t['status']}';
      body = Column(children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fcfa(((t['amount'] as num?) ?? 0).toInt()), style: _st(22, w: FontWeight.w800)), Text('${t['reference']}${'${t['subject']}'.isEmpty ? '' : ' · ${t['subject']}'}', style: _st(12, c: _grey))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: status == 'confirmed' ? const Color(0xFFDDF5EC) : const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(14)), child: Text(paymentStatusLabel(status), style: _st(11.5, w: FontWeight.w700, c: status == 'confirmed' ? const Color(0xFF0F7A52) : const Color(0xFF5A3FE0)))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            reverse: false,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            itemCount: msgs.length,
            itemBuilder: (_, i) {
              final m = msgs[i];
              final mine = '${m['sender']}' == (staff ? 'finance' : 'payer');
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 290),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
                  decoration: BoxDecoration(color: mine ? const Color(0xFFD9FDD3) : Colors.white, borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(mine ? 14 : 3), bottomRight: Radius.circular(mine ? 3 : 14))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Align(alignment: Alignment.centerLeft, child: Text('${m['body']}', style: _st(13.5).copyWith(height: 1.4))),
                    const SizedBox(height: 3),
                    Text('${'${m['sender']}' == 'finance' ? 'Finance · ' : ''}${_hm(m['created_at'])}', style: _st(10.5, c: _grey)),
                  ]),
                ),
              );
            },
          ),
        ),
        if (status == 'created' || status == 'failed')
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
            child: Row(children: [
              Expanded(child: TextField(controller: _ref, decoration: InputDecoration(hintText: 'Référence de la transaction (SMS)', filled: true, fillColor: const Color(0xFFF2EFF6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
              const SizedBox(width: 8),
              GestureDetector(onTap: _busy ? null : () => _declare('${t['id']}'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), decoration: BoxDecoration(color: const Color(0xFF1F9D6B), borderRadius: BorderRadius.circular(22)), child: Text(_busy ? '…' : 'J’ai payé', style: _st(13, w: FontWeight.w700, c: Colors.white)))),
            ]),
          )
        else if (status == 'pending' && staff)
          _decisionBar(t)
        else
          Container(width: double.infinity, color: Colors.white, padding: const EdgeInsets.fromLTRB(18, 14, 18, 18), child: Text(status == 'pending' ? 'Votre paiement est en cours de vérification par la finance.' : status == 'confirmed' ? 'Paiement confirmé.' : 'Paiement annulé.', textAlign: TextAlign.center, style: _st(12.5, c: _grey))),
      ]);
    }
    return DecoratedBox(decoration: tpBackground, child: TpFrame(child: Scaffold(backgroundColor: Colors.transparent, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        foregroundColor: _ink,
        leading: Padding(padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4), child: GlassBack(onTap: () => gBack(context))),
        title: Row(children: [
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1F9D6B)), child: const Icon(Icons.chat_bubble_outline, size: 17, color: Colors.white)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Paiement Boutik-École', style: _st(14.5, w: FontWeight.w700)), Text('Paiement par messagerie', style: _st(11, c: _grey))]),
        ]),
      ),
      body: SafeArea(child: body),
    )));
  }
}

/// Écran 290 : mes paiements par messagerie.
class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedOut = ref.watch(authProvider.select((a) => a.current == null));
    final staff = ref.watch(authProvider.select((a) => _isFinanceRole(roleKey(a.current))));
    final rows = ref.watch(myPaymentsProvider);
    final toVerify = staff ? ref.watch(paymentsToVerifyProvider) : null;
    void open(Object? id) {
      ref.read(selectedPaymentProvider.notifier).select('$id');
      GoRouter.of(context).push('/paiement');
    }

    Widget heading(String s) => Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text(s, style: _st(15, w: FontWeight.w800)));
    Widget info(String s) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(s, style: _st(13, c: _grey)));
    Widget row(Map<String, dynamic> r, {bool verify = false}) {
      final payer = '${r['payer'] ?? ''}', sms = '${r['provider_ref'] ?? ''}';
      final detail = verify ? [if (payer.isNotEmpty) payer, if (sms.isNotEmpty) 'Réf. SMS : $sms'].join(' · ') : '${r['subject'] ?? ''}';
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => open(r['id']),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['reference']} · ${fcfa(((r['amount'] as num?) ?? 0).toInt())}', style: _st(14, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12, c: _grey)),
            ])),
            Text(paymentStatusLabel(r['status']), style: _st(11.5, w: FontWeight.w700, c: '${r['status']}' == 'confirmed' ? const Color(0xFF0F7A52) : const Color(0xFF5A3FE0))),
          ]),
        ),
      );
    }

    Widget body;
    if (signedOut) {
      body = const Center(child: Text('Connectez-vous pour voir vos paiements.'));
    } else if (rows == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (rows.isEmpty && !staff) {
      body = Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Aucun paiement pour le moment.', style: _st(14, c: _grey))));
    } else {
      final verifyError = staff && ref.read(paymentsToVerifyProvider.notifier).error;
      body = RefreshIndicator(
        onRefresh: () async {
          await ref.read(myPaymentsProvider.notifier).refresh();
          if (staff) await ref.read(paymentsToVerifyProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            if (staff) ...[
              heading('À vérifier'),
              if (toVerify == null)
                info('Chargement…')
              else if (verifyError)
                info('Lecture des paiements à vérifier impossible pour le moment. Tirez pour réessayer.')
              else if (toVerify.isEmpty)
                info('Aucun paiement à vérifier.')
              else
                for (final r in toVerify) ...[row(r, verify: true), const Divider(height: 12, color: Color(0xFFE9E5F0))],
              const SizedBox(height: 14),
              heading('Mes paiements'),
            ],
            if (rows.isEmpty) info('Aucun paiement pour le moment.'),
            for (final r in rows) ...[row(r), const Divider(height: 12, color: Color(0xFFE9E5F0))],
          ],
        ),
      );
    }
    return DecoratedBox(decoration: tpBackground, child: TpFrame(child: Scaffold(backgroundColor: Colors.transparent, 
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, leadingWidth: 64, foregroundColor: _ink, leading: Padding(padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4), child: GlassBack(onTap: () => gBack(context))), title: Text('Mes paiements', style: _st(16, w: FontWeight.w700))),
      body: SafeArea(child: body),
    )));
  }
}
