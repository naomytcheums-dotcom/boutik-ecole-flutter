import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un visiteur explore librement ; la connexion n'est proposée qu'au moment d'une action qui l'exige, et il peut renoncer.
void main() {
  tearDown(() => Backend.ready = false);

  Future<bool?> pump(WidgetTester t, {Account? account}) async {
    bool? result;
    await t.pumpWidget(ProviderScope(
      overrides: [if (account != null) initialAccountProvider.overrideWithValue(account)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(child: TextButton(onPressed: () async => result = await requireLogin(context, ref, 'enregistrer vos favoris'), child: const Text('agir'))),
          ),
        ),
      ),
    ));
    await t.tap(find.text('agir'));
    await t.pumpAndSettle();
    return result;
  }

  testWidgets('visiteur : la demande est proposée avec la possibilité de renoncer, rien n\'est imposé', (t) async {
    Backend.ready = true;
    await pump(t);
    expect(find.text('Un compte est nécessaire'), findsOneWidget);
    expect(find.textContaining('continuer à explorer sans compte'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    await t.tap(find.text('Plus tard'));
    await t.pumpAndSettle();
    expect(find.text('Un compte est nécessaire'), findsNothing);
    expect(find.text('agir'), findsOneWidget); // l'utilisateur est resté où il était
  });

  testWidgets('compte connecté : l\'action passe sans aucune demande', (t) async {
    Backend.ready = true;
    final r = await pump(t, account: demoAccount);
    expect(r, isTrue);
    expect(find.text('Un compte est nécessaire'), findsNothing);
  });

  testWidgets('hors connexion serveur (aperçu, tests) : jamais de blocage', (t) async {
    final r = await pump(t);
    expect(r, isTrue);
    expect(find.text('Un compte est nécessaire'), findsNothing);
  });
}
