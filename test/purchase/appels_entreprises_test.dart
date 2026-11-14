import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/litiges_screens.dart' show DisputesScreen;
import 'package:boutik_ecole/figma/live/marche/marche_appels.dart';
import 'package:boutik_ecole/figma/live/marche/marche_data.dart' show mFcfa;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w, {List<Override> overrides = const []}) async {
  await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('appel à entreprises : un besoin publié s’affiche avec son budget et ses propositions', (t) async {
    await _pump(t, const AppelsScreen(), overrides: [
      marcheCallsProvider.overrideWith((ref) async => [
            {'id': '1', 'title': 'Gestion des stocks pour ma boutique', 'description': 'Je cherche une solution', 'company': 'Boutique Awa', 'budget_min': 50000, 'budget_max': 100000, 'deadline': '30 nov.', 'proposals': 2, 'own': false, 'proposed': false},
            {'id': '2', 'title': 'Logo', 'description': '', 'company': 'Moi', 'proposals': 0, 'own': true, 'proposed': false},
            {'id': '3', 'title': 'Site web', 'description': '', 'company': 'Autre', 'proposals': 1, 'own': false, 'proposed': true},
          ]),
    ]);
    expect(find.text('Gestion des stocks pour ma boutique'), findsOneWidget);
    expect(find.textContaining('Budget : ${mFcfa(50000)} à ${mFcfa(100000)}'), findsOneWidget);
    expect(find.textContaining('2 propositions'), findsOneWidget);
    expect(find.text('Proposer une solution'), findsOneWidget, reason: 'seul le besoin des autres, sans proposition déjà envoyée');
    expect(find.text('Votre besoin'), findsOneWidget);
    expect(find.text('Proposition envoyée'), findsOneWidget);
    expect(find.text('Publier mon besoin'), findsOneWidget);
  });

  testWidgets('appel à entreprises : état vide clair, rien d’inventé', (t) async {
    await _pump(t, const AppelsScreen(), overrides: [marcheCallsProvider.overrideWith((ref) async => <Map<String, dynamic>>[])]);
    expect(find.textContaining('Aucun appel publié pour le moment'), findsOneWidget);
  });

  testWidgets('projets de l’IUT : regroupés par filière avec le badge de validation', (t) async {
    await _pump(t, const ProjetsIutScreen(), overrides: [
      marcheIutProjectsProvider.overrideWith((ref) async => [
            {'id': 'a', 'title': 'Pompe solaire', 'summary': 'Irrigation autonome', 'department': 'Génie civil', 'owner': 'Awa M.', 'owner_id': 'u1'},
            {'id': 'b', 'title': 'Application de caisse', 'summary': '', 'department': 'Génie informatique', 'owner': 'Paul K.', 'owner_id': 'u2'},
          ]),
    ]);
    expect(find.text('Génie civil'), findsOneWidget);
    expect(find.text('Génie informatique'), findsOneWidget);
    expect(find.text('Pompe solaire'), findsOneWidget);
    expect(find.textContaining('Projet validé par l’établissement · Awa M.'), findsOneWidget);
  });

  testWidgets('projets de l’IUT : le nom de l’établissement est affiché quand le serveur le renvoie', (t) async {
    await _pump(t, const ProjetsIutScreen(), overrides: [
      marcheIutProjectsProvider.overrideWith((ref) async => [
            {'id': 'a', 'title': 'Pompe solaire', 'summary': '', 'department': 'Génie civil', 'owner': 'Awa M.', 'owner_id': 'u1', 'institution': 'ENSET de Douala'},
          ]),
    ]);
    expect(find.textContaining('Projet validé par ENSET de Douala · Awa M.'), findsOneWidget);
  });

  testWidgets('visiteur : appels à entreprises et litiges invitent à se connecter', (t) async {
    Backend.ready = true;
    addTearDown(() => Backend.ready = false);
    await _pump(t, const AppelsScreen());
    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    await _pump(t, const DisputesScreen());
    expect(find.text('Connexion requise'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
