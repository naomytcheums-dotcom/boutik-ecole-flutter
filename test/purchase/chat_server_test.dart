import 'package:boutik_ecole/figma/live/chat_server.dart';
import 'package:boutik_ecole/figma/live/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('types de pièces jointes acceptés : images, PDF, Word, Excel, texte ; le reste est refusé côté application aussi', () {
    expect(mimeOf('photo.PNG'), 'image/png');
    expect(mimeOf('scan.jpeg'), 'image/jpeg');
    expect(mimeOf('devis.pdf'), 'application/pdf');
    expect(mimeOf('note.txt'), 'text/plain');
    expect(mimeOf('cv.docx'), contains('wordprocessingml'));
    expect(mimeOf('chiffres.xlsx'), contains('spreadsheetml'));
    expect(mimeOf('virus.exe'), isNull);
    expect(mimeOf('page.html'), isNull);
    expect(mimeOf('sans_extension'), isNull);
  });

  test('une conversation de commande garde son numéro de commande', () {
    final c = ConversationItem.fromRow({'id': 'c', 'other_name': 'Alice', 'last_body': 'Photo', 'order_number': '#BE-2026-0156', 'unread': 1});
    expect(c.orderNumber, '#BE-2026-0156');
    expect(ConversationItem.fromRow({'id': 'd'}).orderNumber, '');
  });

  testWidgets('sans conversation choisie : message d\'orientation, aucune saisie possible', (t) async {
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: SizedBox(width: 390, height: 844, child: Stack(children: [ServerChatPanel()]))))));
    await t.pump();
    expect(find.textContaining('Choisissez une conversation'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
