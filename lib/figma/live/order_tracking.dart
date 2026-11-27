import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart' show Text;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'store.dart';

/// Suivi et historique d'une commande (migration 20261128030100, fonction `order_tracking`) : la même matrice d'états pour l'acheteur, le vendeur et l'administration.
/// L'acheteur voit toutes les boutiques de sa commande, le vendeur seulement la sienne. La frise reprend les événements réels horodatés par le serveur :
/// aucune étape ni date n'est inventée. Un reçu de paiement n'est jamais une facture fiscale.

/// États d'une commande (une seule matrice, côté serveur).
const orderStateLabels = {
  'awaiting_payment': 'En attente de paiement',
  'to_prepare': 'Confirmée, à préparer',
  'accepted': 'Acceptée par la boutique',
  'preparing': 'En préparation',
  'ready': 'Prête',
  'out_for_delivery': 'En livraison',
  'delivered': 'Livrée',
  'cancelled': 'Annulée',
  'refunded': 'Remboursée',
};

const orderPaymentLabels = {
  'unpaid': 'Non payée',
  'cod_pending': 'À payer à la livraison',
  'paid': 'Payée',
  'partially_refunded': 'Payée, remboursée en partie',
  'refunded': 'Remboursée',
};

String orderStateLabel(Object? s) => orderStateLabels['$s'] ?? 'État inconnu';
String orderPaymentLabel(Object? s) => orderPaymentLabels['$s'] ?? '';

/// Libellé de la console d'administration (écran 132) pour un état de la matrice : les libellés historiques sont conservés.
String adminLabelForState(String s) => switch (s) {
      'awaiting_payment' => 'En attente de paiement',
      'to_prepare' => 'Confirmée',
      'accepted' || 'preparing' => 'En préparation',
      'ready' || 'out_for_delivery' => 'Expédiée',
      'delivered' => 'Livrée',
      'refunded' => 'Remboursée',
      _ => 'Annulée',
    };

/// Date et heure locales d'un horodatage du serveur.
String _when(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}h${two(d.minute)}';
}

/// Texte de la réservation de stock d'une commande impayée.
String reservationText(Object? r) {
  if (r is! Map) return '';
  return switch ('${r['state']}') {
    'reserved' => 'Articles réservés pour vous jusqu’au ${_when(r['until'])}. Passé ce délai sans paiement, la commande est annulée et le stock remis en vente.',
    'payment_in_progress' => 'Paiement en cours de vérification : vos articles restent réservés.',
    'released' => 'Réservation terminée : le stock a été remis en vente.',
    _ => '',
  };
}

final orderTrackingProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, number) async {
  final r = await marcheCall('order_tracking', {'p_number': number});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
}, retry: (_, _) => null);

/// Liste des commandes du compte, point d'entrée du suivi détaillé.
class OrderTrackingListScreen extends ConsumerWidget {
  const OrderTrackingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final loaded = ref.watch(ordersLoadedProvider);
    final failed = ref.watch(ordersFailedProvider);
    Widget body;
    if (orders.isEmpty && !loaded) {
      body = failed
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [mNote('Vos commandes ne peuvent pas être chargées pour le moment.'), mButton('Réessayer', () => ref.read(ordersProvider.notifier).refresh(), dark: false)]))
          : const Center(child: CircularProgressIndicator());
    } else if (orders.isEmpty) {
      body = mNote('Vous n’avez pas encore de commande. Vos achats apparaîtront ici avec leur suivi.');
    } else {
      body = ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        for (final o in orders)
          ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 12,
            title: Text(o.id, style: mst(14, w: FontWeight.w800)),
            subtitle: Text('${o.date} · ${mFcfa(o.total)} · ${o.badge}', style: mst(12.5, c: kGrey)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/commandes/suivi/${Uri.encodeComponent(o.id)}'),
          ),
      ]);
    }
    return MarchePage(title: 'Suivi de mes commandes', child: body);
  }
}

/// Détail et frise d'une commande.
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.number});
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(orderTrackingProvider(number));
    return MarchePage(
      title: 'Suivi de la commande',
      child: v.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            mNote(e is MarcheException ? e.toString() : marcheErrorText('$e')),
            mButton('Réessayer', () => ref.invalidate(orderTrackingProvider(number)), dark: false),
          ]),
        ),
        data: (d) => OrderTrackingView(data: d),
      ),
    );
  }
}

class OrderTrackingView extends StatelessWidget {
  const OrderTrackingView({super.key, required this.data});
  final Map<String, dynamic> data;

  List<Map<String, dynamic>> _list(Object? v) => [for (final x in (v as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];

  @override
  Widget build(BuildContext context) {
    final seller = data['viewer'] == 'seller';
    final shops = _list(data['shops']);
    final events = _list(data['events']);
    final refunds = _list(data['refunds']);
    final res = reservationText(data['reservation']);
    final payment = orderPaymentLabel(data['payment']);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      Text('${data['number']}', style: mst(20, w: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(orderStateLabel(data['state']), style: mst(15, w: FontWeight.w700, c: data['state'] == 'cancelled' || data['state'] == 'refunded' ? kRed : kGreen)),
      if (payment.isNotEmpty) Text('Paiement : $payment', style: mst(12.5, c: kGrey)),
      Text('${seller ? 'Montant de vos articles' : 'Total'} : ${mFcfa(seller ? data['subtotal'] : mInt(data['subtotal']) + mInt(data['fee']))}', style: mst(12.5, c: kGrey)),
      if (res.isNotEmpty) Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(8)), child: Text(res, style: mst(12.5, c: const Color(0xFF8A5A00)))),
      if (data['multi_shop'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(seller ? 'Cette commande réunit plusieurs boutiques : vous ne voyez et ne préparez que vos articles.' : 'Votre commande réunit ${shops.length} boutiques : un seul paiement, chaque boutique prépare et remet ses articles. L’état global est celui de la boutique la moins avancée.', style: mst(12, c: kGrey)),
        ),
      mSectionTitle(seller ? 'Vos articles' : 'Par boutique'),
      for (final s in shops)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('${s['shop']}', style: mst(14, w: FontWeight.w800))), Text(orderStateLabel(s['state']), style: mst(12, w: FontWeight.w700, c: kViolet))]),
            for (final l in _list(s['lines']))
              Text('${l['qty']} × ${l['title']}${'${l['variant'] ?? ''}'.isEmpty ? '' : ' (${l['variant']})'} · ${mFcfa(l['unit_price'])}', style: mst(12.5, c: kGrey)),
            Text('Sous-total : ${mFcfa(s['subtotal'])}', style: mst(12.5, w: FontWeight.w700)),
          ]),
        ),
      mSectionTitle('Historique'),
      if (events.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Aucun événement enregistré.', style: mst(13, c: kGrey))),
      for (final e in events)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 4, right: 10), child: Icon(Icons.circle, size: 10, color: kViolet)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['label']}${e['shop'] == null ? '' : ' · ${e['shop']}'}', style: mst(13.5, w: FontWeight.w600)),
              Text(_when(e['at']), style: mst(12, c: kGrey)),
            ])),
          ]),
        ),
      if (refunds.isNotEmpty) ...[
        mSectionTitle('Remboursements'),
        for (final r in refunds)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${r['kind'] == 'partial' ? 'Partiel' : 'Complet'} · ${const {'requested': 'demandé', 'approved': 'accordé', 'refunded': 'versé', 'rejected': 'refusé'}['${r['status']}'] ?? r['status']}${mInt(r['amount']) > 0 ? ' · ${mFcfa(r['amount'])}' : ''}', style: mst(13, c: kGrey)),
          ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text('Un remboursement complet retire l’accès aux ressources numériques de la commande ; un remboursement partiel le conserve.', style: mst(12, c: kGrey))),
      ],
      if (data['paid'] == true && !seller)
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text('Le reçu de paiement est un justificatif non fiscal : il n’a pas valeur de facture légale.', style: mst(12, c: kGrey))),
    ]);
  }
}
