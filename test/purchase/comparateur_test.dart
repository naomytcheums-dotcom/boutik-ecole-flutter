import 'package:boutik_ecole/figma/live/marche/compare_logic.dart';
import 'package:boutik_ecole/figma/live/marche/marche_compare.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

OfferFacts _a({int? fee = 0}) => factsFrom(title: 'Sac à dos design', price: 25000, specs: {'Matériau': 'Tissu recyclé', 'Capacité': '20 L', 'Couleurs': 'Noir, gris', 'Garantie': '6 mois', 'Livraison': '2-5 jours'}, deliveryFee: fee, rating: 4.5, stock: 8);
OfferFacts _b({int? fee = 1500}) => factsFrom(title: 'Sac urbain', price: 32000, specs: {'matériau': 'Cuir synthétique', 'capacité': '25 L', 'Couleurs': 'Noir', 'Garantie': '1 an', 'Livraison': '1 semaine'}, deliveryFee: fee, rating: 4.0, stock: 3);

void main() {
  test('lecture des caractéristiques saisies par les vendeurs', () {
    final a = _a(), b = _b();
    expect(a.capacity, 20);
    expect(a.warrantyMonths, 6);
    expect(b.warrantyMonths, 12, reason: '1 an = 12 mois');
    expect(a.deliveryDays, 5, reason: 'plage 2-5 jours : borne haute');
    expect(b.deliveryDays, 7, reason: '1 semaine = 7 jours');
    expect(firstNumber('1,5 kg'), 1.5);
    expect(warrantyMonths('2 ans'), 24);
    expect(a.material, 'Tissu recyclé');
  });

  test('prix total livré = prix + livraison ; nul si ville non desservie', () {
    expect(_a(fee: 0).totalDelivered, 25000);
    expect(_b(fee: 1500).totalDelivered, 33500);
    expect(_b(fee: null).totalDelivered, isNull);
  });

  test('sans critère, pas de pourcentage', () {
    expect(compatibility(_a(), const CompareCriteria()), isNull);
    expect(const CompareCriteria().count, 0);
  });

  test('budget : le pourcentage change avec le budget', () {
    final serre = compatibility(_b(), const CompareCriteria(budget: 30000));
    final large = compatibility(_b(), const CompareCriteria(budget: 40000));
    expect(large, 100);
    expect(serre, lessThan(100));
    expect(compatibility(_a(), const CompareCriteria(budget: 30000)), 100);
  });

  test('plusieurs critères : moyenne, matériau et couleur par texte, accents ignorés', () {
    const c = CompareCriteria(budget: 30000, minCapacity: 25, material: 'tissu recycle', color: 'noir', minWarrantyMonths: 12, maxDeliveryDays: 5);
    expect(c.count, 6);
    final a = compatibility(_a(), c)!, b = compatibility(_b(), c)!;
    expect(a, 88, reason: 'budget 1, capacité 0,8, matériau 1, couleur 1, garantie 0,5, délai 1');
    expect(b, lessThan(a));
    expect(compatibility(_a(), c.copy(material: 'cuir')), lessThan(a), reason: 'changer un critère recalcule');
  });

  test('information absente chez le vendeur : le critère vaut 0, rien n est deviné', () {
    final f = factsFrom(title: 'X', price: 1000, specs: const {});
    expect(compatibility(f, const CompareCriteria(minCapacity: 10)), 0);
    expect(compatibility(f, const CompareCriteria(color: 'rouge')), 0);
  });

  test('meilleure valeur par ligne', () {
    expect(bestOf(25000, 32000, lowerIsBetter: true), 0);
    expect(bestOf(4.0, 4.5), 1);
    expect(bestOf(5, 5), isNull, reason: 'égalité : personne ne gagne');
    expect(bestOf(null, 5), isNull, reason: 'valeur inconnue : pas de gagnant');
  });

  Map<String, dynamic> detail(String id, String title, int price, Map<String, dynamic> specs, {String type = 'product'}) => {
        'found': true,
        'card': {'id': id, 'title': title, 'price': price, 'stock': 5, 'offer_type': type, 'shop_name': 'Atelier', 'rating_avg': 4.5},
        'specs': specs,
      };

  Future<void> pump(WidgetTester t, List<String> ids) async {
    final overrides = <Override>[
      marcheProductProvider('a').overrideWith((ref) async => detail('a', 'Sac à dos design', 25000, {'Matériau': 'Tissu recyclé', 'Capacité': '20 L', 'Garantie': '6 mois'})),
      marcheProductProvider('b').overrideWith((ref) async => detail('b', 'Sac urbain', 32000, {'Matériau': 'Cuir synthétique', 'Capacité': '25 L', 'Garantie': '1 an'})),
      compareFeeProvider((id: 'a', city: 'Douala')).overrideWith((ref) async => 0),
      compareFeeProvider((id: 'b', city: 'Douala')).overrideWith((ref) async => 1500),
    ];
    await t.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(builder: (c, ref, _) {
          Future.microtask(() {
            final n = ref.read(marcheCompareProvider.notifier);
            if (ref.read(marcheCompareProvider).isEmpty) {
              for (final i in ids) {
                n.toggle(i);
              }
            }
          });
          return const CompareScreen();
        }),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('comparaison : deux offres, prix total livré et meilleure valeur', (t) async {
    t.view.physicalSize = const Size(420, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pump(t, ['a', 'b']);
    expect(find.text('Sac à dos design'), findsOneWidget);
    expect(find.text('Sac urbain'), findsOneWidget);
    expect(find.text('Prix total livré'), findsOneWidget);
    expect(find.text(mFcfa(25000)), findsNWidgets(2), reason: 'prix et total livré identiques pour l offre à livraison gratuite');
    expect(find.text(mFcfa(33500)), findsOneWidget);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets, reason: 'meilleures valeurs mises en évidence');
    expect(find.text('Indiquez vos critères'), findsNWidgets(2));
    expect(find.text('Choisir celle-ci'), findsNWidgets(2));
  });

  testWidgets('comparaison : changer le budget recalcule la compatibilité en direct', (t) async {
    t.view.physicalSize = const Size(420, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pump(t, ['a', 'b']);
    await t.enterText(find.widgetWithText(TextField, 'Budget max (FCFA)'), '30000');
    await t.pumpAndSettle();
    expect(find.text('100 %'), findsOneWidget, reason: 'seule l offre à 25 000 FCFA tient dans le budget');
    expect(find.textContaining('Meilleure correspondance : Sac à dos design'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Budget max (FCFA)'), '40000');
    await t.pumpAndSettle();
    expect(find.text('100 %'), findsNWidgets(2), reason: 'les deux entrent dans 40 000 FCFA');
  });

  testWidgets('comparaison : moins de deux offres, message et accès à la marketplace', (t) async {
    await pump(t, ['a']);
    expect(find.textContaining('Une offre est déjà choisie'), findsOneWidget);
    expect(find.text('Parcourir la marketplace'), findsOneWidget);
  });
}
