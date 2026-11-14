import 'package:boutik_ecole/figma/live/concours_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Map<String, dynamic> a, {bool staff = false, bool admin = false}) async {
  t.view.physicalSize = const Size(420, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: Consumer(builder: (c, ref, _) => ListView(children: prizeActions(c, ref, a, staff: staff, admin: admin)))))));
  await t.pumpAndSettle();
}

void main() {
  const base = {'id': 'a1', 'title': 'Défi solaire', 'status': 'pending', 'prize_amount': 100000};

  testWidgets('récompense à payer : l\'organisateur voit le bouton de paiement', (t) async {
    await _pump(t, {...base, 'prize_status': 'awaiting'});
    expect(find.textContaining('à payer pour pouvoir publier'), findsOneWidget);
    expect(find.textContaining('Payer la récompense'), findsOneWidget);
    expect(find.text('Attribuer la récompense'), findsNothing);
  });

  testWidgets('récompense sous séquestre et annonce publiée : bouton d\'attribution', (t) async {
    await _pump(t, {...base, 'status': 'published', 'prize_status': 'held'});
    expect(find.textContaining('sous séquestre'), findsOneWidget);
    expect(find.text('Attribuer la récompense'), findsOneWidget);
    expect(find.textContaining('Payer la récompense'), findsNothing);
    expect(find.textContaining('Rembourser'), findsNothing);
  });

  testWidgets('administrateur : peut rembourser une récompense sans gagnant, pas payer ni attribuer', (t) async {
    await _pump(t, {...base, 'status': 'published', 'prize_status': 'held'}, staff: true, admin: true);
    expect(find.textContaining('Rembourser l’organisateur'), findsOneWidget);
    expect(find.text('Attribuer la récompense'), findsNothing);
  });

  testWidgets('récompense attribuée : nom du gagnant, aucune action', (t) async {
    await _pump(t, {...base, 'status': 'published', 'prize_status': 'awarded', 'prize_winner_name': 'Alice N.'});
    expect(find.textContaining('attribuée à Alice N.'), findsOneWidget);
    expect(find.textContaining('Payer'), findsNothing);
    expect(find.text('Attribuer la récompense'), findsNothing);
  });

  testWidgets('sans récompense en argent : rien n\'est affiché', (t) async {
    await _pump(t, {...base, 'prize_amount': 0, 'prize_status': 'none'});
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });
}
