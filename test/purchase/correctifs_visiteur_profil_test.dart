import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/opportunites_screens.dart';
import 'package:boutik_ecole/figma/live/seller.dart';
import 'package:boutik_ecole/figma/live/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _Annonces extends PublicListings {
  _Annonces(this.v);
  final List<Listing> v;
  @override
  List<Listing> build() => v;
}

Map<String, dynamic> _offre(int i) => {
      'id': '$i',
      'org': 'Orange',
      'title': 'Stage $i',
      'kind': 'stage',
      'contract': '',
      'location': 'Douala',
      'mode': 'onsite',
      'duration': '',
      'pay_kind': 'paid',
      'pay_amount': 50000,
      'deadline': null,
      'skills': const [],
      'verified': false,
    };

void main() {
  tearDown(() => Backend.ready = false);

  Future<ProviderContainer> monter(WidgetTester t, Widget w, {Account? compte, List<Override> overrides = const []}) async {
    Backend.ready = true;
    t.view.physicalSize = const Size(420, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
    final c = ProviderScope.containerOf(t.element(find.byWidget(w)));
    if (compte != null) c.read(authProvider.notifier).login(compte);
    await t.pumpAndSettle();
    return c;
  }

  const entreprise = Account(name: 'Orange', phone: '690000000', email: 'rh@orange.cm', password: 'x', role: 2);
  const equipe = Account(name: 'Admin', phone: '690000001', email: 'admin@iut.cm', password: 'x', staff: 'Admin global');

  testWidgets('visiteur : « Mes opportunités » et « Publier une offre » invitent à se connecter', (t) async {
    await monter(t, const MyOpportunitiesScreen());
    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    await monter(t, const OpportunityEditScreen());
    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Organisation'), findsNothing);
  });

  testWidgets('étudiant : le dépôt d’offre est refusé d’emblée, l’entreprise voit le formulaire', (t) async {
    await monter(t, const OpportunityEditScreen(), compte: demoAccount);
    expect(find.text('Réservé aux entreprises, ONG, startups et à l’équipe de l’IUT.'), findsOneWidget);
    expect(find.text('Organisation'), findsNothing);
    await monter(t, const OpportunityEditScreen(), compte: entreprise);
    expect(find.text('Organisation'), findsOneWidget);
  });

  testWidgets('refuser une offre demande un motif d’au moins 3 caractères', (t) async {
    await monter(t, const MyOpportunitiesScreen(), compte: equipe, overrides: [
      oppMyPostedProvider.overrideWith((ref) async => [
            {'id': 'o1', 'org': 'Orange', 'title': 'Stage', 'status': 'pending', 'applications': 0}
          ]),
      oppMyApplicationsProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
      oppsProvider.overrideWith((ref, q) async => <Map<String, dynamic>>[]),
      oppStatsProvider.overrideWith((ref) async => <String, Map<String, dynamic>>{}),
    ]);
    await t.tap(find.text('Refuser'));
    await t.pumpAndSettle();
    expect(find.text('Refuser cette offre'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'no');
    await t.tap(find.text('Refuser').last);
    await t.pumpAndSettle();
    expect(find.text('Écrivez au moins 3 caractères.'), findsOneWidget);
  });

  testWidgets('« Voir tout » de « Rémunérées en premier » active réellement le filtre', (t) async {
    final vide = <Map<String, dynamic>>[];
    await monter(t, const OpportunitiesScreen(), overrides: [
      for (final q in const [OppQuery(), OppQuery(section: 'new'), OppQuery(section: 'closing'), OppQuery(section: 'foryou'), OppQuery(section: 'iut')]) oppsProvider(q).overrideWith((ref) async => vide),
      oppsProvider(const OppQuery(paid: true)).overrideWith((ref) async => [for (var i = 1; i <= 4; i++) _offre(i)]),
      oppHiredProvider.overrideWith((ref) async => vide),
      oppAlertProvider.overrideWith((ref) async => false),
    ]);
    expect(find.text('Rémunérées en premier'), findsOneWidget);
    await t.tap(find.text('Voir tout'));
    await t.pumpAndSettle();
    expect(find.text('Résultats'), findsOneWidget);
    expect(find.text('Rémunérées en premier'), findsNothing);
    expect(find.text('Stage 4'), findsOneWidget);
  });

  test('services : les pastilles filtrent sur le titre et la description, « Tous » ne filtre rien', () {
    final c = ProviderContainer(overrides: [
      publicListingsProvider.overrideWith(() => _Annonces(const [
            Listing(title: 'Logo et identité visuelle', category: 'Services', price: 15000, stock: 1),
            Listing(title: 'Site web sur mesure', category: 'Services', price: 30000, stock: 1, description: 'Développement'),
            Listing(title: 'Cours de soutien en maths', category: 'Services', price: 5000, stock: 1),
            Listing(title: 'Montage vidéo', category: 'Services', price: 10000, stock: 1),
            Listing(title: 'Sac en bâche', category: 'Maison', price: 8000, stock: 3),
          ])),
    ]);
    addTearDown(c.dispose);
    List<String> titres() => [for (final l in c.read(filteredServicesProvider)) l.title];
    expect(titres().length, 4, reason: 'seuls les services publiés, « Tous » sans filtre');
    c.read(serviceFilterProvider.notifier).set(1);
    expect(titres(), ['Logo et identité visuelle']);
    c.read(serviceFilterProvider.notifier).set(2);
    expect(titres(), ['Site web sur mesure']);
    c.read(serviceFilterProvider.notifier).set(3);
    expect(titres(), ['Cours de soutien en maths']);
    c.read(serviceFilterProvider.notifier).set(4);
    expect(titres(), ['Montage vidéo']);
  });
}
