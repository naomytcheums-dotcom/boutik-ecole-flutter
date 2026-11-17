import 'package:boutik_ecole/figma/live/l10_ui.dart';
import 'package:boutik_ecole/figma/live/opportunites_screens.dart' show OpportunityCard;
import 'package:boutik_ecole/figma/live/study_rooms.dart' show RoomWhiteboard;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Lot G7 (étudiant : opportunités, mentors, messagerie, coéquipiers, vœux, salons) : cibles tactiles de 48 dp à 390 px, sans débordement.
void main() {
  setUpAll(loadAppFonts);

  Future<void> monter(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: child)))));
    await t.pump();
  }

  testWidgets('l10Btn (vœux, précommandeurs) : 48 dp de haut, compact ou non', (t) async {
    await monter(t, Column(children: [
      l10Btn('Écrire aux précommandeurs', () {}, width: 342, compact: true),
      const SizedBox(height: 8),
      l10Btn('Précommander', () {}, width: 342),
    ]));
    expect(t.takeException(), isNull);
    Size taille(String label) => t.getSize(find.ancestor(of: find.text(label), matching: find.byType(Container)).first);
    expect(taille('Écrire aux précommandeurs').height, greaterThanOrEqualTo(48));
    expect(taille('Précommander').height, greaterThanOrEqualTo(48));
  });

  testWidgets('carte d\'offre : bouton « Enregistrer » de 48 x 48 dp, rien ne déborde', (t) async {
    await monter(t, OpportunityCard(o: const {'id': 'o1', 'title': 'Stage de design graphique', 'org': 'Atelier Test', 'saved': false, 'skills': ['Figma']}, onTap: () {}, onSave: () {}));
    expect(t.takeException(), isNull);
    final save = find.bySemanticsLabel('Enregistrer l’offre');
    expect(save, findsOneWidget);
    final s = t.getSize(save);
    expect(s.width, greaterThanOrEqualTo(48));
    expect(s.height, greaterThanOrEqualTo(48));
  });

  testWidgets('tableau blanc d\'un salon : choix de couleur et « Tout effacer » de 48 dp', (t) async {
    await monter(t, RoomWhiteboard(strokes: const [], onStroke: (_) {}, onClear: () {}));
    expect(t.takeException(), isNull);
    final couleur = find.bySemanticsLabel('Couleur du trait');
    expect(couleur, findsWidgets);
    for (final e in couleur.evaluate()) {
      final box = e.renderObject! as RenderBox;
      expect(box.size.width, greaterThanOrEqualTo(48));
      expect(box.size.height, greaterThanOrEqualTo(48));
    }
    expect(t.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(48));
  });
}
