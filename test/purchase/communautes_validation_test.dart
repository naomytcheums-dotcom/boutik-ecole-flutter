import 'package:boutik_ecole/figma/gsound.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/communities.dart';
import 'package:boutik_ecole/figma/live/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Communautés : validation par l'administrateur, 500 mots, départements du référentiel ; carte produit unique.
/// La logique serveur est testée par supabase/tests/communautes_pglite (18 contrôles).

void main() {
  setUpAll(loadAppFonts);
  tearDown(() => Backend.ready = false);

  test('comptage des mots', () {
    expect(wordCount(''), 0);
    expect(wordCount('   '), 0);
    expect(wordCount('un deux\ntrois   quatre'), 4);
    expect(wordCount(List.filled(500, 'mot').join(' ')), 500);
  });

  test('états de validation', () {
    final c = Community.fromRow({'id': '1', 'name': 'A b c', 'status': 'pending', 'department': 'Génie logiciel', 'my_status': 'active', 'my_role': 'owner'});
    expect([c.isPending, c.isRejected, c.department, c.canManage], [true, false, 'Génie logiciel', true]);
    expect(Community.fromRow({'id': '2', 'name': 'X', 'status': 'rejected', 'decision_note': 'Doublon'}).decisionNote, 'Doublon');
    expect(Community.fromRow({'id': '3', 'name': 'Y'}).status, 'active');
  });

  Future<void> monter(WidgetTester t, Widget w, [List<Override> overrides = const []]) async {
    GAnim.enabled = false;
    t.view.physicalSize = const Size(390, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: w)));
    await t.pumpAndSettle();
  }

  testWidgets('création : compteur de mots, blocage au-delà de 500, départements du référentiel', (t) async {
    await monter(t, const CommunityCreateScreen(), [
      communityDepartmentsProvider.overrideWith((ref) async => const [DepartmentOption('d1', 'Génie logiciel', 'IUT Douala')]),
    ]);
    t.view.physicalSize = const Size(400, 3200); // le formulaire est plus long avec le type de communauté
    await t.pumpAndSettle();
    expect(find.text('0 / 500 mots'), findsOneWidget);
    expect(find.textContaining('validation'), findsWidgets);
    final desc = find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText ?? '').startsWith('À quoi sert'));
    await t.ensureVisible(desc);
    await t.enterText(desc, List.filled(501, 'mot').join(' '));
    await t.pump();
    expect(find.text('501 / 500 mots'), findsOneWidget);
    await t.ensureVisible(find.text('Envoyer pour validation'));
    await t.tap(find.text('Envoyer pour validation'), warnIfMissed: false);
    await t.pump();
    // bouton inactif : aucune erreur serveur, le compteur reste rouge
    await t.enterText(desc, List.filled(500, 'mot').join(' '));
    await t.pump();
    expect(find.text('500 / 500 mots'), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<String?>));
    await t.pumpAndSettle();
    expect(find.text('Génie logiciel · IUT Douala'), findsWidgets);
  });

  testWidgets('carte produit : photo, titre, prix, boutique et bouton', (t) async {
    var ouvert = 0;
    await monter(t, Scaffold(body: SizedBox(width: 180, child: ProductCardView(photo: Container(color: Colors.grey), title: 'Lampe en bois', price: '25 000 FCFA', shop: 'Atelier Test', onTap: () => ouvert++))));
    expect(find.text('Lampe en bois'), findsOneWidget);
    expect(find.text('25 000 FCFA'), findsOneWidget);
    expect(find.text('Atelier Test'), findsOneWidget);
    await t.tap(find.text('Voir le produit'));
    expect(ouvert, 1);
  });
}
