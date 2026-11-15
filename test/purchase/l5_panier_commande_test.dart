import 'package:boutik_ecole/data/demo/section_a_demo.dart' show CartLine, maxCartQty;
import 'package:boutik_ecole/figma/live/docs.dart';
import 'package:boutik_ecole/figma/live/order_summary.dart';
import 'package:boutik_ecole/figma/live/orders_list.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lot L5 : numéros de documents cohérents, libellés honnêtes du reçu, recherche et filtres de « Mes commandes ».
Order _order(String id, {int status = 0, bool paid = false, bool cancelled = false, bool cod = false, int fee = 0, int discount = 0, String promo = '', String title = 'Lampe'}) =>
    Order(id: id, date: '1 janv. 2026', lines: [CartLine(title, '', 10000, '')], subtotal: 10000, fee: fee, method: 'Orange Money', reference: '', status: status, paid: paid, cancelled: cancelled, cod: cod, discount: discount, promoCode: promo);

void main() {
  test('le numéro de facture et de reçu dérive du numéro de commande, identique à l’écran et dans le PDF', () {
    final o = _order('#BE-2026-0142');
    expect(documentNumber(o, invoice: true), 'FA-2026-0142');
    expect(documentNumber(o, invoice: false), 'RC-2026-0142');
  });

  test('un reçu de paiement n’est émis que pour une commande payée', () {
    expect(documentTitle(_order('#BE-2026-0001', paid: true), invoice: false), 'REÇU DE PAIEMENT');
    expect(documentTitle(_order('#BE-2026-0002', cod: true), invoice: false), 'CONFIRMATION DE COMMANDE');
    expect(documentTitle(_order('#BE-2026-0003'), invoice: false), 'RÉCAPITULATIF DE COMMANDE');
    expect(documentTitle(_order('#BE-2026-0003'), invoice: true), 'FACTURE');
  });

  test('l’état de paiement d’une commande à payer à la livraison n’est jamais « Payé »', () {
    expect(orderPaymentStatus(_order('#BE-2026-0004', cod: true)), 'À payer à la livraison');
    expect(orderPaymentStatus(_order('#BE-2026-0005', paid: true)), 'Payé');
    expect(orderPaymentStatus(_order('#BE-2026-0006', cancelled: true)), 'Annulée');
  });

  test('la remise est visible sur la ligne des montants', () {
    final o = _order('#BE-2026-0007', fee: 1000, discount: 2000, promo: 'BIENVENUE');
    expect(orderAmountLine(o), contains('remise'));
    expect(orderAmountLine(o), contains('BIENVENUE'));
    expect(orderAmountLine(o), contains('livraison'));
  });

  test('la recherche, le filtre et le tri de « Mes commandes » agissent réellement', () {
    final all = [
      _order('#BE-2026-0003', status: 3, paid: true, title: 'Sac à dos'),
      _order('#BE-2026-0002', cancelled: true, title: 'Lampe'),
      _order('#BE-2026-0001', status: 1, paid: true, title: 'Drone'),
    ];
    expect(filterOrders(all).length, 3);
    expect(filterOrders(all, query: 'drone').map((o) => o.id), ['#BE-2026-0001']);
    expect(filterOrders(all, filter: 2).map((o) => o.id), ['#BE-2026-0003']);
    expect(filterOrders(all, filter: 3).map((o) => o.id), ['#BE-2026-0002']);
    expect(filterOrders(all, filter: 1).map((o) => o.id), ['#BE-2026-0001']);
    expect(filterOrders(all, sort: 1).map((o) => o.id), ['#BE-2026-0001', '#BE-2026-0002', '#BE-2026-0003']);
  });

  test('la quantité d’une ligne du panier est plafonnée à 20', () {
    expect(maxCartQty, 20);
    expect(const CartLine('Lampe', '', 1000, '').withQty(5).qty, 5);
  });

  test('une commande annulée a une frise vide et un badge « Annulée »', () {
    final o = _order('#BE-2026-0008', cancelled: true);
    expect(o.step, -1);
    expect(o.badge, 'Annulée');
  });
}
