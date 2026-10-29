import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';
import 'store.dart';

/// Paiement Mobile Money réel (Orange Money, MTN MoMo) via la fonction serveur « pay » (Notch Pay).

class PayPhone extends Notifier<String> {
  @override
  String build() => ref.watch(profileAccountProvider).phone;
  void set(String v) => state = v;
}

final payPhoneProvider = NotifierProvider<PayPhone, String>(PayPhone.new);

enum PayPhase { idle, starting, pending, paid, failed }

class PayState {
  const PayState(this.phase, [this.message = '']);
  final PayPhase phase;
  final String message;
}

class PayNotifier extends Notifier<PayState> {
  Timer? _poll;
  @override
  PayState build() {
    ref.onDispose(() => _poll?.cancel());
    return const PayState(PayPhase.idle);
  }

  void set(PayState s) => state = s;

  void startPolling(BuildContext context, Order o) {
    _poll?.cancel();
    var n = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
      n++;
      final r = await check(context, o, quiet: true);
      if (r != PayPhase.pending || n > 45) t.cancel();
    });
  }

  /// Interroge le serveur ; ouvre le reçu dès que le paiement est confirmé.
  Future<PayPhase> check(BuildContext context, Order o, {bool quiet = false}) async {
    final res = GAnim.enabled ? await _call({'action': 'status', 'order_number': o.id}) : {'status': 'complete'};
    final st = res?['status'] as String?;
    if (st == 'complete') {
      state = const PayState(PayPhase.paid);
      ref.read(ordersProvider.notifier).markPaid(o.id);
      ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Paiement Mobile Money confirmé', o.id, 'Finances');
      _poll?.cancel();
      if (context.mounted) {
        if (GAnim.enabled) gToast(context, 'Paiement confirmé');
        gOpen(context, '259');
      }
      return PayPhase.paid;
    }
    if (st == 'failed') {
      state = const PayState(PayPhase.failed, 'Paiement refusé ou annulé.');
      _poll?.cancel();
      if (context.mounted) gToast(context, 'Paiement refusé ou annulé. Réessayez.');
      return PayPhase.failed;
    }
    if (!quiet && context.mounted) gToast(context, 'Paiement toujours en attente de validation sur votre téléphone.');
    return PayPhase.pending;
  }
}

final payProvider = NotifierProvider<PayNotifier, PayState>(PayNotifier.new);

Future<Map<String, dynamic>?> _call(Map<String, dynamic> body) async {
  if (!Backend.ready) return null;
  try {
    final r = await Supabase.instance.client.functions.invoke('pay', body: body);
    return Map<String, dynamic>.from(r.data as Map);
  } on FunctionException catch (e) {
    final d = e.details;
    return d is Map ? Map<String, dynamic>.from(d) : {'error': 'server', 'message': '$d'};
  } catch (_) {
    return {'error': 'network', 'message': 'Connexion impossible au serveur de paiement.'};
  }
}

/// Bouton « Payer maintenant » : crée la commande, envoie la demande de prélèvement sur le téléphone du client.
Future<void> startPayment(WidgetRef ref, BuildContext context) async {
  final pay = ref.read(payProvider.notifier);
  if (ref.read(payProvider).phase == PayPhase.starting) return;
  if (!GAnim.enabled) {
    // Tests automatisés : pas d'appel réseau.
    ref.read(ordersProvider.notifier).place();
    gOpen(context, '257');
    return;
  }
  final who = ref.read(profileAccountProvider);
  if (!Backend.ready || Supabase.instance.client.auth.currentUser == null) {
    gToast(context, 'Connectez-vous pour payer avec Mobile Money.');
    return;
  }
  var phone = ref.read(payPhoneProvider).replaceAll(RegExp(r'\D'), '');
  if (phone.startsWith('237')) phone = phone.substring(3);
  if (!RegExp(r'^[62]\d{8}$').hasMatch(phone)) {
    gToast(context, 'Saisissez un numéro Mobile Money valide (9 chiffres, ex. 690 11 22 33).');
    return;
  }
  pay.set(const PayState(PayPhase.starting));
  var o = ref.read(ordersProvider.notifier).place();
  final created = await Backend.createOrder(o.lines, ref.read(homeDeliveryProvider), o.method);
  if (created['error'] != null) {
    ref.read(ordersProvider.notifier).discard(o.id);
    final msg = created['error'] as String;
    pay.set(PayState(PayPhase.failed, msg));
    if (context.mounted) gToast(context, msg);
    return;
  }
  ref.read(ordersProvider.notifier).adopt(o.id, created['number'] as String, (created['subtotal'] as num).toInt(), (created['fee'] as num).toInt());
  o = ref.read(ordersProvider).firstWhere((x) => x.id == created['number']);
  final orange = ref.read(payMethodProvider) == 0 || phone.startsWith('69') || RegExp(r'^65[5-9]').hasMatch(phone);
  final res = await _call({
    'action': 'start',
    'order_number': o.id,
    'phone': '+237$phone',
    'channel': orange ? 'cm.orange' : 'cm.mtn',
    'name': who.name,
    'email': who.email,
  });
  if (res == null || res['error'] != null) {
    final msg = (res?['message'] ?? 'Paiement indisponible pour le moment.') as String;
    pay.set(PayState(PayPhase.failed, msg));
    if (context.mounted) gToast(context, msg);
    return;
  }
  ref.read(auditProvider.notifier).log(who.name, 'Paiement Mobile Money demandé', o.id, 'Finances');
  pay.set(const PayState(PayPhase.pending));
  if (!context.mounted) return;
  pay.startPolling(context, o);
  gOpen(context, '257');
}
