import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '230': ['Assistante vocale Kéla', 'À l’écoute…', 'pour mon parfum, avant fin novembre ?'],
    '231': ['Que fait-on aujourd’hui ?', 'Parle à Kéla', 'Suivre ma mission', 'Voir les profils'],
    '232': ['Voix en texte', 'Crée la mission pour moi', '1:33', 'Écris ou parle à Kéla…'],
    '233': ['Boutik-École', 'L’équipe vient de déposer des propositions de logo.', 'Voir les propositions', 'Preuve'],
    '234': ['Jalon 2 · 72 000 FCFA', 'Paiement bloqué en séquestre', 'Demander une correction'],
    '235': ['Paiement sécurisé', '54 000 FCFA', 'Payer avec Orange Money', 'Séquestre · jalon 1 sur 3'],
    '236': ['Canaux et notifications', 'Où voulez-vous suivre vos missions ?', 'Numéro WhatsApp', 'Enregistrer'],
  });

  setUpAll(loadAppFonts);

  testWidgets('230 : le micro met l’écoute en pause puis la reprend', (tester) async {
    await pumpScreen(tester, '230', size: const Size(390, 844));
    await tester.tap(find.bySemanticsLabel('Mettre l’écoute en pause'));
    await tester.pumpAndSettle();
    expect(find.text('En pause'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Reprendre l’écoute'));
    await tester.pumpAndSettle();
    expect(find.text('À l’écoute…'), findsOneWidget);
  });

  testWidgets('232 : un message saisi apparaît dans la conversation', (tester) async {
    await pumpScreen(tester, '232', size: const Size(390, 844));
    await tester.enterText(find.byType(TextField), 'Oui, une vidéo de 30 secondes');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Oui, une vidéo de 30 secondes'), findsOneWidget);
  });

  testWidgets('233 : message vide refusé, message saisi ajouté au fil', (tester) async {
    await pumpScreen(tester, '233', size: const Size(390, 844));
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Écrivez un message.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Merci, je regarde ce soir');
    await tester.tap(find.bySemanticsLabel('Envoyer'));
    await tester.pumpAndSettle();
    expect(find.text('Merci, je regarde ce soir'), findsOneWidget);
  });

  testWidgets('236 : activer l’e-mail et refuser un numéro WhatsApp invalide', (tester) async {
    await pumpScreen(tester, '236', size: const Size(390, 844));
    expect(find.text('Désactivé'), findsOneWidget);
    await tester.tap(find.text('E-mail'));
    await tester.pumpAndSettle();
    expect(find.text('Désactivé'), findsNothing);
    expect(find.text('Activé'), findsNWidgets(4));

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Numéro invalide : 9 chiffres commençant par 6.'), findsOneWidget);
  });
}
