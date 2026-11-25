import 'package:boutik_ecole/data/demo/section_a_demo.dart' show CartLine;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/variant_stock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H12 · stock par variante : sélecteur acheteur (muet / 500 / épuisée / dernières unités), commande (variant_id envoyé, succès,
/// refus serveur, panne, aucune confirmation), gestion vendeur (ajout, modification, ajustement, désactivation, refus, panne). Faux serveur local.
const _listing = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

Map<String, dynamic> _pub(String id, String label, String state, {int? left}) => {'id': id, 'label': label, 'state': state, 'active': true, 'left': ?left};

Map<String, dynamic> _own(String id, String label, int stock, {int threshold = 3, bool active = true, String? sku, Map<String, String>? attrs}) => {
      'id': id,
      'label': label,
      'stock': stock,
      'low_threshold': threshold,
      'active': active,
      'sku': sku,
      'attributes': attrs ?? <String, String>{},
      'state': stock <= 0 ? 'out' : (stock <= threshold ? 'low' : 'available'),
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
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)))));
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

  group('Sélecteur de variante (acheteur)', () {
    testWidgets('serveur muet (404) : annonce sans variante, aucun sélecteur ni donnée inventée', (t) async {
      srv.unknownIsError = true;
      await host(t, VariantPicker(listingId: _listing, selectedId: null, onSelect: (_) {}));
      await settleReal(t);
      expect(find.text('Choisissez une variante'), findsNothing);
      expect(srv.callsOf('listing_variants_public'), hasLength(1));
      await fin(t);
    });

    testWidgets('panne serveur (500) : erreur lisible avec Réessayer, jamais « aucune variante »', (t) async {
      srv.failRpc.add('listing_variants_public');
      await host(t, VariantPicker(listingId: _listing, selectedId: null, onSelect: (_) {}));
      await attendre(t, find.text('Réessayer'));
      expect(find.textContaining('n’ont pas pu être chargées'), findsOneWidget);
      expect(find.text('Choisissez une variante'), findsNothing);
      srv.failRpc.clear();
      srv.rpc['listing_variants_public'] = (_) => [_pub('v1', 'M — Rouge', 'available')];
      await t.tap(find.text('Réessayer'));
      await attendre(t, find.text('Choisissez une variante'));
      expect(find.text('M — Rouge'), findsOneWidget);
      await fin(t);
    });

    testWidgets('variante épuisée refusée, dernières unités signalées, disponible sélectionnable', (t) async {
      srv.rpc['listing_variants_public'] = (a) {
        expect(a['p_listing'], _listing);
        return [_pub('v1', 'S — Rouge', 'out'), _pub('v2', 'M — Rouge', 'low', left: 2), _pub('v3', 'L — Rouge', 'available')];
      };
      final chosen = <String>[];
      await host(t, VariantPicker(listingId: _listing, selectedId: 'v2', onSelect: (v) => chosen.add(v.id)));
      await attendre(t, find.text('Choisissez une variante'));
      expect(find.text('S — Rouge · épuisée'), findsOneWidget);
      expect(find.text('M — Rouge · plus que 2'), findsOneWidget);
      expect(find.textContaining('Derniers exemplaires : plus que 2'), findsOneWidget);
      await t.tap(find.text('S — Rouge · épuisée'));
      await t.pump();
      expect(chosen, isEmpty);
      expect(find.textContaining('est épuisée'), findsOneWidget);
      await t.tap(find.text('L — Rouge'));
      await t.pump();
      expect(chosen, ['v3']);
      await fin(t);
    });
  });

  group('Commande avec variante', () {
    const line = CartLine('Polo', 'Boutique', 5000, '', variant: 'M — Rouge', variantId: 'v2');

    test('le panier conserve la variante à stock propre', () {
      final back = CartLine.fromJson(line.toJson())!;
      expect(back.variantId, 'v2');
      expect(back.withQty(3).variantId, 'v2');
      expect(CartLine.fromJson(const CartLine('X', '', 100, '').toJson())!.variantId, isNull);
    });

    test('succès : variant_id envoyé au serveur, numéro de commande confirmé par le serveur', () async {
      srv.calls.clear();
      srv.rpc['marketplace_checkout'] = (_) => {'number': '#BE-2026-0001', 'subtotal': 5000, 'fee': 0, 'discount': 0};
      final r = await Backend.createOrder([line], false, 'wave');
      expect(r['error'], isNull);
      expect(r['number'], '#BE-2026-0001');
      final items = srv.callsOf('marketplace_checkout').single.args['p_items'] as List;
      expect((items.single as Map)['variant_id'], 'v2');
      expect((items.single as Map)['title'], 'Polo');
    });

    test('la clé d\'idempotence distingue deux variantes du même produit', () async {
      srv.calls.clear();
      srv.rpc['marketplace_checkout'] = (_) => {'number': '#BE-2026-0002'};
      await Backend.createOrder([line], false, 'wave');
      await Backend.createOrder([const CartLine('Polo', 'Boutique', 5000, '', variant: 'L — Rouge', variantId: 'v3')], false, 'wave');
      final keys = [for (final c in srv.callsOf('marketplace_checkout')) c.args['p_key']];
      expect(keys, hasLength(2));
      expect(keys[0], isNot(keys[1]));
    });

    test('refus serveur (variante épuisée) : message du serveur sans code interne, aucune confirmation', () async {
      srv.rpc['marketplace_checkout'] = (_) => throw const FakeRpcError('Stock insuffisant pour « Polo — M — Rouge » : 0 disponible(s) (variant_out_of_stock)');
      final r = await Backend.createOrder([line], false, 'wave');
      expect(r['number'], isNull);
      expect('${r['error']}', contains('Stock insuffisant pour « Polo — M — Rouge »'));
      expect('${r['error']}', isNot(contains('variant_out_of_stock')));
    });

    test('variante retirée : refus lisible, aucune confirmation', () async {
      srv.rpc['marketplace_checkout'] = (_) => throw const FakeRpcError('Cette variante de « Polo » n\'est plus proposée : choisissez-en une autre (variant_unavailable)');
      final r = await Backend.createOrder([line], false, 'wave');
      expect(r['number'], isNull);
      expect('${r['error']}', contains('n\'est plus proposée'));
      expect('${r['error']}', isNot(contains('variant_unavailable')));
    });

    test('panne serveur (500) : erreur, aucune confirmation', () async {
      srv.failRpc.add('marketplace_checkout');
      final r = await Backend.createOrder([line], false, 'wave');
      expect(r['number'], isNull);
      expect('${r['error']}', isNotEmpty);
    });

    test('serveur muet (404) : « pas disponible », aucune confirmation', () async {
      srv.unknownIsError = true;
      final r = await Backend.createOrder([line], false, 'wave');
      expect(r['number'], isNull);
      expect('${r['error']}', contains('n’est pas disponible pour le moment'));
    });
  });

  group('Stock par variante (vendeur)', () {
    Future<void> ouvre(WidgetTester t) async {
      await host(t, const VariantStockSection(listingId: _listing));
      await attendre(t, find.text('Ajouter une variante'));
    }

    Finder champ(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);

    testWidgets('serveur muet (404) : message honnête, aucune variante, pas de bouton d\'ajout', (t) async {
      srv.unknownIsError = true;
      await host(t, const VariantStockSection(listingId: _listing));
      await attendre(t, find.text('Réessayer'));
      expect(find.textContaining('n’est pas disponible pour le moment'), findsOneWidget);
      expect(find.text('Ajouter une variante'), findsNothing);
      await fin(t);
    });

    testWidgets('panne serveur (500) sur la liste : erreur, jamais « aucune variante »', (t) async {
      srv.failRpc.add('seller_variants_list');
      await host(t, const VariantStockSection(listingId: _listing));
      await attendre(t, find.text('Réessayer'));
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucune variante'), findsNothing);
      expect(find.text('Ajouter une variante'), findsNothing);
      await fin(t);
    });

    testWidgets('liste : stock exact, état, seuil ; annonce sans variante = stock global', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10, sku: 'POLO-M-R', attrs: {'Taille': 'M'}), _own('v2', 'L — Rouge', 0), _own('v3', 'XL', 2, active: false)];
      await ouvre(t);
      expect(find.textContaining('Stock : 10 · alerte à 3 · SKU POLO-M-R'), findsOneWidget);
      expect(find.text('Épuisée'), findsOneWidget);
      expect(find.text('Désactivée'), findsOneWidget);
      expect(find.text('Taille : M'), findsOneWidget);
      await fin(t);
    });

    testWidgets('ajout : variant_save reçoit le libellé, les critères, le stock ; la liste est rechargée', (t) async {
      var rows = <Map<String, dynamic>>[];
      srv.rpc['seller_variants_list'] = (_) => rows;
      srv.rpc['variant_save'] = (a) {
        rows = [_own('new1', '${a['p_label']}', a['p_stock'] as int)];
        return rows.first;
      };
      await ouvre(t);
      expect(find.textContaining('Aucune variante'), findsOneWidget);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M — Bleu');
      await t.enterText(champ(1), 'Taille: M\nCouleur: Bleu');
      await t.enterText(champ(3), '7');
      await t.tap(find.text('Enregistrer'));
      for (var i = 0; i < 60 && find.byType(AlertDialog).evaluate().isNotEmpty; i++) {
        await settleReal(t, rounds: 2, ms: 100);
      }
      final a = srv.callsOf('variant_save').single.args;
      expect(a['p_listing'], _listing);
      expect(a['p_label'], 'M — Bleu');
      expect(a['p_attributes'], {'Taille': 'M', 'Couleur': 'Bleu'});
      expect(a['p_stock'], 7);
      expect(a.containsKey('p_id'), isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      await fin(t);
    });

    testWidgets('ajout refusé par le serveur : le dialogue reste ouvert avec le refus, aucune confirmation', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10)];
      srv.rpc['variant_save'] = (_) => throw const FakeRpcError('Cette annonce a déjà une variante « M — Rouge »');
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M — Rouge');
      await t.tap(find.text('Enregistrer'));
      await attendre(t, find.textContaining('a déjà une variante'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Variante ajoutée'), findsNothing);
      await fin(t);
    });

    testWidgets('ajout pendant une panne (500) : erreur dans le dialogue, aucune confirmation', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10)];
      srv.failRpc.add('variant_save');
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'S — Vert');
      await t.tap(find.text('Enregistrer'));
      await settleReal(t, rounds: 8);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Variante ajoutée'), findsNothing);
      expect(find.text('Enregistrer'), findsOneWidget);
      await fin(t);
    });

    testWidgets('libellé vide : refus local, aucun appel serveur', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M', 1)];
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Enregistrer'));
      await t.pump();
      expect(find.textContaining('Indiquez le libellé'), findsOneWidget);
      expect(srv.callsOf('variant_save'), isEmpty);
      await fin(t);
    });

    testWidgets('modification : variant_save reçoit p_id de la variante', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10)];
      srv.rpc['variant_save'] = (a) => _own('v1', '${a['p_label']}', 10);
      await ouvre(t);
      await t.tap(find.text('Modifier'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M — Écarlate');
      await t.tap(find.text('Enregistrer'));
      await settleReal(t, rounds: 8);
      final a = srv.callsOf('variant_save').single.args;
      expect(a['p_id'], 'v1');
      expect(a['p_label'], 'M — Écarlate');
      expect(a.containsKey('p_stock'), isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      await fin(t);
    });

    testWidgets('ajustement : motif obligatoire (refus local), puis variant_adjust avec le motif ; refus serveur affiché', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10)];
      srv.rpc['variant_adjust'] = (_) => throw const FakeRpcError('Stock insuffisant : il ne reste que 10 exemplaire(s), le stock ne peut pas devenir négatif');
      await ouvre(t);
      await t.tap(find.text('Ajuster le stock'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(find.byType(TextField).first, '4');
      await t.tap(find.text('Enregistrer'));
      await t.pump();
      expect(find.textContaining('Indiquez le motif'), findsOneWidget);
      expect(srv.callsOf('variant_adjust'), isEmpty);
      await t.enterText(find.byType(TextField).last, 'Inventaire');
      await t.tap(find.text('Enregistrer'));
      await attendre(t, find.textContaining('ne peut pas devenir négatif'));
      final a = srv.callsOf('variant_adjust').single.args;
      expect(a, {'p_id': 'v1', 'p_set': 4, 'p_reason': 'Inventaire'});
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Stock ajusté.'), findsNothing);
      await fin(t);
    });

    testWidgets('désactivation : variant_set_active(false) ; refus serveur annoncé tel quel', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10)];
      srv.rpc['variant_set_active'] = (a) => _own('v1', 'M — Rouge', 10, active: a['p_active'] as bool);
      await ouvre(t);
      await t.tap(find.byType(Switch));
      await settleReal(t, rounds: 6);
      expect(srv.callsOf('variant_set_active').single.args, {'p_id': 'v1', 'p_active': false});
      expect(find.textContaining('n’est plus proposée aux acheteurs'), findsOneWidget);
      await fin(t);
    });

    testWidgets('désactivation en panne (500) : aucune confirmation « désactivée »', (t) async {
      srv.rpc['seller_variants_list'] = (_) => [_own('v1', 'M — Rouge', 10)];
      srv.failRpc.add('variant_set_active');
      await ouvre(t);
      await t.tap(find.byType(Switch));
      await settleReal(t, rounds: 6);
      expect(find.textContaining('n’est plus proposée aux acheteurs'), findsNothing);
      await fin(t);
    });
  });
}
