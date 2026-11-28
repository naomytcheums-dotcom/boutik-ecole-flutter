import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/demo/section_a_demo.dart' show CartLine;
import '../../data/repositories/repositories.dart' show cartProvider;
import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'delivery.dart' show discardTransientAddress, selectedAddressProvider;
import 'auth.dart';
import 'backend.dart';
import 'money_lot.dart' show requestViewedOrderRefund;
import 'promo_state.dart' show promoCodeProvider;
import 'store.dart';

/// Paiement Mobile Money réel (Orange Money, MTN MoMo) via la fonction serveur « pay » (Notch Pay).

class PayPhone extends Notifier<String> {
  /// Vrai dès que l'utilisateur a saisi son numéro : le numéro par défaut du compte (lu en retard) ne l'écrase plus.
  bool touched = false;

  @override
  String build() => ref.watch(profileAccountProvider).phone;
  void set(String v) => state = v;
  void type(String v) {
    touched = true;
    state = v;
  }

  void setDefault(String v) {
    if (!touched) state = v;
  }
}

final payPhoneProvider = NotifierProvider<PayPhone, String>(PayPhone.new);

/// [verify] : le fournisseur signale un écart de montant ou de référence ; la commande est conservée et le paiement vérifié par l'équipe.
enum PayPhase { idle, starting, pending, paid, failed, verify }

class PayState {
  const PayState(this.phase, [this.message = '', this.late = false]);
  final PayPhase phase;

  /// Cause réelle de l'échec, ou précision sur l'attente.
  final String message;

  /// Vrai quand le suivi automatique (3 minutes) s'est arrêté sans réponse du fournisseur.
  final bool late;
}

class PayNotifier extends Notifier<PayState> {
  Timer? _poll;

  /// Panier (lignes, code promo) de la dernière tentative : remis dans le panier pour recommencer après un échec.
  List<CartLine> retryLines = const [];
  String retryPromo = '';

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
      if (r != PayPhase.pending) return t.cancel();
      if (n >= 45) {
        t.cancel();
        if (ref.mounted && state.phase == PayPhase.pending) {
          state = const PayState(PayPhase.pending, 'La confirmation tarde. Validez la demande sur votre téléphone, puis touchez « Vérifier le statut ».', true);
        }
      }
    });
  }

  /// Interroge le serveur ; ouvre le reçu dès que le paiement est confirmé, et la page d'échec (avec la vraie cause) sinon.
  Future<PayPhase> check(BuildContext context, Order o, {bool quiet = false}) async {
    // « Réduire les animations » ne change jamais la vérité d'un paiement : seul le mode démonstration (hors serveur) simule la réponse
    final res = Backend.ready || GAnim.enabled ? await _call({'action': 'status', 'order_number': o.id}) : {'status': 'complete'};
    final st = res?['status'] as String?;
    if (st == 'complete') {
      state = const PayState(PayPhase.paid);
      ref.read(ordersProvider.notifier).markPaid(o.id);
      unawaited(discardTransientAddress(ref.read));
      ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Paiement Mobile Money confirmé', o.id, 'Finances');
      _poll?.cancel();
      if (context.mounted) {
        if (GAnim.enabled || Backend.ready) gToast(context, 'Paiement confirmé');
        gOpen(context, '259');
      }
      return PayPhase.paid;
    }
    if (st == 'failed') {
      _poll?.cancel();
      final reason = res?['reason'];
      if (reason == 'mismatch') {
        // De l'argent a pu être prélevé : la commande n'est PAS annulée, l'équipe vérifie le paiement.
        state = PayState(PayPhase.verify, 'Le fournisseur signale un écart sur ce paiement (montant ou référence). Votre commande est conservée et le paiement est à vérifier : ne payez pas une seconde fois, et contactez le support si votre compte a été débité.');
        if (context.mounted) gToast(context, 'Paiement à vérifier : votre commande est conservée.');
        return PayPhase.verify;
      }
      final gone = reason == 'cancelled';
      final why = gone ? 'Commande annulée : recommencez pour la repasser.' : 'Le paiement n’a pas abouti : il a été refusé, a expiré ou a été annulé sur votre téléphone.';
      state = PayState(PayPhase.failed, why);
      if (!gone) unawaited(Backend.cancelOrder(o.id)); // la commande n'aboutira pas : le stock réservé est restitué
      ref.read(ordersProvider.notifier).cancel(o.id);
      if (context.mounted) {
        gToast(context, why);
        gOpen(context, '258');
      }
      return PayPhase.failed;
    }
    if (!quiet && context.mounted) {
      final msg = res?['message'];
      if (res?['error'] != null) {
        gToast(context, msg is String && msg.isNotEmpty ? Backend.userMessage(msg) : 'Vérification impossible pour le moment. Réessayez dans un instant.');
      } else {
        gToast(context, 'Paiement toujours en attente de validation sur votre téléphone.');
      }
    }
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
    if (d is Map) {
      final m = Map<String, dynamic>.from(d);
      // erreur HTTP sans statut ni code d'erreur dans le corps : jamais un succès (5xx : réponse du fournisseur inconnue ; 4xx : refus net)
      if (e.status >= 400 && m['error'] == null && m['status'] == null) m['error'] = e.status >= 500 ? 'server' : 'rejected';
      return {...m, if (d['message'] is String) 'message': Backend.userMessage(d['message'] as String)};
    }
    return {'error': 'server', 'message': 'Le paiement est indisponible pour le moment. Réessayez dans un instant.'};
  } catch (_) {
    return {'error': 'network', 'message': 'Le service de paiement ne répond pas pour le moment. Réessayez dans un instant.'};
  }
}

/// La commande est passée (paiement lancé, ou confirmée à la livraison) : le panier et le code promo sont vidés.
/// L'adresse temporaire est gardée tant que le paiement Mobile Money n'est pas confirmé (elle sert à recommencer en cas d'échec).
void _completeCheckout(WidgetRef ref, {bool keepAddress = false}) {
  ref.read(cartProvider.notifier).clear();
  ref.read(promoCodeProvider.notifier).set('');
  if (!keepAddress) unawaited(discardTransientAddress(ref.read));
}

/// 258 « Réessayer le paiement » : le panier de la tentative est remis, puis le paiement est relancé
/// (une nouvelle commande est créée : l'ancienne est annulée ou en échec).
Future<void> retryPayment(WidgetRef ref, BuildContext context) async {
  if (_payBusy) return;
  _payBusy = true;
  try {
    await _retryPayment(ref, context);
  } finally {
    _payBusy = false;
  }
}

/// Vrai pendant qu'un lancement de paiement ou un nouvel essai est en cours : un second appui (double clic) ne crée jamais une seconde commande.
/// Posé de façon synchrone, avant toute attente (la phase « starting » n'arrive qu'après la connexion et les contrôles).
bool _payBusy = false;

Future<void> _retryPayment(WidgetRef ref, BuildContext context) async {
  final pay = ref.read(payProvider.notifier);
  if (ref.read(payProvider).phase == PayPhase.pending) {
    final waiting = payableOrder(ref.read(ordersProvider));
    final ok = await gConfirm(context, 'Demande de paiement en cours', 'Une demande est encore en attente sur votre téléphone. Pour changer de moyen, elle doit être annulée : ne la validez plus. Annuler cette demande ?', yes: 'Annuler la demande', no: 'Garder');
    if (!ok || !context.mounted) return;
    if (waiting != null) {
      final err = await Backend.cancelOrder(waiting.id);
      if (err != null) {
        if (context.mounted) await gAlert(context, 'Annulation impossible', err);
        return;
      }
      ref.read(ordersProvider.notifier).cancel(waiting.id);
    }
    pay.set(const PayState(PayPhase.idle));
  }
  if (ref.read(cartProvider).isEmpty && pay.retryLines.isNotEmpty) {
    ref.read(cartProvider.notifier).restore(pay.retryLines);
    if (pay.retryPromo.isNotEmpty) ref.read(promoCodeProvider.notifier).set(pay.retryPromo);
  }
  if (!context.mounted) return;
  if (ref.read(cartProvider).isEmpty) {
    gToast(context, 'Votre panier est vide : ajoutez un article pour commander.');
    return gOpen(context, '06');
  }
  pay.set(const PayState(PayPhase.idle));
  await _startPayment(ref, context);
}

/// Bouton « Payer maintenant » : crée la commande, envoie la demande de prélèvement sur le téléphone du client.
Future<void> startPayment(WidgetRef ref, BuildContext context) async {
  if (_payBusy) return;
  final phase = ref.read(payProvider).phase;
  if (Backend.ready && phase == PayPhase.pending && payableOrder(ref.read(ordersProvider)) != null) {
    return gToast(context, 'Un paiement est déjà en cours de vérification : ne payez pas une seconde fois. Touchez « Vérifier le statut » pour le suivre.');
  }
  _payBusy = true;
  try {
    await _startPayment(ref, context);
  } finally {
    _payBusy = false;
  }
}

Future<void> _startPayment(WidgetRef ref, BuildContext context) async {
  final pay = ref.read(payProvider.notifier);
  if (ref.read(payProvider).phase == PayPhase.starting) return;
  if (!Backend.ready && !GAnim.enabled) {
    // Démonstration hors connexion au serveur (tests automatisés) : pas d'appel réseau.
    ref.read(ordersProvider.notifier).place();
    gOpen(context, '257');
    return;
  }
  final who = ref.read(profileAccountProvider);
  if (!Backend.ready) {
    gToast(context, 'Paiement indisponible hors connexion au serveur.');
    return;
  }
  if (!await requireLogin(context, ref, 'payer votre commande') || !context.mounted) return;
  if (Supabase.instance.client.auth.currentUser == null) return;
  final cod = ref.read(payMethodProvider) == 2;
  var phone = ref.read(payPhoneProvider).replaceAll(RegExp(r'\D'), '');
  if (phone.startsWith('237')) phone = phone.substring(3);
  if (!cod && !RegExp(r'^[62]\d{8}$').hasMatch(phone)) {
    gToast(context, 'Saisissez un numéro Mobile Money valide (9 chiffres, ex. 690 11 22 33).');
    return;
  }
  if (ref.read(cartProvider).isEmpty) {
    gToast(context, 'Votre panier est vide : ajoutez un article pour commander.');
    return;
  }
  final shown = ref.read(totalsProvider);
  if (ref.read(homeDeliveryProvider) && shown.feeProblem != null) {
    await gAlert(context, 'Livraison à domicile', shown.feeProblem!);
    if (context.mounted) gOpen(context, '07');
    return;
  }
  pay.set(const PayState(PayPhase.starting));
  try {
    await _runPayment(ref, context, pay, who, cod, phone, shown.total);
  } catch (_) {
    pay.set(const PayState(PayPhase.failed, 'Le paiement n’a pas pu être lancé. Réessayez dans un instant.'));
    if (context.mounted) gToast(context, 'Le paiement n’a pas pu être lancé. Réessayez dans un instant.');
  }
}

Future<void> _runPayment(WidgetRef ref, BuildContext context, PayNotifier pay, Account who, bool cod, String phone, int shownTotal) async {
  pay.retryLines = List.of(ref.read(cartProvider));
  pay.retryPromo = ref.read(promoCodeProvider);
  final created = await _createOrder(ref, context, shownTotal);
  if (created == null) return;
  final o = created;
  if (cod) {
    // Paiement à la livraison : aucun prélèvement ; la commande est confirmée, le vendeur la prépare et encaisse à la remise.
    final err = await Backend.confirmCodOrder(o.id);
    if (err != null) {
      await Backend.cancelOrder(o.id); // le stock réservé est restitué
      ref.read(ordersProvider.notifier).discard(o.id);
      pay.set(PayState(PayPhase.failed, err));
      if (context.mounted) gToast(context, err);
      return;
    }
    ref.read(ordersProvider.notifier).markCod(o.id);
    ref.read(auditProvider.notifier).log(who.name, 'Commande confirmée, paiement à la livraison', o.id, 'Finances');
    pay.set(const PayState(PayPhase.idle));
    _completeCheckout(ref);
    if (!context.mounted) return;
    gToast(context, 'Commande enregistrée : vous payez à la livraison.');
    gOpen(context, '259');
    return;
  }
  var order = o;
  var res = await _startMobileMoney(ref, order, phone, who);
  if (res?['error'] == 'order_cancelled' || (res?['error'] != null && '${res?['message']}'.contains('annulée'))) {
    // La commande a été annulée entre-temps (expiration, annulation) : une nouvelle commande est créée une seule fois.
    if (!context.mounted) return;
    final again = await _createOrder(ref, context, order.total);
    if (again == null) return;
    order = again;
    res = await _startMobileMoney(ref, order, phone, who);
  }
  if (res != null && (res['error'] == 'network' || res['error'] == 'server')) {
    // Réponse perdue (coupure, délai dépassé, erreur serveur sans détail) : la demande a peut-être atteint le fournisseur. La commande est conservée,
    // jamais annulée ni déclarée payée : seul le serveur de paiement tranche (suivi automatique puis « Vérifier le statut »).
    pay.set(const PayState(PayPhase.pending, 'Vérification en cours : la connexion a été interrompue pendant la demande de paiement. Si vous recevez une demande sur votre téléphone, validez-la ; ne payez pas une seconde fois.'));
    ref.read(auditProvider.notifier).log(who.name, 'Paiement Mobile Money demandé, réponse non reçue (vérification en cours)', order.id, 'Finances');
    _completeCheckout(ref, keepAddress: true);
    if (!context.mounted) return;
    pay.startPolling(context, ref.read(ordersProvider).firstWhere((x) => x.id == order.id, orElse: () => order));
    gOpen(context, '257');
    return;
  }
  if (res == null || res['error'] != null) {
    await Backend.cancelOrder(order.id); // le prélèvement n'a pas démarré : on libère le stock réservé
    ref.read(ordersProvider.notifier).discard(order.id);
    final msg = Backend.userMessage('${res?['message'] ?? 'Paiement indisponible pour le moment.'}');
    pay.set(PayState(PayPhase.failed, msg));
    if (context.mounted) gToast(context, msg);
    return;
  }
  final ref0 = res['reference'];
  if (ref0 is String && ref0.isNotEmpty) ref.read(ordersProvider.notifier).setReference(order.id, ref0);
  ref.read(auditProvider.notifier).log(who.name, 'Paiement Mobile Money demandé', order.id, 'Finances');
  pay.set(const PayState(PayPhase.pending));
  _completeCheckout(ref, keepAddress: true);
  if (!context.mounted) return;
  pay.startPolling(context, ref.read(ordersProvider).firstWhere((x) => x.id == order.id));
  gOpen(context, '257');
}

Future<Map<String, dynamic>?> _startMobileMoney(WidgetRef ref, Order o, String phone, Account who) {
  // l'opérateur se déduit du numéro (Orange : 69x, 655-659 ; MTN : 67x, 68x, 650-654) ; le moyen choisi ne tranche que les numéros ambigus
  final isOrange = RegExp(r'^(69|65[5-9])').hasMatch(phone);
  final isMtn = RegExp(r'^(67|68|65[0-4])').hasMatch(phone);
  final orange = isOrange || (!isMtn && ref.read(payMethodProvider) == 0);
  return _call({
    'action': 'start',
    'order_number': o.id,
    'phone': '+237$phone',
    'channel': orange ? 'cm.orange' : 'cm.mtn',
    'name': who.name,
    'email': who.email,
  });
}

/// Paiement par messagerie depuis un panier neuf (S10-16) : la commande (non payée) est créée avec la même vérification des totaux que
/// « Payer maintenant », puis le panier est vidé. Null : panier vide, livraison impossible ou refus (message déjà affiché).
Future<Order?> createOrderForMessagePayment(WidgetRef ref, BuildContext context) async {
  if (ref.read(cartProvider).isEmpty) return null;
  final shown = ref.read(totalsProvider);
  if (ref.read(homeDeliveryProvider) && shown.feeProblem != null) {
    await gAlert(context, 'Livraison à domicile', shown.feeProblem!);
    return null;
  }
  final o = await _createOrder(ref, context, shown.total);
  if (o != null) _completeCheckout(ref, keepAddress: true);
  return o;
}

/// Crée la commande sur le serveur à partir du panier. Le total serveur peut différer de celui affiché (prix, vente flash, pack, frais) :
/// le client le confirme avant tout prélèvement. Retourne la commande enregistrée, ou null (échec affiché, ou refus du client).
Future<Order?> _createOrder(WidgetRef ref, BuildContext context, int shownTotal) async {
  final pay = ref.read(payProvider.notifier);
  final o = ref.read(ordersProvider.notifier).place();
  final created = await Backend.createOrder(o.lines, ref.read(homeDeliveryProvider), o.method, address: ref.read(selectedAddressProvider));
  if (created['error'] != null) {
    ref.read(ordersProvider.notifier).discard(o.id);
    final raw = created['error'] as String;
    final msg = raw.startsWith('Stock insuffisant') ? 'Stock insuffisant pour « ${raw.split(': ').last} ». Réduisez la quantité.' : raw;
    pay.set(PayState(PayPhase.failed, msg));
    if (context.mounted) gToast(context, msg);
    return null;
  }
  final number = created['number'] as String;
  final subtotal = (created['subtotal'] as num).toInt(), fee = (created['fee'] as num).toInt();
  ref.read(ordersProvider.notifier).adopt(o.id, number, subtotal, fee, discount: (created['discount'] as num?)?.toInt() ?? 0);
  ref.read(selectedOrderIdProvider.notifier).set(number);
  if (subtotal + fee != shownTotal) {
    if (!context.mounted) return null;
    final ok = await gConfirm(context, 'Le total a changé', 'Le total de votre commande est de ${fcfa(subtotal + fee)} (au lieu de ${fcfa(shownTotal)} affichés : prix, promotion ou livraison mis à jour). Voulez-vous continuer ?', yes: 'Continuer', no: 'Annuler');
    if (!ok) {
      await Backend.cancelOrder(number);
      ref.read(ordersProvider.notifier).discard(number);
      pay.set(const PayState(PayPhase.idle));
      return null;
    }
  }
  return ref.read(ordersProvider).firstWhere((x) => x.id == number);
}

/// Une commande réelle (enregistrée sur le serveur), non payée et non annulée peut être annulée avec un motif (écran 47).
bool canCancelViewedOrder(WidgetRef ref) {
  if (!Backend.ready || demoContent) return false;
  final o = ref.watch(viewedOrderProvider);
  return !o.paid && !o.cancelled && o.status < 2 && ref.watch(ordersProvider).any((x) => x.id == o.id);
}

/// Motif choisi sur l'écran 47 (valeurs acceptées par le serveur).
const cancelReasons = ['wrong_product', 'too_slow', 'better_offer', 'other'];

class CancelReason extends Notifier<int> {
  @override
  int build() => 0;
  void set(int v) => state = v.clamp(0, cancelReasons.length - 1);
}

final cancelReasonProvider = NotifierProvider<CancelReason, int>(CancelReason.new);

/// « Annuler la commande » : seule une commande impayée peut l'être ; le serveur restitue le stock réservé.
Future<void> cancelViewedOrder(WidgetRef ref, BuildContext context) async {
  final o = ref.read(viewedOrderProvider);
  if (o.cancelled) return gToast(context, 'Cette commande est déjà annulée.');
  if (o.paid && Backend.ready && !o.cod) {
    final go = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Commande déjà payée'),
        content: const Text('Une commande payée ne s’annule pas directement : envoyez une demande d’annulation. Le support ou la finance l’examine, vous êtes remboursé si elle est acceptée, et le vendeur est prévenu.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fermer')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Demander l’annulation'))],
      ),
    );
    if (go == true && context.mounted) await requestViewedOrderRefund(ref, context);
    return;
  }
  if (o.paid) return gAlert(context, 'Annulation impossible', 'Cette commande est déjà payée : déposez une réclamation depuis le suivi de commande.');
  if (Backend.ready) {
    final err = await Backend.cancelOrderWithReason(o.id, cancelReasons[ref.read(cancelReasonProvider)]);
    if (err != null) {
      if (context.mounted) await gAlert(context, 'Annulation impossible', err);
      return;
    }
  }
  ref.read(ordersProvider.notifier).cancel(o.id);
  ref.read(cancelReasonProvider.notifier).set(0);
  if (ref.read(payProvider).phase != PayPhase.idle) ref.read(payProvider.notifier).set(const PayState(PayPhase.idle));
  if (!context.mounted) return;
  gToast(context, 'Commande annulée');
  gTab(context, '03');
}

/// Commande visée par « Copier la référence » et « J'ai payé » : la plus récente commande impayée du compte connecté ;
/// null (connecté au serveur) quand aucune commande réelle n'est à payer. Hors connexion (démonstration), la commande affichée.
Order? _orderToSettle(WidgetRef ref) => Backend.ready ? ref.read(payableOrderProvider) : ref.read(viewedOrderProvider);

/// Copie la référence de la commande dans le presse-papiers.
Future<void> copyOrderRef(WidgetRef ref, BuildContext context) async {
  final o = _orderToSettle(ref);
  if (o == null) return gToast(context, 'Aucune commande : la référence sera attribuée à la validation.');
  await Clipboard.setData(ClipboardData(text: o.id));
  if (context.mounted) gToast(context, 'Référence ${o.id} copiée');
}

/// « J'ai payé » : interroge le serveur de paiement ; la commande n'est confirmée que si le paiement l'est réellement.
Future<void> checkPaymentNow(WidgetRef ref, BuildContext context) async {
  if (!await requireLogin(context, ref, 'vérifier votre paiement') || !context.mounted) return;
  final o = _orderToSettle(ref);
  if (o == null) return gToast(context, 'Aucune commande à vérifier.');
  await ref.read(payProvider.notifier).check(context, o);
}
