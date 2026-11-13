import 'package:boutik_ecole/figma/live/profile_extras.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  t.view.physicalSize = const Size(420, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: Scaffold(body: w))));
  await t.pumpAndSettle();
}

void main() {
  test('résumé des disponibilités lisible, vide quand rien n’est renseigné', () {
    expect(availabilitySummary(null), '');
    expect(availabilitySummary({'kinds': <String>[]}), '');
    expect(availabilitySummary({'kinds': ['internship', 'mission'], 'available_from': '2027-01-15'}), 'Stage, Mission · à partir du 15/01/2027');
    expect(availabilitySummary({'kinds': ['job'], 'available_from': null}), 'Job étudiant ou emploi');
    expect(availabilityKinds.keys, ['internship', 'vacation', 'mission', 'job', 'volunteer']);
    expect(languageLevels.keys, ['basic', 'intermediate', 'advanced', 'native']);
  });

  testWidgets('mon profil : invitation à renseigner quand c’est vide', (t) async {
    await _pump(t, const ProfileExtrasCard(), overrides: [profileExtrasProvider('').overrideWith((ref) async => {'mine': true, 'availability': null, 'languages': []})]);
    expect(find.text('Disponibilités'), findsOneWidget);
    expect(find.text('Renseigner'), findsOneWidget);
    expect(find.textContaining('Indiquez si vous cherchez'), findsOneWidget);
    expect(find.text('Aucune langue renseignée.'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget);
  });

  testWidgets('profil d’un étudiant vu par une entreprise : disponibilités et langues, sans boutons de modification', (t) async {
    await _pump(t, const ProfileExtrasCard(userId: 'u1'), overrides: [
      profileExtrasProvider('u1').overrideWith((ref) async => {
            'mine': false,
            'availability': {'kinds': ['internship', 'mission'], 'note': 'Libre le soir', 'available_from': '2027-01-15'},
            'languages': [
              {'language': 'Français', 'level': 'native'},
              {'language': 'Anglais', 'level': 'advanced'}
            ],
          }),
    ]);
    expect(find.text('Stage, Mission · à partir du 15/01/2027'), findsOneWidget);
    expect(find.text('Libre le soir'), findsOneWidget);
    expect(find.text('Français · Langue maternelle'), findsOneWidget);
    expect(find.text('Anglais · Avancé'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Ajouter'), findsNothing);
  });

  testWidgets('profil d’un étudiant sans rien de renseigné : la carte n’apparaît pas', (t) async {
    await _pump(t, const ProfileExtrasCard(userId: 'u2'), overrides: [profileExtrasProvider('u2').overrideWith((ref) async => {'mine': false, 'availability': null, 'languages': []})]);
    expect(find.text('Disponibilités'), findsNothing);
  });
}
