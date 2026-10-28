import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '50': ['Notifications', 'Commande expédiée', 'Plus tôt'],
    '51': ['Notification', 'Prête au retrait', '330 000 FCFA'],
    '52': ['Messages', 'Rechercher une conversation', 'Support Boutik-École'],
    '53': ['Mouanga Yannick', 'Lampe en bois recyclé', '25 000 FCFA'],
    '54': ['Commande #BE-2026-0142', 'Prête au retrait · 25 000 FCFA', 'Merci ! Je passe cet après-midi.'],
    '55': ['Orange Cameroun', 'Budget 300 000 – 500 000 FCFA', 'Répondre à l’entreprise…'],
    '56': ['Notifications et confidentialité', 'Statistiques anonymes', 'Télécharger mes données'],
  });

  testWidgets('50 : filtres et « Tout lire »', (tester) async {
    await pumpScreen(tester, '50');
    expect(find.text('Nouveau'), findsNWidgets(2));
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau message de Yannick'), findsOneWidget);
    expect(find.text('Commande expédiée'), findsNothing);
    await tester.tap(find.text('Toutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout lire'));
    await tester.pumpAndSettle();
    expect(find.text('Nouveau'), findsNothing);
  });

  testWidgets('52 : la recherche filtre les conversations', (tester) async {
    await pumpScreen(tester, '52');
    await tester.enterText(find.byType(TextField), 'drone');
    await tester.pumpAndSettle();
    expect(find.text('Brice Ndoumbe'), findsOneWidget);
    expect(find.text('Mouanga Yannick'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucune conversation trouvée'), findsOneWidget);
  });

  testWidgets('53 : envoyer un message', (tester) async {
    await pumpScreen(tester, '53');
    expect(find.bySemanticsLabel('Message vocal'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Je serai là à 14 h.');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Je serai là à 14 h.'), findsOneWidget);
  });

  testWidgets('56 : basculer une préférence', (tester) async {
    await pumpScreen(tester, '56');
    final toggle = find.bySemanticsLabel('Statistiques anonymes');
    expect(tester.getSemantics(toggle), isSemantics(isToggled: false));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(toggle), isSemantics(isToggled: true));
  });
}
