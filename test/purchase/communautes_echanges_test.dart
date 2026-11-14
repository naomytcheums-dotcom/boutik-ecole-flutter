import 'package:boutik_ecole/figma/live/community_exchanges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester t, Widget w) async {
  await t.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(body: w))));
  await t.pumpAndSettle();
}

void main() {
  test('date d’événement lisible', () {
    expect(eventWhen(DateTime(2026, 11, 20, 18, 30)), '20 nov. · 18 h 30');
    expect(eventWhen(DateTime(2026, 12, 3, 9, 5)), '3 déc. · 09 h 05');
  });

  test('taille de fichier', () {
    expect(fileSizeLabel(500), '1 Ko');
    expect(fileSizeLabel(120000), '118 Ko');
    expect(fileSizeLabel(3 * 1048576), '3.0 Mo');
  });

  testWidgets('chat : réservé aux membres, message clair et aucun champ de saisie', (t) async {
    await _pump(t, const CommunityChatTab(communityId: 'c1', isMember: false));
    expect(find.textContaining('réservé aux membres'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('fichiers : réservés aux membres', (t) async {
    await _pump(t, const CommunityFilesTab(communityId: 'c1', isMember: false));
    expect(find.textContaining('réservés aux membres'), findsOneWidget);
    expect(find.text('Partager un fichier'), findsNothing);
  });

  testWidgets('questions, événements : sans serveur, message explicite et aucune donnée inventée', (t) async {
    await _pump(t, const CommunityQaTab(communityId: 'c1', isMember: true));
    expect(find.textContaining('indisponibles'), findsOneWidget);
    await _pump(t, const CommunityEventsTab(communityId: 'c1', isMember: true));
    expect(find.textContaining('indisponibles'), findsOneWidget);
  });
}
