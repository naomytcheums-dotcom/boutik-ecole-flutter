import 'package:boutik_ecole/figma/live/company_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('profil de ma propre entreprise : nom, badge, présentation, offres, boutons', (t) async {
    await _pump(t, const CompanyPublicProfileScreen(showNav: false), overrides: [
      companyProfileViewProvider.overrideWith((ref, owner) async => {
            'company_name': 'Orange Cameroun',
            'sector': 'Numérique et télécoms',
            'city': 'Douala',
            'size': '201-1000',
            'description': 'Opérateur de télécoms.',
            'verified': true,
            'mine': true,
            'status': 'approved',
            'offers': [
              {'id': 'o1', 'title': 'Stage développeur', 'kind': 'stage', 'location': 'Douala'}
            ],
            'contests': [],
            'needs_open': 2,
            'recruits': 1,
          }),
    ]);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('Opérateur de télécoms.'), findsOneWidget);
    expect(find.text('Stage développeur'), findsOneWidget);
    expect(find.text('Offres en cours'), findsOneWidget);
    expect(find.text('Modifier la fiche et la vérification'), findsOneWidget);
    expect(find.text('Publier une offre'), findsOneWidget);
    expect(find.text('Couverture'), findsOneWidget);
  });

  testWidgets('profil vu par un étudiant : pas de boutons de gestion', (t) async {
    await _pump(t, const CompanyPublicProfileScreen(owner: 'x', showNav: false), overrides: [
      companyProfileViewProvider.overrideWith((ref, owner) async => {'company_name': 'Orange Cameroun', 'verified': false, 'mine': false, 'offers': [], 'contests': []}),
    ]);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.text('Modifier la fiche et la vérification'), findsNothing);
    expect(find.text('Couverture'), findsNothing);
    expect(find.text('Aucune offre pour le moment.'), findsOneWidget);
  });

  testWidgets('pas encore de fiche : invitation à la créer', (t) async {
    await _pump(t, const CompanyPublicProfileScreen(showNav: false), overrides: [companyProfileViewProvider.overrideWith((ref, owner) async => null)]);
    expect(find.text('Créez le profil de votre entreprise'), findsOneWidget);
    expect(find.text('Compléter la fiche'), findsOneWidget);
  });
}
