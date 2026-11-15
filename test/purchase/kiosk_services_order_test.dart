import 'package:boutik_ecole/core/router/paths.dart';
import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider;
import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/marche_catalogue.dart' show marcheFetcherProvider;
import 'package:boutik_ecole/figma/live/missions.dart';
import 'package:boutik_ecole/figma/live/seller.dart' show allProductsProvider;
import 'package:boutik_ecole/figma/live/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lamp = LiveProduct('Lampe test', 'Génie civil', 25000, 'Yannick M.', 'Lampe.', 'placeholder', category: 'Maison', stock: 3, id: 'p-1');
const _service = {'id': 's-1', 'title': 'Logo sur mesure', 'price': 0, 'category': 'Services', 'offer_type': 'service', 'stock': 1, 'shop_name': 'Atelier MMI', 'image': null};

List<Override> _overrides({List<Map<String, dynamic>> services = const [_service], Object? fail, List<LiveProduct> products = const [_lamp], List<Map<String, dynamic>>? calls}) => [
      allProductsProvider.overrideWith((ref) => products),
      marcheFetcherProvider.overrideWithValue((fn, params) async {
        calls?.add({'fn': fn, ...params});
        if (fail != null) throw fail;
        return services;
      }),
    ];

class _Kind2 extends KioskKind {
  @override
  int build() => 2;
}

/// Chemin de l'écran affiché au sommet de la pile (les pages ouvertes par `push` comprises).
String _at(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Backend.ready = true;
  });
  tearDown(() => Backend.ready = false);

  test('207 : le filtre Services lit les offres approuvées de type service (marketplace_search) et ne casse pas les autres filtres', () async {
    final calls = <Map<String, dynamic>>[];
    final c = ProviderContainer(overrides: _overrides(calls: calls));
    addTearDown(c.dispose);
    await c.read(kioskServicesProvider.future);
    expect(calls.single['fn'], 'marketplace_search');
    expect(calls.single['p_offer_type'], 'service');

    c.read(kioskKindProvider.notifier).set(2);
    final s = c.read(kioskProductsProvider);
    expect(s.map((p) => p.title), ['Logo sur mesure']);
    expect((s.first.category, s.first.seller, s.first.id, kioskPrice(s.first)), ('Services', 'Atelier MMI', 's-1', 'Sur devis'));

    c.read(kioskKindProvider.notifier).set(1);
    expect(c.read(kioskProductsProvider).map((p) => p.title), ['Lampe test']);
    c.read(kioskKindProvider.notifier).set(0);
    expect(c.read(kioskProductsProvider).map((p) => p.title), ['Lampe test', 'Logo sur mesure']);
    c.read(kioskQueryProvider.notifier).set('logo');
    expect(c.read(kioskProductsProvider).map((p) => p.title), ['Logo sur mesure']);
    // le service choisi dans la grille s'ouvre à la fiche 208
    c.read(kioskProductProvider.notifier).set('Logo sur mesure');
    expect(c.read(kioskCurrentProvider).id, 's-1');
  });

  test('207 : hors connexion (démonstration) le filtre Services ne lit aucun serveur', () async {
    Backend.ready = false;
    final calls = <Map<String, dynamic>>[];
    final c = ProviderContainer(overrides: _overrides(calls: calls));
    addTearDown(c.dispose);
    c.read(kioskKindProvider.notifier).set(2);
    expect(c.read(kioskProductsProvider), isEmpty);
    expect(await c.read(kioskServicesProvider.future), isEmpty);
    expect(calls, isEmpty);
  });

  testWidgets('207 : états vides honnêtes (chargement, aucun service, échec, recherche sans résultat)', (t) async {
    Future<void> pump(List<Override> o, {String q = ''}) async {
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          ...o,
          kioskKindProvider.overrideWith(_Kind2.new),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          if (q.isNotEmpty) Future.microtask(() => ref.read(kioskQueryProvider.notifier).set(q));
          return Scaffold(body: Text(kioskEmptyText(ref)));
        })),
      ));
      await t.pump();
      await t.pump();
    }

    await pump(_overrides(services: const []));
    expect(find.textContaining('Aucun service approuvé pour le moment'), findsOneWidget);
    await pump(_overrides(fail: 'offline'));
    expect(find.textContaining('ne peuvent pas être chargés'), findsOneWidget);
    await pump(_overrides(), q: 'zzz');
    expect(find.text('Aucun service ne correspond à votre recherche.'), findsOneWidget);
  });

  group('208 « Commander »', () {
    Future<(GoRouter, ProviderContainer)> pump(WidgetTester t, {Account? account, List<LiveProduct> products = const [_lamp], String selected = 'Lampe test'}) async {
      late ProviderContainer container;
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(body: Consumer(builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return TextButton(onPressed: () => kioskOrder(ref, context), child: const Text('commander'));
          })),
        ),
        GoRoute(path: '/marche/produit/:id', builder: (context, state) => const Scaffold(body: Text('fiche marketplace'))),
        GoRoute(path: screenPath('06'), builder: (context, state) => const Scaffold(body: Text('panier'))),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [..._overrides(products: products), if (account != null) initialAccountProvider.overrideWithValue(account)],
        child: MaterialApp.router(routerConfig: router),
      ));
      container.read(kioskProductProvider.notifier).set(selected);
      await t.runAsync(() => container.read(kioskServicesProvider.future));
      return (router, container);
    }

    testWidgets('visiteur : invite de connexion, jamais de commande anonyme', (t) async {
      final (router, c) = await pump(t);
      await t.tap(find.text('commander'));
      await t.pumpAndSettle();
      expect(find.text('Un compte est nécessaire'), findsOneWidget);
      expect(c.read(cartProvider), isEmpty);
      expect(_at(router), '/');
    });

    testWidgets('client connecté : l’article rejoint le panier persistant et le parcours de paiement existant s’ouvre', (t) async {
      final (router, c) = await pump(t, account: demoAccount);
      await t.tap(find.text('commander'));
      await t.pumpAndSettle();
      expect(c.read(cartProvider).map((l) => (l.title, l.qty)), [('Lampe test', 1)]);
      expect(_at(router), screenPath('06'));
    });

    testWidgets('stock déjà atteint dans le panier : rien n’est ajouté en plus, message honnête', (t) async {
      final (_, c) = await pump(t, account: demoAccount);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('commander'));
        await t.pumpAndSettle();
        if (i < 2) {
          final r = c.read(cartProvider);
          expect(r.single.qty, i + 1);
          // retour à la borne
          (t.state(find.byType(Navigator)) as NavigatorState).pop();
          await t.pumpAndSettle();
        }
      }
      expect(c.read(cartProvider).single.qty, 3);
      (t.state(find.byType(Navigator)) as NavigatorState).pop();
      await t.pumpAndSettle();
      await t.tap(find.text('commander'));
      await t.pumpAndSettle();
      expect(c.read(cartProvider).single.qty, 3); // stock 3 : pas de 4e exemplaire
    });

    testWidgets('service : pas de commande, renvoi vers la fiche et sa demande de devis', (t) async {
      final (router, c) = await pump(t, account: demoAccount, selected: 'Logo sur mesure');
      await t.tap(find.text('commander'));
      await t.pumpAndSettle();
      expect(c.read(cartProvider), isEmpty);
      expect(_at(router), '/marche/produit/s-1');
    });

    testWidgets('produit d’exemple : jamais commandé', (t) async {
      const demo = LiveProduct('Exemple', 'IUT', 1000, 'Démo', '', 'placeholder', showcase: true);
      final (router, c) = await pump(t, account: demoAccount, products: const [demo], selected: 'Exemple');
      await t.tap(find.text('commander'));
      await t.pumpAndSettle();
      expect(c.read(cartProvider), isEmpty);
      expect(_at(router), '/');
    });
  });
}
