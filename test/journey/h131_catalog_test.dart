import 'dart:typed_data';

import 'package:boutik_ecole/data/demo/section_a_demo.dart' show CartLine;
import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/commerce_logic.dart';
import 'package:boutik_ecole/figma/live/docs.dart' show documentTitle, orderPaymentStatus;
import 'package:boutik_ecole/figma/live/marche/marche_data.dart' show mFcfa;
import 'package:boutik_ecole/figma/live/marche/marche_screens.dart';
import 'package:boutik_ecole/figma/live/marche/marche_widgets.dart' show MChip;
import 'package:boutik_ecole/figma/live/marche/variant_stock.dart';
import 'package:boutik_ecole/figma/live/pay.dart';
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_supabase.dart';
import '../helpers/render.dart';

/// H13.1 · catalogue : téléversement réel des images de variantes (chemin, orphelins, erreurs honnêtes), fiche produit (prix et disponibilité par variante),
/// ajout au panier au prix de la variante, états de paiement jamais simulés. Faux serveur local, aucun accès réseau.
const _listing = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _uid = FakeSupabase.userId;

Map<String, dynamic> _pub(String id, String label, {int? price, int effective = 8000, String state = 'available', int? left, String? image}) =>
    {'id': id, 'label': label, 'state': state, 'active': true, 'price': ?price, 'effective_price': effective, 'left': ?left, 'image': ?image};

Map<String, dynamic> _own(String id, String label, int stock, {int? price, String? image}) =>
    {'id': id, 'label': label, 'stock': stock, 'low_threshold': 3, 'active': true, 'attributes': <String, String>{}, 'state': 'available', 'price': ?price, 'effective_price': price ?? 8000, 'image': ?image};

Map<String, dynamic> _product({int stock = 20}) => {
      'found': true,
      'card': {'id': _listing, 'title': 'Robe H131', 'price': 8000, 'stock': stock, 'image': '', 'shop_name': 'Boutique Awa', 'shop_slug': 'boutique-awa', 'city': 'Douala'},
      'description': 'Robe en pagne.',
      'images': <String>[],
      'variants': <Map<String, dynamic>>[],
      'specs': <String, String>{},
      'is_owner': false,
      'alerts': <String>[],
      'questions': <Map<String, dynamic>>[],
      'reviews': <Map<String, dynamic>>[],
    };

({Uint8List bytes, String mime}) _png() => (bytes: Uint8List.fromList(List.filled(64, 7)), mime: 'image/png');

void main() {
  late FakeSupabase srv;
  setUpAll(() async {
    await loadAppFonts();
    srv = await FakeSupabase.start();
    await srv.initSupabase();
  });
  tearDownAll(() => srv.close());

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GScreen.mockupFrame = false;
    GAnim.enabled = false;
    Backend.ready = true;
    srv.rpc.clear();
    srv.tables.clear();
    srv.calls.clear();
    srv.failRpc.clear();
    srv.functions.clear();
    srv.unknownIsError = false;
    srv.failWrites = false;
    srv.failStorage = false;
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    variantImagePicker = () async => null;
  });

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

  Future<void> until(WidgetTester t, bool Function() cond) async {
    for (var i = 0; i < 60 && !cond(); i++) {
      await settleReal(t, rounds: 1, ms: 100);
    }
  }

  Future<void> fin(WidgetTester t) async {
    await settleReal(t, rounds: 5, ms: 100);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 60));
  }

  group('Logique pure', () {
    test('chemin d’image de variante : <vendeur>/<annonce>/variante-<horodatage>.<ext>, jamais le nom du fichier choisi', () {
      expect(variantImagePath('U', 'L', 'png', 123), 'U/L/variante-123.png');
      final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/([A-Za-z0-9._ -]{1,80}/){0,2}[A-Za-z0-9._ -]{1,150}\.(jpg|jpeg|png|webp)$', caseSensitive: false);
      expect(re.hasMatch(variantImagePath(_uid, _listing, 'webp', DateTime.now().microsecondsSinceEpoch)), isTrue, reason: 'même format que la validation du serveur');
    });

    test('type MIME -> extension ; autres formats refusés', () {
      expect(variantImageExtension('image/jpeg'), 'jpg');
      expect(variantImageExtension('IMAGE/PNG'), 'png');
      expect(variantImageExtension('image/webp'), 'webp');
      expect(variantImageExtension('image/gif'), isNull);
      expect(variantImageExtension('application/octet-stream'), isNull);
    });

    test('seuls les fichiers déposés par le formulaire de variante sont supprimables (jamais une photo de l’annonce)', () {
      expect(isVariantImageUpload('$_uid/$_listing/variante-1.jpg'), isTrue);
      expect(isVariantImageUpload('$_uid/variantes/1-m.jpg'), isTrue);
      expect(isVariantImageUpload('$_uid/$_listing/1700-photo.jpg'), isFalse);
      expect(isVariantImageUpload('photo.jpg'), isFalse);
    });

    test('quantité du panier : plafonnée au plus petit stock connu', () {
      expect(cartQtyCap(20), 20);
      expect(cartQtyCap(20, variantLeft: 2), 2);
      expect(cartQtyCap(20, variantLeft: 5, productStock: 3), 3);
      expect(cartQtyCap(20, productStock: 50), 20);
      expect(cartQtyCap(20, variantLeft: 0), 1);
    });

    test('variante : disponibilité et prix affiché (propre, sinon celui de l’annonce)', () {
      final out = StockVariant.fromJson(_pub('a', 'L', state: 'out'))!;
      final low = StockVariant.fromJson(_pub('b', 'M', state: 'low', left: 2, price: 9500))!;
      final ok = StockVariant.fromJson(_pub('c', 'S'))!;
      expect(variantAvailability(out), 'épuisée');
      expect(variantAvailability(low), 'plus que 2');
      expect(variantAvailability(ok), 'disponible');
      expect(variantShownPrice(low, fallback: 5000), 9500);
      expect(variantShownPrice(ok, fallback: 5000), 5000, reason: 'vente flash de l’annonce');
      expect(variantShownPrice(ok), 8000);
    });

    test('panier : une même annonce avec deux variantes = deux lignes ; même variante = quantités cumulées', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(cartProvider.notifier);
      while (c.read(cartProvider).isNotEmpty) {
        n.remove(0);
      }
      n.add(const CartLine('Robe', 'Boutique : A', 9500, '', variant: 'M', variantId: 'vm'));
      n.add(const CartLine('Robe', 'Boutique : A', 8000, '', variant: 'S', variantId: 'vs'));
      n.add(const CartLine('Robe', 'Boutique : A', 9500, '', variant: 'M', variantId: 'vm'));
      final l = c.read(cartProvider);
      expect(l, hasLength(2));
      expect(l.firstWhere((x) => x.variantId == 'vm').qty, 2);
      expect(l.firstWhere((x) => x.variantId == 'vs').price, 8000);
    });

    test('ligne de panier : annonce et plafond conservés après relecture, envoyés à la commande sans prix', () {
      const l = CartLine('Robe', 'Boutique : A', 9500, '', variant: 'M', variantId: 'vm', listingId: _listing, maxQty: 2);
      final back = CartLine.fromJson(l.toJson())!;
      expect(back.listingId, _listing);
      expect(back.maxQty, 2);
      expect(back.withQty(2).maxQty, 2);
      final item = Backend.orderItems([l]).single;
      expect(item, {'title': 'Robe', 'qty': 1, 'id': _listing, 'variant': 'M', 'variant_id': 'vm'});
    });
  });

  group('Téléversement des images de variantes (vendeur)', () {
    Finder champ(int i) => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).at(i);
    final stored = RegExp(r'^/storage/v1/object/listing-images/(.+)$');

    List<String> uploads() => [for (final c in srv.calls) if (c.kind == 'storage' && c.args['method'] != 'DELETE' && stored.hasMatch(c.name)) stored.firstMatch(c.name)!.group(1)!];
    List<String> deletions() => [for (final c in srv.calls) if (c.kind == 'storage' && c.args['method'] == 'DELETE') '${c.args['body']}'];

    Future<void> ouvre(WidgetTester t, {List<Map<String, dynamic>> list = const []}) async {
      srv.rpc['seller_variants_list'] = (_) => list;
      await host(t, const SingleChildScrollView(child: VariantStockSection(listingId: _listing)));
      await attendre(t, find.text('Ajouter une variante'));
    }

    Future<void> pick(WidgetTester t, {({Uint8List bytes, String mime})? file, bool upload = true}) async {
      variantImagePicker = () async => file ?? _png();
      final before = uploads().length;
      await t.tap(find.textContaining(RegExp('Ajouter une image|Changer l’image')));
      if (upload) {
        await until(t, () => uploads().length > before);
        await settleReal(t, rounds: 4, ms: 100);
      } else {
        await settleReal(t, rounds: 6, ms: 100);
      }
    }

    Future<void> save(WidgetTester t) async {
      await t.tap(find.text('Enregistrer'));
      await settleReal(t, rounds: 6, ms: 100);
    }

    Future<void> deleted(WidgetTester t, int n) => until(t, () => deletions().length >= n);

    testWidgets('dépôt dans <vendeur>/<annonce>/variante-….png, puis variant_upsert reçoit ce même chemin ; aucun fichier supprimé', (t) async {
      srv.rpc['variant_upsert'] = (a) => _own('n1', '${a['p_label']}', 5, image: a['p_image'] as String?);
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M — Rouge');
      await t.enterText(champ(3), '5');
      await pick(t);
      final up = uploads();
      expect(up, hasLength(1));
      expect(up.single, startsWith('$_uid/$_listing/variante-'));
      expect(up.single, endsWith('.png'));
      await save(t);
      final a = srv.callsOf('variant_upsert').single.args;
      expect(a['p_image'], up.single, reason: 'l’image est associée à la variante enregistrée');
      expect(a.containsKey('p_clear_image'), isFalse);
      expect(deletions(), isEmpty);
      await fin(t);
    });

    testWidgets('autre image choisie avant d’enregistrer : la précédente (non utilisée) est supprimée, la dernière est enregistrée', (t) async {
      srv.rpc['variant_upsert'] = (a) => _own('n1', '${a['p_label']}', 5, image: a['p_image'] as String?);
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M');
      await pick(t);
      await pick(t);
      final up = uploads();
      expect(up, hasLength(2));
      expect(up[0] == up[1], isFalse);
      await deleted(t, 1);
      expect(deletions().single, contains(up[0]));
      await save(t);
      expect(srv.callsOf('variant_upsert').single.args['p_image'], up[1]);
      expect(deletions(), hasLength(1), reason: 'la dernière image reste');
      await fin(t);
    });

    testWidgets('dialogue quitté sans enregistrer : le fichier déposé est supprimé (aucune orpheline)', (t) async {
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await pick(t);
      final up = uploads().single;
      await t.tap(find.text('Annuler'));
      await deleted(t, 1);
      expect(deletions().single, contains(up));
      expect(srv.callsOf('variant_upsert'), isEmpty);
      await fin(t);
    });

    testWidgets('« Retirer » une image déposée par ce dialogue : fichier supprimé, aucun p_image envoyé', (t) async {
      srv.rpc['variant_save'] = (a) => _own('n1', '${a['p_label']}', 5);
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M');
      await pick(t);
      final up = uploads().single;
      await t.tap(find.text('Retirer'));
      await deleted(t, 1);
      expect(deletions().single, contains(up));
      await save(t);
      expect(srv.callsOf('variant_upsert'), isEmpty);
      expect(srv.callsOf('variant_save'), hasLength(1));
      await fin(t);
    });

    testWidgets('refus du serveur sur l’image : le dialogue reste ouvert avec le refus, rien n’est supprimé tant que le dialogue est ouvert', (t) async {
      srv.rpc['variant_upsert'] = (_) => throw const FakeRpcError('Image invalide : choisissez une image envoyée depuis votre compte (jpg, png ou webp)');
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M');
      await pick(t);
      await save(t);
      await attendre(t, find.textContaining('Image invalide'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Image invalide'), findsOneWidget);
      expect(deletions(), isEmpty);
      await t.tap(find.text('Annuler'));
      await deleted(t, 1);
      expect(deletions(), hasLength(1), reason: 'le fichier non rattaché est supprimé à la fermeture');
      await fin(t);
    });

    testWidgets('panne du stockage : erreur honnête dans le dialogue, aucune image associée', (t) async {
      srv.failStorage = true;
      srv.rpc['variant_save'] = (a) => _own('n1', '${a['p_label']}', 5);
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await t.enterText(champ(0), 'M');
      await pick(t);
      expect(find.textContaining('Envoi impossible'), findsOneWidget);
      expect(find.text('Ajouter une image'), findsOneWidget, reason: 'aucune image n’est présentée comme envoyée');
      await save(t);
      expect(srv.callsOf('variant_upsert'), isEmpty);
      await fin(t);
    });

    testWidgets('format refusé (GIF) : message clair, aucun envoi', (t) async {
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await pick(t, file: (bytes: Uint8List(8), mime: 'image/gif'));
      expect(find.text('Format accepté : JPEG, PNG ou WebP.'), findsOneWidget);
      expect(uploads(), isEmpty);
      await fin(t);
    });

    testWidgets('image trop lourde (> 5 Mo) : refus local, aucun envoi', (t) async {
      await ouvre(t);
      await t.tap(find.text('Ajouter une variante'));
      await t.pump(const Duration(milliseconds: 300));
      await pick(t, file: (bytes: Uint8List(5 * 1024 * 1024 + 1), mime: 'image/jpeg'));
      expect(find.textContaining('5 Mo maximum'), findsOneWidget);
      expect(uploads(), isEmpty);
      await fin(t);
    });

    testWidgets('remplacement d’une image existante : après enregistrement confirmé, l’ancien fichier de variante est supprimé', (t) async {
      final old = '$_uid/$_listing/variante-1.jpg';
      srv.rpc['variant_upsert'] = (a) => _own('v1', 'M', 5, image: a['p_image'] as String?);
      await ouvre(t, list: [_own('v1', 'M', 5, image: old)]);
      await t.tap(find.text('Modifier'));
      await t.pump(const Duration(milliseconds: 300));
      await pick(t);
      final nouveau = uploads().single;
      expect(deletions(), isEmpty, reason: 'l’ancien fichier reste tant que le remplacement n’est pas confirmé');
      await save(t);
      expect(srv.callsOf('variant_upsert').single.args['p_image'], nouveau);
      await deleted(t, 1);
      expect(deletions().single, contains(old));
      await fin(t);
    });

    testWidgets('retrait d’une image existante : p_clear_image, puis suppression de l’ancien fichier de variante', (t) async {
      final old = '$_uid/$_listing/variante-1.jpg';
      srv.rpc['variant_upsert'] = (a) => _own('v1', 'M', 5);
      await ouvre(t, list: [_own('v1', 'M', 5, image: old)]);
      await t.tap(find.text('Modifier'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Retirer'));
      await t.pump(const Duration(milliseconds: 100));
      await save(t);
      expect(srv.callsOf('variant_upsert').single.args['p_clear_image'], isTrue);
      await deleted(t, 1);
      expect(deletions().single, contains(old));
      await fin(t);
    });

    testWidgets('jamais supprimées : une photo de l’annonce, ni une image encore utilisée par une autre variante', (t) async {
      final photo = '$_uid/$_listing/1700-photo.jpg';
      final partagee = '$_uid/$_listing/variante-2.jpg';
      srv.rpc['variant_upsert'] = (a) => _own('v1', 'M', 5);
      await ouvre(t, list: [_own('v1', 'M', 5, image: photo), _own('v2', 'L', 5, image: partagee), _own('v3', 'XL', 5, image: partagee)]);
      await t.tap(find.text('Modifier').first);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Retirer'));
      await save(t);
      expect(srv.callsOf('variant_upsert'), hasLength(1));
      expect(deletions(), isEmpty, reason: 'la photo de l’annonce n’est pas un fichier de variante');
      await ouvre(t, list: [_own('v2', 'L', 5, image: partagee), _own('v3', 'XL', 5, image: partagee)]);
      await t.tap(find.text('Modifier').first);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('Retirer'));
      await save(t);
      expect(deletions(), isEmpty, reason: 'l’image est encore utilisée par la variante XL');
      await fin(t);
    });
  });

  group('Fiche produit : variantes, prix, disponibilité, panier', () {
    final images = '$_uid/$_listing/variante-5.jpg';

    void serveur({int stock = 20}) {
      srv.rpc['product_detail'] = (_) => _product(stock: stock);
      srv.rpc['listing_variants_public'] = (_) => [
            _pub('v-prem', 'Premium', price: 9500, effective: 9500, image: images),
            _pub('v-std', 'Standard', effective: 8000),
            _pub('v-last', 'Dernière', state: 'low', left: 2, price: 8800, effective: 8800),
            _pub('v-out', 'Épuisée', state: 'out', effective: 8000),
          ];
    }

    Future<ProviderContainer> ouvre(WidgetTester t) async {
      serveur();
      t.view.physicalSize = const Size(420, 4200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(const ProviderScope(child: MaterialApp(home: ProductPageScreen(id: _listing))));
      await attendre(t, find.text('Choisissez une variante'));
      final c = ProviderScope.containerOf(t.element(find.byType(ProductPageScreen)));
      await settleReal(t, rounds: 3, ms: 100);
      while (c.read(cartProvider).isNotEmpty) {
        c.read(cartProvider.notifier).remove(0);
      }
      return c;
    }

    Finder chip(String prefix) => find.byWidgetPredicate((w) => w is MChip && w.label.startsWith(prefix));

    testWidgets('sélecteur : prix et disponibilité de chaque variante, image de la variante choisie, état épuisé / derniers exemplaires', (t) async {
      await ouvre(t);
      expect(chip('Premium · ${mFcfa(9500)}'), findsOneWidget);
      expect(chip('Standard · ${mFcfa(8000)}'), findsOneWidget, reason: 'sans prix propre : le prix de l’annonce');
      expect(chip('Dernière · ${mFcfa(8800)} · plus que 2'), findsOneWidget);
      expect(chip('Épuisée · ${mFcfa(8000)} · épuisée'), findsOneWidget);
      await t.tap(chip('Premium'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text(mFcfa(9500)), findsWidgets, reason: 'le prix affiché est celui de la variante');
      expect(find.textContaining('« Premium » : disponible'), findsOneWidget);
      await t.tap(chip('Dernière'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Derniers exemplaires : plus que 2'), findsOneWidget);
      expect(find.textContaining('Derniers exemplaires : plus que 2 en stock.'), findsOneWidget);
      expect(find.text(mFcfa(8800)), findsWidgets);
      await fin(t);
    });

    testWidgets('variante épuisée : refus clair, rien n’est ajouté au panier', (t) async {
      final c = await ouvre(t);
      await t.tap(chip('Épuisée'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('est épuisée'), findsOneWidget);
      await t.ensureVisible(find.text('Ajouter au panier'));
      await t.tap(find.text('Ajouter au panier'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('Choisissez une variante.'), findsOneWidget);
      expect(c.read(cartProvider), isEmpty);
      await fin(t);
    });

    testWidgets('BOUT EN BOUT : variante à prix propre -> panier (variantId, prix de la variante) -> cart_check puis marketplace_checkout avec variant_id, sans prix, montant serveur = montant affiché', timeout: const Timeout(Duration(seconds: 120)), (t) async {
      final c = await ouvre(t);
      await t.tap(chip('Premium'));
      await t.pump(const Duration(milliseconds: 200));
      await t.ensureVisible(find.text('Ajouter au panier'));
      await t.tap(find.text('Ajouter au panier'));
      await t.pump(const Duration(milliseconds: 200));
      final lines = c.read(cartProvider);
      expect(lines, hasLength(1));
      expect(lines.single.title, 'Robe H131');
      expect(lines.single.variantId, 'v-prem');
      expect(lines.single.variant, 'Premium');
      expect(lines.single.listingId, _listing);
      expect(lines.single.price, 9500, reason: 'prix de la variante, pas celui de l’annonce (8 000)');
      expect(lines.single.department, 'Boutique : Boutique Awa');

      // la même variante ajoutée deux fois : quantités cumulées ; une autre variante : ligne distincte au prix de l’annonce
      await t.tap(find.text('Ajouter au panier'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(chip('Standard'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Ajouter au panier'));
      await t.pump(const Duration(milliseconds: 200));
      final l2 = c.read(cartProvider);
      expect(l2, hasLength(2));
      expect(l2.firstWhere((l) => l.variantId == 'v-prem').qty, 2);
      expect(l2.firstWhere((l) => l.variantId == 'v-std').price, 8000);
      await fin(t);
    });

    // La commande est testée hors widget (même schéma que h12_stock_test) : le panier ci-dessus est reconstruit tel que l'écran le produit.
    test('BOUT EN BOUT (suite) : panier de variantes -> cart_check puis marketplace_checkout avec variant_id, sans prix, montant serveur = montant affiché', () async {
      const l2 = [
        CartLine('Robe H131', 'Boutique : Boutique Awa', 9500, '', variant: 'Premium', variantId: 'v-prem', listingId: _listing, qty: 2),
        CartLine('Robe H131', 'Boutique : Boutique Awa', 8000, '', variant: 'Standard', variantId: 'v-std', listingId: _listing),
      ];
      srv.rpc['cart_check'] = (a) {
        final its = (a['p_items'] as List).cast<Map>();
        return {
          'ok': true,
          'lines': [for (final (i, it) in its.indexed) {'index': i, 'ok': true, 'qty': it['qty'], 'shop': 'Boutique Awa', 'unit_price': it['variant_id'] == 'v-prem' ? 9500 : 8000}],
        };
      };
      srv.rpc['marketplace_checkout'] = (a) {
        final its = (a['p_items'] as List).cast<Map>();
        final sub = its.fold<int>(0, (s, it) => s + (it['qty'] as int) * (it['variant_id'] == 'v-prem' ? 9500 : 8000));
        return {'number': '#BE-2026-0777', 'subtotal': sub, 'fee': 0, 'discount': 0};
      };
      final r = await Backend.createOrder(l2, false, 'Mobile Money');
      expect(r['error'], isNull);
      final check = srv.callsOf('cart_check').single.args['p_items'] as List;
      final order = srv.callsOf('marketplace_checkout').single.args['p_items'] as List;
      expect(order, check, reason: 'même panier contrôlé puis commandé');
      final prem = check.cast<Map>().firstWhere((x) => x['variant_id'] == 'v-prem');
      expect(prem['qty'], 2);
      expect(prem['id'], _listing);
      expect(prem.containsKey('price'), isFalse);
      expect(prem.containsKey('unit_price'), isFalse);
      final shown = l2.fold<int>(0, (s, l) => s + l.price * l.qty);
      expect(r['subtotal'], shown, reason: 'montant du serveur = montant affiché au panier (2 x 9 500 + 8 000)');
      expect(shown, 27000);
    });

    testWidgets('quantité limitée au stock annoncé (« plus que 2 ») : le 3e ajout est refusé, le panier garde 2', (t) async {
      final c = await ouvre(t);
      await t.tap(chip('Dernière'));
      await t.pump(const Duration(milliseconds: 200));
      await t.ensureVisible(find.text('Ajouter au panier'));
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('Ajouter au panier'));
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(c.read(cartProvider).single.qty, 2);
      expect(c.read(cartProvider).single.maxQty, 2);
      expect(find.textContaining('Stock insuffisant : 2 exemplaire'), findsOneWidget);
      await fin(t);
    });

    testWidgets('panier par boutique : variante affichée, montants mis à jour, « + » plafonné au stock annoncé', (t) async {
      late ProviderContainer c;
      t.view.physicalSize = const Size(420, 3200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(builder: (ctx, ref, _) {
        c = ProviderScope.containerOf(ctx);
        return const CartByShopScreen();
      }))));
      await t.pump(const Duration(milliseconds: 300));
      while (c.read(cartProvider).isNotEmpty) {
        c.read(cartProvider.notifier).remove(0);
      }
      c.read(cartProvider.notifier).add(const CartLine('Robe H131', 'Boutique : Awa', 8800, '', variant: 'Dernière', variantId: 'v-last', listingId: _listing, maxQty: 2));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Dernière'), findsOneWidget);
      expect(find.text(mFcfa(8800)), findsWidgets);
      await t.tap(find.byTooltip('Plus'));
      await t.pump(const Duration(milliseconds: 200));
      expect(c.read(cartProvider).single.qty, 2);
      expect(find.text(mFcfa(17600)), findsWidgets, reason: 'sous-total recalculé');
      await t.tap(find.byTooltip('Plus'));
      await t.pump(const Duration(milliseconds: 200));
      expect(c.read(cartProvider).single.qty, 2, reason: 'plafonné au stock annoncé');
      expect(find.text('Stock disponible : 2'), findsOneWidget);
      await fin(t);
    });
  });

  group('États de commande et de paiement : jamais simulés', () {
    const pending = Order(id: '#BE-2026-0100', date: '27 nov. 2026', lines: [CartLine('Robe', 'Boutique : A', 9500, '', variant: 'Premium')], subtotal: 9500, fee: 0, method: 'Mobile Money', reference: '');

    test('commande impayée : « En attente de paiement », jamais payée ni confirmée (étape de suivi -1, titre de document non « reçu »)', () {
      expect(pending.awaitingPayment, isTrue);
      expect(pending.badge, 'En attente de paiement');
      expect(pending.step, -1);
      expect(orderPaymentStatus(pending), 'En attente de paiement');
      expect(documentTitle(pending, invoice: false), 'RÉCAPITULATIF DE COMMANDE');
      final paid = pending.copyWith(paid: true);
      expect(orderPaymentStatus(paid), 'Payé');
      expect(documentTitle(paid, invoice: false), 'REÇU DE PAIEMENT');
      expect(pending.copyWith(cancelled: true).badge, 'Annulée');
    });

    testWidgets('lecture serveur : commande impayée -> en attente ; payée -> payée ; variante et prix du serveur conservés', (t) async {
      srv.tables['orders'] = [
        {'number': '#BE-2026-0200', 'subtotal': 9500, 'fee': 0, 'method': 'Mobile Money', 'reference': '', 'status': 0, 'paid': false, 'cancelled': false, 'created_at': '2026-11-27T08:00:00Z', 'order_lines': [{'title': 'Robe H131', 'qty': 1, 'unit_price': 9500, 'fulfillment': 0, 'variant': 'Premium'}]},
        {'number': '#BE-2026-0201', 'subtotal': 8000, 'fee': 0, 'method': 'Mobile Money', 'reference': 'R1', 'status': 0, 'paid': true, 'cancelled': false, 'created_at': '2026-11-27T08:00:00Z', 'order_lines': [{'title': 'Robe H131', 'qty': 1, 'unit_price': 8000, 'fulfillment': 0}]},
      ];
      late ProviderContainer c;
      await host(t, Consumer(builder: (ctx, ref, _) {
        c = ProviderScope.containerOf(ctx);
        return const SizedBox();
      }));
      await t.runAsync(() => c.read(ordersProvider.notifier).refresh());
      final o = c.read(ordersProvider);
      final a = o.firstWhere((x) => x.id == '#BE-2026-0200'), b = o.firstWhere((x) => x.id == '#BE-2026-0201');
      expect(a.paid, isFalse);
      expect(a.badge, 'En attente de paiement');
      expect(a.lines.single.price, 9500);
      expect(a.lines.single.variant, 'Premium');
      expect(b.paid, isTrue);
      expect(b.badge, isNot('En attente de paiement'));
      await fin(t);
    });

    Future<({ProviderContainer c, BuildContext ctx, Order o})> paiement(WidgetTester t) async {
      late ProviderContainer c;
      late BuildContext ctx;
      t.view.physicalSize = const Size(420, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (context, _) => Consumer(builder: (cx, ref, _) {
          c = ProviderScope.containerOf(cx);
          ctx = cx;
          return const Scaffold(body: Text('accueil'));
        })),
        GoRoute(path: '/s/:id', builder: (context, s) => Scaffold(body: Text('écran ${s.pathParameters['id']}'))),
      ]);
      await t.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
      await t.pump(const Duration(milliseconds: 200));
      final o = c.read(ordersProvider.notifier).place();
      return (c: c, ctx: ctx, o: o);
    }

    testWidgets('paiement EN ATTENTE : le serveur est interrogé même avec « réduire les animations » ; la commande n’est pas payée, aucun écran de reçu', (t) async {
      srv.functions['pay'] = (_) => (status: 200, body: {'status': 'pending'});
      final p = await paiement(t);
      final ph = await t.runAsync(() => p.c.read(payProvider.notifier).check(p.ctx, p.o));
      expect(ph, PayPhase.pending);
      expect(srv.callsOf('pay'), hasLength(1), reason: 'pas de statut simulé quand GAnim est désactivé');
      expect(p.c.read(ordersProvider).firstWhere((x) => x.id == p.o.id).paid, isFalse);
      expect(find.textContaining('écran 259'), findsNothing);
      await fin(t);
    });

    testWidgets('paiement CONFIRMÉ par le serveur : commande marquée payée puis écran du reçu (259)', (t) async {
      srv.functions['pay'] = (_) => (status: 200, body: {'status': 'complete'});
      final p = await paiement(t);
      final ph = await t.runAsync(() => p.c.read(payProvider.notifier).check(p.ctx, p.o));
      await t.pump(const Duration(milliseconds: 300));
      expect(ph, PayPhase.paid);
      expect(p.c.read(ordersProvider).firstWhere((x) => x.id == p.o.id).paid, isTrue);
      expect(find.text('écran 259'), findsOneWidget);
      await fin(t);
    });

    testWidgets('paiement ÉCHOUÉ : commande annulée côté serveur et local, jamais payée, écran d’échec (258)', (t) async {
      srv.functions['pay'] = (_) => (status: 200, body: {'status': 'failed', 'reason': 'refused'});
      final p = await paiement(t);
      final ph = await t.runAsync(() => p.c.read(payProvider.notifier).check(p.ctx, p.o));
      await t.pump(const Duration(milliseconds: 300));
      expect(ph, PayPhase.failed);
      final o = p.c.read(ordersProvider).firstWhere((x) => x.id == p.o.id);
      expect(o.paid, isFalse);
      expect(o.cancelled, isTrue);
      expect(p.c.read(payProvider).message, contains('n’a pas abouti'));
      expect(find.text('écran 258'), findsOneWidget);
      await fin(t);
    });

    testWidgets('écart du fournisseur : « à vérifier », commande conservée, ni payée ni annulée', (t) async {
      srv.functions['pay'] = (_) => (status: 200, body: {'status': 'failed', 'reason': 'mismatch'});
      final p = await paiement(t);
      final ph = await t.runAsync(() => p.c.read(payProvider.notifier).check(p.ctx, p.o));
      expect(ph, PayPhase.verify);
      final o = p.c.read(ordersProvider).firstWhere((x) => x.id == p.o.id);
      expect(o.paid, isFalse);
      expect(o.cancelled, isFalse);
      await fin(t);
    });

    testWidgets('service de paiement injoignable : toujours en attente, jamais confirmé', (t) async {
      final p = await paiement(t); // aucune fonction « pay » déclarée : 404
      final ph = await t.runAsync(() => p.c.read(payProvider.notifier).check(p.ctx, p.o));
      expect(ph, PayPhase.pending);
      expect(p.c.read(ordersProvider).firstWhere((x) => x.id == p.o.id).paid, isFalse);
      expect(find.textContaining('écran 259'), findsNothing);
      await fin(t);
    });
  });
}
