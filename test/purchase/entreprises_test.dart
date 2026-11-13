import 'package:boutik_ecole/figma/live/company_screens.dart';
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
  test('statuts de vérification en toutes lettres', () {
    expect(companyStatusLabel('draft'), contains('Brouillon'));
    expect(companyStatusLabel('pending'), contains('vérification par l’administrateur'));
    expect(companyStatusLabel('approved'), 'Entreprise vérifiée');
    expect(companyStatusLabel('rejected'), 'Vérification refusée');
  });

  test('site web : https obligatoire, vide accepté', () {
    expect(validCompanyWebsite(''), isTrue);
    expect(validCompanyWebsite('https://orange.cm'), isTrue);
    expect(validCompanyWebsite('orange.cm'), isFalse);
    expect(validCompanyWebsite('https://a.cm/ x'), isFalse);
  });

  testWidgets('fiche vide : brouillon, champs, pièces, envoi pour vérification', (t) async {
    await _pump(t, const CompanyProfileScreen(showNav: false), overrides: [companyProvider.overrideWith((ref) async => null)]);
    expect(find.text('Fiche entreprise'), findsOneWidget);
    expect(find.textContaining('Brouillon'), findsOneWidget);
    expect(find.text('Nom de l’entreprise'), findsOneWidget);
    expect(find.text('Numéro d’immatriculation (RCCM)'), findsOneWidget);
    expect(find.text('Pièces justificatives'), findsOneWidget);
    expect(find.text('Aucune pièce pour le moment.'), findsOneWidget);
    expect(find.text('Envoyer pour vérification'), findsOneWidget);
  });

  testWidgets('fiche refusée : motif visible, renvoi possible, pièces listées', (t) async {
    await _pump(t, const CompanyProfileScreen(showNav: false), overrides: [
      companyProvider.overrideWith((ref) async => {
            'company_name': 'Orange Cameroun',
            'sector': 'Télécoms',
            'city': 'Douala',
            'status': 'rejected',
            'review_note': 'Pièce illisible',
            'documents': [
              {'id': 'd1', 'kind': 'registration', 'name': 'RCCM.pdf', 'path': 'u/company/1.pdf', 'mime': 'application/pdf', 'size_bytes': 5000}
            ],
          }),
    ]);
    expect(find.text('Vérification refusée'), findsOneWidget);
    expect(find.text('Motif : Pièce illisible'), findsOneWidget);
    expect(find.text('RCCM.pdf'), findsOneWidget);
    expect(find.text('Immatriculation (RCCM)'), findsWidgets);
    expect(find.text('Renvoyer pour vérification'), findsOneWidget);
  });

  testWidgets('fiche vérifiée : badge, plus d’envoi', (t) async {
    await _pump(t, const CompanyProfileScreen(showNav: false), overrides: [
      companyProvider.overrideWith((ref) async => {'company_name': 'Orange', 'status': 'approved', 'documents': []}),
    ]);
    expect(find.text('Entreprise vérifiée'), findsOneWidget);
    expect(find.text('Envoyer pour vérification'), findsNothing);
  });

  testWidgets('administrateur : file d’examen avec fiche, pièces, valider ou refuser', (t) async {
    await _pump(t, const CompanyReviewScreen(), overrides: [
      companyQueueProvider.overrideWith((ref) async => [
            {
              'owner_id': 'o1',
              'company_name': 'Orange Cameroun',
              'sector': 'Télécoms',
              'city': 'Douala',
              'size': '1000+',
              'contact_name': 'Mme Ndongo',
              'contact_role': 'RH',
              'phone': '699000000',
              'email': 'rh@orange.cm',
              'registration_number': 'RC/DLA/1999/B/1234',
              'documents': [
                {'id': 'd1', 'kind': 'registration', 'name': 'RCCM.pdf', 'path': 'o1/company/1.pdf', 'mime': 'application/pdf'}
              ],
            }
          ]),
    ]);
    expect(find.text('Orange Cameroun'), findsOneWidget);
    expect(find.textContaining('Mme Ndongo (RH)'), findsOneWidget);
    expect(find.text('RCCM.pdf'), findsOneWidget);
    expect(find.text('Voir'), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
  });

  testWidgets('administrateur : aucune demande en attente', (t) async {
    await _pump(t, const CompanyReviewScreen(), overrides: [companyQueueProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.textContaining('Aucune entreprise en attente'), findsOneWidget);
  });
}
