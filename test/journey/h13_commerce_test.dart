import 'package:boutik_ecole/data/demo/section_a_demo.dart' show CartLine;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/commerce_logic.dart';
import 'package:boutik_ecole/figma/live/marche/variant_stock.dart';
import 'package:boutik_ecole/figma/live/order_tracking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13 · commerce : prix et image par variante (acheteur et vendeur), contrôle du panier avant commande (aucune commande partielle),
/// suivi et historique d'une commande (mêmes états pour acheteur, vendeur et administration). Faux serveur local, aucun accès réseau.
const _listing = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

Map<String, dynamic> _pub(String id, String label, {int? price, int? effective, String state = 'available'}) =>
    {'id': id, 'label': label, 'state': state, 'active': true, 'price': ?price, 'effective_price': ?effective};

Map<String, dynamic> _own(String id, String label, int stock, {int? price, int effective = 8000, int reserved = 0}) => {
      'id': id,
      'label': label,
      'stock': stock,
      'low_threshold': 3,
      'active': true,
      'attributes': <String, String>{},
      'state': stock <= 0 ? 'out' : 'available',
      'price': ?price,
      'effective_price': effective,
      'reserved': reserved,
    };

Map<String, dynamic> _tracking({String viewer = 'buyer', String state = 'to_prepare', String payment = 'paid', List<Map<String, dynamic>> events = const [], List<Map<String, dynamic>> refunds = const [], Map<String, dynamic>? reservation, bool multi = false}) => {
      'number': '#BE-2026-0042',
      'viewer': viewer,
      'state': state,
      'payment': payment,
      'paid': payment == 'paid',
      'subtotal': 17500,
      'fee': 500,
      'multi_shop': multi,
      'reservation': reservation,
      'shops': [
        {
          'shop': 'Boutique Alpha',
          'state': state,
          'subtotal': 9500,
          'lines': [
            {'qty': 1, 'title': 'Veste', 'variant': 'Premium', 'unit_price': 9500}
          ]
        },
        if (multi)
          {
            'shop': 'Boutique Beta',
            'state': 'preparing',
            'subtotal': 8000,
            'lines': [
              {'qty': 2, 'title': 'Cahier', 'unit_price': 4000}
            ]
          },
      ],
      'events': events,
      'refunds': refunds,
    };

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.unknownIsError = false;
    srv.failWrites = false;
  });
  tearDown(() => GScreen.mockupFrame = true);

  Future<void> host(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(420, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: child))));
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> attendre(WidgetTester t, Finder f) async {
    for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
      await settleReal(t, rounds: 2, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('Logique pure', () {
    test('cart_check : panier valide ou réponse absente => aucun message', () {
      expect(cartIssuesMessage(null), isNull);
      expect(cartIssuesMessage({'ok': true, 'lines': []}), isNull);
      expect(cartIssuesMessage({'ok': false, 'lines': []}), isNull);
    });

    test('cart_check : chaque article refusé est nommé avec sa boutique, aucune commande créée', () {
      final one = cartIssuesMessage({
        'ok': false,
        'lines': [
          {'ok': true, 'title': 'Cahier', 'shop': 'Beta'},
          {'ok': false, 'title': 'Veste', 'shop': 'Alpha', 'message': 'Stock insuffisant'},
        ]
      })!;
      expect(one, contains('Un article de votre panier pose problème'));
      expect(one, contains('Alpha — Stock insuffisant'));
      expect(one, isNot(contains('Beta')));
      expect(one, contains('aucune commande n’a été créée'));
      final two = cartIssuesMessage({
        'ok': false,
        'lines': [
          {'ok': false, 'title': 'Veste', 'shop': 'Alpha', 'message': 'Stock insuffisant'},
          {'ok': false, 'title': 'Cahier', 'message': 'Annonce retirée'},
        ]
      })!;
      expect(two, contains('2 articles de votre panier posent problème'));
      expect(two, contains('• Annonce retirée'));
    });

    test('une seule matrice d’états : libellés acheteur et libellés de la console admin cohérents', () {
      for (final s in orderStateLabels.keys) {
        expect(adminLabelForState(s), isNotEmpty);
      }
      expect(orderStateLabel('delivered'), 'Livrée');
      expect(orderStateLabel('inconnu'), 'État inconnu');
      expect(adminLabelForState('refunded'), 'Remboursée');
      expect(adminLabelForState('cancelled'), 'Annulée');
      expect(adminLabelForState('out_for_delivery'), 'Expédiée');
      expect(orderPaymentLabel('partially_refunded'), contains('en partie'));
      expect(orderPaymentLabel('n’importe quoi'), '');
    });

    test('réservation : texte seulement pour un état connu, rien d’inventé sinon', () {
      expect(reservationText(null), '');
      expect(reservationText({'state': 'x'}), '');
      expect(reservationText({'state': 'reserved', 'until': '2026-11-26T10:30:00Z'}), contains('réservés pour vous'));
      expect(reservationText({'state': 'payment_in_progress'}), contains('vérification'));
      expect(reservationText({'state': 'released'}), contains('remis en vente'));
    });

    test('variante : prix propre facultatif lu du serveur', () {
      final avec = StockVariant.fromJson(_pub('v1', 'Premium', price: 9500, effective: 9500))!;
      final sans = StockVariant.fromJson(_pub('v2', 'Standard', effective: 8000))!;
      expect(avec.hasOwnPrice, isTrue);
      expect(avec.price, 9500);
      expect(sans.hasOwnPrice, isFalse);
      expect(sans.effectivePrice, 8000);
    });
  });

  group('Prix de variante (acheteur)', () {
    testWidgets('le sélecteur affiche le prix propre, jamais de prix inventé pour les autres', (t) async {
      srv.rpc['listing_variants_public'] = (_) => [_pub('v1', 'Premium', price: 9500, effective: 9500), _pub('v2', 'Standard', effective: 8000)];
      await host(t, VariantPicker(listingId: _listing, selectedId: null, onSelect: (_) {}));
      await attendre(t, find.text('Choisissez une variante'));
      expect(find.textContaining('Premium · 9'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      await fin(t);
    });
  });

  group('Contrôle du panier avant commande', () {
    const l1 = CartLine('Veste', 'Alpha', 9500, '', variant: 'Premium', variantId: 'v1');
    const l2 = CartLine('Cahier', 'Beta', 4000, '');

    test('panier refusé : message par article, marketplace_checkout jamais appelé', () async {
      srv.rpc['cart_check'] = (_) => {
            'ok': false,
            'lines': [
              {'ok': false, 'shop': 'Alpha', 'title': 'Veste', 'message': 'Stock insuffisant'},
              {'ok': true, 'shop': 'Beta', 'title': 'Cahier'},
            ]
          };
      srv.rpc['marketplace_checkout'] = (_) => {'number': '#NE-DOIT-PAS-EXISTER'};
      final r = await Backend.createOrder([l1, l2], false, 'wave');
      expect(r['number'], isNull);
      expect('${r['error']}', contains('Alpha — Stock insuffisant'));
      expect(srv.callsOf('marketplace_checkout'), isEmpty);
      final items = srv.callsOf('cart_check').single.args['p_items'] as List;
      expect(items, hasLength(2));
      expect((items.first as Map)['variant_id'], 'v1');
      expect((items.first as Map).containsKey('price'), isFalse);
      expect((items.first as Map).containsKey('unit_price'), isFalse);
    });

    test('panier valide : la commande est créée par le serveur (une seule fois) et son numéro est celui du serveur', () async {
      srv.rpc['cart_check'] = (_) => {'ok': true, 'lines': []};
      srv.rpc['marketplace_checkout'] = (_) => {'number': '#BE-2026-0042', 'subtotal': 13500};
      final r = await Backend.createOrder([l1, l2], false, 'wave');
      expect(r['error'], isNull);
      expect(r['number'], '#BE-2026-0042');
      expect(srv.callsOf('marketplace_checkout'), hasLength(1));
    });

    test('cart_check absent du serveur (404) : la commande décide seule', () async {
      srv.rpc['marketplace_checkout'] = (_) => {'number': '#BE-2026-0043'};
      final r = await Backend.createOrder([l1], false, 'wave');
      expect(r['number'], '#BE-2026-0043');
    });

    test('cart_check en panne (500) : erreur, aucune commande tentée', () async {
      srv.failRpc.add('cart_check');
      srv.rpc['marketplace_checkout'] = (_) => {'number': '#NE-DOIT-PAS-EXISTER'};
      final r = await Backend.createOrder([l1], false, 'wave');
      expect(r['number'], isNull);
      expect('${r['error']}', isNotEmpty);
      expect(srv.callsOf('marketplace_checkout'), isEmpty);
    });
  });

  group('Variantes (vendeur) : prix et image', () {
    Finder champ(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);

    Future<void> ouvre(WidgetTester t) async {
      await host(t, const SingleChildScrollView(child: VariantStockSection(listingId: _listing)));
      await attendre(t, find.text('Ajouter une variante'));
    }

    testWidgets('liste : prix propre, prix de l’annonce et stock réservé par des commandes impayées', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'Premium', 10, price: 9500, reserved: 2), _own('v2', 'Standard', 4)];
      await ouvre(t);
      expect(find.textContaining('Prix propre : '), findsOneWidget);
      expect(find.textContaining('Prix : celui de l’annonce'), findsOneWidget);
      expect(find.textContaining('dont 2 réservé(s) par des commandes non payées'), findsOneWidget);
      await fin(t);
    });

    testWidgets('prix hors bornes : refus local, aucun appel serveur', (t) async {
      srv.rpc['seller_variants_list'] = (_) => <Map<String, dynamic>>[];
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'Premium');
      await t.enterText(champ(3), '5');
      await t.enterText(champ(5), '100');
      await t.tap(find.text('Enregistrer'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Prix de la variante : de 500'), findsOneWidget);
      expect(srv.callsOf('variant_save'), isEmpty);
      expect(srv.callsOf('variant_upsert'), isEmpty);
      await fin(t);
    });

    testWidgets('prix valide : variant_upsert reçoit le prix (une seule transaction serveur) ; sans prix : variant_save historique', (t) async {
      srv.rpc['seller_variants_list'] = (_) => <Map<String, dynamic>>[];
      srv.rpc['variant_upsert'] = (a) => _own('n1', '${a['p_label']}', 5, price: a['p_price'] as int?);
      srv.rpc['variant_save'] = (a) => _own('n2', '${a['p_label']}', 5);
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'Premium');
      await t.enterText(champ(3), '5');
      await t.enterText(champ(5), '9500');
      await t.tap(find.text('Enregistrer'));
      for (var i = 0; i < 60 && find.byType(AlertDialog).evaluate().isNotEmpty; i++) {
        await settleReal(t, rounds: 2, ms: 100);
      }
      final a = srv.callsOf('variant_upsert').single.args;
      expect(a['p_price'], 9500);
      expect(a['p_label'], 'Premium');
      expect(a['p_listing'], _listing);
      expect(srv.callsOf('variant_save'), isEmpty);

      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'Standard');
      await t.enterText(champ(3), '5');
      await t.tap(find.text('Enregistrer'));
      for (var i = 0; i < 60 && find.byType(AlertDialog).evaluate().isNotEmpty; i++) {
        await settleReal(t, rounds: 2, ms: 100);
      }
      expect(srv.callsOf('variant_save'), hasLength(1));
      expect(srv.callsOf('variant_save').single.args.containsKey('p_price'), isFalse);
      await fin(t);
    });

    testWidgets('refus du serveur sur le prix : le dialogue reste ouvert avec le refus', (t) async {
      srv.rpc['seller_variants_list'] = (_) => <Map<String, dynamic>>[];
      srv.rpc['variant_upsert'] = (_) => throw const FakeRpcError('Prix de variante invalide');
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'Premium');
      await t.enterText(champ(3), '5');
      await t.enterText(champ(5), '9500');
      await t.tap(find.text('Enregistrer'));
      await attendre(t, find.textContaining('Prix de variante invalide'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Prix de variante invalide'), findsOneWidget);
      await fin(t);
    });
  });

  group('Suivi de commande', () {
    testWidgets('acheteur multi-boutiques : états par boutique, historique réel, reçu non fiscal', (t) async {
      await host(
        t,
        OrderTrackingView(
          data: _tracking(multi: true, events: [
            {'label': 'Commande passée', 'at': '2026-11-25T08:00:00Z'},
            {'label': 'Paiement confirmé', 'at': '2026-11-25T08:05:00Z', 'shop': 'Boutique Alpha'},
          ]),
        ),
      );
      expect(find.text('#BE-2026-0042'), findsOneWidget);
      expect(find.text('Confirmée, à préparer'), findsWidgets);
      expect(find.text('Boutique Alpha'), findsOneWidget);
      expect(find.text('Boutique Beta'), findsOneWidget);
      expect(find.textContaining('un seul paiement'), findsOneWidget);
      expect(find.textContaining('1 × Veste (Premium) · 9'), findsOneWidget);
      expect(find.text('Commande passée'), findsOneWidget);
      expect(find.textContaining('Paiement confirmé'), findsOneWidget);
      expect(find.textContaining('justificatif non fiscal'), findsOneWidget);
    });

    testWidgets('vendeur : ne voit que ses articles et son montant, aucune étape inventée sans événement', (t) async {
      await host(t, OrderTrackingView(data: _tracking(viewer: 'seller', multi: true)));
      expect(find.textContaining('Montant de vos articles'), findsOneWidget);
      expect(find.textContaining('vous ne voyez et ne préparez que vos articles'), findsOneWidget);
      expect(find.text('Aucun événement enregistré.'), findsOneWidget);
      expect(find.textContaining('justificatif non fiscal'), findsNothing);
    });

    testWidgets('commande impayée : réservation du stock expliquée', (t) async {
      await host(t, OrderTrackingView(data: _tracking(state: 'awaiting_payment', payment: 'unpaid', reservation: {'state': 'reserved', 'until': '2026-11-26T10:30:00Z'})));
      expect(find.text('En attente de paiement'), findsWidgets);
      expect(find.textContaining('réservés pour vous'), findsOneWidget);
    });

    testWidgets('remboursement complet : accès numérique retiré ; remboursement partiel présenté comme tel, sans décision inventée', (t) async {
      await host(
        t,
        OrderTrackingView(
          data: _tracking(state: 'refunded', payment: 'refunded', refunds: [
            {'kind': 'full', 'status': 'refunded', 'amount': 18000},
            {'kind': 'partial', 'status': 'requested', 'amount': 0},
          ]),
        ),
      );
      expect(find.text('Remboursée'), findsWidgets);
      expect(find.textContaining('Complet · versé'), findsOneWidget);
      expect(find.textContaining('Partiel · demandé'), findsOneWidget);
      expect(find.textContaining('remboursement complet retire l’accès'), findsOneWidget);
    });

    testWidgets('écran : order_tracking appelé avec le numéro ; panne => erreur et Réessayer, jamais un faux état', (t) async {
      srv.failRpc.add('order_tracking');
      await host(t, const OrderTrackingScreen(number: '#BE-2026-0042'));
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Confirmée, à préparer'), findsNothing);
      expect(srv.callsOf('order_tracking').first.args['p_number'], '#BE-2026-0042');
      srv.failRpc.clear();
      srv.rpc['order_tracking'] = (_) => _tracking();
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.text('Confirmée, à préparer'));
      expect(find.text('Confirmée, à préparer'), findsWidgets);
      await fin(t);
    });
  });
}
