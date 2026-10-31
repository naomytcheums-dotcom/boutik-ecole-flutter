import 'package:boutik_ecole/figma/live/lots.dart' show formDialog;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fenêtre de formulaire (dont « Confirmer la remise », écran 146-2) : un double clic sur le bouton de validation
/// ne doit renvoyer la saisie qu'une fois et ne jamais fermer l'écran situé dessous (Flutter ignore les clics sur une
/// fenêtre en cours de fermeture : ce test fige ce comportement).
void main() {
  Future<List<List<String>?>> ouvrir(WidgetTester t) async {
    final results = <List<String>?>[];
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
              builder: (c) => Scaffold(
                body: Column(children: [
                  const Text('Écran kiosque'),
                  TextButton(
                    onPressed: () async => results.add(await formDialog(c, 'Confirmer la remise', [('Numéro de commande', '#BE-1'), ('Code', '123456')], submit: 'Confirmer')),
                    child: const Text('ouvrir'),
                  ),
                ]),
              ),
            )),
            child: const Text('accueil'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('accueil'));
    await t.pumpAndSettle();
    await t.tap(find.text('ouvrir'));
    await t.pumpAndSettle();
    return results;
  }

  testWidgets('double clic sur « Confirmer » : une seule valeur, l’écran du kiosque reste affiché', (t) async {
    final results = await ouvrir(t);
    final bouton = find.widgetWithText(FilledButton, 'Confirmer');
    await t.tap(bouton);
    await t.tap(bouton, warnIfMissed: false); // second clic avant la fin de l'animation de fermeture
    await t.pumpAndSettle();
    expect(results, [
      ['#BE-1', '123456']
    ]);
    expect(find.text('Écran kiosque'), findsOneWidget);
    expect(find.text('accueil'), findsNothing);
  });

  testWidgets('double clic sur « Annuler » : rien n’est renvoyé, l’écran du kiosque reste affiché', (t) async {
    final results = await ouvrir(t);
    final bouton = find.widgetWithText(TextButton, 'Annuler');
    await t.tap(bouton);
    await t.tap(bouton, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(results, [null]);
    expect(find.text('Écran kiosque'), findsOneWidget);
  });
}
