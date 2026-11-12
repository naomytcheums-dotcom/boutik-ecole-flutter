import 'package:boutik_ecole/figma/live/test_accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  test('mot de passe des comptes de test : 10 caractères, une lettre, un chiffre', () {
    expect(validTestPassword('Test12345678'), isTrue);
    expect(validTestPassword('court1A'), isFalse);
    expect(validTestPassword('SansChiffreAAAA'), isFalse);
    expect(validTestPassword('12345678901234'), isFalse);
  });

  test('libellés : un par profil de test', () {
    expect(testRoleLabels.keys, ['visitor', 'client', 'student', 'company', 'other', 'dept', 'direction', 'finance', 'support', 'admin']);
    expect(testAccountLabel({'role': 'dept'}), 'Responsable de département');
    expect(testAccountLabel({'role': 'inconnu'}), 'inconnu');
  });

  testWidgets('aucun compte de test : message et bouton de création', (t) async {
    await _pump(t, const TestAccountsScreen(), overrides: [testAccountsProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.text('Comptes de test'), findsOneWidget);
    expect(find.text('Créer les comptes de test manquants'), findsOneWidget);
    expect(find.text('Changer le mot de passe des comptes de test'), findsOneWidget);
    expect(find.textContaining('Aucun compte de test'), findsOneWidget);
  });

  testWidgets('comptes de test : profil, courriel, dernier accès et ouverture', (t) async {
    await _pump(t, const TestAccountsScreen(), overrides: [
      testAccountsProvider.overrideWith((ref) async => [
            {'id': 'a', 'role': 'student', 'name': 'Test Étudiant-vendeur', 'email': 'test-student@boutik-ecole.test', 'last_login': null},
            {'id': 'b', 'role': 'finance', 'name': 'Test Finance', 'email': 'test-finance@boutik-ecole.test', 'last_login': '2026-11-14T10:00:00Z'},
          ]),
    ]);
    expect(find.text('Étudiant-vendeur'), findsOneWidget);
    expect(find.text('test-student@boutik-ecole.test'), findsOneWidget);
    expect(find.text('Jamais ouvert'), findsOneWidget);
    expect(find.text('Dernière ouverture : 2026-11-14'), findsOneWidget);
    expect(find.text('Ouvrir en tant que ce profil'), findsNWidgets(2));
  });
}
