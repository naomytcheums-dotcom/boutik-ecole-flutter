import 'package:boutik_ecole/figma/live/auth.dart' show kSalesTermsVersion, kTermsVersion;
import 'package:boutik_ecole/figma/live/legal.dart' show termsSections;
import 'package:boutik_ecole/figma/live/verification.dart' show StudentVerificationCard, myStudentStatusProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _card(WidgetTester t, Map<String, dynamic> status) async {
  await t.pumpWidget(ProviderScope(
    overrides: [myStudentStatusProvider.overrideWith((ref) async => status)],
    child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StudentVerificationCard()))),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('S1-16/25 : un étudiant non vérifié voit l’état réel et peut demander la certification', (t) async {
    await _card(t, {'verified': false, 'has_identity_document': true, 'certification': 'none', 'can_request_certification': true});
    expect(find.text('Vérification en cours'), findsOneWidget);
    expect(find.text('Demander la certification'), findsOneWidget);
    expect(find.text('Certification : non demandée'), findsOneWidget);
  });

  testWidgets('S1-25 : « Étudiant vérifié » annonce ce qu’il débloque réellement', (t) async {
    await _card(t, {'verified': true, 'has_identity_document': true, 'certification': 'approved', 'can_request_certification': false});
    expect(find.text('Étudiant vérifié'), findsOneWidget);
    expect(find.textContaining('annuaire des talents'), findsOneWidget);
    expect(find.text('Demander la certification'), findsNothing);
  });

  test('S1-60 : les CGV ont leur propre version, distincte des CGU', () {
    expect(kSalesTermsVersion, matches(RegExp(r'^cgv-\d{4}-\d{2}$')));
    expect(kTermsVersion, matches(RegExp(r'^cgu-\d{4}-\d{2}$')));
    expect(kSalesTermsVersion, isNot(kTermsVersion));
  });

  test('S1-60 : le texte des CGV existe et décrit la répartition 70/20/10, les remboursements et les litiges', () {
    expect(termsSections.length, 4);
    final cgv = termsSections[1].map((s) => '${s.$1} ${s.$2}').join('\n');
    expect(cgv, contains('70 %'));
    expect(cgv, contains('20 %'));
    expect(cgv, contains('10 %'));
    expect(cgv.toLowerCase(), contains('remboursement'));
    expect(cgv.toLowerCase(), contains('litige'));
    expect(cgv.toLowerCase(), contains('réclamation'));
  });

  test('S1-13 : la conservation décrit l’anonymisation réellement exécutée', () {
    final conservation = termsSections[2].firstWhere((s) => s.$1 == 'Conservation').$2;
    expect(conservation, contains('anonymis'));
    expect(conservation, contains('30 jours'));
  });
}
