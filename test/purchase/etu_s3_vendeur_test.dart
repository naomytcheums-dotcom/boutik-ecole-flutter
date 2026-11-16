import 'package:boutik_ecole/figma/g/g_57.dart';
import 'package:boutik_ecole/figma/g/g_58.dart';
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/seller_edit.dart';
import 'package:boutik_ecole/figma/live/seller_live.dart';
import 'package:boutik_ecole/figma/live/seller_new_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot S3 (espace vendeur) : formulaire « Nouveau produit », tableau de bord réel, stocks, catalogue.

Future<void> _pump(WidgetTester tester, Widget screen, ProviderContainer c) async {
  GAnim.enabled = false;
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: Scaffold(body: screen))));
  await tester.pump();
}

const _l = Listing(title: 'Lampe', category: 'Maison', price: 5000, stock: 3, id: 'a1', status: 'approved');

void main() {
  setUpAll(loadAppFonts);
  tearDown(() {
    Backend.ready = false;
    Listing.lowStock = 30;
  });

  group('58 « Nouveau produit » (S3-1, S3-2, S3-5)', () {
    testWidgets('connecté : un vrai champ de prix et un stock vides au départ (jamais « 25 000 » ni « 15 » imposés)', (tester) async {
      Backend.ready = true;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await _pump(tester, const G_58(), c);
      expect(find.text('Ex. 5 000'), findsOneWidget, reason: 'champ de prix saisissable');
      expect(find.text('Ex. 10'), findsOneWidget, reason: 'champ de stock vide, valeur obligatoire');
      expect(find.text('25 000'), findsNothing);
      expect(find.text('15'), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), '7500');
      expect(c.read(formProvider)['np_price'], '7500', reason: 'la valeur saisie est la valeur retenue');
    });

    testWidgets('hors connexion : la maquette garde « 25 000 » et « 15 »', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await _pump(tester, const G_58(), c);
      expect(find.text('25 000'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('connecté : l\'ouverture remet le formulaire à zéro (plus de description de l\'annonce précédente)', (tester) async {
      Backend.ready = true;
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(formProvider.notifier).put('np_desc', 'ancienne description');
      c.read(formProvider.notifier).put('np_sup', 'M. Ancien');
      c.read(errorsProvider.notifier).setAll({'np_price': 'x'});
      await _pump(tester, const G_58(), c);
      await tester.pump();
      expect(c.read(formProvider)['np_desc'], isNull);
      expect(c.read(formProvider)['np_sup'], isNull);
      expect(c.read(errorsProvider), isEmpty);
    });
  });

  group('57 « Tableau de bord » (S3-3)', () {
    testWidgets('connecté : les chiffres viennent du serveur, jamais 1 245 000 ni 38', (tester) async {
      Backend.ready = true;
      final c = ProviderContainer(overrides: [
        sellerOverviewProvider.overrideWith((ref) async => {
              'revenue': 8300,
              'orders': 4,
              'pending_orders': 2,
              'listings': {'approved': 6, 'pending': 1, 'draft': 3, 'rejected': 0},
              'months': [
                for (var i = 0; i < 6; i++) {'month': '2026-0${i + 5}', 'revenue': i == 5 ? 8300 : 0}
              ],
            }),
        sellerOrdersProvider.overrideWithValue(const []),
      ]);
      addTearDown(c.dispose);
      await _pump(tester, const G_57(), c);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('1 245'), findsNothing);
      expect(find.text('38'), findsNothing);
      expect(find.textContaining('8'), findsWidgets);
      expect(find.text('Ventes (30 jours)'), findsOneWidget);
      expect(find.text('À préparer'), findsOneWidget);
      expect(find.text('Revenu attendu'), findsNothing);
      expect(find.text('1 en validation · 3 brouillon(s)'), findsOneWidget);
    });
  });

  group('61 / 62 : catalogue et stocks (S3-14, S3-41)', () {
    test('un service n\'a pas de stock : il n\'est pas dans la liste de réassort, les publiés bas passent en premier', () {
      final all = [
        const Listing(title: 'Soutien', category: 'Services', price: 0, stock: 999, id: 's'),
        const Listing(title: 'Brouillon', category: 'Maison', price: 900, stock: 1, id: 'd', status: 'draft', published: false),
        const Listing(title: 'Haut', category: 'Maison', price: 900, stock: 40, id: 'h', status: 'approved'),
        const Listing(title: 'Bas', category: 'Maison', price: 900, stock: 2, id: 'b', status: 'approved'),
      ];
      expect(stockListings(all).map((l) => l.title), ['Bas', 'Haut', 'Brouillon']);
    });

    test('l\'étiquette « Stock bas » suit le seuil réglé par le vendeur', () {
      expect(_l.label, 'Stock bas');
      Listing.lowStock = 2;
      expect(_l.label, 'Publié');
    });

    test('sous-titre d\'une ligne : service « Sur devis », statut réel d\'un brouillon', () {
      expect(listingSubtitle(const Listing(title: 'S', category: 'Services', price: 0, stock: 999)), 'Sur devis');
      expect(listingSubtitle(const Listing(title: 'R', category: 'Mode', price: 1500, stock: 1, status: 'rejected', published: false)), contains('Refusée'));
    });

    test('avertissement quand la boutique n\'est pas active et que des annonces sont publiées', () {
      expect(shopVisibilityNote({'id': 'x', 'status': 'pending'}, [_l]), contains('en validation'));
      expect(shopVisibilityNote({'id': 'x', 'status': 'active'}, [_l]), isNull);
      expect(shopVisibilityNote({}, [_l]), isNull, reason: 'sans boutique, les annonces restent publiques');
      expect(shopVisibilityNote({'id': 'x', 'status': 'suspended'}, const []), isNull);
    });
  });

  group('60 : annonce choisie par identifiant (S3-31)', () {
    test('connecté : sans sélection, aucune annonce n\'est devinée', () {
      Backend.ready = true;
      final c = ProviderContainer(overrides: [listingsProvider.overrideWith(() => _FixedListings([_l]))]);
      addTearDown(c.dispose);
      expect(c.read(currentListingProvider), isNull);
      c.read(selectedListingProvider.notifier).set('a1');
      expect(c.read(currentListingProvider)?.title, 'Lampe');
      expect(_l.key, 'a1');
    });
  });

  test('photos du formulaire : plafond unique de 8, 5 Mo', () {
    expect(maxListingPhotos, 8);
    expect(maxPhotoBytes, 5 * 1024 * 1024);
  });
}

class _FixedListings extends Listings {
  _FixedListings(this.rows);
  final List<Listing> rows;
  @override
  List<Listing> build() => rows;
}
