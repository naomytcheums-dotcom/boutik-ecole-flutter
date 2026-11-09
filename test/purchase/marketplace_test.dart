import 'package:boutik_ecole/data/repositories/repositories.dart' show cartProvider, CartLine;
import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart';
import 'package:boutik_ecole/figma/live/marche/marche_screens.dart';
import 'package:boutik_ecole/figma/live/marche/marche_vendeur.dart';
import 'package:boutik_ecole/figma/live/marche/marche_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

// Données de test (jamais affichées dans l'application) : une ligne de produit telle que la renvoie marketplace_search.
Map<String, dynamic> card({String id = 'p1', String title = 'Lampe en bois', int price = 25000, int? before, int? flash, int stock = 5}) => {
      'id': id,
      'title': title,
      'price': price,
      'price_before': before,
      'flash_price': flash,
      'flash_ends': flash == null ? null : '2030-01-01T00:00:00Z',
      'flash_left': 3,
      'stock': stock,
      'image': '',
      'shop_name': 'Atelier Test',
      'shop_slug': 'atelier-test',
      'city': 'Douala',
      'rating_avg': 4.5,
      'rating_count': 2,
    };

Future<void> pump(WidgetTester tester, Widget w, {List<Override> overrides = const [], Size size = const Size(390, 3200)}) async {
  GAnim.enabled = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);
  tearDown(() {
    Backend.ready = false;
    Backend.promoCode = '';
    Backend.packLines.clear();
  });

  group('formats', () {
    test('FCFA avec séparateur de milliers', () => expect(mFcfa(25000), '25 000 FCFA'));
    test('compte à rebours : jours puis heures:minutes:secondes', () {
      final now = DateTime(2026, 11, 9, 10);
      expect(mCountdown(now.add(const Duration(days: 2, hours: 3)), now), '2 j 03 h');
      expect(mCountdown(now.add(const Duration(hours: 1, minutes: 2, seconds: 5)), now), '01:02:05');
      expect(mCountdown(now.subtract(const Duration(seconds: 1)), now), 'Terminée');
    });
    test('filtres → paramètres du serveur', () {
      const f = MarcheFilters(q: ' lampe ', category: 'Maison', city: 'Douala', min: 1000, max: 50000, sort: 'price_asc');
      expect(f.productParams, {'p_q': 'lampe', 'p_category': 'Maison', 'p_city': 'Douala', 'p_min': 1000, 'p_max': 50000, 'p_sort': 'price_asc'});
      expect(const MarcheFilters().productParams, {'p_sort': 'popular'});
      expect(f.copy(min: null).min, isNull);
    });
    test('comparaison limitée à 4 produits', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(marcheCompareProvider.notifier);
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(n.toggle(id), isTrue);
      }
      expect(n.toggle('e'), isFalse);
      expect(n.toggle('a'), isTrue);
      expect(c.read(marcheCompareProvider), ['b', 'c', 'd']);
    });
  });

  testWidgets('marketplace hors connexion : message honnête, aucun produit inventé', (tester) async {
    await pump(tester, const MarketplaceScreen());
    expect(find.textContaining('disponible une fois l’application connectée'), findsWidgets);
    expect(find.byType(MarcheProductTile), findsNothing);
  });

  testWidgets('cadre de produit : photo 4:5 en coins modérés, texte HORS du cadre, prix barré et badge promo', (tester) async {
    await pump(tester, Scaffold(body: SizedBox(width: 180, child: MarcheProductTile(card: card(price: 18000, before: 25000)))));
    final photo = tester.getRect(find.byType(AspectRatio).first);
    expect(photo.width / photo.height, closeTo(0.8, 0.01));
    final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(AspectRatio), matching: find.byType(ClipRRect)).first);
    expect(clip.borderRadius, BorderRadius.circular(14));
    expect(tester.getTopLeft(find.text('Lampe en bois')).dy, greaterThanOrEqualTo(photo.bottom), reason: 'le titre est sous la photo');
    expect(find.text('−28 %'), findsOneWidget);
    expect(find.text(mFcfa(25000)), findsOneWidget);
    expect(find.textContaining('Atelier Test · Douala'), findsOneWidget);
  });

  testWidgets('vente flash : prix flash en rouge et badge', (tester) async {
    await pump(tester, Scaffold(body: SizedBox(width: 180, child: MarcheProductTile(card: card(price: 20000, flash: 15000)))));
    expect(find.text('Flash −25 %'), findsOneWidget);
    expect(find.text(mFcfa(15000)), findsOneWidget);
  });

  testWidgets('galerie : les photos défilent seules toutes les 3 secondes (3 photos au plus)', (tester) async {
    await pump(tester, const Scaffold(body: SizedBox(width: 300, child: AutoCarousel(urls: ['a', 'b', 'c', 'd'], autoplay: true))));
    double activeIndex() {
      final dots = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
      expect(dots.length, 3, reason: '4 URL données, 3 photos affichées');
      return dots.indexWhere((d) => (d.constraints?.maxWidth ?? 0) == 18).toDouble();
    }

    expect(activeIndex(), 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(activeIndex(), 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(activeIndex(), 2);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(activeIndex(), 0, reason: 'retour à la première photo');
  });

  testWidgets('vitrine de boutique : bannière, nom, abonnement, ventes flash, packs, produits, avis', (tester) async {
    final data = {
      'found': true,
      'shop': {'id': 's1', 'slug': 'atelier-test', 'name': 'Atelier Test', 'description': 'Créations en bois.', 'logo_url': '', 'banner_url': '', 'categories': ['Maison'], 'city': 'Douala', 'delivery_info': 'Retrait sur campus', 'terms': 'Retour 7 jours', 'socials': {'instagram': '@atelier'}, 'color_primary': '#111015', 'color_secondary': '#5A3FE0', 'status': 'active', 'owner_id': 'o1'},
      'followers': 3,
      'following': false,
      'is_owner': false,
      'rating_avg': 4.5,
      'rating_count': 2,
      'sales': 7,
      'products': [card()],
      'flash': [{'id': 'f1', 'listing': card(id: 'p2', title: 'Table basse', price: 40000, flash: 30000), 'ends_at': '2030-01-01T00:00:00Z', 'left': 3}],
      'campaigns': [{'id': 'c1', 'title': 'Rentrée', 'description': 'Offres de la rentrée', 'products': [card(id: 'p3', title: 'Cahier recyclé')]}],
      'packs': [{'id': 'k1', 'title': 'Pack bureau', 'description': '', 'price': 30000, 'normal_price': 40000, 'items': []}],
      'reviews': [{'rating': 5, 'comment': 'Très beau travail', 'author': 'Awa M.'}],
    };
    await pump(tester, const ShopPageScreen(slug: 'atelier-test'), overrides: [marcheShopProvider('atelier-test').overrideWith((ref) async => data)]);
    expect(find.text('Atelier Test'), findsWidgets);
    expect(find.text('Suivre la boutique'), findsOneWidget);
    expect(find.text('Ventes flash'), findsOneWidget);
    expect(find.text('Rentrée'), findsOneWidget);
    expect(find.text('Pack bureau'), findsOneWidget);
    expect(find.textContaining('Tous les produits (1)'), findsOneWidget);
    expect(find.textContaining('Retrait sur campus'), findsOneWidget);
    expect(find.textContaining('Très beau travail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('boutique introuvable ou non ouverte : message clair', (tester) async {
    await pump(tester, const ShopPageScreen(slug: 'x'), overrides: [marcheShopProvider('x').overrideWith((ref) async => {'found': false})]);
    expect(find.textContaining('n’existe pas ou n’est pas encore ouverte'), findsOneWidget);
  });

  testWidgets('fiche produit : variantes obligatoires, ajout au panier avec la boutique, questions et avis', (tester) async {
    final data = {
      'found': true,
      'card': card(price: 18000, before: 25000),
      'description': 'Lampe LED économe.',
      'images': <String>[],
      'video_url': null,
      'variants': [{'name': 'Couleur', 'options': ['Naturel', 'Noir']}],
      'specs': {'Matière': 'Bois recyclé'},
      'is_owner': false,
      'alerts': <String>[],
      'questions': [{'id': 'q1', 'question': 'Livrez-vous à Bonabéri ?', 'answer': 'Oui, sur rendez-vous.', 'author': 'Awa M.'}],
      'reviews': [{'rating': 4, 'comment': 'Solide', 'author': 'Paul K.'}],
    };
    late ProviderContainer c;
    await pump(tester, Consumer(builder: (ctx, ref, _) {
      c = ProviderScope.containerOf(ctx);
      return const ProductPageScreen(id: 'p1');
    }), overrides: [marcheProductProvider('p1').overrideWith((ref) async => data)]);
    expect(find.text('Lampe en bois'), findsWidgets);
    expect(find.text('Matière'), findsOneWidget);
    expect(find.textContaining('Oui, sur rendez-vous.'), findsOneWidget);
    expect(find.textContaining('Solide'), findsOneWidget);
    final before = c.read(cartProvider).length;
    await tester.ensureVisible(find.text('Ajouter au panier'));
    await tester.tap(find.text('Ajouter au panier'));
    await tester.pump();
    expect(c.read(cartProvider).length, before, reason: 'variante non choisie : rien n’est ajouté');
    await tester.tap(find.text('Noir'));
    await tester.pump();
    await tester.tap(find.text('Ajouter au panier'));
    await tester.pump();
    final line = c.read(cartProvider).last;
    expect(line.title, 'Lampe en bois');
    expect(line.department, 'Boutique : Atelier Test');
    expect(line.price, 18000);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('panier par boutique : une commande par boutique et sous-totaux', (tester) async {
    late ProviderContainer c;
    await pump(tester, Consumer(builder: (ctx, ref, _) {
      c = ProviderScope.containerOf(ctx);
      return const CartByShopScreen();
    }));
    while (c.read(cartProvider).isNotEmpty) {
      c.read(cartProvider.notifier).remove(0);
    }
    c.read(cartProvider.notifier).add(const CartLine('Lampe', 'Boutique : Atelier A', 10000, ''));
    c.read(cartProvider.notifier).add(const CartLine('Sac', 'Boutique : Atelier B', 5000, ''));
    c.read(cartProvider.notifier).add(const CartLine('Table', 'Boutique : Atelier A', 20000, ''));
    await tester.pump();
    expect(find.text('Commande Atelier A'), findsOneWidget);
    expect(find.text('Commande Atelier B'), findsOneWidget);
    expect(find.text(mFcfa(30000)), findsWidgets, reason: 'sous-total de la boutique A');
    expect(find.text(mFcfa(35000)), findsOneWidget, reason: 'total des articles');
  });

  testWidgets('mon espace vendeur : tableau de bord avec chiffres, graphique et meilleurs produits', (tester) async {
    final d = {
      'revenue': 90000,
      'orders': 3,
      'views': 120,
      'conversion': 2.5,
      'pending_orders': 1,
      'followers': 4,
      'top': [{'title': 'Lampe en bois', 'qty': 3, 'revenue': 75000}],
      'series': [for (var i = 1; i <= 7; i++) {'day': '2026-11-0$i', 'revenue': i * 1000, 'views': i}],
    };
    await pump(tester, const SellerHubScreen(), overrides: [marcheDashboardProvider(30).overrideWith((ref) async => d)]);
    expect(find.text(mFcfa(90000)), findsOneWidget);
    expect(find.text('2.5 %'), findsOneWidget);
    expect(find.text('Lampe en bois'), findsOneWidget);
    expect(find.text('Chiffre d’affaires par jour'), findsOneWidget);
    await tester.tap(find.text('7 jours'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('modération : boutiques à valider, signalements et litiges', (tester) async {
    final d = {
      'pending_shops': [{'id': 's1', 'slug': 'neuve', 'name': 'Boutique Neuve', 'description': 'Bijoux', 'owner': 'Awa M.'}],
      'active_shops': [{'id': 's2', 'slug': 'vieille', 'name': 'Vieille Boutique', 'status': 'active'}],
      'shop_reports': [{'id': 'r1', 'shop': 'Vieille Boutique', 'reason': 'fraud', 'details': 'Faux produits'}],
      'disputes': [{'id': 'd1', 'reason': 'not_received', 'details': 'Colis jamais reçu'}],
      'categories': [{'slug': 'maison', 'label': 'Maison', 'active': true}],
    };
    await pump(tester, const ModerationScreen(), overrides: [marcheModerationProvider.overrideWith((ref) async => d)]);
    expect(find.textContaining('Boutique Neuve'), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(find.textContaining('Faux produits'), findsOneWidget);
    expect(find.textContaining('Colis jamais reçu'), findsOneWidget);
    expect(find.text('Suspendre'), findsOneWidget);
  });

  testWidgets('création de boutique : formulaire, adresse publique et statut brouillon', (tester) async {
    await pump(tester, const ShopEditorScreen(), overrides: [marcheMyShopProvider.overrideWith((ref) async => <String, dynamic>{})]);
    expect(find.text('Créer ma boutique (brouillon)'), findsOneWidget);
    expect(find.text('Adresse publique (unique)'), findsOneWidget);
  });

  testWidgets('boutique soumise : statut En validation et adresse publique', (tester) async {
    await pump(tester, const ShopEditorScreen(), overrides: [
      marcheMyShopProvider.overrideWith((ref) async => {'id': 's1', 'slug': 'atelier-test', 'name': 'Atelier Test', 'status': 'pending', 'categories': <String>[], 'socials': <String, dynamic>{}})
    ]);
    expect(find.text('Statut : En validation'), findsOneWidget);
    expect(find.textContaining('$publicShopBase' 'atelier-test'), findsOneWidget);
  });
}

